// usb_host.c

#include <FreeRTOS.h>
#include <queue.h>

#include "usb.h"
#include "usbh_core.h"
#include "usbh_hid.h"
#include "bflb_gpio.h"
#include "hidparser.h"

#include "sysctrl.h"   // for core_id

// #define CHERRY_NEW     // for cu >= 10.2

#include "menu.h"    // for event codes

// queue to send messages to OSD thread
extern QueueHandle_t xQueue;

#define MAX_REPORT_SIZE 8

#define STATE_NONE      0 
#define STATE_DETECTED  1 
#define STATE_RUNNING   2
#define STATE_FAILED    3

extern struct bflb_device_s *gpio;

static struct usb_config {
  osd_t *osd;  
  spi_t *spi;
  
  struct hid_info_S {
    int index;
    int state;
    struct usbh_hid *class;
#ifndef CHERRY_NEW
    struct usbh_urb intin_urb;
#endif
    uint8_t *buffer;
    int nbytes;
    hid_report_t report;
    struct usb_config *usb;
    SemaphoreHandle_t sem;
    TaskHandle_t task_handle;    
    union {
      struct {
	unsigned char last_report[8];	
      } keyboard;
      struct { } mouse;
      struct {
	unsigned char last_state;
      } joystick;
    };
  } hid_info[CONFIG_USBHOST_MAX_HID_CLASS];
} usb_config;
  
USB_NOCACHE_RAM_SECTION USB_MEM_ALIGNX uint8_t hid_buffer[CONFIG_USBHOST_MAX_HID_CLASS][MAX_REPORT_SIZE];

// include the keyboard mappings
#include "atari_st.h"
#include "cbm.h"

const unsigned char *keymap[] = {
  NULL,             // id 0: unknown core
  keymap_atarist,   // id 1: atari st
  keymap_cbm        // id 2: c64
};

const unsigned char *modifier[] = {
  NULL,             // id 0: unknown core
  modifier_atarist, // id 1: atari st
  modifier_cbm      // id 2: c64
};

void kbd_tx(struct hid_info_S *hid, unsigned char byte) {
  spi_t *spi = hid->usb->spi;
  
  printf("KBD: %02x\r\n", byte);

  spi_begin(spi);
  spi_tx_u08(spi, SPI_TARGET_HID);
  spi_tx_u08(spi, SPI_HID_KEYBOARD);
  spi_tx_u08(spi, byte);
  spi_end(spi);
}

// the c64 core can use the numerical pad on the keyboard to
// emulate a joystick
void kbd_num2joy(struct hid_info_S *hid, char state, unsigned char code) {
  static unsigned char kbd_joy_state = 0;
  static unsigned char kbd_joy_state_last = 0;
  
  // mapping:
  // keycode 55 = KP * = selects port
  // keycode 5a = KP 2 = down
  // keycode 5c = KP 4 = left
  // keycode 5e = KP 6 = right
  // keycode 60 = KP 8 = up
  // keycode 62 = KP 0 = fire

  if(state == 0)
    // start parsing a new set of keys
    kbd_joy_state = 0;
  else if(state == 1) {
    // collect key/btn states
    if(code == 0x5e) kbd_joy_state |= 0x01;
    if(code == 0x5c) kbd_joy_state |= 0x02;
    if(code == 0x5a) kbd_joy_state |= 0x04;
    if(code == 0x60) kbd_joy_state |= 0x08;
    if(code == 0x62) kbd_joy_state |= 0x10;
    if(code == 0x55) kbd_joy_state |= 0x20;
  } else if(state == 2) {
    // submit if state has changed
    if(kbd_joy_state != kbd_joy_state_last) {
      
      printf("KP Joy: %02x\r\n", kbd_joy_state);
  
      spi_t *spi = hid->usb->spi;  
      spi_begin(spi);
      spi_tx_u08(spi, SPI_TARGET_HID);
      spi_tx_u08(spi, SPI_HID_JOYSTICK);
      spi_tx_u08(spi, 4);             // report this as joystick 4 as js0-3 are USB joysticks
      spi_tx_u08(spi, kbd_joy_state);
      spi_end(spi);
      
      kbd_joy_state_last = kbd_joy_state;
    }
  }
}
  
void kbd_parse(struct hid_info_S *hid, unsigned char *buffer, int nbytes) {
  // we expect boot mode packets which are exactly 8 bytes long
  if(nbytes != 8) return;
  
  // check if modifier have changed
  if((buffer[0] != hid->keyboard.last_report[0]) && !osd_is_visible(usb_config.osd)) {
    for(int i=0;i<8;i++) {
      if(modifier[core_id][i]) {      
	// modifier released?
	if((hid->keyboard.last_report[0] & (1<<i)) && !(buffer[0] & (1<<i)))
	  kbd_tx(hid, 0x80 | modifier[core_id][i]);
	// modifier pressed?
	if(!(hid->keyboard.last_report[0] & (1<<i)) && (buffer[0] & (1<<i)))
	  kbd_tx(hid, modifier[core_id][i]);
      }
    }
  }

  // prepare for parsing numpad joystick
  if(core_id == CORE_ID_C64) kbd_num2joy(hid, 0, 0);
  
  // check if regular keys have changed
  for(int i=0;i<6;i++) {
    // C64 uses some keys for joystick emulation
    if(core_id == CORE_ID_C64) kbd_num2joy(hid, 1, buffer[2+i]);
    
    if(buffer[2+i] != hid->keyboard.last_report[2+i]) {
      // key released?
      if(hid->keyboard.last_report[2+i] && !osd_is_visible(usb_config.osd))
	kbd_tx(hid, 0x80 | keymap[core_id][hid->keyboard.last_report[2+i]]);
      
      // key pressed?
      if(buffer[2+i])  {
	static unsigned long msg;
	msg = 0;

	// F12 toggles the OSD state. Therefore F12 must never be forwarded
	// to the core and thus must have an empty entry in the keymap. ESC
	// can only close the OSD.

	// Caution: Since the OSD closes on the press event, the following
	// release event will be sent into the core. The core should thus
	// cope with release events that did not have a press event before
	if(buffer[2+i] == 0x45 || (osd_is_visible(usb_config.osd) && buffer[2+i] == 0x29))
	  msg = osd_is_visible(usb_config.osd)?MENU_EVENT_HIDE:MENU_EVENT_SHOW;
	else {
	  if(!osd_is_visible(usb_config.osd))
	    kbd_tx(hid, keymap[core_id][buffer[2+i]]);
	  else {
	    // check if cursor up/down or space has been pressed
	    if(buffer[2+i] == 0x51) msg = MENU_EVENT_DOWN;      
	    if(buffer[2+i] == 0x52) msg = MENU_EVENT_UP;
	    if(buffer[2+i] == 0x4e) msg = MENU_EVENT_PGDOWN;      
	    if(buffer[2+i] == 0x4b) msg = MENU_EVENT_PGUP;
	    if((buffer[2+i] == 0x2c) || (buffer[2+i] == 0x28))
	      msg = MENU_EVENT_SELECT;
	  }
	}
	  
	if(msg)
	  xQueueSendToBackFromISR(xQueue, &msg,  ( TickType_t ) 0);
      }
    }    
  }
  memcpy(hid->keyboard.last_report, buffer, 8);

  // check if numpad joystick has changed state and send message if so
  if(core_id == CORE_ID_C64) kbd_num2joy(hid, 2, 0);
}

// collect bits from byte stream and assemble them into a signed word
static uint16_t collect_bits(uint8_t *p, uint16_t offset, uint8_t size, bool is_signed) {
  // mask unused bits of first byte
  uint8_t mask = 0xff << (offset&7);
  uint8_t byte = offset/8;
  uint8_t bits = size;
  uint8_t shift = offset&7;
  
  //  iprintf("0 m:%x by:%d bi=%d sh=%d ->", mask, byte, bits, shift);
  uint16_t rval = (p[byte++] & mask) >> shift;
  mask = 0xff;
  shift = 8-shift;
  bits -= shift;
  
  // first byte already contained more bits than we need
  if(shift > size) {
    // mask unused bits
    rval &= (1<<size)-1;
  } else {
    // further bytes if required
    while(bits) {
      mask = (bits<8)?(0xff>>(8-bits)):0xff;
      rval += (p[byte++] & mask) << shift;
      shift += 8;
      bits -= (bits>8)?8:bits;
    }
  }
  
  if(is_signed) {
    // do sign expansion
    uint16_t sign_bit = 1<<(size-1);
    if(rval & sign_bit) {
      while(sign_bit) {
	rval |= sign_bit;
	sign_bit <<= 1;
      }
    }
  }
  
  return rval;
}

void mouse_parse(struct hid_info_S *hid, unsigned char *buffer, int nbytes) {
  // we expect at least three bytes:
  if(nbytes < 3) return;
  
  //  printf("MOUSE:"); for(int i=0;i<nbytes;i++) printf(" %02x", buffer[i]); printf("\r\n");

  // collect info about the two axes
  int a[2];
  for(int i=0;i<2;i++) {  
    bool is_signed = hid->report.joystick_mouse.axis[i].logical.min > 
      hid->report.joystick_mouse.axis[i].logical.max;

    a[i] = collect_bits(buffer, hid->report.joystick_mouse.axis[i].offset, 
			hid->report.joystick_mouse.axis[i].size, is_signed);
  }

  // ... and two buttons
  unsigned char btns = 0;
  for(int i=0;i<2;i++)
    if(buffer[hid->report.joystick_mouse.button[i].byte_offset] & 
       hid->report.joystick_mouse.button[i].bitmask)
      btns |= (1<<i);

#if 0
  // decellerate mouse somewhat
  static int x_left = 0;
  static int y_left = 0;

  a[0] += x_left;  a[1] += y_left;       // add bits left from previous 
  x_left = a[0] & 1;  y_left = a[1] & 1; // save bits that would now be lost
  
  a[0] /= 2; a[1] /= 2;
#endif
  
  spi_t *spi = hid->usb->spi;  
  spi_begin(spi);
  spi_tx_u08(spi, SPI_TARGET_HID);
  spi_tx_u08(spi, SPI_HID_MOUSE);
  spi_tx_u08(spi, btns);
  spi_tx_u08(spi, a[0]);
  spi_tx_u08(spi, a[1]);
  spi_end(spi);
}

void joystick_parse(struct hid_info_S *hid, unsigned char *buffer, int nbytes) {
  //  printf("joystick: %d %02x %02x %02x %02x\r\n", nbytes,
  //  	 buffer[0]&0xff, buffer[1]&0xff, buffer[2]&0xff, buffer[3]&0xff);

  unsigned char joy = 0;
  
  // collect info about the two axes
  int a[2];
  for(int i=0;i<2;i++) {  
    bool is_signed = hid->report.joystick_mouse.axis[i].logical.min > 
      hid->report.joystick_mouse.axis[i].logical.max;

    a[i] = collect_bits(buffer, hid->report.joystick_mouse.axis[i].offset, 
			hid->report.joystick_mouse.axis[i].size, is_signed);
  }

  // ... and four buttons
  for(int i=0;i<4;i++)
    if(buffer[hid->report.joystick_mouse.button[i].byte_offset] & 
       hid->report.joystick_mouse.button[i].bitmask)
      joy |= (0x10<<i);

  // map directions to digital
  if(a[0] > 0xc0) joy |= 0x01;
  if(a[0] < 0x40) joy |= 0x02;
  if(a[1] > 0xc0) joy |= 0x04;
  if(a[1] < 0x40) joy |= 0x08;

  if(joy != hid->joystick.last_state) {  
    hid->joystick.last_state = joy;
    printf("JOY: %02x\r\n", joy);
  
    spi_t *spi = hid->usb->spi;  
    spi_begin(spi);
    spi_tx_u08(spi, SPI_TARGET_HID);
    spi_tx_u08(spi, SPI_HID_JOYSTICK);
    spi_tx_u08(spi, 0);
    spi_tx_u08(spi, joy);
    spi_end(spi);
  }
}

void rii_joy_parse(struct hid_info_S *hid, unsigned char *buffer) {
  unsigned char b = 0;
  if(buffer[0] == 0xcd && buffer[1] == 0x00) b = 0x10;      // cd == play/pause  -> center
  if(buffer[0] == 0xe9 && buffer[1] == 0x00) b = 0x08;      // e9 == V+          -> up
  if(buffer[0] == 0xea && buffer[1] == 0x00) b = 0x04;      // ea == V-          -> down
  if(buffer[0] == 0xb6 && buffer[1] == 0x00) b = 0x02;      // b6 == skip prev   -> left
  if(buffer[0] == 0xb5 && buffer[1] == 0x00) b = 0x01;      // b5 == skip next   -> right

  printf("RII Joy: %02x %02x\r\n", 0, b);
  
  spi_t *spi = hid->usb->spi;  
  spi_begin(spi);
  spi_tx_u08(spi, SPI_TARGET_HID);
  spi_tx_u08(spi, SPI_HID_JOYSTICK);
  spi_tx_u08(spi, 0);
  spi_tx_u08(spi, b);
  spi_end(spi);
}

void usbh_hid_callback(void *arg, int nbytes) {
  struct hid_info_S *hid = (struct hid_info_S *)arg;

  xSemaphoreGiveFromISR(hid->sem, NULL);
  hid->nbytes = nbytes;
}  

static void usbh_hid_update(struct usb_config *usb) {
  // check for active devices
  for(int i=0;i<CONFIG_USBHOST_MAX_HID_CLASS;i++) {
    char *dev_str = "/dev/inputX";
    dev_str[10] = '0' + i;
    usb->hid_info[i].class = (struct usbh_hid *)usbh_find_class_instance(dev_str);
    
    if(usb->hid_info[i].class && usb->hid_info[i].state == STATE_NONE) {
      printf("NEW %d\r\n", i);

      printf("Interval: %d\r\n", usb->hid_info[i].class->hport->config.intf[i].altsetting[0].ep[0].ep_desc.bInterval);
	 
      printf("Interface %d\r\n", usb->hid_info[i].class->intf);
      printf("  class %d\r\n", usb->hid_info[i].class->hport->config.intf[i].altsetting[0].intf_desc.bInterfaceClass);
      printf("  subclass %d\r\n", usb->hid_info[i].class->hport->config.intf[i].altsetting[0].intf_desc.bInterfaceSubClass);
      printf("  protocol %d\r\n", usb->hid_info[i].class->hport->config.intf[i].altsetting[0].intf_desc.bInterfaceProtocol);
	
      // parse report descriptor ...
      printf("report descriptor: %p\r\n", usb->hid_info[i].class->report_desc);
      
      if(!parse_report_descriptor(usb->hid_info[i].class->report_desc, 128, &usb->hid_info[i].report)) {
	usb->hid_info[i].state = STATE_FAILED;   // parsing failed, don't use
	return;
      }
      
      usb->hid_info[i].state = STATE_DETECTED;
    }
    
    else if(!usb->hid_info[i].class && usb->hid_info[i].state != STATE_NONE) {
      printf("LOST %d\r\n", i);
      vTaskDelete( usb->hid_info[i].task_handle );
      usb->hid_info[i].state = STATE_NONE;
    }
  }

  // check for number of mice and keyboards and update leds
  int mice = 0, keyboards = 0;  
  for(int i=0;i<CONFIG_USBHOST_MAX_HID_CLASS;i++) {
    if(usb->hid_info[i].state == STATE_RUNNING) {
      if(usb->hid_info[i].report.type == REPORT_TYPE_MOUSE)    mice++;
      if(usb->hid_info[i].report.type == REPORT_TYPE_KEYBOARD) keyboards++;      
    }
  }

  extern void set_led(int pin, int on);
  set_led(GPIO_PIN_27, mice);
  set_led(GPIO_PIN_28, keyboards);
}

static void hid_parse(struct hid_info_S *hid) {
#if 0
  USB_LOG_RAW("CB%d: ", hid->index);
  
  // just dump the report
  for (size_t i = 0; i < hid->nbytes; i++) 
    USB_LOG_RAW("0x%02x ", hid->buffer[i]);
  USB_LOG_RAW("\r\n");
#endif
  
  // the following is a hack for the Rii keyboard/touch combos to use the
  // left top multimedia pad as a joystick. These special keys are sent
  // via the mouse/touchpad part
  if(hid->report.report_id_present &&
     hid->report.type == REPORT_TYPE_MOUSE &&
     hid->nbytes == 3 &&
     hid->buffer[0] != hid->report.report_id) {
    rii_joy_parse(hid, hid->buffer+1);
    return;
  }
  
  // check and skip report id if present
  unsigned char *buffer = hid->buffer;
  if(hid->report.report_id_present) {
    if(!hid->nbytes || (buffer[0] != hid->report.report_id))
      return;
    
    // skip report id
    buffer++; hid->nbytes--;
  }
  
  if(hid->nbytes == hid->report.report_size) {
    if(hid->report.type == REPORT_TYPE_KEYBOARD)
      kbd_parse(hid, buffer, hid->nbytes);
    
    if(hid->report.type == REPORT_TYPE_MOUSE)
      mouse_parse(hid, buffer, hid->nbytes);
    
    if(hid->report.type == REPORT_TYPE_JOYSTICK)
      joystick_parse(hid, buffer, hid->nbytes);
  }
}

// each HID client gets itws own thread which submits urbs
// and waits for the interrupt to succeed
static void usbh_hid_client_thread(void *argument) {
  struct hid_info_S *hid = (struct hid_info_S *)argument;

  printf("HID client #%d: thread started\r\n", hid->index);

  while(1) {
#ifndef CHERRY_NEW
    int ret = usbh_submit_urb(&hid->intin_urb);
#else
    int ret = usbh_submit_urb(&hid->class->intin_urb);
#endif
    if (ret < 0)
      printf("HID client #%d: submit failed\r\n", hid->index);
    else {
      // Wait for result
      xSemaphoreTake(hid->sem, 0xffffffffUL);
      if(hid->nbytes > 0) hid_parse(hid);
      hid->nbytes = 0;
    }      

    // todo: honour binterval which is in milliseconds for low speed
    vTaskDelay(pdMS_TO_TICKS(10));
  }
}

static void usbh_hid_thread(void *argument) {
  printf("Starting usb host task...\r\n");

  struct usb_config *usb = (struct usb_config *)argument;

  // request status (currently only dummy data, will return 0x5c, 0x42)
  // in the long term the core is supposed to return its HID demands
  // (keyboard matrix type, joystick type and number, ...)
  
  spi_begin(usb->spi);
  spi_tx_u08(usb->spi, SPI_TARGET_HID);
  spi_tx_u08(usb->spi, SPI_HID_STATUS);
  spi_tx_u08(usb->spi, 0x00);
  printf("HID status #0: %02x\r\n", spi_tx_u08(usb->spi, 0x00));
  printf("HID status #1: %02x\r\n", spi_tx_u08(usb->spi, 0x00));
  spi_end(usb->spi);

  while (1) {
    usbh_hid_update(usb);

    for(int i=0;i<CONFIG_USBHOST_MAX_HID_CLASS;i++) {
      if(usb->hid_info[i].state == STATE_DETECTED) {
	printf("NEW device %d\r\n", i);
	usb->hid_info[i].state = STATE_RUNNING; 

#if 0
	// set report protocol 1 if subclass != BOOT_INTF
	// CherryUSB doesn't report the InterfaceSubClass (HID_BOOT_INTF_SUBCLASS)
	// we thus set boot protocol on keyboards
	if( usb->hid_info[i].report.type == REPORT_TYPE_KEYBOARD ) {	
	  // /* 0x0 = boot protocol, 0x1 = report protocol */
	  printf("setting boot protocol\r\n");
	  ret = usbh_hid_set_protocol(usb->hid_info[i].class, HID_PROTOCOL_BOOT);
	  if (ret < 0) {
	    printf("failed\r\n");
	    usb->hid_info[i].state = STATE_FAILED;  // failed
	    continue;
	  }
	}
#endif

	// setup urb
	usbh_int_urb_fill(
#ifdef CHERRY_NEW
			  &usb->hid_info[i].class->intin_urb,
			  usb->hid_info[i].class->hport,
#else
			  &usb->hid_info[i].intin_urb,
#endif
			  usb->hid_info[i].class->intin, usb->hid_info[i].buffer,
			  usb->hid_info[i].report.report_size + (usb->hid_info[i].report.report_id_present ? 1:0),
			  0, usbh_hid_callback, &usb->hid_info[i]);
	
	// start a new thread for the new device
	xTaskCreate(usbh_hid_client_thread, (char *)"usb_task", 2048, &usb->hid_info[i], configMAX_PRIORITIES-3, &usb->hid_info[i].task_handle );
      }
    }
    // this thread only handles new devices and thus doesn't have to run very
    // often
    vTaskDelay(pdMS_TO_TICKS(100));
  }
}

void usbh_hid_run(struct usbh_hid *hid_class) { }
void usbh_hid_stop(struct usbh_hid *hid_class) { }

void usb_register_osd(osd_t *osd) {
  usb_config.osd = osd;
}

void usb_host(spi_t *spi) {
  TaskHandle_t usb_handle;

  printf("init usb hid host\r\n");

  usbh_initialize();  
  usb_config.spi = spi;
  usb_config.osd = NULL;
  
  // initialize all HID info entries
  for(int i=0;i<CONFIG_USBHOST_MAX_HID_CLASS;i++) {
    usb_config.hid_info[i].index = i;
    usb_config.hid_info[i].state = 0;
    usb_config.hid_info[i].buffer = hid_buffer[i];      
    usb_config.hid_info[i].usb = &usb_config;
    usb_config.hid_info[i].sem = xSemaphoreCreateBinary();
  }

  xTaskCreate(usbh_hid_thread, (char *)"usb_task", 2048, &usb_config, configMAX_PRIORITIES-3, &usb_handle);
}

// hid event triggered by FPGA
void hid_handle_event(void) {
  spi_t *spi = usb_config.spi;
  
  spi_begin(spi);
  spi_tx_u08(spi, SPI_TARGET_HID);
  spi_tx_u08(spi, SPI_HID_GET_DB9);
  spi_tx_u08(spi, 0x00);
  uint8_t db9 = spi_tx_u08(spi, 0x00);
  spi_end(spi);

  printf("DB9: %02x\r\n", db9);
}

// usb_host.c

#include <FreeRTOS.h>
#include <queue.h>

#include "usb.h"
#include "usbh_core.h"
#include "usbh_hid.h"
#include "bflb_gpio.h"
#include "hidparser.h"

#include "menu.h"    // for event codes

// queue to send messages to OSD thread
extern QueueHandle_t xQueue;

// queue to send messages from interrupt callback to local thread
static QueueHandle_t iQueue;

#define MAX_REPORT_SIZE 8

#define STATE_NONE      0 
#define STATE_DETECTED  1 
#define STATE_RUNNING   2
#define STATE_FAILED    3

extern struct bflb_device_s *gpio;

static struct usb_config {
  // The USB side keeps track of the OSDs visibility as this will also
  // suppress forwarding of HID events into the core
  int osd_is_visible;
  
  spi_t *spi;
  
  struct hid_info_S {
    int state;
    struct usbh_hid *class;
    struct usbh_urb intin_urb;
    uint8_t *buffer;
    hid_report_t report;
    struct usb_config *usb;
  } hid_info[CONFIG_USBHOST_MAX_HID_CLASS];
} usb_config;
  
USB_NOCACHE_RAM_SECTION USB_MEM_ALIGNX uint8_t hid_buffer[CONFIG_USBHOST_MAX_HID_CLASS][MAX_REPORT_SIZE];

#include "atari_st.h"

void kbd_tx(struct usb_config *usb, unsigned char byte) {
  printf("KBD: %02x\r\n", byte);

  unsigned char kbd_cmd[4] = { SPI_HID_KEYBOARD, byte, 0, 0 };
  xQueueSendToBackFromISR(iQueue, kbd_cmd,  ( TickType_t ) 0);
}

void kbd_parse(struct usb_config *usb, unsigned char *buffer, int nbytes) {
  // we expect boot mode packets which are exactly 8 bytes long
  if(nbytes != 8) return;
  
  // store local list of pressed keys to detect key release
  static unsigned char last_report[8] = { 0,0,0,0,0,0,0,0 };

  // check if modifier have changed
  if((buffer[0] != last_report[0]) && !usb_config.osd_is_visible) {
    for(int i=0;i<8;i++) {
      if(modifier_atarist[i]) {      
	// modifier released?
	if((last_report[0] & (1<<i)) && !(buffer[0] & (1<<i)))
	  kbd_tx(usb, 0x80 | modifier_atarist[i]);
	// modifier pressed?
	if(!(last_report[0] & (1<<i)) && (buffer[0] & (1<<i)))
	  kbd_tx(usb, modifier_atarist[i]);
      }
    }
  }

  // check if regular keys have changed
  for(int i=0;i<6;i++) {
    if(buffer[2+i] != last_report[2+i]) {
      // key released?
      if(last_report[2+i] && !usb_config.osd_is_visible)
	kbd_tx(usb, 0x80 | keymap_atarist[last_report[2+i]]);
      
      // key pressed?
      if(buffer[2+i])  {
	unsigned long msg = 0;

	// F12 toggles the OSD state. Therefore F12 must never be forwarded
	// to the core and thus must have an empty entry in the keymap. ESC
	// can only close the OSD.

	// Caution: Since the OSD closes on the press event, the following
	// release event will be sent into the core. The core should thus
	// cope with release events that did not have a press event before
	if(buffer[2+i] == 0x45 || (usb_config.osd_is_visible && buffer[2+i] == 0x29)) {
	  msg = usb_config.osd_is_visible?MENU_EVENT_HIDE:MENU_EVENT_SHOW;
	  usb_config.osd_is_visible = !usb_config.osd_is_visible;
	} else {

	  if(!usb_config.osd_is_visible)
	    kbd_tx(usb, keymap_atarist[buffer[2+i]]);
	  else {
	    // check if cursor up/down or space has been pressed
	    if(buffer[2+i] == 0x51) msg = MENU_EVENT_DOWN;      
	    if(buffer[2+i] == 0x52) msg = MENU_EVENT_UP;
	    if(buffer[2+i] == 0x2c) msg = MENU_EVENT_SELECT;
	  }
	}
	  
	if(msg) xQueueSendToBackFromISR(xQueue, &msg,  ( TickType_t ) 0);
      }
    }    
  }
  memcpy(last_report, buffer, 8);
}

void mouse_parse(struct usb_config *usb, signed char *buffer, int nbytes) {
  // we expect at least three bytes:
  if(nbytes < 3) return;

  // decellerate mouse somewhat
  buffer[1] /= 2;
  buffer[2] /= 2;

  printf("MOUSE: %02x %d %d\r\n", buffer[0], buffer[1], buffer[2]);
  
  unsigned char mouse_cmd[4] = { SPI_HID_MOUSE, buffer[0], buffer[1], buffer[2] };
  xQueueSendToBackFromISR(iQueue, mouse_cmd,  ( TickType_t ) 0);
}

void usbh_hid_callback(void *arg, int nbytes) {
  struct hid_info_S *hid_info = (struct hid_info_S *)arg;

  // nbytes < 0 means something went wrong. E.g. a devices connected to a hub was
  // disconnected, but the hub wasn't monitored. Sometimes this just happens when
  // two configs are polled at the same time
  if(nbytes < 0) {
    USB_LOG_RAW("fail\r\n");
    // hid_info->state = STATE_FAILED;
    return;
  }
  
  if (nbytes > 0) {
    USB_LOG_RAW("CB%d: ", hid_info->class->minor);
  
    // just dump the report
    for (size_t i = 0; i < nbytes; i++) 
      USB_LOG_RAW("0x%02x ", hid_info->buffer[i]);
    USB_LOG_RAW("\r\n");
    
    // parse reply
    
    // check and skip report id if present
    unsigned char *buffer = hid_info->buffer;
    if(hid_info->report.report_id_present) {
      if(!nbytes || (buffer[0] != hid_info->report.report_id))
	return;

      // skip report id
      buffer++; nbytes--;
    }
  
    if(nbytes == hid_info->report.report_size) {
      if(hid_info->report.type == REPORT_TYPE_KEYBOARD)
	kbd_parse(hid_info->usb, buffer, nbytes);
      
      if(hid_info->report.type == REPORT_TYPE_MOUSE)
	mouse_parse(hid_info->usb, (signed char*)buffer, nbytes);
    }
  }
  //  else
  //    USB_LOG_RAW("no data\r\n");
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
      usb->hid_info[i].state = STATE_NONE;
    }
  }

#ifdef M0S_DOCK
  // check for number of mice and keyboards and update leds
  int mice = 0, keyboards = 0;  
  for(int i=0;i<CONFIG_USBHOST_MAX_HID_CLASS;i++) {
    if(usb->hid_info[i].state == STATE_RUNNING) {
      if(usb->hid_info[i].report.type == REPORT_TYPE_MOUSE)    mice++;
      if(usb->hid_info[i].report.type == REPORT_TYPE_KEYBOARD) keyboards++;      
    }
  }
  
  if(mice)      bflb_gpio_reset(gpio, GPIO_PIN_27);
  else          bflb_gpio_set(gpio, GPIO_PIN_27);
  
  if(keyboards) bflb_gpio_reset(gpio, GPIO_PIN_28);
  else          bflb_gpio_set(gpio, GPIO_PIN_28);
#endif 
      
}

static void usbh_hid_thread(void *argument) {
  int ret;

  struct usb_config *usb = (struct usb_config *)argument;

  // request status (currently only dummy data, will return 0x5c, 0x42)
  spi_begin(usb->spi);
  spi_tx_u08(usb->spi, SPI_TARGET_HID);
  spi_tx_u08(usb->spi, SPI_HID_STATUS);
  spi_tx_u08(usb->spi, 0x00);
  printf("HID status #0: %02x\r\n", spi_tx_u08(usb->spi, 0x00));
  printf("HID status #1: %02x\r\n", spi_tx_u08(usb->spi, 0x00));
  spi_end(usb->spi);

  // queue to receive messages from ISR/callback, 10 entries of 4 bytes each
  iQueue = xQueueCreate(10, 4);

  while (1) {
    unsigned char cmd[4];
    
    usbh_hid_update(usb);

    // TODO: reduce the wait time, so a stream of USB data won't block the loop
    // int ms = pdTICKS_TO_MS(xTaskGetTickCount());
  
    // read from queue with 10ms timeout and forward HID commands via spi to core
    while(xQueueReceive( iQueue, cmd, pdMS_TO_TICKS(10))) {
      spi_begin(usb->spi);
      spi_tx_u08(usb->spi, SPI_TARGET_HID);
      spi_tx_u08(usb->spi, cmd[0]);
      spi_tx_u08(usb->spi, cmd[1]);

      // mouse has two more bytes to send
      if(cmd[0] == SPI_HID_MOUSE) {
	spi_tx_u08(usb->spi, cmd[2]);
	spi_tx_u08(usb->spi, cmd[3]);
      }
    
      spi_end(usb->spi);      
    }
    // usb_osal_msleep(10);
      
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
	
	// request first urb
	printf("%d: Submit urb size %d\r\n", i, usb->hid_info[i].report.report_size + (usb->hid_info[i].report.report_id_present ? 1:0));
	usbh_int_urb_fill(&usb->hid_info[i].intin_urb, usb->hid_info[i].class->intin, usb->hid_info[i].buffer,
			  usb->hid_info[i].report.report_size + (usb->hid_info[i].report.report_id_present ? 1:0),
			  0, usbh_hid_callback, &usb->hid_info[i]);
	ret = usbh_submit_urb(&usb->hid_info[i].intin_urb);
	if (ret < 0) {
	  // submit failed
	  printf("initial submit failed\r\n");
	  usb->hid_info[i].state = STATE_FAILED;
	  continue;
	}
      } else if(usb->hid_info[i].state == STATE_RUNNING) {
	// todo: honour binterval which is in milliseconds for low speed
	// todo: wait for callback
	ret = usbh_submit_urb(&usb->hid_info[i].intin_urb);
	// if (ret < 0) printf("submit failed\r\n");
      }
    }
  }
}

void usbh_hid_run(struct usbh_hid *hid_class) { }
void usbh_hid_stop(struct usbh_hid *hid_class) { }

void usb_host(spi_t *spi) {
  printf("init usb hid host\r\n");

  usb_config.spi = spi;
  
  usbh_initialize();

  // mark all HID info entries as unused
  for(int i=0;i<CONFIG_USBHOST_MAX_HID_CLASS;i++) {
    usb_config.hid_info[i].state = 0;
    usb_config.hid_info[i].buffer = hid_buffer[i];      
    usb_config.hid_info[i].usb = &usb_config;
  }

  usb_osal_thread_create("usbh_hid", 2048, CONFIG_USBHOST_PSC_PRIO + 1, usbh_hid_thread, &usb_config);
}

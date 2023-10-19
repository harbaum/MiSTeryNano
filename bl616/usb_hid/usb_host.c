// usb_host.c

#include "usbh_core.h"
#include "usbh_hid.h"
#include "bflb_gpio.h"
#include "hidparser.h"

#define MAX_REPORT_SIZE 8

#define STATE_NONE      0 
#define STATE_DETECTED  1 
#define STATE_RUNNING   2
#define STATE_FAILED    3

struct hid_info_S {
  int state;
  struct usbh_hid *class;
  struct usbh_urb intin_urb;
  uint8_t *buffer;
  hid_report_t report;
} hid_info[CONFIG_USBHOST_MAX_HID_CLASS];

USB_NOCACHE_RAM_SECTION USB_MEM_ALIGNX uint8_t hid_buffer[CONFIG_USBHOST_MAX_HID_CLASS][MAX_REPORT_SIZE];

extern struct bflb_device_s *gpio;

#define DEV_KBD   0
#define DEV_MOUSE 1

void ps2_tx_bit(int dev, char bit) {
  static const int clk[]  = { GPIO_PIN_11, GPIO_PIN_13 };
  static const int data[] = { GPIO_PIN_10, GPIO_PIN_12 };
  
  // intended clock is ~14kHz
  
  // set data bit
  if(bit) bflb_gpio_set(gpio, clk[dev]);
  else    bflb_gpio_reset(gpio, clk[dev]);
  bflb_mtimer_delay_us(10);
    
  // clock low
  bflb_gpio_reset(gpio, data[dev]);
  bflb_mtimer_delay_us(30);
  
  // clock high
  bflb_gpio_set(gpio, data[dev]);
  bflb_mtimer_delay_us(30);
}

void ps2_tx_byte(int dev, unsigned char byte) {
  char parity = 1;

  printf("%c-TX %02x\r\n", (dev==DEV_KBD)?'K':'M', byte);
  
  ps2_tx_bit(dev, 0);     // start bit

  for(int i=0;i<8;i++) {
    ps2_tx_bit(dev, byte & 1);
    if(byte & 1) parity = !parity;
    byte >>= 1;
  }
    
  ps2_tx_bit(dev, parity);
  ps2_tx_bit(dev, 1);     // stop bit

  // stop bit leaves clk and data high
}

#include "keycodes.h"

void ps2_kbd_tx_ps2(char make, unsigned short ps2) {
  if(ps2 & EXT)  ps2_tx_byte(DEV_KBD, 0xe0);
  
  // send break code
  if(!make)  ps2_tx_byte(DEV_KBD, 0xf0);

  ps2_tx_byte(DEV_KBD, ps2 & 0xff);
}

void ps2_kbd_tx(char make, unsigned char code) {
  // ignore everything outside table
  if(code >= 0x70) return;

  ps2_kbd_tx_ps2(make, usb2ps2[code]);
}

void kbd_parse(unsigned char *buffer, int nbytes) {
  /* usb modifer bits:
        0     1     2    3    4     5     6    7
     LCTRL LSHIFT LALT LGUI RCTRL RSHIFT RALT RGUI
  */

  static const unsigned short ps2_modifier[] = 
    { 0x14, 0x12, 0x11, EXT|0x1f, EXT|0x14, 0x59, EXT|0x11, EXT|0x27 };

  // we expect boot mode packets which are exactly 8 bytes long
  if(nbytes != 8) return;
  
  // store local list of pressed keys to detect key release
  static unsigned char last_report[8] = { 0,0,0,0,0,0,0,0 };

  // check if modifier have changed
  if(buffer[0] != last_report[0]) {
    for(int i=0;i<8;i++) {
      // modifier released?
      if((last_report[0] & (1<<i)) && !(buffer[0] & (1<<i)))
	 ps2_kbd_tx_ps2(0, ps2_modifier[i]);
      // modifier pressed?
      if(!(last_report[0] & (1<<i)) && (buffer[0] & (1<<i)))
	 ps2_kbd_tx_ps2(1, ps2_modifier[i]);
    }
  }

  // check if regular keys have changed
  for(int i=0;i<6;i++) {
    if(buffer[2+i] != last_report[2+i]) {
      // key released?
      if(last_report[2+i]) ps2_kbd_tx(0, last_report[2+i]);      
      // key pressed?
      if(hid_info->buffer[2+i]) ps2_kbd_tx(1, buffer[2+i]);
    }    
  }
  
  memcpy(last_report, buffer, 8);
}

void mouse_parse(signed char *buffer, int nbytes) {
  // we expect at least three bytes:
  if(nbytes < 3) return;

  // decellerate mouse somewhat and invert y-axis
  buffer[1] /= 2;
  buffer[2] = -buffer[2]/2;
  
  // first byte contains buttons and overflow and sign bits
  unsigned char b0 = buffer[0] & 3;  // buttons
  b0 |= 0x08;                        // always 1
  if(buffer[2] < 0) b0 |= 0x10;      // negative x
  if(buffer[1] < 0) b0 |= 0x20;      // negative y

  ps2_tx_byte(DEV_MOUSE, b0);
  ps2_tx_byte(DEV_MOUSE, buffer[2]);
  ps2_tx_byte(DEV_MOUSE, buffer[1]);
  ps2_tx_byte(DEV_MOUSE, 0x00);       // z-axis
}

void usbh_hid_callback(void *arg, int nbytes) {
  struct hid_info_S *hid_info = (struct hid_info_S *)arg;

  USB_LOG_RAW("CB%d: ", hid_info->class->minor);
  
  // nbytes < 0 means something went wrong. E.g. a devices connected to a hub was
  // disconnected, but the hub wasn't monitored
  if(nbytes < 0) {
    USB_LOG_RAW("fail\r\n");
    hid_info->state = STATE_FAILED;
    return;
  }
  
  if (nbytes > 0) {
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
	kbd_parse(buffer, nbytes);
      
      if(hid_info->report.type == REPORT_TYPE_MOUSE)
	mouse_parse((signed char*)buffer, nbytes);
    }
  } else
    USB_LOG_RAW("no data\r\n");
    
  // TODO: submit at rate specified by endpoint 
  
  // re-submit urb for next request
  //  usbh_submit_urb(&hid_info->intin_urb);
}  

static void usbh_hid_update(void) {
  // check for active devices
  for(int i=0;i<CONFIG_USBHOST_MAX_HID_CLASS;i++) {
    char *dev_str = "/dev/inputX";
    dev_str[10] = '0' + i;
    hid_info[i].class = (struct usbh_hid *)usbh_find_class_instance(dev_str);
    
    if(hid_info[i].class && hid_info[i].state == STATE_NONE) {
      printf("NEW %d\r\n", i);

      // class struct:
      // struct usbh_hubport *hport;
      //
      // uint8_t report_desc[128];
      // uint8_t intf; /* interface number */
      // uint8_t minor;
      // usbh_pipe_t intin;  /* INTR IN endpoint */
      // usbh_pipe_t intout; /* INTR OUT endpoint */

      printf("Interval: %d\r\n", hid_info[i].class->hport->config.intf[i].altsetting[0].ep[0].ep_desc.bInterval);
	 
      printf("Interface %d\r\n", hid_info[i].class->intf);
      printf("  class %d\r\n", hid_info[i].class->hport->config.intf[i].altsetting[0].intf_desc.bInterfaceClass);
      printf("  subclass %d\r\n", hid_info[i].class->hport->config.intf[i].altsetting[0].intf_desc.bInterfaceSubClass);
      printf("  protocol %d\r\n", hid_info[i].class->hport->config.intf[i].altsetting[0].intf_desc.bInterfaceProtocol);
	
      // cherryusb does not store the descriptor length. So try to figure it out
      // It's probably safe to assume that the hid report ends with an "end collection" (c0)
      int len = 128;
      while(len>0 && hid_info[i].class->report_desc[len-1] != HID_MAIN_ITEM_ENDCOLLECTION_PREFIX) len--;

      if(!len) {
	printf("no valid report descriptor\r\n");
	hid_info[i].state = STATE_FAILED;
	return;	
      }
      
      // parse report descriptor ...
      printf("report descriptor: %p, len=%d\r\n", hid_info[i].class->report_desc, len);
      
      if(!parse_report_descriptor(hid_info[i].class->report_desc, len, &hid_info[i].report)) {
	hid_info[i].state = STATE_FAILED;   // parsing failed, don't use
	return;
      }
      
      hid_info[i].state = STATE_DETECTED;
    }
    
    else if(!hid_info[i].class && hid_info[i].state != STATE_NONE) {
      printf("LOST %d\r\n", i);
      hid_info[i].state = STATE_NONE;
    }
  }
}

static void usbh_hid_thread(void *argument)
{
  int ret;

  while (1) {
    usbh_hid_update();
    
    usb_osal_msleep(10);

    for(int i=0;i<CONFIG_USBHOST_MAX_HID_CLASS;i++) {
      if(hid_info[i].state == STATE_DETECTED) {
	printf("NEW device %d\r\n", i);
	hid_info[i].state = STATE_RUNNING; 

#if 0
	// set report protocol 1 if subclass != BOOT_INTF
	// CherryUSB doesn't report the InterfaceSubClass (HID_BOOT_INTF_SUBCLASS)
	// we thus set boot protocol on keyboards
	if( hid_info[i].report.type == REPORT_TYPE_KEYBOARD ) {	
	  // /* 0x0 = boot protocol, 0x1 = report protocol */
	  printf("setting boot protocol\r\n");
	  ret = usbh_hid_set_protocol(hid_info[i].class, HID_PROTOCOL_BOOT);
	  if (ret < 0) {
	    printf("failed\r\n");
	    hid_info[i].state = STATE_FAILED;  // failed
	    continue;
	  }
	}
#endif
	
	// request first urb
	printf("%d: Submit urb size %d\r\n", i, hid_info[i].report.report_size + (hid_info[i].report.report_id_present ? 1:0));
	usbh_int_urb_fill(&hid_info[i].intin_urb, hid_info[i].class->intin, hid_info[i].buffer,
			  hid_info[i].report.report_size + (hid_info[i].report.report_id_present ? 1:0), 0, usbh_hid_callback, &hid_info[i]);
	ret = usbh_submit_urb(&hid_info[i].intin_urb);
	if (ret < 0) {
	  // submit failed
	  printf("initial submit failed\r\n");
	  hid_info[i].state = STATE_FAILED;
	  continue;
	}
      } else if(hid_info[i].state == STATE_RUNNING) {
	// todo: honour binterval which is in milliseconds for low speed
	// todo: wait for callback
	ret = usbh_submit_urb(&hid_info[i].intin_urb);
	// if (ret < 0) printf("submit failed\r\n");
      }
    }
  }
}

void usbh_hid_run(struct usbh_hid *hid_class) {
  printf("HID run\r\n");
  // LED 1 on
  bflb_gpio_reset(gpio, GPIO_PIN_27);
}

void usbh_hid_stop(struct usbh_hid *hid_class) {
  printf("HID stop\r\n");
  // LED 1 off
  bflb_gpio_set(gpio, GPIO_PIN_27);
}

void usbh_class_test(void) {
  printf("init usbh class\r\n");

  // mark all HID info entries as unused
  for(int i=0;i<CONFIG_USBHOST_MAX_HID_CLASS;i++) {
    hid_info[i].state = 0;
    hid_info[i].buffer = hid_buffer[i];      
  }

  usb_osal_thread_create("usbh_hid", 2048, CONFIG_USBHOST_PSC_PRIO + 1, usbh_hid_thread, NULL);
}

/* hid.h */

#ifndef HID_H
#define HID_H

#include <stdbool.h>
#include "hidparser.h"

struct hid_kbd_state_S {
  unsigned char last_report[8];	
};

struct hid_mouse_state_S {
};

struct hid_joystick_state_S {
  unsigned char last_state;
  unsigned char js_index;
  unsigned char last_state_x;
  unsigned char last_state_y;
  unsigned char last_state_btn_extra;
};

// parsers are re-used from usb_host
void kbd_parse(spi_t *spi, hid_report_t *report, struct hid_kbd_state_S *state, const unsigned char *buffer, int nbytes);
void mouse_parse(spi_t *spi, hid_report_t *report, struct hid_mouse_state_S *state, const unsigned char *buffer, int nbytes);
void joystick_parse(spi_t *spi, hid_report_t *report, struct hid_joystick_state_S *state, const unsigned char *buffer, int nbytes);

#endif // HID_H

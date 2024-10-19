//
// a2600.h
//
// USB HID to Atari 2600 dummy translation table
//

#define MISS          (0)
#define MATRIXA2600(b,a)   (b*8+a)

static const unsigned char keymap_a2600[] = {
  MISS,         // 00: NoEvent
  MISS,         // 01: Overrun Error
  MISS,         // 02: POST fail
  MISS,         // 03: ErrorUndefined
 
  // characters
  MATRIXA2600( 2,1), // 04: a
  MATRIXA2600( 4,3), // 05: b
  MATRIXA2600( 4,2), // 06: c
  MATRIXA2600( 2,2), // 07: d
  MATRIXA2600( 6,1), // 08: e
  MATRIXA2600( 5,2), // 09: f
  MATRIXA2600( 2,3), // 0a: g
  MATRIXA2600( 5,3), // 0b: h
  MATRIXA2600( 1,4), // 0c: i
  MATRIXA2600( 2,4), // 0d: j
  MATRIXA2600( 5,4), // 0e: k
  MATRIXA2600( 2,5), // 0f: l
  MATRIXA2600( 4,4), // 10: m
  MATRIXA2600( 7,4), // 11: n
  MATRIXA2600( 6,4), // 12: o
  MATRIXA2600( 1,5), // 13: p
  MATRIXA2600( 6,7), // 14: q
  MATRIXA2600( 1,2), // 15: r
  MATRIXA2600( 5,1), // 16: s
  MATRIXA2600( 6,2), // 17: t
  MATRIXA2600( 6,3), // 18: u
  MATRIXA2600( 7,3), // 19: v
  MATRIXA2600( 1,1), // 1a: w
  MATRIXA2600( 7,2), // 1b: x
  MATRIXA2600( 1,3), // 1c: y
  MATRIXA2600( 4,1), // 1d: z

  // top number key row
  MATRIXA2600( 0,7), // 1e: 1
  MATRIXA2600( 3,7), // 1f: 2
  MATRIXA2600( 0,1), // 20: 3
  MATRIXA2600( 3,1), // 21: 4
  MATRIXA2600( 0,2), // 22: 5
  MATRIXA2600( 3,2), // 23: 6
  MATRIXA2600( 0,3), // 24: 7
  MATRIXA2600( 3,3), // 25: 8
  MATRIXA2600( 0,4), // 26: 9
  MATRIXA2600( 3,4), // 27: 0
  
  // other keys
  MATRIXA2600( 1,0), // 28: return
  MATRIXA2600( 7,7), // 29: esc  as run/stop
  MATRIXA2600( 0,0), // 2a: backspace as del
  MATRIXA2600( 7,1), // lshift // 2b: tab
  MATRIXA2600( 4,7), // 2c: space

  MATRIXA2600( 3,5), // 2d: - as -
  MATRIXA2600( 0,5), // 2e: = as +
  MATRIXA2600( 6,5), // 2f: [  as @
  MATRIXA2600( 1,6), // 30: ]  as *
  MATRIXA2600( 0,6), // 31: backslash as pound 
  MATRIXA2600( 0,6), // 32: EUR-1 as pound backup
  MATRIXA2600( 5,5), // 33: ; as :
  MATRIXA2600( 2,6), // 34: ' as ;
  MATRIXA2600( 1,7), // 35: ` as arrow left
  MATRIXA2600( 7,5), // 36: , as ,
  MATRIXA2600( 4,5), // 37: . as .
  MATRIXA2600( 7,6), // 38: / as /
  MATRIXA2600( 5,7), // 39: caps lock as cbm 
  
  // function keys
  MATRIXA2600( 4,0), // 3a: F1
  MATRIXA2600( 4,0), // 3b: F2
  MATRIXA2600( 5,0), // 3c: F3
  MATRIXA2600( 5,0), // 3d: F4
  MATRIXA2600( 6,0), // 3e: F5
  MATRIXA2600( 6,0), // 3f: F6
  MATRIXA2600( 3,0), // 40: F7
  MATRIXA2600( 3,0), // 41: F8
  MATRIXA2600( 6,6), // 42: F9  as arrow up
  MATRIXA2600( 5,6), // 43: F10 as equal
  MATRIXA2600( 7,1), // lshift // 44: F11 as restore (NMI) !
  MISS,            // 45: F12 (OSD)

  MATRIXA2600( 7,1), // lshift // 46: PrtScr
  MATRIXA2600( 7,1), // lshift // 47: Scroll Lock
  MATRIXA2600( 7,1), // lshift // 48: Pause
  MATRIXA2600( 3,6), // 49: Insert as CLR
  MATRIXA2600( 7,1), // lshift // 4a: Home
  MATRIXA2600( 7,1), // lshift // 4b: PageUp
  MATRIXA2600( 3,6), // 4c: Delete as CLR
  MATRIXA2600( 7,1), // lshift // 4d: End
  MATRIXA2600( 7,1), // lshift // 4e: PageDown
  
  // cursor keys
  MATRIXA2600( 2,0), // 4f: right
  MATRIXA2600( 2,0), // 50: left
  MATRIXA2600( 7,0), // 51: down
  MATRIXA2600( 7,0), // 52: up
  
  MATRIXA2600( 7,1), // lshift             // 53: Num Lock

  // keypad
  MATRIXA2600( 7,1), // lshift // 54: KP /
  MATRIXA2600( 7,1), // lshift // 55: KP *
  MATRIXA2600( 7,1), // lshift // 56: KP -
  MATRIXA2600( 7,1), // lshift // 57: KP +
  MATRIXA2600( 7,1), // lshift // 58: KP Enter
  MATRIXA2600( 7,1), // lshift // 59: KP 1
  MATRIXA2600( 7,1), // lshift // 5a: KP 2
  MATRIXA2600( 7,1), // lshift // 5b: KP 3
  MATRIXA2600( 7,1), // lshift // 5c: KP 4
  MATRIXA2600( 7,1), // lshift // 5d: KP 5
  MATRIXA2600( 7,1), // lshift // 5e: KP 6
  MATRIXA2600( 7,1), // lshift // 5f: KP 7
  MATRIXA2600( 7,1), // lshift // 60: KP 8
  MATRIXA2600( 7,1), // lshift // 61: KP 9
  MATRIXA2600( 7,1), // lshift // 62: KP 0
  MATRIXA2600( 7,1), // lshift // 63: KP .
  MATRIXA2600( 7,1), // lshift // 64: EUR-2
};  
  
static const unsigned char modifier_a2600[] = {
  /* usb modifer bits:
     0     1      2    3    4     5      6    7
     LCTRL LSHIFT LALT LGUI RCTRL RSHIFT RALT RGUI
  */

  MATRIXA2600( 2,7), // ctrl (left)
  MATRIXA2600( 7,1), // lshift
  MATRIXA2600( 5,7), // lalt as CBM 
  MATRIXA2600( 7,1), // lshift // lgui
  MATRIXA2600( 2,7), // ctrl (right)
  MATRIXA2600( 4,6), // rshift
  MATRIXA2600( 5,7), // ralt as CBM
  MATRIXA2600( 7,1) // lshift // rgui
};
  

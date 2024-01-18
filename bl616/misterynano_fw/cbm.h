//
// cbm.h
//
// USB HID to Commodore c64 /vic20 key MATRIXCBM translation table
//

#define MISS          (0)
#define MATRIXCBM(b,a)   (b*8+a)

static const unsigned char keymap_cbm[] = {
  MISS,         // 00: NoEvent
  MISS,         // 01: Overrun Error
  MISS,         // 02: POST fail
  MISS,         // 03: ErrorUndefined
 
  // characters
  MATRIXCBM( 2,1), // 04: a
  MATRIXCBM( 4,3), // 05: b
  MATRIXCBM( 4,2), // 06: c
  MATRIXCBM( 2,2), // 07: d
  MATRIXCBM( 6,1), // 08: e
  MATRIXCBM( 5,2), // 09: f
  MATRIXCBM( 2,3), // 0a: g
  MATRIXCBM( 5,3), // 0b: h
  MATRIXCBM( 1,4), // 0c: i
  MATRIXCBM( 2,4), // 0d: j
  MATRIXCBM( 5,4), // 0e: k
  MATRIXCBM( 2,5), // 0f: l
  MATRIXCBM( 4,4), // 10: m
  MATRIXCBM( 7,4), // 11: n
  MATRIXCBM( 6,4), // 12: o
  MATRIXCBM( 1,5), // 13: p
  MATRIXCBM( 6,7), // 14: q
  MATRIXCBM( 1,2), // 15: r
  MATRIXCBM( 5,1), // 16: s
  MATRIXCBM( 6,2), // 17: t
  MATRIXCBM( 6,3), // 18: u
  MATRIXCBM( 7,3), // 19: v
  MATRIXCBM( 1,1), // 1a: w
  MATRIXCBM( 7,2), // 1b: x
  MATRIXCBM( 1,3), // 1c: y
  MATRIXCBM( 4,1), // 1d: z

  // top number key row
  MATRIXCBM( 0,7), // 1e: 1
  MATRIXCBM( 3,7), // 1f: 2
  MATRIXCBM( 0,1), // 20: 3
  MATRIXCBM( 3,1), // 21: 4
  MATRIXCBM( 0,2), // 22: 5
  MATRIXCBM( 3,2), // 23: 6
  MATRIXCBM( 0,3), // 24: 7
  MATRIXCBM( 3,3), // 25: 8
  MATRIXCBM( 0,4), // 26: 9
  MATRIXCBM( 3,4), // 27: 0
  
  // other keys
  MATRIXCBM( 1,0), // 28: return
  MATRIXCBM( 7,7), // 29: esc  as run/stop
  MATRIXCBM( 0,0), // 2a: backspace as del
  MISS,            // 2b: tab
  MATRIXCBM( 4,7), // 2c: space

  MATRIXCBM( 3,5), // 2d: - as -
  MATRIXCBM( 0,5), // 2e: = as +
  MATRIXCBM( 6,5), // 2f: [  as @
  MATRIXCBM( 1,6), // 30: ]  as *
  MATRIXCBM( 0,6), // 31: backslash as pound 
  MATRIXCBM( 0,6), // 32: EUR-1 as pound backup
  MATRIXCBM( 5,5), // 33: ; as :
  MATRIXCBM( 2,6), // 34: ' as ;
  MATRIXCBM( 1,7), // 35: ` as arrow left
  MATRIXCBM( 7,5), // 36: , as ,
  MATRIXCBM( 4,5), // 37: . as .
  MATRIXCBM( 7,6), // 38: / as /
  MATRIXCBM( 5,7), // 39: caps lock as cbm 
  
  // function keys
  MATRIXCBM( 4,0), // 3a: F1
  MATRIXCBM( 4,0), // 3b: F2
  MATRIXCBM( 5,0), // 3c: F3
  MATRIXCBM( 5,0), // 3d: F4
  MATRIXCBM( 6,0), // 3e: F5
  MATRIXCBM( 6,0), // 3f: F6
  MATRIXCBM( 3,0), // 40: F7
  MATRIXCBM( 3,0), // 41: F8
  MATRIXCBM( 6,6), // 42: F9  as arrow up
  MATRIXCBM( 5,6), // 43: F10 as equal
  MISS,            // 44: F11 as restore (NMI) WIP !
  MISS,            // 45: F12 (OSD)

  MISS,            // 46: PrtScr
  MISS,            // 47: Scroll Lock
  MISS,            // 48: Pause
  MATRIXCBM( 3,6), // 49: Insert as CLR
  MISS,            // 4a: Home
  MISS,            // 4b: PageUp
  MATRIXCBM( 3,6), // 4c: Delete as CLR
  MISS,            // 4d: End
  MISS,            // 4e: PageDown
  
  // cursor keys
  MATRIXCBM( 2,0), // 4f: right
  MATRIXCBM( 2,0), // 50: left
  MATRIXCBM( 7,0), // 51: down
  MATRIXCBM( 7,0), // 52: up
  
  MISS,            // 53: Num Lock

  // keypad
  MISS,//  MATRIXCBM(,), // 54: KP /
  MISS,//  MATRIXCBM(,), // 55: KP *
  MISS,//  MATRIXCBM(,), // 56: KP -
  MISS,//  MATRIXCBM(,), // 57: KP +
  MISS,//  MATRIXCBM(,), // 58: KP Enter
  MISS,//  MATRIXCBM(,), // 59: KP 1
  MISS,//  MATRIXCBM(,), // 5a: KP 2
  MISS,//  MATRIXCBM(,), // 5b: KP 3
  MISS,//  MATRIXCBM(,), // 5c: KP 4
  MISS,//  MATRIXCBM(,), // 5d: KP 5
  MISS,//  MATRIXCBM(,), // 5e: KP 6
  MISS,//  MATRIXCBM(,), // 5f: KP 7
  MISS,//  MATRIXCBM(,), // 60: KP 8
  MISS,//  MATRIXCBM(,), // 61: KP 9
  MISS,//  MATRIXCBM(,), // 62: KP 0
  MISS,//  MATRIXCBM(,), // 63: KP .
  MISS,//  MATRIXCBM(,), // 64: EUR-2
};  
  
static const unsigned char modifier_cbm[] = {
  /* usb modifer bits:
     0     1      2    3    4     5      6    7
     LCTRL LSHIFT LALT LGUI RCTRL RSHIFT RALT RGUI
  */

  MATRIXCBM( 2,7), // ctrl (left)
  MATRIXCBM( 7,1), // lshift
  MATRIXCBM( 5,7), // lalt as CBM 
  MISS,            // lgui
  MATRIXCBM( 2,7), // ctrl (right)
  MATRIXCBM( 4,6), // rshift
  MATRIXCBM( 5,7), // ralt as CBM
  MISS             // rgui
};
  

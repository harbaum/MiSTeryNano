//
// c64.h
//
// USB HID to Commodore c64 key MATRIXC64 translation table
//

#define MISS          (0)
#define MATRIXC64(b,a)   (b*8+a)

static const unsigned char keymap_c64[] = {
  MISS,         // 00: NoEvent
  MISS,         // 01: Overrun Error
  MISS,         // 02: POST fail
  MISS,         // 03: ErrorUndefined
 
  // characters
  MATRIXC64( 2,1), // 04: a
  MATRIXC64( 4,3), // 05: b
  MATRIXC64( 4,2), // 06: c
  MATRIXC64( 2,2), // 07: d
  MATRIXC64( 6,1), // 08: e
  MATRIXC64( 5,2), // 09: f
  MATRIXC64( 2,3), // 0a: g
  MATRIXC64( 5,3), // 0b: h
  MATRIXC64( 1,4), // 0c: i
  MATRIXC64( 2,4), // 0d: j
  MATRIXC64( 5,4), // 0e: k
  MATRIXC64( 2,5), // 0f: l
  MATRIXC64( 4,4), // 10: m
  MATRIXC64( 7,4), // 11: n
  MATRIXC64( 6,4), // 12: o
  MATRIXC64( 1,5), // 13: p
  MATRIXC64( 6,7), // 14: q
  MATRIXC64( 1,2), // 15: r
  MATRIXC64( 5,1), // 16: s
  MATRIXC64( 6,2), // 17: t
  MATRIXC64( 6,3), // 18: u
  MATRIXC64( 7,3), // 19: v
  MATRIXC64( 1,1), // 1a: w
  MATRIXC64( 7,2), // 1b: x
  MATRIXC64( 1,3), // 1c: y
  MATRIXC64( 4,1), // 1d: z

  // top number key row
  MATRIXC64( 0,7), // 1e: 1
  MATRIXC64( 3,7), // 1f: 2
  MATRIXC64( 0,1), // 20: 3
  MATRIXC64( 3,1), // 21: 4
  MATRIXC64( 0,2), // 22: 5
  MATRIXC64( 3,2), // 23: 6
  MATRIXC64( 0,3), // 24: 7
  MATRIXC64( 3,3), // 25: 8
  MATRIXC64( 0,4), // 26: 9
  MATRIXC64( 3,4), // 27: 0
  
  // other keys
  MATRIXC64( 1,0), // 28: return
  MATRIXC64( 7,7), // 29: esc  as run/stop
  MATRIXC64( 0,0), // 2a: backspace as del
  MISS,            // 2b: tab
  MATRIXC64( 4,7), // 2c: space

  MATRIXC64( 3,5), // 2d: - as -
  MATRIXC64( 0,5), // 2e: = as +
  MATRIXC64( 6,5), // 2f: [  as @
  MATRIXC64( 1,6), // 30: ]  as *
  MATRIXC64( 0,6), // 31: backslash as pound 
  MATRIXC64( 0,6), // 32: EUR-1 as pound backup
  MATRIXC64( 5,5), // 33: ; as :
  MATRIXC64( 2,6), // 34: ' as ;
  MATRIXC64( 1,7), // 35: ` as arrow left
  MATRIXC64( 7,5), // 36: , as ,
  MATRIXC64( 4,5), // 37: . as .
  MATRIXC64( 7,6), // 38: / as /
  MATRIXC64( 5,7), // 39: caps lock as cbm 
  
  // function keys
  MATRIXC64( 4,0), // 3a: F1
  MATRIXC64( 4,0), // 3b: F2
  MATRIXC64( 5,0), // 3c: F3
  MATRIXC64( 5,0), // 3d: F4
  MATRIXC64( 6,0), // 3e: F5
  MATRIXC64( 6,0), // 3f: F6
  MATRIXC64( 3,0), // 40: F7
  MATRIXC64( 3,0), // 41: F8
  MATRIXC64( 6,6), // 42: F9  as arrow up
  MATRIXC64( 5,6), // 43: F10 as equal
  MISS,            // 44: F11 as restore (NMI) WIP !
  MISS,            // 45: F12 (OSD)

  MISS,            // 46: PrtScr
  MISS,            // 47: Scroll Lock
  MISS,            // 48: Pause
  MATRIXC64( 3,6), // 49: Insert as CLR
  MISS,            // 4a: Home
  MISS,            // 4b: PageUp
  MATRIXC64( 3,6), // 4c: Delete as CLR
  MISS,            // 4d: End
  MISS,            // 4e: PageDown
  
  // cursor keys
  MATRIXC64( 2,0), // 4f: right
  MATRIXC64( 2,0), // 50: left
  MATRIXC64( 7,0), // 51: down
  MATRIXC64( 7,0), // 52: up
  
  MISS,            // 53: Num Lock

  // keypad
  MISS,//  MATRIXC64(,), // 54: KP /
  MISS,//  MATRIXC64(,), // 55: KP *
  MISS,//  MATRIXC64(,), // 56: KP -
  MISS,//  MATRIXC64(,), // 57: KP +
  MISS,//  MATRIXC64(,), // 58: KP Enter
  MISS,//  MATRIXC64(,), // 59: KP 1
  MISS,//  MATRIXC64(,), // 5a: KP 2
  MISS,//  MATRIXC64(,), // 5b: KP 3
  MISS,//  MATRIXC64(,), // 5c: KP 4
  MISS,//  MATRIXC64(,), // 5d: KP 5
  MISS,//  MATRIXC64(,), // 5e: KP 6
  MISS,//  MATRIXC64(,), // 5f: KP 7
  MISS,//  MATRIXC64(,), // 60: KP 8
  MISS,//  MATRIXC64(,), // 61: KP 9
  MISS,//  MATRIXC64(,), // 62: KP 0
  MISS,//  MATRIXC64(,), // 63: KP .
  MISS,//  MATRIXC64(,), // 64: EUR-2
};  
  
static const unsigned char modifier_c64[] = {
  /* usb modifer bits:
     0     1      2    3    4     5      6    7
     LCTRL LSHIFT LALT LGUI RCTRL RSHIFT RALT RGUI
  */

  MATRIXC64( 2,7), // ctrl (left)
  MATRIXC64( 7,1), // lshift
  MATRIXC64( 5,7), // lalt as CBM 
  MISS,            // lgui
  MATRIXC64( 2,7), // ctrl (right)
  MATRIXC64( 4,6), // rshift
  MATRIXC64( 5,7), // ralt as CBM
  MISS             // rgui
};
  

//
// vic20.h
//
// USB HID to Commodore VIC20 key MATRIXVIC20 translation table
//

#define MISS               (0)
#define MATRIXVIC20(a,b)   (b*8+a)

static const unsigned char keymap_vic20[] = {
  MISS,         // 00: NoEvent
  MISS,         // 01: Overrun Error
  MISS,         // 02: POST fail
  MISS,         // 03: ErrorUndefined
 
  // characters
  MATRIXVIC20( 2,1), // 04: a
  MATRIXVIC20( 4,3), // 05: b
  MATRIXVIC20( 4,2), // 06: c
  MATRIXVIC20( 2,2), // 07: d
  MATRIXVIC20( 6,1), // 08: e
  MATRIXVIC20( 5,2), // 09: f
  MATRIXVIC20( 2,3), // 0a: g
  MATRIXVIC20( 5,3), // 0b: h
  MATRIXVIC20( 1,4), // 0c: i
  MATRIXVIC20( 2,4), // 0d: j
  MATRIXVIC20( 5,4), // 0e: k
  MATRIXVIC20( 2,5), // 0f: l
  MATRIXVIC20( 4,4), // 10: m
  MATRIXVIC20( 3,4), // 11: n
  MATRIXVIC20( 6,4), // 12: o
  MATRIXVIC20( 1,5), // 13: p
  MATRIXVIC20( 6,0), // 14: q
  MATRIXVIC20( 1,2), // 15: r
  MATRIXVIC20( 5,1), // 16: s
  MATRIXVIC20( 6,2), // 17: t
  MATRIXVIC20( 6,3), // 18: u
  MATRIXVIC20( 3,3), // 19: v
  MATRIXVIC20( 1,1), // 1a: w
  MATRIXVIC20( 3,2), // 1b: x
  MATRIXVIC20( 1,3), // 1c: y
  MATRIXVIC20( 4,1), // 1d: z

  // top number key row
  MATRIXVIC20( 0,0), // 1e: 1
  MATRIXVIC20( 7,0), // 1f: 2
  MATRIXVIC20( 0,1), // 20: 3
  MATRIXVIC20( 7,1), // 21: 4
  MATRIXVIC20( 0,2), // 22: 5
  MATRIXVIC20( 7,2), // 23: 6
  MATRIXVIC20( 0,3), // 24: 7
  MATRIXVIC20( 7,3), // 25: 8
  MATRIXVIC20( 0,4), // 26: 9
  MATRIXVIC20( 7,4), // 27: 0
  
  // other keys
  MATRIXVIC20( 1,7), // 28: return
  MATRIXVIC20( 3,0), // 29: esc  as run/stop
  MATRIXVIC20( 0,7), // 2a: backspace as del
  MATRIXVIC20( 3,1), // lshift // 2b: tab
  MATRIXVIC20( 4,0), // 2c: space

  MATRIXVIC20( 7,5), // 2d: - as -
  MATRIXVIC20( 0,5), // 2e: = as +
  MATRIXVIC20( 6,5), // 2f: [  as @
  MATRIXVIC20( 1,6), // 30: ]  as *
  MATRIXVIC20( 0,6), // 31: backslash as pound 
  MATRIXVIC20( 0,6), // 32: EUR-1 as pound backup
  MATRIXVIC20( 5,5), // 33: ; as :
  MATRIXVIC20( 2,6), // 34: ' as ;
  MATRIXVIC20( 1,0), // 35: ` as arrow left
  MATRIXVIC20( 3,5), // 36: , as ,
  MATRIXVIC20( 4,5), // 37: . as .
  MATRIXVIC20( 3,6), // 38: / as /
  MATRIXVIC20( 5,0), // 39: caps lock as cbm 
  
  // function keys
  MATRIXVIC20( 4,7), // 3a: F1
  MATRIXVIC20( 4,7), // 3b: F2
  MATRIXVIC20( 5,7), // 3c: F3
  MATRIXVIC20( 5,7), // 3d: F4
  MATRIXVIC20( 6,7), // 3e: F5
  MATRIXVIC20( 6,7), // 3f: F6
  MATRIXVIC20( 7,7), // 40: F7
  MATRIXVIC20( 7,7), // 41: F8
  MATRIXVIC20( 6,6), // 42: F9  as arrow up
  MATRIXVIC20( 5,6), // 43: F10 as equal
  MATRIXVIC20( 3,1), // lshift // 44: F11 as restore
  MISS,              // 45: F12 (OSD)

  MATRIXVIC20( 3,1), // lshift // 46: PrtScr
  MATRIXVIC20( 3,1), // lshift // 47: Scroll Lock
  MATRIXVIC20( 3,1), // lshift // 48: Pause
  MATRIXVIC20( 7,6), // 49: Insert as CLR
  MATRIXVIC20( 3,1), // lshift // 4a: Home
  MATRIXVIC20( 3,1), // lshift // 4b: PageUp
  MATRIXVIC20( 7,6), // 4c: Delete as CLR
  MATRIXVIC20( 3,1), // lshift // 4d: End
  MATRIXVIC20( 3,1), // lshift // 4e: PageDown
  
  // cursor keys
  MATRIXVIC20( 2,7), // 4f: right
  MATRIXVIC20( 2,7), // 50: left
  MATRIXVIC20( 3,7), // 51: down
  MATRIXVIC20( 3,7), // 52: up
  
  MATRIXVIC20( 3,1), // lshift // 53: Num Lock

  // keypad
  MATRIXVIC20( 3,1), // lshift //  54: KP /
  MATRIXVIC20( 3,1), // lshift //  55: KP *
  MATRIXVIC20( 3,1), // lshift //  56: KP -
  MATRIXVIC20( 3,1), // lshift //  57: KP +
  MATRIXVIC20( 3,1), // lshift //  58: KP Enter
  MATRIXVIC20( 3,1), // lshift //  59: KP 1
  MATRIXVIC20( 3,1), // lshift //  a: KP 2
  MATRIXVIC20( 3,1), // lshift //  5b: KP 3
  MATRIXVIC20( 3,1), // lshift //  5c: KP 4
  MATRIXVIC20( 3,1), // lshift //  5d: KP 5
  MATRIXVIC20( 3,1), // lshift //  5e: KP 6
  MATRIXVIC20( 3,1), // lshift //  f: KP 7
  MATRIXVIC20( 3,1), // lshift //  60: KP 8
  MATRIXVIC20( 3,1), // lshift //  61: KP 9
  MATRIXVIC20( 3,1), // lshift //  62: KP 0
  MATRIXVIC20( 3,1), // lshift //  63: KP .
  MATRIXVIC20( 3,1), // lshift //  64: EUR-2
};  
  
static const unsigned char modifier_vic20[] = {
  /* usb modifer bits:
     0     1      2    3    4     5      6    7
     LCTRL LSHIFT LALT LGUI RCTRL RSHIFT RALT RGUI
  */

  MATRIXVIC20( 2,0), // ctrl (left)
  MATRIXVIC20( 3,1), // lshift
  MATRIXVIC20( 5,0), // lalt as CBM 
  MATRIXVIC20( 3,1), // lshift // lgui
  MATRIXVIC20( 2,0), // ctrl (right)
  MATRIXVIC20( 4,6), // rshift
  MATRIXVIC20( 5,0), // ralt as CBM
  MATRIXVIC20( 3,1)  // lshift // rgui
};
  

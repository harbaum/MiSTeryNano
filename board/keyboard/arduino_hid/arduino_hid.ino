/*
  arduino_hid.ino - MiSTeryNano USB HID keyboard
*/

#include "Keyboard.h"

/*
 * Wiring:
 * EN   = 2
 * SCK  = 3
 * MOSI = 4
 * MISO = 5
 */

/*
 * the (US) matrix:
 *       0    1    2    3    4    5    6    7    8    9    A    B    C    D    E
 *  +---------------------------------------------------------------------------
 * 0|        F1   F2   F3   F4   F5   F6   F7   F8   F9  F10 Help Undo    (    /
 * 1|                      ESC    2    4    6    8    0    +   BS   Up    )    *
 * 2|                        1    3    5    7    9    -    ~  Del  Clr    7    9
 * 3|                      Tab    W    R    Y    U    O    [  Ins Left    8    -
 * 4| Ctrl                   Q    E    T    G    I    P    ]    \ Down    4    6 
 * 5|      LShf              A    S    F    H    J    L    :  Ret Rght    5    +
 * 6|            Alt        EU    D    C    B    K    .    ,    '   1     2    3
 * 7|                RShf    Z    X    V    N    M  Spc Caps    /   0     .  Ent  
 */

// Table to translate from matrix position to hid keycode. Some very atari st specific
// keys like HELP and UNDO are using the mapping of the MiSTeryNano. These may have to be adjusted for use with
// specific Atari ST emulators: HID key codes 0xfx are actually indices to the modifier bitmap
// Atari ST  ->   PC HID code
// HELP           Page Up
// UNDO           Page Down
// KP-(           Print Screen
// KP-)           End
// International  F12

const uint8_t key_codes[8][15] = {
     0,0x3a,0x3b,0x3c,0x3d,0x3e,0x3f,0x40,0x41,0x42,0x43,0x4b,0x4e,0x46,0x54,  // 0
     0,   0,   0,   0,0x29,0x1f,0x21,0x23,0x25,0x27,0x2e,0x2a,0x52,0x4d,0x55,  // 1
     0,   0,   0,   0,0x1e,0x20,0x22,0x24,0x26,0x37,0x35,0x4c,0x4a,0x5f,0x61,  // 2
     0,   0,   0,   0,0x2b,0x1a,0x15,0x1c,0x18,0x12,0x2f,0x49,0x50,0x60,0x56,  // 3
     0xf0,0,   0,   0,0x14,0x08,0x17,0x0a,0x0c,0x13,0x30,0x31,0x51,0x5c,0x5e,  // 4
     0,0xf1,   0,   0,0x04,0x16,0x09,0x0b,0x0d,0x0f,0x33,0x28,0x4f,0x97,0x57,  // 5
     0,   0,0xf2,   0,0x45,0x07,0x06,0x05,0x0e,0x37,0x36,0x34,0x59,0x5a,0x5b,  // 6
     0,   0,   0,0xf5,0x1d,0x1b,0x19,0x11,0x10,0x2c,0x39,0x38,0x62,0x63,0x58   // 7
};

#define EN   2
#define SCK  3
#define MOSI 4
#define MISO 5

static bool key_state[128];

uint8_t set_outputs(uint16_t value) {
  uint8_t ret = 0;
  
  // shift 16 bits out
  for(int i=0;i<16;i++) {
    digitalWrite(MOSI, (value & (1<<i))?1:0 );
    if(i < 8) {
      ret <<= 1;
      if(digitalRead(MISO)) ret |= 1;
    }

    // clock low pulse
    digitalWrite(SCK, 0);
    digitalWrite(SCK, 1);
  }  

  // Output data is latched on rising edge of EN. This will 
  // select the requested column
  digitalWrite(EN, 0);
  digitalWrite(EN, 1);

  // input is latched while EN is low. This happens a second
  // time here, so the previously loaded column is being latched
  digitalWrite(EN, 0);
  digitalWrite(EN, 1);  

  return ret;
}

void scan_kbd(bool report, bool led) {

  // scan all 15 matrix columns
  uint16_t oval = led?0xffff:0x7fff;   // include led state at 1/8 rate
  set_outputs(oval & ~0x4000);             // start by driving column 0 low
  for(int col=0;col<15;col++) {
    oval |= 0x7fff;                        // deselect previous column
    if(col != 15) oval &= ~(0x2000>>col);  // select new column

    // drive next column and read previous row
    uint8_t r = set_outputs(oval);

    // parse eight row bits
    for(int row=0;row<8;row++) {
      if(!(r & (0x80>>row))) {
        // check if key wasn't already pressed
        if(!key_state[row*16 + col]) {
          key_state[row*16 + col] = 1;     // mark as pressed
          if(report && key_codes[row][col])
            Keyboard.press(key_codes[row][col]);
        }
      } else {
        // check if key was already pressed, but now isn't
        if(key_state[row*16 + col]) {
          key_state[row*16 + col] = 0;     // mark as released
          if(report && key_codes[row][col])
            Keyboard.release(key_codes[row][col]);
        }
      }
    }     
  }
}

void setup() {
  pinMode(EN, OUTPUT);
  pinMode(SCK, OUTPUT);
  pinMode(MOSI, OUTPUT);
  pinMode(MISO, INPUT);  

  digitalWrite(EN, 1);    // enable default HI
  digitalWrite(SCK, 1);   // clock default hi
  digitalWrite(MOSI, 0);  // output data actually doesn't matter

  for(int i=0;i<128;i++)  // reset key state table
    key_state[i] = 0;

  // scan once to check for stuck keys
  scan_kbd(false, false);  

  // evaluate table for stuck keys
  int stuck = 0;  
  for(int i=0;i<128;i++)
    if(key_state[i])
      stuck++;

  // flash led forever if any stuck key is detected
  if(stuck) {
    while(1) {
      scan_kbd(false, true);  
      delay(100);
      scan_kbd(false, false);  
      delay(100);
    }
  }
}

void loop() {
  scan_kbd(true, Keyboard.getLedStatus()&0x02?true:false);  
  delay(10);
}

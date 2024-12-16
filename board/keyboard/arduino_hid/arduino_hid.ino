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

// Table to translate from matrix position to hid keycode. This table is rather odd as there's another table
// inside the arduino keyboard library that translates from ascii to US key codes. Some very atari st specific
// keys like HELP and UNDO are using the mapping of the MiSTeryNano. These may have to be adjusted for use with
// specific Atari ST emulators:
// Atari ST  ->   PC HID code
// HELP           Page Up
// UNDO           Page Down
// KP-(           Print Screen
// KP-)           End
// International  F12

const unsigned char key_codes[8][15] = {
     0,KEY_F1,KEY_F2,KEY_F3, KEY_F4,KEY_F5,KEY_F6,KEY_F7,KEY_F8,KEY_F9,KEY_F10,KEY_PAGE_UP,KEY_PAGE_DOWN,KEY_PRINT_SCREEN,KEY_KP_SLASH,  // 0
     0,0,0,0,KEY_ESC,'2','4','6','8','0','+',KEY_BACKSPACE,KEY_UP_ARROW,KEY_END,KEY_KP_ASTERISK,  // 1
     0,0,0,0,'1','3','5','7','9','-','~',KEY_DELETE,KEY_HOME,KEY_KP_7,KEY_KP_9,  // 2
     0,0,0,0,KEY_TAB,'w','r','y','u','o','[',KEY_INSERT,KEY_LEFT_ARROW,KEY_KP_8,KEY_KP_MINUS,  // 3
     KEY_LEFT_CTRL,0,0,0,'q','e','t','g','i','p',']','\\',KEY_DOWN_ARROW,KEY_KP_4,KEY_KP_6,  // 4
     0,KEY_LEFT_SHIFT,0,0,'a','s','f','h','j','l',';',KEY_RETURN,KEY_RIGHT_ARROW,KEY_KP_5,KEY_KP_PLUS,  // 5
     0,0,KEY_LEFT_ALT,0,KEY_F12,'d','c','b','k','.',',','\'',KEY_KP_1,KEY_KP_2,KEY_KP_3,  // 6
     0,0,0,KEY_RIGHT_SHIFT,'z','x','v','n','m',' ',KEY_CAPS_LOCK,'/',KEY_KP_0,KEY_KP_DOT,KEY_KP_ENTER   // 7
};

#define EN   2
#define SCK  3
#define MOSI 4
#define MISO 5

static bool key_state[128];

void setup() {
  Keyboard.begin();
  
  pinMode(EN, OUTPUT);
  pinMode(SCK, OUTPUT);
  pinMode(MOSI, OUTPUT);
  pinMode(MISO, INPUT);  

  digitalWrite(EN, 1);    // enable default HI
  digitalWrite(SCK, 1);   // clock default hi
  digitalWrite(MOSI, 0);  // output data actually doesn't matter

  for(int i=0;i<128;i++)  // reset key state table
    key_state[i] = 0;
}

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

void scan_kbd(bool led) {

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
          if(key_codes[row][col])
            Keyboard.press(key_codes[row][col]);
        }
      } else {
        // check if key was already pressed, but now isn't
        if(key_state[row*16 + col]) {
          key_state[row*16 + col] = 0;     // mark as released
          if(key_codes[row][col])
            Keyboard.release(key_codes[row][col]);
        }
      }
    }     
  }
}

void loop() {
  scan_kbd(0);  
  delay(10);
}

/* Arduino based test for the MiSTeryNano keyboard pcb */

/*
 * Wiring:
 * EN   = D2
 * SCK  = D3
 * MOSI = D4
 * MISO = D5
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

// table to translate from matrix position to key name
const char *key_names[8][15] = {
  { "", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "Help", "Undo", "KP (", "KP /" },
  { "", "", "", "", "Escape", "2", "4", "6", "8", "0", "+", "Backspace", "Up", "KP )", "KP *" },
  { "", "", "", "", "1", "3", "5", "7", "9", "-", "~", "Delete", "Clear/Home", "KP 7", "KP 9" },
  { "", "", "", "", "Tab", "W", "R", "Y", "U", "O", "[", "Insert", "Left", "KP 8", "KP -" },
  { "Control", "", "", "", "Q", "E", "T", "G", "I", "P", "]", "\\", "Down", "KP 4", "KP 6" },
  { "", "Left Shift", "", "", "A", "S", "F", "H", "J", "L", ":", "Return", "Right", "KP 5", "KP +" },
  { "", "", "Alternate", "", "International", "D", "C", "B", "K", ".", ",", "'", "KP 1", "KP 2", "KP 3" },
  { "", "", "", "Right Shift", "Z", "X", "V", "N", "M", "Space", "Caps Lock", "/", "KP 0", "KP .", "KP Enter" }  
};

#define EN   2
#define SCK  3
#define MOSI 4
#define MISO 5

void setup() {
  Serial.begin(115200);
  
  pinMode(EN, OUTPUT);
  pinMode(SCK, OUTPUT);
  pinMode(MOSI, OUTPUT);
  pinMode(MISO, INPUT);  

  digitalWrite(EN, 1);    // enable default HI
  digitalWrite(SCK, 1);   // clock default hi
  digitalWrite(MOSI, 0);  // output data actually doesn't matter
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

void loop() {
  static int led = 0; 

  // scan all 15 matrix columns
  uint16_t oval = (led&8)?0xffff:0x7fff;   // include led state at 1/8 rate
  set_outputs(oval & ~0x4000);             // start by driving column 0 low
  for(int col=0;col<15;col++) {
    oval |= 0x7fff;                        // deselect previous column
    if(col != 15) oval &= ~(0x2000>>col);  // select new column

    // drive next column and read previous row
    uint8_t r = set_outputs(oval);

    // parse eight row bits
    for(int row=0;row<8;row++) {
      if(!(r & (0x80>>row))) {
        Serial.print(row, HEX);    
        Serial.print(col, HEX);    

        Serial.print(" ");    
        Serial.println(key_names[row][col]);      
      }  
    }     
  }
  
  delay(10);
  led++;
}

/*
 * sdtest.ino
 * 
 * SD card communication test. Adresses the SD card in 
 * 4 bit SD mode via bit banging.
 * 
*/

#define PIN_LED  LED_BUILTIN
#define PIN_CLK  D0
#define PIN_CMD  D1
#define PIN_DAT0 D2
#define PIN_DAT1 D3
#define PIN_DAT2 D4
#define PIN_DAT3 D5

void clk(int n) {
  while(n--) {
    digitalWrite(PIN_CLK,  LOW);
    digitalWrite(PIN_CLK, HIGH);  
  }
}

uint8_t CRC7_one(uint8_t crcIn, uint8_t data) {
  const uint8_t g = 0x89;
  uint8_t i;

  crcIn ^= data;
  for (i = 0; i < 8; i++) {
    if (crcIn & 0x80) crcIn ^= g;
    crcIn <<= 1;
  }
  
  return crcIn;
}

// Calculate CRC16 CCITT
// It's a 16 bit CRC with polynomial x^16 + x^12 + x^5 + 1
// input:
//   crcIn - the CRC before (0 for rist step)
//   data - byte for CRC calculation
// return: the CRC16 value
uint16_t CRC16_one(uint16_t crcIn, uint8_t data) {
  crcIn  = (uint8_t)(crcIn >> 8)|(crcIn << 8);
  crcIn ^=  data;
  crcIn ^= (uint8_t)(crcIn & 0xff) >> 4;
  crcIn ^= (crcIn << 8) << 4;
  crcIn ^= ((crcIn & 0xff) << 4) << 1;
  
  return crcIn;
}

void cmd_bit(bool b) {
  digitalWrite(PIN_CMD, b?HIGH:LOW);
  clk(1);  
}

void send_cmd(unsigned char cmd, unsigned long arg) {
  pinMode(PIN_CMD,  OUTPUT);

  Serial.print("CMD: ");
  Serial.print(cmd, DEC);

  // first byte always starts with '01'
  cmd = (cmd & 0x3f) | 0x40;

  // calculate crc 
  uint8_t crc = CRC7_one(0, cmd);
  for (int i=0; i<4; i++)
    crc = CRC7_one(crc, ((unsigned char*)(&arg))[3-i]);

  // send command bits
  for(int i=0;i<8;i++) {
    cmd_bit((cmd & 0x80)?1:0);
    cmd <<= 1;
  }
  
  Serial.print(" ARG: ");
  Serial.print(arg, HEX);
  
  // send arg
  for(int i=0;i<32;i++) {
    cmd_bit((arg & 0x80000000)?1:0);
    arg <<= 1;
  }

  Serial.print(" CRC: ");
  Serial.println(crc>>1, HEX);

  // send crc
  crc |= 1;
  for(int i=0;i<8;i++) {
    cmd_bit((crc & 0x80)?1:0);
    crc <<= 1;
  }  
}

char cmd_bit_get(void) {
  char bit = digitalRead(PIN_CMD)?1:0;
  clk(1);  
  return bit;  
}

char data_get(void) {
  char nib = (digitalRead(PIN_DAT0)?1:0) +
             (digitalRead(PIN_DAT1)?2:0) +
             (digitalRead(PIN_DAT2)?4:0) +
             (digitalRead(PIN_DAT3)?8:0);
  clk(1);  
  return nib;  
}

unsigned long reply(int len) {
  unsigned char buffer[(len-16)/8];
  
  pinMode(PIN_CMD,  INPUT_PULLUP);

  // wait for startbit
  int i;
  for(i=0;i<32 && cmd_bit_get();i++);

  if(i == 32) {
    Serial.println("Response timeout!");
    pinMode(PIN_CMD,  OUTPUT);
    return 0;
  }

  Serial.print("@");
  Serial.print(i, DEC);
  Serial.print(" ");

  // response bit must also be 0
  if(cmd_bit_get()) {
    pinMode(PIN_CMD,  OUTPUT);
    Serial.println("Response bit is not 0!");
    return 0;
  }

  uint8_t cmd = 0;
  for(i=0;i<6;i++)
    cmd = (cmd << 1)|cmd_bit_get();
  
  Serial.print("-> CMD: ");
  Serial.print(cmd, DEC);

  Serial.print(" ARG: ");

  // get data bits
  uint32_t arg = 0;
  for(i=0;i<len-16;i++) {
    arg = (arg << 1)|cmd_bit_get();
    if((i&7) == 7) buffer[i/8] = arg & 0xff;
  }

  for(i=0;i<(len-16)/8;i++) {
    Serial.print(buffer[i], HEX);
    if(buffer[i] >= 32 && buffer[i] < 127) {
      Serial.print("(");
      Serial.print((char)buffer[i]);
      Serial.print(")");      
    }     
    
    Serial.print(" ");
  }

  uint8_t crc = 0;
  for(i=0;i<8;i++)
    crc = (crc << 1)|cmd_bit_get();

  uint8_t crc_calc = CRC7_one(0, cmd);
  if(cmd == 63) crc_calc = 0;
  for (int i=0; i<(len-16)/8; i++)
    crc_calc = CRC7_one(crc_calc, buffer[i]);

  if(cmd != 63 || crc != 0xff) {
    if((crc&0xfe) != crc_calc) {
      Serial.print(" CRC error: ");
      Serial.print(crc&0xfe, HEX);
      Serial.print("/");
      Serial.println(crc_calc, HEX);
      pinMode(PIN_CMD,  OUTPUT);
      return arg;      
    }
  }
  
  Serial.println(" OK");

  pinMode(PIN_CMD,  OUTPUT);

  return arg;
}

void dump(unsigned char *data) {
  // hex dump
  for(int i=0;i<32;i++) {
    Serial.printf("%04x:", i*16);
    for(int j=0;j<16;j++) Serial.printf(" %02x", data[16*i+j]);
    Serial.print("  ");
    for(int j=0;j<16;j++) Serial.printf("%c", isprint(data[16*i+j])?data[16*i+j]:'.');      
    Serial.println("");
  }
}

int readData(void) {
  // wait for dat0 to go low  
  int i;
  for(i=0;i<1024 && (data_get()&1);i++);

  if(i == 1024) {
    Serial.println("Data timeout!");
    return 0;
  }

  // read 512 bytes
  unsigned short crc_calc[4] = { 0,0,0,0 };
  unsigned char buffer[512];
  unsigned char dbits[4];
  for(int i=0;i<512;i++) {
    unsigned char dat = data_get();
    dat = (dat << 4) | data_get();

    buffer[i] = dat;

    // calculate the crc for each data line seperately
    for(int c=0;c<4;c++) {
      if((i & 3) == 0) dbits[c] = 0;
      dbits[c] = (dbits[c] << 2) | ((dat&(0x10<<c))?2:0) | ((dat&(0x01<<c))?1:0);      
      if((i & 3) == 3) crc_calc[c] = CRC16_one(crc_calc[c], dbits[c]);
    }
  }

  dump(buffer);

  // read crc for each data line seperately
  unsigned short crc[4] =  { 0,0,0,0 };
  for(int b=0;b<16;b++) {
    unsigned char cd = data_get();    
    for(int c=0;c<4;c++)     
      crc[c] = (crc[c] << 1)|((cd&(1<<c))?1:0);
  }

  printf("CRCs %04x %04x %04x %04x\n", crc[0], crc[1], crc[2], crc[3]);

  for(int c=0;c<4;c++) {
    if(crc[c] != crc_calc[c]) {
      Serial.println("Data CRC mismatch!");
      return 0;
    }
  }

  return 512;
}

void data_set(unsigned char nib) {
  digitalWrite(PIN_DAT0, (nib&1)?1:0);
  digitalWrite(PIN_DAT1, (nib&2)?1:0);
  digitalWrite(PIN_DAT2, (nib&4)?1:0);
  digitalWrite(PIN_DAT3, (nib&8)?1:0);
  clk(1);  
}

void writeData(void) {
  pinMode(PIN_DAT0, OUTPUT);
  pinMode(PIN_DAT1, OUTPUT);
  pinMode(PIN_DAT2, OUTPUT);
  pinMode(PIN_DAT3, OUTPUT);

  int start = random(255);
  Serial.printf("Starting with %02x\n", start);
  unsigned char buffer[512];
  for(int i=0;i<512;i++) buffer[i] = start+i;

  // original
//  for(int i=0;i<512;i++) buffer[i] = 0;
//  memcpy(buffer, "\x15\x57\x81\x15\x59\xa1\x15\x5b\xc1\x15\x5d\xe1\x15\x5f\x01\x16\x61\x21\x16\x63\xf1\xff", 22);

  unsigned short crc[4] = { 0,0,0,0 };
  // calculate the crc for each data line seperately
  unsigned char dbits[4];
  for(int i=0;i<512;i++) {
    for(int c=0;c<4;c++) {
      if((i & 3) == 0) dbits[c] = 0;
      dbits[c] = (dbits[c] << 2) | ((buffer[i]&(0x10<<c))?2:0) | ((buffer[i]&(0x01<<c))?1:0);      
      if((i & 3) == 3) crc[c] = CRC16_one(crc[c], dbits[c]);
    }
  }

  Serial.printf("CRCs %04x %04x %04x %04x\n", crc[0], crc[1], crc[2], crc[3]);

  data_set(0); // start bit(s)
  
  // send bytes
  for(int i=0;i<512;i++) {
     data_set((buffer[i]>>4) & 0x0f);
     data_set(buffer[i] & 0x0f);
  }

  // send crc's
  for(int i=0;i<16;i++) {
    unsigned char b = 0;
    for(int c=0;c<4;c++)
      if(crc[c] & (0x8000 >> i))
        b |= (1<<c);

     data_set(b);
  }
  
  pinMode(PIN_DAT0, INPUT_PULLUP);
  pinMode(PIN_DAT1, INPUT_PULLUP);
  pinMode(PIN_DAT2, INPUT_PULLUP);
  pinMode(PIN_DAT3, INPUT_PULLUP);

  // wait for ack
  int i;
  for(i=0;i<1024 && (data_get()&1);i++);

  if(i == 1024) {
    Serial.println("Data timeout!");
    return;
  }

  int ack = 0;
  for(int b=0;b<4;b++)
      ack = (ack << 1)|(data_get()&1);

  // ack[0] is always 1
  // ack[3:1] == 010/OK, 101/CRCERR, 110/WRERR
  Serial.printf("ACK %02x\n", ack);

  // wait while card is busy
  for(i=0;i<8192 && !(data_get()&1);i++);

  Serial.printf("BUSY for %d\n", i);
}

void sd_init(void) {
  // start clocking
  clk(64000); send_cmd( 0, 0x00000000);                 // go idle
  clk(512);   send_cmd( 8, 0x000001aa); reply(48);      // interface condition command

  // wait for sd card to become ready
  unsigned long r=0;
  do {
    clk(512);   send_cmd(55, 0x00000000); reply(48);    // prepare ACMD
    clk(256);   send_cmd(41, 0x40100000); r=reply(48);  // read OCR
  } while(!(r & 0x80000000));  // check busy bit

  // we'll finally only support sdhc cards
  if(r & 0x40000000) printf("Card type: SDHCv2\n");
  else               printf("Card type: SDv2\n");

  clk(256);   send_cmd( 2, 0x00000000); reply(136);     // read CID
  
  clk(256);   send_cmd( 3, 0x00000000); r=reply(48);    // get rca
  int rca = r >> 16;
  printf("RCA = %04x\n", rca);
 
  clk(256);   send_cmd( 9, rca << 16);  reply(136);     // get CSD
  clk(256);   send_cmd( 7, rca << 16);  reply(48);      // select card 

  clk(512);   send_cmd(55, rca << 16); reply(48);    // prepare ACMD
  clk(256);   send_cmd(6,  2); r=reply(48);           // switch to 4 bit mode
    
  clk(256);   send_cmd(16, 512); reply(48);             // select block len 512

  // on the demo cards, the first partition starts at sector 2048. So we can
  // mess with the sectors 2 to 2047 without damaging the file systems

  clk(96);    send_cmd(17, 2);  reply(48); readData();  // read sector 2

//  clk(96);    send_cmd(24, 2);  reply(48); writeData(); // write sector // 2
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.printf("\n\nSD card test\n------------\n");
  delay(10);
  
  pinMode(PIN_LED,  OUTPUT);
  pinMode(PIN_CLK,  OUTPUT);
  pinMode(PIN_CMD,  OUTPUT);
  pinMode(PIN_DAT0, INPUT_PULLUP);
  pinMode(PIN_DAT1, INPUT_PULLUP);
  pinMode(PIN_DAT2, INPUT_PULLUP);
  pinMode(PIN_DAT3, INPUT_PULLUP);

  digitalWrite(PIN_CLK,  HIGH);
  digitalWrite(PIN_CMD,  HIGH);

  sd_init();
}

// the loop function runs over and over again forever
void loop() {
  digitalWrite(LED_BUILTIN, HIGH);   // turn the LED on (HIGH is the voltage level)
  delay(1000);                       // wait for a second
  digitalWrite(LED_BUILTIN, LOW);    // turn the LED off by making the voltage LOW
  delay(1000);                       // wait for a second
}

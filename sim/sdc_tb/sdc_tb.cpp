#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>

#include "Vsd_rw.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#define BIT4    // send/receive 4bits data

static Vsd_rw *tb;
static VerilatedVcdC *trace;
static double simulation_time;

#define TICKLEN   (1.0/64000000)

#ifndef BIT4
uint8_t sector_data[514];   // 512 bytes + one 16 bit crc
#else
uint8_t sector_data[520];   // 512 bytes + four 16 bit crcs
#endif

// https://github.com/LonelyWolf/stm32/blob/master/stm32l-dosfs/sdcard.c

// Calculate CRC7
// It's a 7 bit CRC with polynomial x^7 + x^3 + 1
// input:
//   crcIn - the CRC before (0 for first step)
//   data - byte for CRC calculation
// return: the new CRC7
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

uint8_t getCRC(unsigned char cmd, unsigned long arg) {
  uint8_t CRC = CRC7_one(0, cmd);
  for (int i=0; i<4; i++) CRC = CRC7_one(CRC, ((unsigned char*)(&arg))[3-i]);
  return CRC;
}

uint8_t getCRC_bytes(unsigned char *data, int len) {
  uint8_t CRC = 0;
  while(len--) CRC = CRC7_one(CRC, *data++);
  return CRC;  
}
  
unsigned long long reply(unsigned char cmd, unsigned long arg) {
  unsigned long r = 0;
  r |= ((unsigned long long)cmd) << 40;
  r |= ((unsigned long long)arg) << 8;
  r |= getCRC(cmd, arg);
  r |= 1;
  return r;
}

#define OCR  0xc0ff8000  // not busy, CCS=1(SDHC card), all voltage, not dual-voltage card
#define RCA  0x0013

// total cid respose is 136 bits / 17 bytes
unsigned char cid[17] = "\x3f" "\x02TMS" "A08G" "\x14\x39\x4a\x67" "\xc7\x00\xe4";

int rw_state = 0;

void tick(int c) {
  static long long cmd_in = -1;
  static long long cmd_out = -1;
  static unsigned char *cmd_ptr = 0;
  static int cmd_bits = 0;
  static unsigned char *dat_ptr = 0;
  static int dat_bits = 0;
  static int last_was_acmd = 0;
  static int write_count = 0;
  static int write_expect = 0;
  
  tb->clk = c; 
  tb->eval();
  
  if(c) {
    // data byte to be written to sd card
    if(tb->inen)
      tb->inbyte = 0xff ^ tb->outaddr;
  }
  
  static int last_sdclk = -1;
  if(tb->sdclk != last_sdclk) {
    // rising sd card clock edge
    if(tb->sdclk) {
      static unsigned char rbuf[520];
      
      // write postamble (ack + busy)
      int ack_start = 580;
      int busy_end  = 700;
      int ack_token = 0b00101000;  // start bit 0, ack ok 010, stopbit 1, busy 000
      if(write_count < 512) {
	if(write_expect < 0) {
	  // wait for first data != 15
	  if(!(tb->sddat & 1))
	    write_expect = 1024+16;  // 1024 * 4 bit + 4 * 16 bit crc
	  
	} else if(write_expect > 0) {
	  if((write_expect-1)&1)
	    rbuf[519-((write_expect-1)/2)] = tb->sddat << 4;
	  else
	    rbuf[519-((write_expect-1)/2)] |= tb->sddat;

	  //	  printf("Write %d %s = %x\n", (write_expect-1)/2,
	  //		 ((write_expect-1)&1)?"hi":"lo",
	  //		 rbuf[519-((write_expect-1)/2)]);
	  
	  write_expect--;
	  if(write_expect == 0) {
	    // done with data. verify checksum
	    unsigned short crc[4] = { 0,0,0,0 };
	    unsigned char dbits[4];
	    for(int i=0;i<512;i++) {
	      // calculate the crc for each data line seperately
	      for(int c=0;c<4;c++) {
		if((i & 3) == 0) dbits[c] = 0;
		dbits[c] = (dbits[c] << 2) |
		  ((rbuf[i]&(0x10<<c))?2:0) | ((rbuf[i]&(0x01<<c))?1:0);      
		if((i & 3) == 3) crc[c] = CRC16_one(crc[c], dbits[c]);
	      }
	    }

	    printf("WR DATA CRC = %04x/%04x/%04x/%04x\n",
		   crc[0], crc[1], crc[2], crc[3]);

	    // extract sent crc from last 8 bytes
	    unsigned short s_crc[4] = { 0,0,0,0 };
	    for(int i=0;i<16;i++) {
	      int nibble = (rbuf[512+i/2] >> ((i&1)?0:4)) & 15;
	      s_crc[0] = (s_crc[0] << 1)|((nibble&1)?1:0);
	      s_crc[1] = (s_crc[1] << 1)|((nibble&2)?1:0);
	      s_crc[2] = (s_crc[2] << 1)|((nibble&4)?1:0);
	      s_crc[3] = (s_crc[3] << 1)|((nibble&8)?1:0);	      
	    }
	    
	    printf("WR SENT CRC = %04x/%04x/%04x/%04x\n",
		   s_crc[0], s_crc[1], s_crc[2], s_crc[3]);

	    write_count = 512;
	  }
	}
	
	// printf("WRITE %d = %d\n", write_count, tb->sddat);	
      } else if(write_count < busy_end) {
	if(write_count < ack_start) tb->sddat_in = 15;
	else if(write_count < ack_start+8)
	  tb->sddat_in = (ack_token & (0x80>>(write_count-ack_start)))?1:0;
	else if(write_count < busy_end-1) tb->sddat_in = 0;
	else                              tb->sddat_in = 15;
	
	write_count++;
      }
    
      cmd_in = ((cmd_in << 1) | tb->sdcmd) & 0xffffffffffffll;      

#ifndef BIT4
      if(dat_ptr && dat_bits) {
	if(dat_bits == 512*8 + 16 + 1 + 1) {
	  // card sends start bit
	  tb->sddat_in = 0;
	  printf("READ START\n");
	} else if(dat_bits > 1) {
	  int bit = 7-((dat_bits-2) & 7);
	  tb->sddat_in = (*dat_ptr & (0x80>>bit))?1:0;
	  if(bit == 7) dat_ptr++;
	} else
	  tb->sddat_in = 15;
	
	dat_bits--;
      }
#else
      // sending 4 bits
      if(dat_ptr && dat_bits) {
	if(dat_bits == 128*8 + 16 + 1 + 1) {
	  // card sends start bit
	  tb->sddat_in = 0;
	  printf("READ-4 START\n");
	} else if(dat_bits > 1) {
	  int nibble = dat_bits&1;   // 1: high nibble, 0: low nibble
	  if(nibble) tb->sddat_in = (*dat_ptr >> 4)&15;
	  else       tb->sddat_in = *dat_ptr++ & 15;
	} else
	  tb->sddat_in = 15;
	dat_bits--;
      }
#endif
      
      if(cmd_ptr && cmd_bits) {
	int bit = 7-((cmd_bits-1) & 7);
	tb->sdcmd_in = (*cmd_ptr & (0x80>>bit))?1:0;
	if(bit == 7) cmd_ptr++;
	cmd_bits--;
      } else {      
	tb->sdcmd_in = (cmd_out & (1ll<<47))?1:0;
	cmd_out = (cmd_out << 1)|1;
      }
      
#if 0
      { static int bcnt = 0;
	if(cmd_in) printf("cmd_in %d %llx\r\n", bcnt++, cmd_in);
	else bcnt = 0;
      }
#endif
      
      // check if bit 47 is 0, 46 is 1 and 0 is 1
      if( !(cmd_in & (1ll<<47)) && (cmd_in & (1ll<<46)) && (cmd_in & (1ll<<0))) {
	unsigned char cmd  = (cmd_in >> 40) & 0x7f;
	unsigned long arg  = (cmd_in >>  8) & 0xffffffff;
	unsigned char crc7 = cmd_in & 0xfe;

	// r1 reply:
	// bit 7 - 0
	// bit 6 - parameter error
	// bit 5 - address error
	// bit 4 - erase sequence error
	// bit 3 - com crc error
	// bit 2 - illegal command
	// bit 1 - erase reset
	// bit 0 - in idle state
	
	if(crc7 == getCRC(cmd, arg)) {
	  printf("%cCMD %2d, ARG %08lx\n", last_was_acmd?'A':' ', cmd & 0x3f, arg);
	  switch(cmd & 0x3f) {
	  case 0:  // Go Idle State
	    break;
	  case 8:  // Send Interface Condition Command
	    cmd_out = reply(8, arg);
	    break;
	  case 55: // Application Specific Command
	    cmd_out = reply(55, 0);
	    break;
	  case 41: // Send Host Capacity Support
	    cmd_out = reply(63, OCR);
	    break;
	  case 2:  // Send CID
	    cid[16] = getCRC_bytes(cid, 16) | 1;  // Adjust CRC
	    cmd_ptr = cid;
	    cmd_bits = 136;
	    break;
	  case 3:  // Send Relative Address
	    cmd_out = reply(3, (RCA<<16) | 0);	// status = 0
	    break;
	  case 7:  // select card
	    cmd_out = reply(7, 0);    // may indicate busy	    
	    break;
	  case 6:  // set bus width
	    printf("Set bus width to %ld\n", arg);
	    cmd_out = reply(6, 0);
	    break;
	  case 16: // set block len (should be 512)
	    printf("Set block len to %ld\n", arg);
	    cmd_out = reply(16, 0);    // ok
	    break;
	  case 17:  // read block
	    printf("Request to read single block %ld\n", arg);
	    tb->rstart = 0;
	    cmd_out = reply(17, 0);    // ok
	    if(rw_state != 1) {
	      printf("unexpected read state\n");
	      // exit(-1);
	    }	    
	    rw_state = 2;

	    // load sector
	    {
	      FILE *fd = fopen("disk_a.st", "rb");
	      if(!fd) { perror("OPEN ERROR"); exit(-1); }	    
	      fseek(fd, 512 * arg, SEEK_SET);
	      int items = fread(sector_data, 2, 256, fd);
	      if(items != 256) perror("fread()");

	      for(int i=0;i<16;i++) printf("%02x ", sector_data[i]);
	      printf("\n");
	      
	      fclose(fd);
	    }

#ifndef BIT4
	    {
	      unsigned short crc = 0;
	      for(int i=0;i<512;i++)
		crc = CRC16_one(crc, sector_data[i]);

	      printf("CRC = %04x\n", crc);
	      sector_data[512] = crc >> 8;
	      sector_data[513] = crc & 0xff;
	    }
	    dat_ptr = sector_data;
	    dat_bits = 512*8 + 16 + 1 + 1;
#else
	    {
	      unsigned short crc[4] = { 0,0,0,0 };
	      unsigned char dbits[4];
	      for(int i=0;i<512;i++) {
		// calculate the crc for each data line seperately
		for(int c=0;c<4;c++) {
		  if((i & 3) == 0) dbits[c] = 0;
		  dbits[c] = (dbits[c] << 2) | ((sector_data[i]&(0x10<<c))?2:0) | ((sector_data[i]&(0x01<<c))?1:0);      
		  if((i & 3) == 3) crc[c] = CRC16_one(crc[c], dbits[c]);
		}
	      }
		
	      printf("CRC = %04x/%04x/%04x/%04x\n", crc[0], crc[1], crc[2], crc[3]);

	      // append crc's to sector_data
	      for(int i=0;i<8;i++) sector_data[512+i] = 0;
	      for(int i=0;i<16;i++) {
		int crc_nibble =
		  ((crc[0] & (0x8000 >> i))?1:0) +
		  ((crc[1] & (0x8000 >> i))?2:0) +
		  ((crc[2] & (0x8000 >> i))?4:0) +
		  ((crc[3] & (0x8000 >> i))?8:0);

		sector_data[512+i/2] |= (i&1)?(crc_nibble):(crc_nibble<<4);
	      }
	    }
	    dat_ptr = sector_data;
	    dat_bits = 128*8 + 16 + 1 + 1;
#endif	    
	    break;
	    
	  case 24:  // write block
	    printf("Request to write single block %ld\n", arg);
	    tb->wstart = 0;
	    write_expect = -1;  
	    write_count = 0;
	    cmd_out = reply(24, 0);    // ok
	    break;
	    
	  default:
	    printf("unexpected command\n");
	  }

	  last_was_acmd = (cmd & 0x3f) == 55;
	  
	  cmd_in = -1;
	} else
	  printf("CMD %02x, ARG %08lx, CRC7 %02x != %02x!!\n", cmd, arg, crc7, getCRC(cmd, arg));	  
      }      
    }      
    last_sdclk = tb->sdclk;
  }
  
  trace->dump(1000000000000 * simulation_time);
  simulation_time += TICKLEN;
}

void wait_ms(int ms) {
  for(int i=0;i<32000*ms;i++) {  
    tick(1);
    tick(0);
  }
}

void wait_ns(int ns) {
  for(int i=0;i<(32*ns)/1000;i++) {  
    tick(1);
    tick(0);
  }
}

void run(int ticks) {
  for(int i=0;i<ticks;i++) {
    tick(1);
    tick(0);
  }
}

void hexdump(void *data, int size) {
  int i, b2c;
  int n=0;
  char *ptr = (char*)data;

  if(!size) return;

  while(size>0) {
    printf("%04x: ", n);

    b2c = (size>16)?16:size;
    for(i=0;i<b2c;i++)      printf("%02x ", 0xff&ptr[i]);
    printf("  ");
    for(i=0;i<(16-b2c);i++) printf("   ");
    for(i=0;i<b2c;i++)      printf("%c", isprint(ptr[i])?ptr[i]:'.');
    printf("\n");
    ptr  += b2c;
    size -= b2c;
    n    += b2c;
  }
}

int main(int argc, char **argv) {
  // Initialize Verilators variables
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  trace = new VerilatedVcdC;
  trace->spTrace()->set_time_unit("1ns");
  trace->spTrace()->set_time_resolution("1ps");
  simulation_time = 0;

  // Create an instance of our module under test
  tb = new Vsd_rw;
	
  tb->trace(trace, 99);
  trace->open("sdc_tb.vcd");

  // reset
  tb->rstn = 0; run(10); tb->rstn = 1; run(10);
  tb->sdcmd_in = 1; tb->sddat_in = 15;  // inputs of sd card

  // wait for ready
  while(tb->card_stat != 8) run(1);
  
  char *type[] = { (char*)"UNKNOWN", (char*)"SDv1",
		   (char*)"SDv2", (char*)"SDHCv2" };
  printf("SD card \"%s\" is ready\n", type[tb->card_type]);
  
  wait_ms(1);

  printf("Requesting read ...\n");
  tb->rstart = 1;
  tb->sector = 100;
  rw_state = 1;
  // wait for busy
  while(!tb->rbusy) tick(1);
  tb->rstart = 0;
  while(tb->card_stat != 8) run(1);
  printf("read done\n");

  wait_ms(1);

  printf("Requesting write ...\n");
  tb->wstart = 1;
  tb->sector = 100;
  rw_state = 1;
  // wait for busy
  while(!tb->rbusy) tick(1);
  tb->wstart = 0;

  //  while(tb->card_stat != 8) run(1);
  //  printf("write done\n");
  
  wait_ms(5);
  
  trace->close();
}

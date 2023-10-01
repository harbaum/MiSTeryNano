#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>
#include "Vste_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

// #define NTSC  // undef for PAL

static Vste_tb *tb;
static VerilatedVcdC *trace;
static int tickcount;

static unsigned char ram[4*1024*1024];
static unsigned char rom[8*1024*1024];  // 8 MB spi flash

void initrom() {
  for(int i=0;i<sizeof(ram);i++) ram[i] = i;
  
  // load ram into into space at 1 MB
  FILE *file=fopen("vmem32k.bin", "rb");
  if(!file) { perror("opening vmem32k.bin"); exit(-1); }
  fread(rom+0x100000, 32, 1000, file);
  fclose(file);
}

void tick(int c) {
  tb->clk32 = c;
  tb->flash_clk = c;

  tb->eval();
  trace->dump(tickcount++);
  
  // ------------ handle spi flash -------------------	
  // process spi on rising edge of spi clk
  static int spi_clk = 0;
  
  if(tb->flash_clk && !spi_clk) {
    
    static int spi_state = -1;
    static int spi_dspi = 0;
    if( spi_state == -1 && tb->mspi_cs == 0) {
      if(spi_dspi) spi_state = 8;
      else         spi_state = 0;
    } else if(tb->mspi_cs == 1)
      spi_state = -1;
    
    if(spi_state != -1) {
      static int spi_cmd, spi_addr, spi_m;

      if(spi_state == 8 && spi_cmd == 0xbb)
	spi_dspi = 1;
      
      if(spi_state < 8) 
	spi_cmd = ((spi_cmd << 1)|(tb->mspi_di?1:0)) & 0xff;
      if(spi_state >= 8 && spi_state < 20) {
	// on dspi the address bits come on di _and_ do
	int b0 = tb->mspi_di?1:0;
	int b1 = tb->mspi_do?2:0;
	spi_addr = ((spi_addr << 2)|(b0+b1)) & 0xffffff;
      }
      if(spi_state >= 20 && spi_state < 24) {
	int b0 = tb->mspi_di?1:0;
	int b1 = tb->mspi_do?2:0;
	spi_m = ((spi_m << 2)|(b0+b1)) & 0xff;
      }
      
      if(spi_state == 23) printf("SPI cmd $%02x, addr %08x, M=%02x\n", spi_cmd, spi_addr, spi_m);
      
      // return rom data
      if(spi_state >= 25) {
	int byte = rom[spi_addr + ((spi_state-25)/4)];
	tb->mspi_din = (byte >> (2*(3-((spi_state-25) & 3)))) & 0x03;
      }
      
      spi_state++;
    }
  }
  spi_clk = tb->flash_clk;
  
  // emulate SDRAM
  if(c && !tb->sd_cs) {
    static int addr;
    
    if(!tb->sd_ras && tb->sd_cas) {
      addr = (tb->sd_ba<<21) + (tb->sd_addr<<10);
    }
    
    if(tb->sd_ras && !tb->sd_cas) {
      addr += (tb->sd_addr&0xff)<<2;
      
      // handle writes
      if(!tb->sd_we) {
	printf("WRITE %x = %x\n", addr, tb->sd_data);
	if(!(tb->sd_dqm & 1)) ram[addr+3] = (tb->sd_data >>  0) & 0xff;
	if(!(tb->sd_dqm & 2)) ram[addr+2] = (tb->sd_data >>  8) & 0xff;
	if(!(tb->sd_dqm & 4)) ram[addr+1] = (tb->sd_data >> 16) & 0xff;
	if(!(tb->sd_dqm & 8)) ram[addr+0] = (tb->sd_data >> 24) & 0xff;
      } else {
	// handle reads
	tb->sd_data_in = (ram[addr+0]<<24)+(ram[addr+1]<<16)+(ram[addr+2]<<8)+(ram[addr+3]<<0);
	printf("READ %x = %x\n", addr, tb->sd_data_in);
      }
    }
  }
}

void dump() {
  int vsync = 0, hsync = 0;
  unsigned short rgb;
  FILE *file = NULL;
  int line = -1;
  int pix = -1;
  
  printf("--- dumping image ---\n");
	
  while(1) {
    if (!tb->VSYNC_N && vsync) {
      printf("VSYNC\n");
      if(!file) {
	file = fopen("video.rgb", "wb");
	line = 0;
      } else {
	fclose(file);
	return;
      }
    }
   
    pix++;
    if (tb->HSYNC_N && !hsync) {
      line++;
      pix = 0;
    }

#ifdef NTSC
    #define COLS 848
    #define ROWS 484
    #define COL1ST  73
    #define ROW1ST  40
#else
    #define COLS 832
    #define ROWS 566
    #define COL1ST  82
    #define ROW1ST  58
#endif
    
    vsync = tb->VSYNC_N;
    hsync = tb->HSYNC_N;
    tick(1); tick(0);
    if(file) {
      // the scandoubler outputs no blanking signal ...      
      if(/* tb->BLANK_N */ line >= ROW1ST && line < ROW1ST+ROWS && pix >= COL1ST && pix < COL1ST+COLS) {
	rgb = ((tb->R>>2)*256) + ((tb->G>>2)*16) + (tb->B>>2);
	fwrite(&rgb, 1, sizeof(rgb), file);
      }
    }
  }
}

int main(int argc, char **argv) {
  initrom();

  // Initialize Verilators variables
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  trace = new VerilatedVcdC;
  tickcount = 0;

  memset(ram, 0x55, 4*1024*1024);
  
  // Create an instance of our module under test
  tb = new Vste_tb;
  tb->trace(trace, 99);
  trace->open("gstmcu.vcd");

#ifdef NTSC
  tb->ntsc = 1;
#else
  tb->ntsc = 0;
#endif
  tb->resb = 0;
  tb->porb = 0;  // 0=cold, 1=warm boot
  tick(1);
  tick(0);
  
  tb->VMA_N = 1;
  tb->MFPINT_N = 1;
  tb->BR_N = 1;
  
  tb->FC0 = 0;
  tb->FC1 = 1;
  tb->FC2 = 1;
  
  for(int i=0;i<100;i++) {
    tick(1); tick(0);
  }
  
  tb->porb = 1;
  
  for(int i=0;i<100;i++) {
    tick(1); tick(0);
  }
  
  tb->resb = 1;

  // copy 32k ram takes 32000*16 cycles
  for(int i=0;i<32000*16;i++) {
    tick(1); tick(0);
  }

  printf("RAM loaded\n");
  
#if 1
  for(int i=0;i<1200000;i++) {
    tick(1); tick(0);
	}
  dump();
#endif

  for(int i=0;i<10000;i++) {
    tick(1); tick(0);
  }
  trace->close();
}

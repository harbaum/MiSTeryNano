#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>

#include "Vste_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

static Vste_tb *tb;
static VerilatedVcdC *trace;
static double simulation_time;
static int tos_is_192k = 0;

#define TOS "ram_test"

#define TICKLEN   (1.0/64000000)

// run for 100ms
#define TRACESTART   .2
#define TRACEEND     (TRACESTART + 0.1)

static uint64_t GetTickCountMs() {
  struct timespec ts;
  
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)(ts.tv_nsec / 1000000) + ((uint64_t)ts.tv_sec * 1000ull);
}

static unsigned char ram[4*1024*1024];
void initram() {
  memset(ram, 0, sizeof(ram));
}

static unsigned char rom[256*1024];
void initrom() {
  FILE *file=fopen(TOS ".img", "rb");
  if(!file) { perror("loading tos"); exit(-1); }
  int len = fread(&rom, 256, 1024, file);
  fclose(file);

  if(len < 256*1024*1024)
    tos_is_192k = 1;
}

void tick(int c) {
  static int old_addr = 0xffffff;
  static uint64_t ticks = 0;
  
  // A[0] must never be 1
  if(tb->A & 1) { printf("A[0] must never be 1\n"); exit(-1); }
  
  tb->clk32 = c; 
  tb->eval();
  
  if(c && !tb->BERR_N) printf("Bus error\n");
  
  if(simulation_time == 0)
    ticks = GetTickCountMs();
  
  // after one simulated millisecond calculate real time */
  if(simulation_time >= 0.001 && ticks) {
    ticks = GetTickCountMs() - ticks;
    printf("Speed factor = %lu\n", ticks);
    ticks = 0;
  }
  
  // trace after
#ifdef TRACESTART
  if(simulation_time > TRACESTART) trace->dump(1000000000000 * simulation_time);
#endif
  simulation_time += TICKLEN;
  
  // each tick is 1/64 us ot 15,625ns as we are simulating a 32 MHz clock
  if (c && !(tb->ROM2_N)) {
    // rom access
    tb->ROM_DOUT = (rom[(tb->A) & 0x3ffff] * 256) + rom[((tb->A) + 1)& 0x3ffff];
    
    if(tb->MHZ4_EN)
      printf("@%.3f CPU ROM read at 0x%08x = 0x%04x\n", 1000*simulation_time, tb->A, tb->ROM_DOUT);
  }
  
  if(c && tb->MHZ4_EN) {
    if(!tb->MFPCS_N) printf("@%.3f MFP at 0x%08x\n", 1000*simulation_time, tb->A);
    if(!tb->FCS_N)   printf("@%.3f FDC at 0x%08x\n", 1000*simulation_time, tb->A);
    if(!tb->RTCCS_N) printf("@%.3f RTC at 0x%08x\n", 1000*simulation_time, tb->A);
    if(tb->N6850)    printf("@%.3f 6850 at 0x%08x\n", 1000*simulation_time, tb->A);
    if(tb->SNDCS)    printf("@%.3f SNDCS at 0x%08x\n", 1000*simulation_time, tb->A);
    // if(!tb->) printf("\n");
  }
  
  /* normaly it doesn't matter who and why is accessing memory. But when
     tracing it may be useful to know whether it's CPU or video. This is what
     the cycle counter is trying to keep track of.*/
  
  static int cycle = -1;
  if(cycle >= 0 && c && tb->MHZ8_EN1) cycle = (cycle+1)&3;
  
  // max 4 MB RAM
  if (c && (!tb->RAS0_N || !tb->RAS1_N) && tb->ram_a < 0x200000) {
    // RAS is only active during one of the two MHZ8_EN1 cycles
    // per 4 MHz/250ns memory cycle
    if(tb->MHZ4_EN) {	    
      // for a memory cycle cas is also active. Otherwise it's
      // a refresh cycle
      if(!tb->CAS0L_N || !tb->CAS0H_N || !tb->CAS1L_N || !tb->CAS1H_N) {
	if(tb->we_n) {
	  tb->mdin = (ram[tb->ram_a<<1] * 256) + ram[(tb->ram_a<<1) + 1];
	  if(cycle == 2) {
	    printf("@%.3f CPU ram read at 0x%08x = 0x%04x\n", 1000*simulation_time, tb->ram_a<<1, tb->mdin);
	  } else {
	    // printf("@%.3f VID ram read at 0x%08x = 0x%04x\n", 1000*simulation_time, tb->ram_a<<1, tb->mdin);
	    
	  }
	} else {
	  // we expect to see ram writes always in cycle 2 as video never writes
	  if(cycle >= 0 && cycle != 2) { printf("unexpected write cycle\n"); exit(-1); }
	  printf("@%.3f CPU ram write at 0x%08x = 0x%04x\n", 1000*simulation_time, tb->ram_a<<1, tb->mdout);
	  
	  if((tb->ram_a<<1) == 0x44c) printf("sshiftmd h = %04x\n", tb->mdout);
	  if((tb->ram_a<<1) == 0x42e) printf("phystop h = %04x\n", tb->mdout);
	  if((tb->ram_a<<1) == 0x430) printf("phystop l = %04x\n", tb->mdout);
	  
	  if(!tb->CAS0H_N || !tb->CAS1H_N) ram[tb->ram_a<<1] = (tb->mdout & 0xff00) >> 8;
	  if(!tb->CAS0L_N || !tb->CAS1L_N) ram[(tb->ram_a<<1) + 1] = tb->mdout & 0xff;
	}
      } else {
	// printf("@%d ram refresh\n", cycle);
	// refresh cycles only happen in video cycle
	
	if(cycle < 0) cycle = 0;
	else if(cycle != 0) { printf("unexpected refresh cycle\n"); exit(-1); }
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
    
    vsync = tb->VSYNC_N;
    hsync = tb->HSYNC_N;
    tick(1); tick(0);
    if(file) {
      static int sub_cnt = 0;
      if(tb->BLANK_N) {
	if(sub_cnt == 3) {
	  rgb = (tb->R*256) + (tb->G*16) + tb->B;
	  fwrite(&rgb, 1, sizeof(rgb), file);
	}
	sub_cnt = (sub_cnt + 1)&3;
      }
    }
  }
}

int main(int argc, char **argv) {
  initrom();  
  initram();
  
  // Initialize Verilators variables
  Verilated::commandArgs(argc, argv);
  // Verilated::debug(1);
  Verilated::traceEverOn(true);
  trace = new VerilatedVcdC;
  trace->spTrace()->set_time_unit("1ns");
  trace->spTrace()->set_time_resolution("1ps");
  simulation_time = 0;
  
  // Create an instance of our module under test
  tb = new Vste_tb;
  tb->tos192k = tos_is_192k;
  
  tb->trace(trace, 99);
  trace->open("ste_tb.vcd");
  
  // apply reset and power-on for a while */
  tb->resb = 0; tb->porb = 0;
  for(int i=0;i<10;i++) { tick(1); tick(0); }
  tb->resb = 1; tb->porb = 1;
  
  /* run for a while */
  while(
#ifdef TRACEEND
	simulation_time<TRACEEND &&
#endif
	tb->HALTED_N) {
    tick(1);
    tick(0);
    
  }
  
  if(!tb->HALTED_N)
    printf("CPU halted\n");
  
  printf("stopped after %.3fms\n", 1000*simulation_time);
  
  dump();
  
  trace->close();
  
  /* dump ram content to disk */
  FILE *rd = fopen("ramdump.bin", "wb");
  fwrite(ram, 1024*1024, 4, rd);
  fclose(rd);
}

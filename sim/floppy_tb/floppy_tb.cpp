#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>

#include "Vfloppy_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

static Vfloppy_tb *tb;
static VerilatedVcdC *trace;
static double simulation_time;

#define TICKLEN   (1.0/64000000)

static uint64_t GetTickCountMs() {
  struct timespec ts;
  
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)(ts.tv_nsec / 1000000) + ((uint64_t)ts.tv_sec * 1000ull);
}

void tick(int c) {
  static uint64_t ticks = 0;
  static unsigned short *disk = NULL;
  
  tb->clk = c; 
  tb->eval();
 
  if(simulation_time == 0)
    ticks = GetTickCountMs();

  // check for floppy data request
  if(!disk) {
    FILE *fd = NULL;
    fd = fopen("disk_a.st", "rb");
    disk = (unsigned short *)malloc(737280);
    fread(disk, 720, 1024, fd);
    fclose(fd);
  }

  if(c && tb->rdreq)
    tb->rddata = disk[tb->rdaddr];
  
  trace->dump(1000000000000 * simulation_time);
  simulation_time += TICKLEN;
}

void wait_clk8() {
  tick(1);
  tick(0);
    
  while(!tb->clk8m_en) {
    tick(1);
    tick(0);
  }  
}

void wait_ms(int ms) {
  for(int i=0;i<32000*ms;i++) {  
    tick(1);
    tick(0);
  }
}

void wait_ns(int ns) {
  //   printf("WAIT %dns\n", ns);
  for(int i=0;i<(32*ns)/1000;i++) {  
    tick(1);
    tick(0);
  }
}

void cpu_write(int reg, int val) {
  wait_clk8();
  
  tb->cpu_addr = reg;
  tb->cpu_sel = 1;
  tb->cpu_rw = 0;
  tb->cpu_din = val;
  
  wait_clk8();
  tb->cpu_sel = 0;  
}

int cpu_read(int reg) {
  wait_clk8();
  
  tb->cpu_addr = reg;
  tb->cpu_sel = 1;
  tb->cpu_rw = 1;
  
  wait_clk8();
  tb->cpu_sel = 0;  

  return tb->cpu_dout;
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
  tb = new Vfloppy_tb;
	
  tb->trace(trace, 99);
  trace->open("floppy_tb.vcd");

  tb->reset = 0;
  tb->cpu_addr = 0;
  tb->cpu_sel = 0;
  tb->cpu_rw = 1;
  tb->cpu_din = 0;

  //   tb->sdcmd_in = 0;
  run(10);
  tb->reset = 1;

  run(1000);

  printf("RESTORE\n");
  cpu_write(0, 0x0b);  // Restore, Motor on, 6ms  
  while(cpu_read(0) & 0x01) wait_ms(1);  // wait for end of command
  printf("RESTORE done\n");

  wait_ms(40);
  
  // and read a sector
  printf("READ_SECTOR\n");
  cpu_write(1, 0);     // track 0
  cpu_write(2, 3);     // sector 3
  cpu_write(3, 0x00);  // data 0 ?
  cpu_write(0, 0x88);  // read sector, spinup

  // reading data should generate 512 drq's until a irq is generated
  int i = 0;
  unsigned char buffer[1024];
  while(!tb->irq) {
    wait_ns(100);
    if(tb->drq) {
      int data = cpu_read(3);      
      if(i < 1024) buffer[i] = data;
      i++;
    }
  }
  
  // read status to clear interrupt
  printf("READ_SECTOR done, read %d bytes, status = %x\n", i, cpu_read(0));
  
  hexdump(buffer, i);
  
  wait_ms(5);

  trace->close();
}

#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>

#include "Vflash.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

static Vflash *tb;
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
  
  tb->clk = c; 
  tb->eval();

  if(simulation_time == 0)
    ticks = GetTickCountMs();

  trace->dump(1000000000000 * simulation_time);
  simulation_time += TICKLEN;
}

void run(int ticks) {
  for(int i=0;i<ticks;i++) {
    tick(1);
    tick(0);
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
  tb = new Vflash;
	
  tb->trace(trace, 99);
  trace->open("flash.vcd");

  tb->resetn = 0;
  tb->cs = 0;
  run(10);
  tb->resetn = 1;

  run(100);
  tb->address = 0x80000;
  tb->cs= 1;
  run(1);
  tb->cs= 0;
  
  run(100);
  tb->address = 0x80001;
  tb->cs= 1;
  run(1);
  tb->cs= 0;

  run(10000);
  
  trace->close();
}

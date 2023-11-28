#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>

#include "Vfloppy_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <ff.h>
#include <diskio.h>

FATFS fs;

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
  static unsigned long sector = 0xffffffff;
  static unsigned short sector_data[256];
  static unsigned long long flen;
  static FILE *fd = NULL;
  
  tb->clk = c; 
  tb->eval();
 
  if(simulation_time == 0)
    ticks = GetTickCountMs();

  // check for floppy data request
  if(!fd) {
    fd = fopen("sd.img", "rb");
    if(!fd) { perror("OPEN ERROR"); exit(-1); }
    fseek(fd, 0, SEEK_END);
    flen = ftello(fd);
    printf("Image size is %lld\n", flen);
    fseek(fd, 0, SEEK_SET);
  }

  static int last_rdreq = 0;
  if(c && tb->rdreq) {
    int s = tb->rdaddr / 256;
    if(s != sector) {
      printf("Loading sector %d\n", s);
      fseek(fd, 512 * s, SEEK_SET);
      fread(sector_data, 2, 256, fd);
      sector = s;
    }
    
    //    if(last_rdreq == 0) printf("Read word 0x%lx sector %ld/%ld\n", tb->rdaddr, tb->rdaddr/256, tb->rdaddr & 255);
    if(tb->rdaddr < flen/2) tb->rddata = sector_data[tb->rdaddr & 255];
    else                    tb->rddata = 0xa5a5;

  }
  last_rdreq = tb->rdreq;
  
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

// mcu interface
// output       mcu_strobe, // byte strobe for sc card target  
// output       mcu_start,
// input  [7:0] mcu_din,
// output [7:0] mcu_dout

// the Atari ST/fdc will request sectors. This request is to
// be sent to the MCU which in return will request the actual read

unsigned char mcu_write_byte(unsigned char byte, char start) {
  tb->mcu_dout = byte;
  if(start) tb->mcu_start = 1;
  tb->mcu_strobe = 1;
  run(1);
  tb->mcu_strobe = 0;
  run(1);
  tb->mcu_start = 0;
  return tb->mcu_din;
}

unsigned char mcu_read_byte(void) {
  tb->mcu_dout = 0x00;
  tb->mcu_strobe = 1;
  run(1);
  tb->mcu_strobe = 0;
  run(1);
  return tb->mcu_din;  
}


static LBA_t clst2sect(DWORD clst) {
  clst -= 2; /* Cluster number is origin from 2 */
  if (clst >= fs.n_fatent - 2)   return 0;
  return fs.database + (LBA_t)fs.csize * clst;
}

FIL fil;
#define SZ_TBL 16   // 64 bytes
DWORD lktbl[SZ_TBL];

void fs_prepare(char *name) {
  if(f_open(&fil, name, FA_OPEN_EXISTING | FA_READ) != 0) {
    printf("file open failed\n");
    return;
  } else {
    printf("file opened, cl=%d(%d)\n", fil.obj.sclust, clst2sect(fil.obj.sclust));
    
    // try to determine files cluster chain    
    printf("cl @%d = %d, sec=%d\n", fil.fptr, fil.clust, fil.sect);

    // create cluster map (link table)
    for(int i=0;i<SZ_TBL;i++) lktbl[i] = -42;

    fil.cltbl = lktbl;
    lktbl[0] = SZ_TBL;

    if(f_lseek(&fil, CREATE_LINKMAP)) {
      printf("Link table creation failed\n");
      fil.cltbl = NULL;
    } else {
      printf("File clusters = %d\n", fil.obj.objsize / 512 / fs.csize);

      // dump the table
      for(int i=0;i<SZ_TBL && lktbl[i];i++)
	printf("%d: %d\n", i, lktbl[i]);
    }
  }
}

void fs_readdir(void) {
  // test read sd cards root
  DIR dir;
  FILINFO fno;

  f_opendir(&dir, "/sd");
  do {
    f_readdir(&dir, &fno);
    if(fno.fname[0] != 0 && !(fno.fattrib & (AM_HID|AM_SYS)) )
      printf("%s %s, len=%d\n", (fno.fattrib & AM_DIR) ? "dir: ":"file:", fno.fname, fno.fsize);
  } while(fno.fname[0] != 0);

  f_closedir(&dir);
}

// the MCU handles the underlying SD card file system and thus
// needs a way to directly access the SD cards contents
void mcu_read_sector(unsigned long sector, unsigned char *buffer) {
  mcu_write_byte(0x03, 1);

  for(int i=0;i<4;i++)
    mcu_write_byte((sector >> 8*(3-i))&0xff, 0);

  // wait for data to arrive
  while(mcu_read_byte());

  // further reads will return the sector data
  for(int i=0;i<512;i++)
    buffer[i] = mcu_read_byte(); 
  
  // hexdump(buffer, 512);  
}

void mcu_poll(void) {
  // MCU requests sd card status
  unsigned char status = mcu_write_byte(0x01, 1);  
  unsigned char request = mcu_write_byte(0, 0); 
  // push in one more byte
  //  unsigned char status = mcu_read_byte();
  printf("STATUS = %02x\n", status);
  char *type[] = { "UNKNOWN", "SDv1", "SDv2", "SDHCv2" };

  printf("  card status: %d\n", (status >> 4)&15);
  printf("  card type: %s\n", type[(status >> 2)&3]);

  unsigned long sector = 0;
  for(int i=0;i<4;i++)
    sector = (sector << 8) | mcu_read_byte();

  if(request & 1) {
    run(100);

    if(!fil.flag) return;
    
    // simulate MCU figuring out which sector to use
  
    // translate sector into a cluster number inside image
    f_lseek(&fil, (sector+1)*512);

    // and add sector offset within cluster    
    unsigned long dsector = clst2sect(fil.clust) + sector%fs.csize;
    
    printf("request sector %lu = %lu\n", sector, dsector);

    // in return request core to load sector + 100
    unsigned char status = mcu_write_byte(0x02, 1);

    // write sector number to load
    for(int i=0;i<4;i++) mcu_write_byte((dsector >> 8*(3-i))&0xff, 0);    
  }
}

void read_sector(int track, int sec) {
  // this poll should return no request to load a sector
  mcu_poll();
  
  // fdc read a sector
  printf("FDC: READ_SECTOR %d/%d\n", track, sec);
  cpu_write(1, track); // track
  cpu_write(2, sec);   // sector
  cpu_write(3, 0x00);  // data 0 ?
  cpu_write(0, 0x88);  // read sector, spinup

  wait_ns(1000);

  // this poll should see a request and handle it
  mcu_poll();
  
#if 1
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
#else
  run(100);
#endif
}

int MSC_disk_status() {
  // printf("MSC_disk_status()\n");
  return 0;
}

int MSC_disk_initialize() {
  // printf("MSC_disk_initialize()\n");
  return 0;
}

int MSC_disk_read(BYTE *buff, LBA_t sector, UINT count) {
  //  printf("MSC_disk_read(%p,%d,%d)\n", buff, sector, count);  
  mcu_read_sector(sector, buff);
  return 0;
}

int MSC_disk_write(const BYTE *buff, LBA_t sector, UINT count) {
  printf("MSC_disk_write(%p,%d,%d)\n", buff, sector, count);  
  return 0;
}

int MSC_disk_ioctl(BYTE cmd, void *buff) {
  printf("MSC_disk_ioctl(%d,%p)\r\n", cmd, buff);
  
  switch (cmd) {
    // Get R/W sector size (WORD)
  case GET_SECTOR_SIZE:
    break;
    
    // Get erase block size in unit of sector (DWORD)
  case GET_BLOCK_SIZE:
    break;
    
  case GET_SECTOR_COUNT:
    break;
    
  case CTRL_SYNC:
    break;
    
  default:
    break;
  }

  return 0;
}

DSTATUS Translate_Result_Code(int result) { return result; }

int fs_init() {
  FRESULT res_msc;

  FATFS_DiskioDriverTypeDef MSC_DiskioDriver = { NULL };
  MSC_DiskioDriver.disk_status = MSC_disk_status;
  MSC_DiskioDriver.disk_initialize = MSC_disk_initialize;
  MSC_DiskioDriver.disk_write = MSC_disk_write;
  MSC_DiskioDriver.disk_read = MSC_disk_read;
  MSC_DiskioDriver.disk_ioctl = MSC_disk_ioctl;
  MSC_DiskioDriver.error_code_parsing = Translate_Result_Code;
  
  disk_driver_callback_init(DEV_SD, &MSC_DiskioDriver);
  
  res_msc = f_mount(&fs, "/sd", 1);
  if (res_msc != FR_OK) {
    printf("mount fail,res:%d\n", res_msc);
    return -1;
  }

  return 0;
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

  tb->mcu_dout = 0;
  tb->mcu_start = 0;
  tb->mcu_strobe = 0;

  run(10);
  tb->reset = 1;

  wait_ms(10);
  
  fs_init();

  // this demo expects a file named "disk_a.st" to be present
  // inside the sd card image on root level
  fs_prepare("/sd/disk_a.st");

#if 1
  printf("RESTORE\n");
  cpu_write(0, 0x0b);  // Restore, Motor on, 6ms  
  while(cpu_read(0) & 0x01) wait_ms(1);  // wait for end of command
  printf("RESTORE done\n");

  wait_ms(40);

  read_sector(0, 3);  
  read_sector(0, 4);

  wait_ms(20);
  
#else
  run(10000);
#endif

  
  trace->close();
}

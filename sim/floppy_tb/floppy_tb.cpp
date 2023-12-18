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

static uint64_t GetTickCountMs() {
  struct timespec ts;
  
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)(ts.tv_nsec / 1000000) + ((uint64_t)ts.tv_sec * 1000ull);
}

void tick(int c) {
  static uint64_t ticks = 0;
  static unsigned long sector = 0xffffffff;
  static unsigned long long flen;
  static FILE *fd = NULL;
  static uint8_t sector_data[520];   // 512 bytes + four 16 bit crcs
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

  static int last_sdclk = -1;
  
  if(tb->sdclk != last_sdclk) {
    // rising sd card clock edge
    if(tb->sdclk) {
      
      // write postamble (ack + busy)
      int ack_start = 580;
      int busy_end  = 700;
      int ack_token = 0b00101000;  // start bit 0, ack ok 010, stopbit 1, busy 000
      if(write_count < 512) {
	static unsigned char rbuf[520];
         if(write_expect < 0) {
          // wait for first data != 15
          if(!(tb->sddat & 1))
            write_expect = 1024+16;  // 1024 * 4 bit + 4 * 16 bit crc
          
	 } else if(write_expect > 0) {
	   if((write_expect-1)&1)
	     rbuf[519-((write_expect-1)/2)] = tb->sddat << 4;
	   else
	     rbuf[519-((write_expect-1)/2)] |= tb->sddat;
	   
	   //printf("Write %d %s = %x\n", (write_expect-1)/2,
	   //	  ((write_expect-1)&1)?"hi":"lo",
	   //	  rbuf[519-((write_expect-1)/2)]);
	   
	   write_expect--;
	   if(write_expect == 0) {

	    printf("Data written to card:\n");
	    hexdump(rbuf, 512);
	    
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
      
      // sending 4 bits
      if(dat_ptr && dat_bits) {
        if(dat_bits == 128*8 + 16 + 1 + 1) {
          // card sends start bit
          tb->sddat_in = 0;
          printf("READ-4 START\n");
        } else if(dat_bits > 1) {
          if(dat_bits == 128*8 + 16 + 1) printf("READ DATA START\n");
          if(dat_bits == 1) printf("READ DATA END\n");
          int nibble = dat_bits&1;   // 1: high nibble, 0: low nibble
          if(nibble) tb->sddat_in = (*dat_ptr >> 4)&15;
          else       tb->sddat_in = *dat_ptr++ & 15;
        } else
	  tb->sddat_in = 15;
	
        dat_bits--;
      }
      
      if(cmd_ptr && cmd_bits) {
        int bit = 7-((cmd_bits-1) & 7);
        tb->sdcmd_in = (*cmd_ptr & (0x80>>bit))?1:0;
        if(bit == 7) cmd_ptr++;
        cmd_bits--;
      } else {      
        tb->sdcmd_in = (cmd_out & (1ll<<47))?1:0;
        cmd_out = (cmd_out << 1)|1;
      }

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
            cmd_out = reply(3, (RCA<<16) | 0);  // status = 0
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
            cmd_out = reply(17, 0);    // ok

            // load sector
            {
	      // check for floppy data request
	      if(!fd) {
		fd = fopen("sd.img", "rb");
		if(!fd) { perror("OPEN ERROR"); exit(-1); }
		fseek(fd, 0, SEEK_END);
		flen = ftello(fd);
		printf("Image size is %lld\n", flen);
		fseek(fd, 0, SEEK_SET);
	      }
	      
              fseek(fd, 512 * arg, SEEK_SET);
              int items = fread(sector_data, 2, 256, fd);
              if(items != 256) perror("fread()");

	      // for(int i=0;i<16;i++) printf("%02x ", sector_data[i]);
              // printf("\n");
            }
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
	    break;
            
          case 24:  // write block
            printf("Request to write single block %ld\n", arg);
            write_count = 0;
	    write_expect = -1;  
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
  

      
  if(simulation_time == 0)
    ticks = GetTickCountMs();

#if 0 // now obsolete sd_fake interface
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
#endif
  
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

void wait_us(int us) {
  for(int i=0;i<32*us;i++) {  
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
  printf("Read sector %lu\n", sector);
  
  mcu_write_byte(0x03, 1);

  for(int i=0;i<4;i++)
    mcu_write_byte((sector >> 8*(3-i))&0xff, 0);

  // wait for data to arrive
  printf("Waiting for data ...\n");
  while(mcu_read_byte());

  // further reads will return the sector data
  for(int i=0;i<512;i++)
    buffer[i] = mcu_read_byte(); 

  //  printf("MCU data for sector %ld\n", sector);
  //  hexdump(buffer, 512);

  wait_ms(1);
}

void mcu_write_sector(unsigned long sector, unsigned char *buffer) {
  printf("Write sector %lu\n", sector);
  
  mcu_write_byte(0x05, 1);  // command byte 5, start byte
  for(int i=0;i<4;i++) mcu_write_byte((sector >> 8*(3-i))&0xff, 0);

  // write payload
  for(int i=0;i<512;i++)
    mcu_write_byte(buffer[i],0);
  
  // read busy flag
  while(mcu_read_byte());

  wait_ms(1);
}

void mcu_poll(int quiet) {
  // MCU requests sd card status
  unsigned char status = mcu_write_byte(0x01, 1);  
  unsigned char request = mcu_write_byte(0, 0);

  if(!quiet) {
    printf("Request is %d\n", request);

    // push in one more byte
    //  unsigned char status = mcu_read_byte();
    printf("STATUS = %02x\n", status);
    char *type[] = { (char*)"UNKNOWN", (char*)"SDv1",
		     (char*)"SDv2", (char*)"SDHCv2" };
    
    printf("  card status: %d\n", (status >> 4)&15);
    printf("  card type: %s\n", type[(status >> 2)&3]);
  }
  
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
  mcu_poll(0);
  
  // fdc read a sector
  printf("FDC: READ_SECTOR %d/%d\n", track, sec);
  cpu_write(1, track); // track
  cpu_write(2, sec);   // sector
  cpu_write(3, 0x00);  // data 0 ?
  cpu_write(0, 0x88);  // read sector, spinup

  wait_ns(1000);

  // this poll should see a request and handle it
  mcu_poll(0);
  
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
}

void write_sector(int track, int sec) {  
  // this poll should return no request to load a sector
  mcu_poll(0);
  
  // fdc write a sector
  printf("FDC: WRITE_SECTOR %d/%d\n", track, sec);
  cpu_write(1, track); // track
  cpu_write(2, sec);   // sector
  cpu_write(3, 0x00);  // data 0 ?
  cpu_write(0, 0xa8);  // write sector, spinup

  wait_ns(1000);

#if 1 
  // writing data should generate 512 drq's until a irq is generated
  int i = 0;
  unsigned char buffer[1024];
  while(!tb->irq) {
    // while(i < 512) {
    wait_ns(100);
    if(tb->drq) {
      cpu_write(3, i);      
      i++;
    }
    
    // this poll should see the sector translation request after 512 bytes
    mcu_poll(1);
    wait_ns(100);    
  }
  
  // read status to clear interrupt
  printf("WRITE_SECTOR done, wrote %d bytes, status = %x\n", i, cpu_read(0));

  wait_ms(10);
#else
  wait_ms(10);
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

  tb->sdcmd_in = 1; tb->sddat_in = 15;  // inputs of sd card
 
  run(10);
  tb->reset = 1;

  printf("Giving card 10ms to initialize\n");
  wait_ms(4);

#if 0 // MCU direct r/w test
  // read a sector
  unsigned char buffer[512];
  mcu_read_sector(1, buffer);
  hexdump(buffer, 512);

  // write sector back
  mcu_write_sector(1, buffer);
#endif
  
#if 1
  printf("Initializing FS ...\n");  
  fs_init();

  // this demo expects a file named "disk_a.st" to be present
  // inside the sd card image on root level
  printf("Opening disk_a.st\n");  
  fs_prepare((char*)"/sd/disk_a.st");
  
#if 1
  printf("RESTORE\n");
  cpu_write(0, 0x0b);  // Restore, Motor on, 6ms  
  while(cpu_read(0) & 0x01) wait_ms(1);  // wait for end of command
  printf("RESTORE done\n");

  wait_ms(40);

  // read_sector(0, 3);  
  write_sector(0, 3);  

  wait_ms(10);
  
#else
  run(10000);
#endif
#endif
  
  trace->close();
}

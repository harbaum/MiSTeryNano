//
// sdc.c - sd card access 
//

#include "sdc.h"
#include <ff.h>
#include <stdlib.h>
#include <diskio.h>
#include <ctype.h>
#include <string.h>

static spi_t *spi;

static FATFS fs;
static FIL fil;

static DWORD *lktbl = NULL;

#define CARD_MOUNTPOINT "/sd"

static void sdc_spi_begin(spi_t *spi) {
  spi_begin(spi);  
  spi_tx_u08(spi, SPI_TARGET_SDC);
}

static LBA_t clst2sect(DWORD clst) {
  clst -= 2;
  if (clst >= fs.n_fatent - 2)   return 0;
  return fs.database + (LBA_t)fs.csize * clst;
}

static void hexdump(void *data, int size) {
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
    for(i=0;i<b2c;i++)      printf("%c", isprint((int)ptr[i])?ptr[i]:'.');
    printf("\r\n");
    ptr  += b2c;
    size -= b2c;
    n    += b2c;
  }
}

int sdc_read_sector(unsigned long sector, unsigned char *buffer) {
  sdc_spi_begin(spi);  
  spi_tx_u08(spi, SPI_SDC_MCU_READ);
  spi_tx_u08(spi, (sector >> 24) & 0xff);
  spi_tx_u08(spi, (sector >> 16) & 0xff);
  spi_tx_u08(spi, (sector >> 8) & 0xff);
  spi_tx_u08(spi, sector & 0xff);

  // todo: add timeout
  while(spi_tx_u08(spi, 0));  // wait for ready

  // read 512 bytes sector data
  for(int i=0;i<512;i++) buffer[i] = spi_tx_u08(spi, 0);

  spi_end(spi);
  
  // hexdump(buffer, 512);

  return 0;
}

// -------------------- fatfs read/write interface to sd card connected to fpga -------------------

static int sdc_status() {
  // printf("sdc_status()\r\n");
  return 0;
}

static int sdc_initialize() {
  // printf("sdc_initialize()\r\n");
  return 0;
}

static int sdc_read(BYTE *buff, LBA_t sector, UINT count) {
  printf("sdc_read(%p,%d,%d)\r\n", buff, sector, count);  
  sdc_read_sector(sector, buff);
  return 0;
}

static int sdc_write(const BYTE *buff, LBA_t sector, UINT count) {
  printf("sdc_write(%p,%d,%d)\r\n", buff, sector, count);  
  return 0;
}

static int sdc_ioctl(BYTE cmd, void *buff) {
  printf("sdc_ioctl(%d,%p)\r\n", cmd, buff);
  return 0;
}
 
static DSTATUS Translate_Result_Code(int result) { return result; }

static int fs_init() {
  FRESULT res_msc;

  FATFS_DiskioDriverTypeDef MSC_DiskioDriver = { NULL };
  MSC_DiskioDriver.disk_status = sdc_status;
  MSC_DiskioDriver.disk_initialize = sdc_initialize;
  MSC_DiskioDriver.disk_write = sdc_write;
  MSC_DiskioDriver.disk_read = sdc_read;
  MSC_DiskioDriver.disk_ioctl = sdc_ioctl;
  MSC_DiskioDriver.error_code_parsing = Translate_Result_Code;
  
  disk_driver_callback_init(DEV_SD, &MSC_DiskioDriver);
  
  res_msc = f_mount(&fs, CARD_MOUNTPOINT, 1);
  if (res_msc != FR_OK) {
    printf("mount fail,res:%d\r\n", res_msc);
    return -1;
  }

  return 0;
}

// -------------- higher layer routines provided to the firmware ----------------
 
// keep track of working directory
static char *cwd = NULL;

int sdc_poll(void) {
  // read sd status
  sdc_spi_begin(spi);  
  spi_tx_u08(spi, SPI_SDC_STATUS);
  unsigned char status = spi_tx_u08(spi, 0);
  unsigned long rsector = 0;
  for(int i=0;i<4;i++) rsector = (rsector << 8) | spi_tx_u08(spi, 0); 
  spi_end(spi);

#if 0
  char *type[] = { "UNKNOWN", "SDv1", "SDv2", "SDHCv2" };
  printf("SDC status: %02x\r\n", status);
  printf("  card status: %d\r\n", (status >> 4)&15);
  printf("  card type: %s\r\n", type[(status >> 2)&3]);
#endif
  
  if(status & 1) {
    if(!fil.flag) {
      // no file selected, nak to make core clear the interrupt
      return -1;
    }
    
    // ---- figure out which physical sector to use ----
  
    // translate sector into a cluster number inside image
    f_lseek(&fil, (rsector+1)*512);

    // and add sector offset within cluster    
    unsigned long dsector = clst2sect(fil.clust) + rsector%fs.csize;
    
    printf("request sector %lu -> %lu\r\n", rsector, dsector);

    // send sector number to core, so it can fetch the right
    // sector from it's local sd card
    sdc_spi_begin(spi);  
    spi_tx_u08(spi, SPI_SDC_READ);
    spi_tx_u08(spi, (dsector >> 24) & 0xff);
    spi_tx_u08(spi, (dsector >> 16) & 0xff);
    spi_tx_u08(spi, (dsector >> 8) & 0xff);
    spi_tx_u08(spi, dsector & 0xff);
    spi_end(spi);
  }

  return 0;
}

int sdc_image_inserted(unsigned long size) {
  // report the size of the inserted image to the core. This is needed
  // to guess sector/track/side information for floppy disk images, so the
  // core can translate from floppy disk to LBA

  printf("Image inserted. Size = %d\r\n", size);
  
  sdc_spi_begin(spi);  
  spi_tx_u08(spi, SPI_SDC_INSERTED);
  spi_tx_u08(spi, (size >> 24) & 0xff);
  spi_tx_u08(spi, (size >> 16) & 0xff);
  spi_tx_u08(spi, (size >> 8) & 0xff);
  spi_tx_u08(spi, size & 0xff);
  spi_end(spi);

  return 0;
}

int sdc_image_open(char *name) {
  char fname[strlen(cwd) + strlen(name) + 2];
  strcpy(fname, cwd);
  strcat(fname, "/");
  strcat(fname, name);

  // tell core that the "disk" has been removed
  sdc_image_inserted(0);

  // close any previous image, especially free the link table
  if(fil.cltbl) {
    printf("freeing link table\r\n");
    free(lktbl);
    lktbl = NULL;
    fil.cltbl = NULL;
  }
  
  printf("Mounting %s\r\n", fname);

  if(f_open(&fil, fname, FA_OPEN_EXISTING | FA_READ) != 0) {
    printf("file open failed\r\n");
    return -1;
  } else {
    printf("file opened, cl=%d(%d)\r\n", fil.obj.sclust, clst2sect(fil.obj.sclust));
    printf("File len = %d, spc = %d, clusters = %d\r\n",
	   fil.obj.objsize, fs.csize, fil.obj.objsize / 512 / fs.csize);      
    
    // try with a 16 entry link table
    lktbl = malloc(16 * sizeof(DWORD));    
    fil.cltbl = lktbl;
    lktbl[0] = 16;
    
    if(f_lseek(&fil, CREATE_LINKMAP)) {
      // this isn't really a problem. But sector access will
      // be slower
      printf("Link table creation failed, required size: %d\r\n", lktbl[0]);

      // re-alloc sufficient memory
      lktbl = realloc(lktbl, sizeof(DWORD) * lktbl[0]);

      // and retry link table creation
      if(f_lseek(&fil, CREATE_LINKMAP)) {
	printf("Link table creation finally failed, required size: %d\r\n", lktbl[0]);
	free(lktbl);
	lktbl = NULL;
	fil.cltbl = NULL;

	return -1;
      } else
	printf("Link table ok\r\n");
    }
  }

  // image has successfully been opened, so report image size to core
  sdc_image_inserted(fil.obj.objsize);
  
  return 0;
}

sdc_dir_t *sdc_readdir(char *name) {
  static sdc_dir_t sdc_dir = { 0, NULL };

  // set default path
  if(!cwd) cwd = strdup(CARD_MOUNTPOINT);

  int dir_compare(const void *p1, const void *p2) {
    sdc_dir_entry_t *d1 = (sdc_dir_entry_t *)p1;
    sdc_dir_entry_t *d2 = (sdc_dir_entry_t *)p2;

    // comparing directory with regular file?
    if(d1->is_dir != d2->is_dir)
      return d2->is_dir - d1->is_dir;

    return strcasecmp(d1->name, d2->name);    
  }

  void append(sdc_dir_t *dir, FILINFO *fno) {
    if(!(dir->len%8))
      // allocate room for 8 more entries
      dir->files = reallocarray(dir->files, dir->len + 8, sizeof(sdc_dir_entry_t));
      
    dir->files[dir->len].name = strdup(fno->fname);
    dir->files[dir->len].len = fno->fsize;
    dir->files[dir->len].is_dir = (fno->fattrib & AM_DIR)?1:0;
    dir->len++;
  }
  
  DIR dir;
  FILINFO fno;

  // assemble name before we free it
  if(name) {
    if(strcmp(name, "..")) {
      // alloc a longer string to fit new cwd
      char *n = malloc(strlen(cwd)+strlen(name)+2);  // both strings + '/' and '\0'
      strcpy(n, cwd); strcat(n, "/"); strcat(n, name);
      free(cwd);
      cwd = n;
    } else {
      // no real need to free here, the unused parts will be free'd
      // once the cwd length increaes
      strrchr(cwd, '/')[0] = 0;
    }
  }
  
  // free existing file names
  if(sdc_dir.files) {
    for(int i=0;i<sdc_dir.len;i++)
      free(sdc_dir.files[i].name);

    free(sdc_dir.files);
    sdc_dir.len = 0;
    sdc_dir.files = NULL;
  }

  // add "<UP>" entry for anything but root
  if(strcmp(cwd, CARD_MOUNTPOINT) != 0) {
    strcpy(fno.fname, "..");
    fno.fattrib = AM_DIR;
    append(&sdc_dir, &fno);
  }

  printf("max name len = %d\r\n", FF_LFN_BUF);

  int ret = f_opendir(&dir, cwd);

  printf("opendir(%s)=%d\r\n", cwd, ret);
  
  do {
    f_readdir(&dir, &fno);
    if(fno.fname[0] != 0 && !(fno.fattrib & (AM_HID|AM_SYS)) ) {
      printf("%s %s, len=%d\r\n", (fno.fattrib & AM_DIR) ? "dir: ":"file:", fno.fname, fno.fsize);

      append(&sdc_dir, &fno);
    }
  } while(fno.fname[0] != 0);

  f_closedir(&dir);

  qsort(sdc_dir.files, sdc_dir.len, sizeof(sdc_dir_entry_t), dir_compare);

  return &sdc_dir;
}

int sdc_init(spi_t *p_spi) {
  spi = p_spi;

  printf("---- SDC init ----\r\n");

  fs_init();

  sdc_poll();
  
  return 0;
}


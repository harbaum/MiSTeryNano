//
// sdc.c - sd card access 
//
//

#include "sdc.h"
#include <ff.h>
#include <stdlib.h>
#include <diskio.h>
#include <ctype.h>
#include <string.h>
#include "sysctrl.h"

static spi_t *spi = NULL;
static int sdc_ready = 0;
static SemaphoreHandle_t sdc_sem;

static FATFS fs;

static FIL fil[MAX_DRIVES];
static DWORD *lktbl[MAX_DRIVES];

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
  // check if sd card is still busy as it may
  // be reading a sector for the core. Forcing a MCU read
  // may change the data direction from core to mcu while
  // the core is still reading
  unsigned char status;
  do {
    sdc_spi_begin(spi);  
    spi_tx_u08(spi, SPI_SDC_STATUS);
    status = spi_tx_u08(spi, 0);
    spi_end(spi);  
  } while(status & 0x02);   // card busy?

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

  //  printf("sector %ld\r\n", sector);
  //  hexdump(buffer, 512);

  return 0;
}

int sdc_write_sector(unsigned long sector, const unsigned char *buffer) {
  // check if sd card is still busy as it may
  // be reading a sector for the core.
  unsigned char status;
  do {
    sdc_spi_begin(spi);  
    spi_tx_u08(spi, SPI_SDC_STATUS);
    status = spi_tx_u08(spi, 0);
    spi_end(spi);  
  } while(status & 0x02);   // card busy?

  sdc_spi_begin(spi);  
  spi_tx_u08(spi, SPI_SDC_MCU_WRITE);
  spi_tx_u08(spi, (sector >> 24) & 0xff);
  spi_tx_u08(spi, (sector >> 16) & 0xff);
  spi_tx_u08(spi, (sector >> 8) & 0xff);
  spi_tx_u08(spi, sector & 0xff);

  // write sector data
  for(int i=0;i<512;i++) spi_tx_u08(spi, buffer[i]);  

  // todo: add timeout
  while(spi_tx_u08(spi, 0));  // wait for ready

  spi_end(spi);

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
  sdc_write_sector(sector, buff);
  return 0;
}

static int sdc_ioctl(BYTE cmd, void *buff) {
  printf("sdc_ioctl(%d,%p)\r\n", cmd, buff);
  return 0;
}
 
static DSTATUS Translate_Result_Code(int result) { return result; }

static int fs_init() {
  FRESULT res_msc;

  for(int i=0;i<MAX_DRIVES;i++)
    lktbl[i] = NULL;

 FATFS_DiskioDriverTypeDef MSC_DiskioDriver = { NULL };
  MSC_DiskioDriver.disk_status = sdc_status;
  MSC_DiskioDriver.disk_initialize = sdc_initialize;
  MSC_DiskioDriver.disk_write = sdc_write;
  MSC_DiskioDriver.disk_read = sdc_read;
  MSC_DiskioDriver.disk_ioctl = sdc_ioctl;
  MSC_DiskioDriver.error_code_parsing = Translate_Result_Code;
  
  disk_driver_callback_init(DEV_SD, &MSC_DiskioDriver);

  // wait for SD card to become available
  // TODO: Add timeout and display error in OSD
  unsigned char status;
  int timeout = 2000;
  do {
    sdc_spi_begin(spi);  
    spi_tx_u08(spi, SPI_SDC_STATUS);
    status = spi_tx_u08(spi, 0);
    spi_end(spi);
    if((status & 0xf0) != 0x80) {
      timeout--;
      vTaskDelay(pdMS_TO_TICKS(1));
    }
  } while(timeout && ((status & 0xf0) != 0x80));
  // getting here with a timeout either means that there
  // is no matching core on the FPGA or that there is no
  // SD card inserted
  
  // switch rgb led to green
  if(!timeout) {
    printf("SD not ready, status = %d\r\n", status);
    sys_set_rgb(spi, 0x400000);  // red, failed
    return -1;
  }
  
  char *type[] = { "UNKNOWN", "SDv1", "SDv2", "SDHCv2" };
  printf("SDC status: %02x\r\n", status);
  printf("  card status: %d\r\n", (status >> 4)&15);
  printf("  card type: %s\r\n", type[(status >> 2)&3]);

  res_msc = f_mount(&fs, CARD_MOUNTPOINT, 1);
  if (res_msc != FR_OK) {
    printf("mount fail,res:%d\r\n", res_msc);
    sys_set_rgb(spi, 0x400000);  // red, failed
    return -1;
  }
  
  sys_set_rgb(spi, 0x004000);  // green, ok
  return 0;
}

// -------------- higher layer routines provided to the firmware ----------------
 
// keep track of working directory for each drive
static char *cwd[MAX_DRIVES] = { NULL, NULL, NULL, NULL };
static char *image_name[MAX_DRIVES] = { NULL, NULL, NULL, NULL };

void sdc_set_default(int drive, const char *name) {
  // a valid filename will currently always begin with /sd
  if(strncasecmp(name, CARD_MOUNTPOINT, strlen(CARD_MOUNTPOINT)) == 0) {
    // name should consist of path and image name
    char *p = strrchr(name+strlen(CARD_MOUNTPOINT), '/');
    if(p && *p) {
      if(cwd[drive]) free(cwd[drive]);
      cwd[drive] = strndup(name, p-name);
      if(image_name[drive]) free(image_name[drive]);
      image_name[drive] = strdup(p+1);
    }
  }
}

char *sdc_get_image_name(int drive) {
  return image_name[drive];
}

char *sdc_get_cwd(int drive) {
  return cwd[drive];
}

int sdc_is_ready(void) {
  return sdc_ready;
}

static const char *drivename(int drive) {
  static const char *names[] = { "A", "B", "ACSI 0", "ACSI 1" };
  return names[drive];  
}

int sdc_handle_event(void) {
  // printf("Handling SDC event\r\n");

  // read sd status
  sdc_spi_begin(spi);  
  spi_tx_u08(spi, SPI_SDC_STATUS);
  spi_tx_u08(spi, 0);
  unsigned char request = spi_tx_u08(spi, 0);
  unsigned long rsector = 0;
  for(int i=0;i<4;i++) rsector = (rsector << 8) | spi_tx_u08(spi, 0); 
  spi_end(spi);

  int drive = 0;               // 0 = Drive A:
  if(request == 2) drive = 1;  // 1 = Drive B:
  if(request == 4) drive = 2;  // 2 = ACSI 0:
  if(request == 8) drive = 3;  // 3 = ACSI 1:
  
  if(request & 15) {
    if(!fil[drive].flag) {
      // no file selected
      // this should actually never happen as the core won't request
      // data if it hasn't been told that an image is inserted
      return -1;
    }
    
    // ---- figure out which physical sector to use ----
  
    // translate sector into a cluster number inside image
    sdc_lock();
    f_lseek(&fil[drive], (rsector+1)*512);

    // and add sector offset within cluster    
    unsigned long dsector = clst2sect(fil[drive].clust) + rsector%fs.csize;
    
    printf("%s: lba %lu = %lu\r\n", drivename(drive), rsector, dsector);

    // send sector number to core, so it can read or write the right
    // sector from/to its local sd card
    sdc_spi_begin(spi);  
    spi_tx_u08(spi, SPI_SDC_CORE_RW);
    spi_tx_u08(spi, (dsector >> 24) & 0xff);
    spi_tx_u08(spi, (dsector >> 16) & 0xff);
    spi_tx_u08(spi, (dsector >> 8) & 0xff);
    spi_tx_u08(spi, dsector & 0xff);

    // wait while core is busy to make sure we don't start
    // requesting data for ourselves while the core is still
    // doing its own io
    while(spi_tx_u08(spi, 0) & 1);
    
    spi_end(spi);

    sdc_unlock();
  }

  return 0;
}

static int sdc_image_inserted(char drive, unsigned long size) {
  // report the size of the inserted image to the core. This is needed
  // to guess sector/track/side information for floppy disk images, so the
  // core can translate from floppy disk to LBA

  printf("%s: inserted. Size = %d\r\n", drivename(drive), size);
  
  sdc_spi_begin(spi);
  spi_tx_u08(spi, SPI_SDC_INSERTED);
  // drive 0=Disk A:, 1=Disk B:, 2=ACSI 0:, 3=ACSI 1:
  spi_tx_u08(spi, drive);
  spi_tx_u08(spi, (size >> 24) & 0xff);
  spi_tx_u08(spi, (size >> 16) & 0xff);
  spi_tx_u08(spi, (size >> 8) & 0xff);
  spi_tx_u08(spi, size & 0xff);
  spi_end(spi);

  return 0;
}

int sdc_image_open(int drive, char *name) {
  // tell core that the "disk" has been removed
  sdc_image_inserted(drive, 0);

  // forget about any previous name
  if(image_name[drive]) {
    free(image_name[drive]);
    image_name[drive] = NULL;
  }
  
  // nothing to be inserted? Do nothing!
  if(!name) return 0;

  // assemble full name incl. path
  char fname[strlen(cwd[drive]) + strlen(name) + 2];
  strcpy(fname, cwd[drive]);
  strcat(fname, "/");
  strcat(fname, name);

  sdc_lock();
  
  // close any previous image, especially free the link table
  if(fil[drive].cltbl) {
    printf("freeing link table\r\n");
    free(lktbl[drive]);
    lktbl[drive] = NULL;
    fil[drive].cltbl = NULL;
  }
  
  printf("Mounting %s\r\n", fname);

  if(f_open(&fil[drive], fname, FA_OPEN_EXISTING | FA_READ) != 0) {
    printf("file open failed\r\n");
    sdc_unlock();
    return -1;
  } else {
    printf("file opened, cl=%d(%d)\r\n",
	   fil[drive].obj.sclust, clst2sect(fil[drive].obj.sclust));
    printf("File len = %d, spc = %d, clusters = %d\r\n",
	   fil[drive].obj.objsize, fs.csize,
	   fil[drive].obj.objsize / 512 / fs.csize);      
    
    // try with a 16 entry link table
    lktbl[drive] = malloc(16 * sizeof(DWORD));    
    fil[drive].cltbl = lktbl[drive];
    lktbl[drive][0] = 16;
    
    if(f_lseek(&fil[drive], CREATE_LINKMAP)) {
      // this isn't really a problem. But sector access will
      // be slower
      printf("Link table creation failed, "
	     "required size: %d\r\n", lktbl[drive][0]);

      // re-alloc sufficient memory
      lktbl[drive] = realloc(lktbl[drive], sizeof(DWORD) * lktbl[drive][0]);

      // and retry link table creation
      if(f_lseek(&fil[drive], CREATE_LINKMAP)) {
	printf("Link table creation finally failed, "
	       "required size: %d\r\n", lktbl[drive][0]);
	free(lktbl[drive]);
	lktbl[drive] = NULL;
	fil[drive].cltbl = NULL;

	sdc_unlock();
	return -1;
      } else 
	printf("Link table ok\r\n");
    }
  }

  sdc_unlock();

  // remember current image name
  image_name[drive] = strdup(name);
  
  // image has successfully been opened, so report image size to core
  sdc_image_inserted(drive, fil[drive].obj.objsize);
  
  return 0;
}

sdc_dir_t *sdc_readdir(int drive, char *name, char *ext) {
  static sdc_dir_t sdc_dir = { 0, NULL };

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

  // setup path if unset
  if(!cwd[drive]) cwd[drive] = strdup(CARD_MOUNTPOINT);
  
  // assemble name before we free it
  if(name) {
    if(strcmp(name, "..")) {
      // alloc a longer string to fit new cwd
      char *n = malloc(strlen(cwd[drive])+strlen(name)+2);  // both strings + '/' and '\0'
      strcpy(n, cwd[drive]); strcat(n, "/"); strcat(n, name);
      free(cwd[drive]);
      cwd[drive] = n;
    } else {
      // no real need to free here, the unused parts will be free'd
      // once the cwd length increases. The menu relies on this!!!!!
      strrchr(cwd[drive], '/')[0] = 0;
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
  if(strcmp(cwd[drive], CARD_MOUNTPOINT) != 0) {
    strcpy(fno.fname, "..");
    fno.fattrib = AM_DIR;
    append(&sdc_dir, &fno);
  } else {
    // the root also gets a special entry for "eject" or No Disk
    // It's identified by the leading /, so the name can be changed
    strcpy(fno.fname, "/No Disk");
    fno.fattrib = AM_DIR;
    append(&sdc_dir, &fno);    
  }

  printf("max name len = %d\r\n", FF_LFN_BUF);

  sdc_lock();
  
  int ret = f_opendir(&dir, cwd[drive]);
  printf("opendir(%s)=%d\r\n", cwd[drive], ret);
  
  do {
    f_readdir(&dir, &fno);
    if(fno.fname[0] != 0 && !(fno.fattrib & (AM_HID|AM_SYS)) ) {
      // printf("%s %s, len=%d\r\n", (fno.fattrib & AM_DIR) ? "dir: ":"file:", fno.fname, fno.fsize);

      // only accept directories or .ST/.HD files
      if((fno.fattrib & AM_DIR) ||
	 (strlen(fno.fname) > 3 && strcasecmp(fno.fname+strlen(fno.fname)-3, ext) == 0))
	append(&sdc_dir, &fno);
    }
  } while(fno.fname[0] != 0);

  f_closedir(&dir);

  qsort(sdc_dir.files, sdc_dir.len, sizeof(sdc_dir_entry_t), dir_compare);
  sdc_unlock();

  return &sdc_dir;
}

int sdc_init(spi_t *p_spi) {
  spi = p_spi;
  sdc_sem = xSemaphoreCreateMutex();

  printf("---- SDC init ----\r\n");

  if(fs_init() == 0) {

#if 0  // do some file system level write tests
    DIR dir;
    FILINFO fno;

    // check existence of a subdirectory
    if(f_opendir(&dir, "/sd/fstest") == FR_OK) {
      printf("Directory /sd/fstest exists. Using it.\r\n");  
      do {
	f_readdir(&dir, &fno);
	if(fno.fname[0] != 0 && !(fno.fattrib & (AM_HID|AM_SYS)) ) {
	  printf("%s %s, len=%d\r\n", (fno.fattrib & AM_DIR) ? "dir: ":"file:", fno.fname, fno.fsize);
	}
      } while(fno.fname[0] != 0);
      f_closedir(&dir);
    } else {
      printf("Directory /sd/fstest does not exist. Creating it.\r\n");  
      if(f_mkdir("/sd/fstest") != FR_OK)
	printf("Unable to create\r\n");
    }
     
    // create a few randomly named files with some more or less random content
    for(int i=0;i<10;i++) {
      char str[32];
      sprintf(str, "/sd/fstest/test_%03d.txt", abs(random()%1000));      
      printf("Writing %s\r\n", str);
      
      FIL file;
      if(f_open(&file, str, FA_WRITE | FA_CREATE_ALWAYS) == FR_OK) {
	int lines = 10 + abs(random()%20);
	
	for(int l=0;l<lines;l++) {
	  sprintf(str, "Hallo Welt %d\r\n", abs(random()%100));	  
	  UINT wlen;
	  FRESULT res = f_write(&file, str, strlen(str), &wlen);
	  printf("Wrote %d, wlen %ld\r\n", res, wlen);
	}
	f_close(&file);      
      } else
	printf("open file failed\r\n");
    }
    printf("done\r\n");
#endif

#if 0  // do some sector level write tests
    unsigned char buffer[4][512];
    for(int i=0;i<4;i++) {
      sdc_read_sector(2+i, buffer[i]);
      printf("Sector %d:\r\n", 2+i);
      hexdump(buffer[i], 512);
    }
    
    for(int i=0;i<4;i++) {
      for(int b=0;b<512;b++) buffer[i][b] = b+i;
      sdc_write_sector(2+i, buffer[i]);
    }
#endif
    
    // process any pending interrupt
    if(sys_irq_ctrl(spi, 0xff) & 0x08)
      sdc_handle_event();

    // signal that we are ready, so other threads may e.g. continue as
    // a config stored on sd card has now been read
    sdc_ready = 1;

    printf("SD card is ready\r\n");
  }
    
  return 0;
}

// use a locking mechanism to make sure the file system isn't modified
// by two threads at the same time
void sdc_lock(void) {
  xSemaphoreTake(sdc_sem, 0xffffffffUL); // wait forever
}

void sdc_unlock(void) {
  xSemaphoreGive(sdc_sem);
}

#ifndef SDC_H
#define SDC_H

#include "spi.h"

// up to four image files can be open. E.g. two
// floppy disks and two ACSI hard drives
#define MAX_DRIVES  4

// fatfs mounts the card under /sd
#define CARD_MOUNTPOINT "/sd"

typedef struct {
  char *name;
  unsigned long len;
  int is_dir;
} sdc_dir_entry_t;

typedef struct {
  int len;
  sdc_dir_entry_t *files;
} sdc_dir_t;

int sdc_init(spi_t *spi);
int sdc_image_open(int drive, char *name);
sdc_dir_t *sdc_readdir(int drive, char *name, char *exts);
int sdc_handle_event(void);
int sdc_is_ready(void);
void sdc_lock(void);
void sdc_unlock(void);
char *sdc_get_image_name(int drive);
char *sdc_get_cwd(int drive);
void sdc_set_default(int drive, const char *name);

#endif // SDC_H

#ifndef SDC_H
#define SDC_H

#include "spi.h"

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
sdc_dir_t *sdc_readdir(char *name, char*);
int sdc_handle_event(void);
int sdc_is_ready(void);
void sdc_lock(void);
void sdc_unlock(void);

#endif // SDC_H

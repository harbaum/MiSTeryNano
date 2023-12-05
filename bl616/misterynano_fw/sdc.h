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
sdc_dir_t *sdc_readdir(char *name);
int sdc_poll(void);
int sdc_is_ready(void);

#endif // SDC_H

#ifndef OSD_H
#define OSD_H

#include "spi.h"
#include "u8g2.h"

#define OSD_INVISIBLE  0
#define OSD_VISIBLE    (!OSD_INVISIBLE)

typedef struct {
  char state;
  spi_t *spi;
  u8g2_t u8g2;
  uint8_t buf[128*8];  // screen buffer
} osd_t;

osd_t *osd_init(spi_t *);
void osd_enable(osd_t *, char);

#endif // OSD_H

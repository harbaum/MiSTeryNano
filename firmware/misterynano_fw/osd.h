#ifndef OSD_H
#define OSD_H

#ifndef SDL
#include <FreeRTOS.h>
#include <timers.h>
#endif

#include "spi.h"
#include "u8g2.h"

#define OSD_INVISIBLE  0
#define OSD_VISIBLE    (!OSD_INVISIBLE)

typedef struct {
  char state;
  spi_t *spi;
  u8g2_t u8g2;
  uint8_t buf[128*8];  // screen buffer
#ifndef SDL
  TimerHandle_t timer;
#endif
} osd_t;

osd_t *osd_init(spi_t *);
void osd_enable(osd_t *, char);
int osd_is_visible(osd_t *);

#endif // OSD_H

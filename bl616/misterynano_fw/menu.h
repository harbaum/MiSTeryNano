#ifndef MENU_H
#define MENU_H

#include "osd.h"
#include "mui.h"
#include "mui_u8g2.h"

#define MENU_EVENT_NONE   0
#define MENU_EVENT_UP     1
#define MENU_EVENT_DOWN   2
#define MENU_EVENT_SELECT 3
#define MENU_EVENT_SHOW   4
#define MENU_EVENT_HIDE   5

typedef struct {
  osd_t *osd; 
  mui_t ui;
} menu_t;

menu_t *menu_init(spi_t *spi);
void menu_do(menu_t *, int);

#endif // MENU_H

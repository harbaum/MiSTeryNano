#ifndef MENU_H
#define MENU_H

#include "osd.h"

#define MENU_EVENT_NONE   0
#define MENU_EVENT_UP     1
#define MENU_EVENT_DOWN   2
#define MENU_EVENT_LEFT   3
#define MENU_EVENT_RIGHT  4
#define MENU_EVENT_SELECT 5
#define MENU_EVENT_SHOW   6
#define MENU_EVENT_HIDE   7

// variables
typedef struct {
  const char id;
  union {
    int value;
    void *ptr;
  };
} menu_variable_t;

typedef struct {
  osd_t *osd; 
  char buffer[32];
  const char **forms;
  menu_variable_t *vars;
  int form;
  int entry;
  int entries;
  int offset;   // scroll offset
} menu_t;

#ifndef SDL
menu_t *menu_init(spi_t *spi);
#else
menu_t *menu_init(u8g2_t *u8g2);
#endif

void menu_do(menu_t *, int);

#endif // MENU_H

/*
  sysctrl.h

  MiSTeryNano system control interface
*/

#ifndef SYS_CTRL_H
#define SYS_CTRL_H

#include "spi.h"

int  sys_status_is_valid(spi_t *);
void sys_set_leds(spi_t *, char);
void sys_set_rgb(spi_t *, unsigned long);
unsigned char sys_get_buttons(spi_t *);
void sys_set_val(spi_t *, char, uint8_t);
unsigned char sys_irq_ctrl(spi_t *, unsigned char);

#endif // SYS_CTRL_H

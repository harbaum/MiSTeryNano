#ifndef USB_H
#define USB_H

#include "spi.h"
#include "osd.h"

extern void usb_host(spi_t *);
extern void usb_register_osd(osd_t *);

#endif // USB_H

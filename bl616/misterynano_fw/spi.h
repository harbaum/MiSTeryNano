#ifndef SPI_H
#define SPI_H

#include <FreeRTOS.h>
#include <semphr.h>

#define SPI_TARGET_HID   1
#define SPI_HID_KEYBOARD 1
#define SPI_HID_MOUSE    2

#define SPI_TARGET_OSD   2

typedef struct {
  struct bflb_device_s *dev;
  SemaphoreHandle_t sem;
} spi_t;
  
spi_t *spi_init(void);
void spi_begin(spi_t *spi);
void spi_tx_u08(spi_t *spi, unsigned char b);
void spi_end(spi_t *spi);

#endif // SPI_H

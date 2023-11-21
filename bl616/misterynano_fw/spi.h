#ifndef SPI_H
#define SPI_H

#ifndef SDL
#include <FreeRTOS.h>
#include <semphr.h>
#endif

#define SPI_TARGET_HID   1   // human interface devices
#define SPI_HID_STATUS   0
#define SPI_HID_KEYBOARD 1
#define SPI_HID_MOUSE    2

#define SPI_TARGET_OSD   2   // on-screen-display
#define SPI_OSD_ENABLE   1
#define SPI_OSD_WRITE    2
#define SPI_OSD_SET      3

#define SPI_TARGET_SDC   3   // sd card
#define SPI_SDC_STATUS   1   // get sd card status
#define SPI_SDC_READ     2   // trigger core read
#define SPI_SDC_MCU_READ 3   // read sector into MCU (e.g. for dir listing)
#define SPI_SDC_INSERTED 4   // inform core that some disk image has been insered

typedef struct {
#ifndef SDL
  struct bflb_device_s *dev;
  SemaphoreHandle_t sem;
#endif
} spi_t;
  
spi_t *spi_init(void);
void spi_begin(spi_t *spi);
unsigned char spi_tx_u08(spi_t *spi, unsigned char b);
void spi_end(spi_t *spi);

#endif // SPI_H

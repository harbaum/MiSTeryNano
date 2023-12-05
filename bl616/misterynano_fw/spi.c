#include "spi.h"

// spi
#include "bflb_mtimer.h"
#include "bflb_spi.h"
#include "bflb_dma.h"

extern struct bflb_device_s *gpio;

#if __has_include("cfg.h")
#include "cfg.h"
#else
#define M0S_DOCK
#include "bflb_gpio.h"
#endif

#ifdef M0S_DOCK
#warning "SPI for M0S DOCK"
#define SPI_PIN_CSN   GPIO_PIN_12
#define SPI_PIN_SCK   GPIO_PIN_13
#define SPI_PIN_MISO  GPIO_PIN_10
#define SPI_PIN_MOSI  GPIO_PIN_11
#else
#warning "SPI for internal"
#define SPI_PIN_CSN   GPIO_PIN_0
#define SPI_PIN_SCK   GPIO_PIN_1
#define SPI_PIN_MISO  GPIO_PIN_10
// #define SPI_PIN_MISO  GPIO_PIN_2
#define SPI_PIN_MOSI  GPIO_PIN_3
#endif

// #define BITBANG

spi_t *spi_init(void) {
  // when FPGA sets data on rising edge:
  // stable with long cables up to 20Mhz
  // short cables up to 32MHz

  static spi_t spi;

#ifndef BITBANG
  /* spi miso */
  bflb_gpio_init(gpio, SPI_PIN_MISO, GPIO_FUNC_SPI0 | GPIO_ALTERNATE | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);
  /* spi mosi */
  bflb_gpio_init(gpio, SPI_PIN_MOSI, GPIO_FUNC_SPI0 | GPIO_ALTERNATE | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);
  /* spi clk */
  bflb_gpio_init(gpio, SPI_PIN_SCK, GPIO_FUNC_SPI0 | GPIO_ALTERNATE | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);
  /* spi cs */
  bflb_gpio_init(gpio, SPI_PIN_CSN, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);
  bflb_gpio_set(gpio, SPI_PIN_CSN);
  
  struct bflb_spi_config_s spi_cfg = {
    .freq = 20000000,   // 20MHz
    .role = SPI_ROLE_MASTER,
    .mode = SPI_MODE1,         // mode 1: idle state low, data sampled on falling edge
    .data_width = SPI_DATA_WIDTH_8BIT,
    .bit_order = SPI_BIT_MSB,
    .byte_order = SPI_BYTE_LSB,
    .tx_fifo_threshold = 0,
    .rx_fifo_threshold = 0,
  };
  
  spi.dev = bflb_device_get_by_name("spi0");
  bflb_spi_init(spi.dev, &spi_cfg);

  bflb_spi_feature_control(spi.dev, SPI_CMD_SET_DATA_WIDTH, SPI_DATA_WIDTH_8BIT);
#else
#warning "BITBANG SPI"
  
  // prepare bitbang SPI
  bflb_gpio_init(gpio, SPI_PIN_CSN, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);
  bflb_gpio_init(gpio, SPI_PIN_SCK, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);
  bflb_gpio_init(gpio, SPI_PIN_MOSI, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);  
  bflb_gpio_init(gpio, SPI_PIN_MISO, GPIO_INPUT | GPIO_SMT_EN | GPIO_DRV_0);

  bflb_gpio_set(gpio, SPI_PIN_CSN);    // CSN high
  bflb_gpio_reset(gpio, SPI_PIN_SCK);  // SCK low
  bflb_gpio_reset(gpio, SPI_PIN_MOSI); // MOSI low
#endif  
  
  spi.sem = xSemaphoreCreateMutex();
  
  return &spi;
}

// spi may be used by different threads. Thus begin and end are using
// semaphores

void spi_begin(spi_t *spi) {
  xSemaphoreTake(spi->sem, 0xffffffffUL); // wait forever
  bflb_gpio_reset(gpio, SPI_PIN_CSN);
}

unsigned char spi_tx_u08(spi_t *spi, unsigned char b) {
#ifndef BITBANG
  return bflb_spi_poll_send(spi->dev, b);
#else
  unsigned char retval = 0;
  for(int i=0;i<8;i++) {
    if(b & 0x80) bflb_gpio_set(gpio, SPI_PIN_MOSI);
    else         bflb_gpio_reset(gpio, SPI_PIN_MOSI);

    // raise and lower sck for one cycle
    bflb_gpio_set(gpio, SPI_PIN_SCK);
    bflb_mtimer_delay_us(4);
    bflb_gpio_reset(gpio, SPI_PIN_SCK);
    bflb_mtimer_delay_us(4);

    retval <<= 1;
    if(bflb_gpio_read(gpio, SPI_PIN_MISO))
      retval |= 1;
    
    b <<= 1;
  }

  return retval;
#endif
}

void spi_end(spi_t *spi) {
  bflb_gpio_set(gpio, SPI_PIN_CSN);
  xSemaphoreGive(spi->sem);
}

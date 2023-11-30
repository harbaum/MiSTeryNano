#include "spi.h"

// spi
#include "bflb_mtimer.h"
#include "bflb_spi.h"
#include "bflb_dma.h"
#include "bflb_gpio.h"

extern struct bflb_device_s *gpio;

volatile uint32_t spi_tc_done_count = 0;

void spi_isr(int irq, void *arg)
{
  spi_t *spi = (spi_t *)arg;
  
    uint32_t intstatus = bflb_spi_get_intstatus(spi->dev);
    if (intstatus & SPI_INTSTS_TC) {
        bflb_spi_int_clear(spi->dev, SPI_INTCLR_TC);
        //printf("tc done\r\n");
        spi_tc_done_count++;
    }
    if (intstatus & SPI_INTSTS_TX_FIFO) {
        //printf("tx fifo\r\n");
    }
    if (intstatus & SPI_INTSTS_RX_FIFO) {
        //printf("rx fifo\r\n");
    }
}

spi_t *spi_init(void) {
  // when FPGA sets data on rising edge:
  // stable with long cables up to 20Mhz
  // short cables up to 32MHz

  static spi_t spi;
  
  // spi on gpio10 to 13
  /* spi miso */
  bflb_gpio_init(gpio, GPIO_PIN_10, GPIO_FUNC_SPI0 | GPIO_ALTERNATE | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);
  /* spi mosi */
  bflb_gpio_init(gpio, GPIO_PIN_11, GPIO_FUNC_SPI0 | GPIO_ALTERNATE | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);
  /* spi cs */
  //    bflb_gpio_init(gpio, GPIO_PIN_12, GPIO_FUNC_SPI0 | GPIO_ALTERNATE | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);
  /* spi clk */
  bflb_gpio_init(gpio, GPIO_PIN_13, GPIO_FUNC_SPI0 | GPIO_ALTERNATE | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);
  
  bflb_gpio_init(gpio, GPIO_PIN_12, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_1);
  bflb_gpio_set(gpio, GPIO_PIN_12);
    
  struct bflb_spi_config_s spi_cfg = {
    .freq = 20 * 1000 * 1000,   // 20MHz
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
  
  bflb_spi_tcint_mask(spi.dev, false);
  bflb_irq_attach(spi.dev->irq_num, spi_isr, &spi);
  bflb_irq_enable(spi.dev->irq_num);
  
  bflb_spi_feature_control(spi.dev, SPI_CMD_SET_CS_INTERVAL, 0);  // whatever this is ...
  bflb_spi_feature_control(spi.dev, SPI_CMD_SET_DATA_WIDTH, SPI_DATA_WIDTH_8BIT);

  spi.sem = xSemaphoreCreateMutex();
  
  return &spi;
}

// spi may be used by different threads. Thus begin and end are using
// semaphores

void spi_begin(spi_t *spi) {
  xSemaphoreTake(spi->sem, 0xffffffffUL); // wait forever
  bflb_gpio_reset(gpio, GPIO_PIN_12);
}

unsigned char spi_tx_u08(spi_t *spi, unsigned char b) {
  return bflb_spi_poll_send(spi->dev, b);
}

void spi_end(spi_t *spi) {
  bflb_gpio_set(gpio, GPIO_PIN_12);
  xSemaphoreGive(spi->sem);
}

#include "spi.h"
#include "sdc.h"
#include "sysctrl.h"

// #define SPI_POLL   // enable to poll and don't use interrupts

// spi
#include "bflb_mtimer.h"
#include "bflb_spi.h"
#include "bflb_dma.h"
#include "bflb_gpio.h"

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
#define SPI_PIN_IRQ   GPIO_PIN_14
#else
#warning "SPI for internal"
#define SPI_PIN_CSN   GPIO_PIN_0
#define SPI_PIN_SCK   GPIO_PIN_1
// #define SPI_PIN_MISO  GPIO_PIN_2   // filtered on the TN20k
#define SPI_PIN_MISO  GPIO_PIN_10     // JTAG TCK replacement
#define SPI_PIN_MOSI  GPIO_PIN_3
#define SPI_PIN_IRQ   GPIO_PIN_12     // JTAG TDI
#endif

// #define BITBANG

static TaskHandle_t spi_task_handle;
void spi_isr(uint8_t pin) {
  if (pin == SPI_PIN_IRQ) {
    // disable further interrupts until thread has processed the current message
    bflb_irq_disable(gpio->irq_num);
    
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    vTaskNotifyGiveFromISR( spi_task_handle, &xHigherPriorityTaskWoken );
    portYIELD_FROM_ISR( xHigherPriorityTaskWoken );
  }
}

// this task receives the interrupt request. Since we cannot
// call sys_irq_ctrl from the interrupt as spi_begin might
// block we need to do this from the task (which is allowed to
// block). The SPI task then demultiplexes the event sources.
static void spi_task(void *parms) {
  spi_t *spi = (spi_t*)parms;

  // initialize SD card
  sdc_init(spi);
  
  while(1) {
#ifdef SPI_POLL
    // polling simply means that we run a timout and
    // request the interrupt state manually every 100ms
    ulTaskNotifyTake( pdTRUE, pdMS_TO_TICKS(10000));
#else
    ulTaskNotifyTake( pdTRUE, portMAX_DELAY );
#endif

    // get pending interrupts and ack them all
    unsigned char pending = sys_irq_ctrl(spi, 0xff);
#ifdef SPI_POLL
    printf("IRQ = %02x\r\n", pending);
#endif
    if(pending) sys_handle_interrupts(pending);
    bflb_irq_enable(gpio->irq_num);   // resume interrupt processing
  }
}

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

  // semaphore to access the spi bus
  spi.sem = xSemaphoreCreateMutex();

  xTaskCreate(spi_task, (char *)"spi_task", 512, &spi, configMAX_PRIORITIES-2, &spi_task_handle);

  /* interrupt input */
  bflb_irq_disable(gpio->irq_num);
  bflb_gpio_init(gpio, SPI_PIN_IRQ, GPIO_INPUT | GPIO_PULLUP | GPIO_SMT_EN);
  bflb_gpio_int_init(gpio, SPI_PIN_IRQ, GPIO_INT_TRIG_MODE_SYNC_LOW_LEVEL);
  bflb_gpio_irq_attach(SPI_PIN_IRQ, spi_isr);
  bflb_irq_enable(gpio->irq_num);

  printf("IRQ enabled\r\n");
  
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

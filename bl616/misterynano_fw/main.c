/*
  main.c

  MiSTeryNano firmware main.
*/

#include <FreeRTOS.h>
#include <queue.h>

#include "board.h"

#include "bflb_gpio.h"
#include "bl616_glb.h"

#include "usb_config.h"

struct bflb_device_s *gpio;

#include <stdio.h>

#include "usb.h"
#include "menu.h"
#include "sdc.h"

#if __has_include("cfg.h")
#include "cfg.h"
#define ENABLE_FLASHER
#else
#warning "-----------------------------------------------------"
#warning "No cfg.h found and thus no ft2232d emulator included!"
#warning "-----------------------------------------------------"
#define M0S_DOCK
#endif

#include "sysctrl.h"

// queue to forward key press events from USB to OSD
QueueHandle_t xQueue = NULL;

void go_flasher(void *);

void set_led(int pin, int on) {
#ifdef M0S_DOCK
  // only M0S dock has those leds
  if(on) bflb_gpio_reset(gpio, pin);
  else   bflb_gpio_set(gpio, pin);
#endif
}

static void sdc_task(void *parms) {
  sdc_init((spi_t*)parms);
  
  while(1) {
    sdc_poll();
    // this delay needs to be rather short to ensure that the
    // MCU responds fast enough to sector requests by the core
    vTaskDelay(pdMS_TO_TICKS(1));
  }
}
  
static void osd_task(void *parms) {
  menu_t *menu;
  spi_t *spi = (spi_t*)parms;

  printf("OSD task\r\n");

  // switch MCU controlled leds off
  sys_set_leds(spi, 0x00);

  menu = menu_init(spi);
  menu_do(menu, 0);

  // wait for user events
  while(1) {
    // receive events from usb
    
    // printf("spi tc done count:%d\r\n", spi_tc_done_count);
    unsigned long cmd;
    xQueueReceive( xQueue, &cmd, 0xffffffffUL);
    menu_do(menu, cmd);
  }
}
    
int main(void) {
  TaskHandle_t osd_handle;
  TaskHandle_t sdc_handle;
    
    board_init();
    gpio = bflb_device_get_by_name("gpio");

#ifdef M0S_DOCK
#warning "M0S DOCK"
    // init on-board LEDs
    bflb_gpio_init(gpio, GPIO_PIN_27, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_28, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);

    // both leds off
    bflb_gpio_set(gpio, GPIO_PIN_27);
    bflb_gpio_set(gpio, GPIO_PIN_28);

    // button
    bflb_gpio_init(gpio, GPIO_PIN_2, GPIO_INPUT | GPIO_PULLDOWN | GPIO_SMT_EN | GPIO_DRV_0);
#endif

    // all communication between MCU and FPGA goes through one SPI channel
    spi_t *spi = spi_init();

    printf("Waiting for FPGA to become ready\r\n");

    // try to establish connection to FPGA for three seconds. Assume the FPGA is
    // not properly configured after that
    int fpga_ok, timeout = 500;
    do {
      fpga_ok = sys_status_is_valid(spi);
      if(!fpga_ok) {
	bflb_mtimer_delay_ms(10);
	timeout--;
      }
    } while(timeout && !fpga_ok);

    if(timeout) {
      printf("FPGA ready after %dms!\r\n", (500-timeout)*10);
      sys_set_rgb(spi, 0x000040);  // blue
    } else {
      printf("FPGA not ready after 5 seconds!\r\n");
      sys_set_rgb(spi, 0x400000);  // red
    }
    
#if 0
    // Check the update button on the Tang Nano 20k and force flasher mode
    // even if no timeout occured and FPGA could be accessed
    if(bflb_gpio_read(gpio, GPIO_PIN_2))
      timeout = 0;
#endif
    
    // Go into flasher mode if the FPGA could not be accessed. This
    // will also happen if the user pressed S1 or S2 during power-on
    // as these are connected to the mode lines of the FPGA.
     
    // Since we are in a freertos environment we need to start a
    // thread for this, anyway, to make sure interrupts work
    if(!timeout) {
      xTaskCreate(go_flasher, (char *)"flasher_task", 4096, spi, configMAX_PRIORITIES-3, &osd_handle);
      vTaskStartScheduler();
      for(;;);
    }

    // message queue from USB to OSD
    xQueue = xQueueCreate(10, sizeof( unsigned long ) );

    usb_host(spi);

    // start a thread for the on screen display    
    xTaskCreate(osd_task, (char *)"osd_task", 4096, spi, configMAX_PRIORITIES-3, &osd_handle);

    // create another task to frequently poll the FPGA via SPI for e.g. floppy disk requests
    xTaskCreate(sdc_task, (char *)"sdc_task", 4096, spi, configMAX_PRIORITIES-3, &sdc_handle);
    
    vTaskStartScheduler();

    // will never get here
    while (1);
}

#ifdef ENABLE_FLASHER
struct bflb_device_s *gpio_hdl;
#include <assert.h>

static inline void gpio_init(void) {
  gpio_hdl = gpio; // bflb_device_get_by_name("gpio");
  // assert(gpio_hdl);
#if 0
  /* DEINIT ALL GPIOS BEGIN */
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_0);   // SPI CSN
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_1);   // SPI SCK
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_2);   // SPI DIR
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_3);   // SPI MOSI
  
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_10);  // JTAG TCK
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_11);  // UART TX
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_12);  // JTAG TDI
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_13);  // UART RX
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_14);  // JTAG TDO 
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_15);
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_16);  // JTAG TMS
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_17);
  
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_20);
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_21);  // I2C SDA
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_22);  // I2C SCK
  
  //  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_27);
  //  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_28);
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_29);
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_30);
  /* DEINIT ALL GPIOS END */
#else
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_10);  // JTAG TCK
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_12);  // JTAG TDI
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_14);  // JTAG TDO 
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_16);  // JTAG TMS
#endif
  
  /* clang-format off */
  bflb_gpio_init(gpio_hdl, GPIO_PIN_JTAG_TMS, GPIO_OUTPUT | GPIO_FLOAT | GPIO_SMT_EN | GPIO_DRV_1);
  bflb_gpio_init(gpio_hdl, GPIO_PIN_JTAG_TCK, GPIO_OUTPUT | GPIO_FLOAT | GPIO_SMT_EN | GPIO_DRV_1);
  bflb_gpio_init(gpio_hdl, GPIO_PIN_JTAG_TDI, GPIO_OUTPUT | GPIO_FLOAT | GPIO_SMT_EN | GPIO_DRV_1);
  bflb_gpio_init(gpio_hdl, GPIO_PIN_JTAG_TDO, GPIO_INPUT  | GPIO_FLOAT | GPIO_SMT_EN | GPIO_DRV_1);
  
  /* clang-format on */
}

extern void ft2232d_init(void);
extern void ft2232d_loop(void);
#endif

void go_flasher(void *p) {
  spi_t *spi = (spi_t*)p;
  
  // switch rgb led to yellow
  sys_set_rgb(spi, 0x404000);

#if 0
  while(1) {
    if(sys_status_is_valid(spi))
      sys_set_rgb(spi, 0x004000);
    else
      sys_set_rgb(spi, 0x400000);

    bflb_mtimer_delay_ms(100);
    sys_set_rgb(spi, 0);
    bflb_mtimer_delay_ms(100);
  }
#endif
  
#ifdef ENABLE_FLASHER
  gpio_init(); 
  ft2232d_init();
#endif

#ifdef M0S_DOCK
  bflb_gpio_reset(gpio, GPIO_PIN_27);
  bflb_gpio_reset(gpio, GPIO_PIN_28);
#endif
  
  while (1) {
#ifdef M0S_DOCK
    static int counter = 0;
    // flicker a little bit with the leds, so we
    // can see that this loop is still running
    if(counter & 0x10000) {
      bflb_gpio_set(gpio, GPIO_PIN_27);
      bflb_gpio_reset(gpio, GPIO_PIN_28);
    } else {
      bflb_gpio_reset(gpio, GPIO_PIN_27);
      bflb_gpio_set(gpio, GPIO_PIN_28);
    }
    counter++;
#endif

#ifdef ENABLE_FLASHER    
    ft2232d_loop();
#else
    bflb_mtimer_delay_us(2);
#endif
  }
}

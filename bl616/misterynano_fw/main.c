/*
  main.c

  MiSTeryNano firmware main.
*/

#include <FreeRTOS.h>
#include <queue.h>
#include <timers.h>

#include "board.h"

#include "bflb_gpio.h"
#include "bl616_glb.h"

#include "usb_config.h"

struct bflb_device_s *gpio;

#include <stdio.h>

#include "usb.h"
#include "menu.h"
#include "sdc.h"

#ifndef M0S_DOCK
  // building for internal BL616
  #warning "Building for internal BL616"
  #if __has_include("cfg.h")
    #include "cfg.h"
    #define ENABLE_FLASHER
  #else
    #error "-----------------------------------------------------"
    #error "No cfg.h found and thus no ft2232d emulator included!"
    #error "-----------------------------------------------------"
  #endif
#else
  #warning "Building for M0S DOCK"
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

// a 25Hz timer that can be activated by the menu whenever animations
// are displayed and which should be updated constantly
static void osd_timer(xTimerHandle pxTimer) {
  static long msg = -1;
  xQueueSendToBack(xQueue, &msg,  ( TickType_t ) 0);
}

static void osd_task(void *parms) {
  menu_t *menu;
  spi_t *spi = (spi_t*)parms;

  printf("OSD task\r\n");

  // switch MCU controlled leds off
  sys_set_leds(spi, 0x00);

  menu = menu_init(spi);
  // inform USB about OSD and MENU, so USB can request e.g.
  // if the OSD is visible and key events should not be sent
  // into the core
  usb_register_osd(menu->osd);
  
  menu_do(menu, 0);

  // create a 25 Hz timer that frequently wakes the OSD thread
  // allowing for animations
  menu->osd->timer = xTimerCreate("OSD timer", pdMS_TO_TICKS(40), pdTRUE,
				  NULL, osd_timer);
  // wait for user events
  while(1) {
    // receive events from usb
    
    // printf("spi tc done count:%d\r\n", spi_tc_done_count);
    long cmd;
    xQueueReceive( xQueue, &cmd, 0xffffffffUL);
    menu_do(menu, cmd);
  }
}

int main(void) {
  TaskHandle_t osd_handle;
    
  board_init();
  gpio = bflb_device_get_by_name("gpio");

#ifdef M0S_DOCK
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
  
  // try to establish connection to FPGA for five seconds. Assume the FPGA is
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
    sys_set_val(spi, 'R', 3);    // immediately set reset as the config may change
    sys_set_rgb(spi, 0x000040);  // blue
  } else {
    printf("FPGA not ready after 5 seconds!\r\n");
    // this is basically useless and will only work if the
    // FPGA receives requests but cannot answer them
    sys_set_rgb(spi, 0x400000);  // red
  }
  
#ifndef M0S_DOCK
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
#endif
  
  // message queue from USB to OSD
  xQueue = xQueueCreate(10, sizeof( long ) );
  
  usb_host(spi);
  
  // start a thread for the on screen display    
  xTaskCreate(osd_task, (char *)"osd_task", 2048, spi, configMAX_PRIORITIES-3, &osd_handle);
  
  vTaskStartScheduler();
  
  // will never get here
  while (1);
}

#ifdef ENABLE_FLASHER
struct bflb_device_s *gpio_hdl;
#include <assert.h>

static inline void gpio_init(void) {
  gpio_hdl = gpio; // bflb_device_get_by_name("gpio");

  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_10);  // JTAG TCK
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_12);  // JTAG TDI
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_14);  // JTAG TDO 
  bflb_gpio_deinit(gpio_hdl, GPIO_PIN_16);  // JTAG TMS
  
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

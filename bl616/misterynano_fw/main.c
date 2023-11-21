#include <FreeRTOS.h>
#include <queue.h>

#include "board.h"

#include "bflb_gpio.h"
#include "bl616_glb.h"

#include "usb_config.h"

// #include "bflb_ef_ctrl.h"
// efuse_dev = bflb_device_get_by_name("ef_ctrl");
//bflb_ef_ctrl_write_direct(efuse_dev, EFUSE_DATA_START_ADDR, (uint32_t *)efuse_data_write, EFUSE_DATA_LEN, 1);
//bflb_ef_ctrl_read_direct(efuse_dev, EFUSE_DATA_START_ADDR, (uint32_t *)efuse_data_read, EFUSE_DATA_LEN, 1);

struct bflb_device_s *gpio;

#include <stdio.h>

#include "usb.h"
#include "menu.h"
#include "sdc.h"

// queue to forward key press events from USB to OSD
QueueHandle_t xQueue = NULL;

static void sdc_task(void *parms) {
  spi_t *spi = (spi_t*)parms;

  while(1) {
    sdc_poll();
    vTaskDelay(10);
  }
}
  
// OSD task gets a callback which it calls whenever the OSD
// opems or closes to inform the USB layer about the OSD state
static void osd_task(void *parms) {
  menu_t *menu;

  printf("OSD task\r\n");

  menu = menu_init((spi_t*)parms);
  menu_do(menu, 0);

  // wait for user events
  while(1) {
    // receive events from usb
    
    // printf("spi tc done count:%d\r\n", spi_tc_done_count);
    unsigned long cmd;
    xQueueReceive( xQueue, &cmd, 0xffffffffUL);
    menu_do(menu, cmd);

    printf("BTN %d\r\n", bflb_gpio_read(gpio, GPIO_PIN_2));
  }
}
    
int main(void) {
    TaskHandle_t osd_handle;
    TaskHandle_t sdc_handle;
    
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
    
    // init eight digital outputs
    bflb_gpio_init(gpio, GPIO_PIN_14, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_15, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_16, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_17, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    
    // all outputs high/inactive
    bflb_gpio_set(gpio, GPIO_PIN_14);
    bflb_gpio_set(gpio, GPIO_PIN_15);
    bflb_gpio_set(gpio, GPIO_PIN_16);
    bflb_gpio_set(gpio, GPIO_PIN_17);   
#else
    // init SPI/PS2 pins
    bflb_gpio_init(gpio, GPIO_PIN_0, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_1, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_2, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_3, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);

    // all outputs high/inactive
    bflb_gpio_set(gpio, GPIO_PIN_0);
    bflb_gpio_set(gpio, GPIO_PIN_1);
    bflb_gpio_set(gpio, GPIO_PIN_2);
    bflb_gpio_set(gpio, GPIO_PIN_3);
#endif

    spi_t *spi = spi_init();

    // message queue from USB to OSD
    xQueue = xQueueCreate(10, sizeof( unsigned long ) );
    
    printf("Starting usb host task...\r\n");
    usb_host(spi);

    // try to write HBN RAM
    //    printf("IS: %02x\r\n", *(unsigned char*)0x20010800);
    //    *(unsigned char*)0x20010800 = 0x55;
    //    printf("SET: %02x\r\n", *(unsigned char*)0x20010800);
    
    // start a thread for the on screen display    
    xTaskCreate(osd_task, (char *)"osd_task", 512, spi, configMAX_PRIORITIES-3, &osd_handle);

    // create another task to frequently poll the FPGA via SPI for e.g.
    // floppy disk requests
    xTaskCreate(sdc_task, (char *)"sdc_task", 512, spi, configMAX_PRIORITIES-3, &sdc_handle);
    
    vTaskStartScheduler();

    // will never get here
    while (1);
}

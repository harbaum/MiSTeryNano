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
// #include "audio.h"
#include "bt_ble.h"

#ifndef M0S_DOCK
  #warning "Building for internal BL616"
#else
  #warning "Building for M0S DOCK"
#endif

#include "sysctrl.h"

// queue to forward key press events from USB to OSD
QueueHandle_t xQueue = NULL;

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

#ifndef nM0S_DOCK
static void led_timer(xTimerHandle xTimer) {
  static bool led_state = 0;

  led_state = !led_state;
}
#endif

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

#include "bflb_uart.h"
#include "bflb_clock.h"
#include "bflb_flash.h"
#include "bflb_clock.h"
#include "mem.h"

extern void log_start(void);
extern void bl_show_flashinfo(void);
extern void bl_show_log(void);
extern void bflb_uart_set_console(struct bflb_device_s *dev);

extern uint32_t __HeapBase;
extern uint32_t __HeapLimit;

#ifdef M0S_DOCK
// the M0S uses max bitrate as I use another M0S for console debug which can
// deal with 2MBit/s
#define CONSOLE_BAUDRATE 2000000
#else
// the internal BL616 uses 921600 as I use a cp2102 USB UART with it which doesn't
// cope with more tham 921600 bit/s
#define CONSOLE_BAUDRATE 921600
#endif

static struct bflb_device_s *uart0;

static void system_clock_init(void) {
  /* wifipll/audiopll */
  GLB_Power_On_XTAL_And_PLL_CLK(GLB_XTAL_40M, GLB_PLL_WIFIPLL | GLB_PLL_AUPLL);
  GLB_Set_MCU_System_CLK(GLB_MCU_SYS_CLK_TOP_WIFIPLL_320M);
  CPU_Set_MTimer_CLK(ENABLE, BL_MTIMER_SOURCE_CLOCK_MCU_XCLK, Clock_System_Clock_Get(BL_SYSTEM_CLOCK_XCLK) / 1000000 - 1);
}

/* TODO: disabled everything we don't need or use */
static void peripheral_clock_init(void) {
  PERIPHERAL_CLOCK_ADC_DAC_ENABLE();
  PERIPHERAL_CLOCK_SEC_ENABLE();
  PERIPHERAL_CLOCK_DMA0_ENABLE();
  PERIPHERAL_CLOCK_UART0_ENABLE();
  PERIPHERAL_CLOCK_UART1_ENABLE();
  PERIPHERAL_CLOCK_SPI0_ENABLE();
  PERIPHERAL_CLOCK_I2C0_ENABLE();
  PERIPHERAL_CLOCK_PWM0_ENABLE();
  PERIPHERAL_CLOCK_TIMER0_1_WDG_ENABLE();
  PERIPHERAL_CLOCK_IR_ENABLE();
  PERIPHERAL_CLOCK_I2S_ENABLE();
  PERIPHERAL_CLOCK_USB_ENABLE();
  PERIPHERAL_CLOCK_CAN_ENABLE();
  PERIPHERAL_CLOCK_AUDIO_ENABLE();
  PERIPHERAL_CLOCK_CKS_ENABLE();
    
  GLB_Set_UART_CLK(ENABLE, HBN_UART_CLK_XCLK, 0);
  GLB_Set_SPI_CLK(ENABLE, GLB_SPI_CLK_MCU_MUXPLL_160M, 0);
  GLB_Set_DBI_CLK(ENABLE, GLB_SPI_CLK_MCU_MUXPLL_160M, 0);
  GLB_Set_I2C_CLK(ENABLE, GLB_I2C_CLK_XCLK, 0);
  GLB_Set_ADC_CLK(ENABLE, GLB_ADC_CLK_XCLK, 1);
  GLB_Set_DIG_CLK_Sel(GLB_DIG_CLK_XCLK);
  GLB_Set_DIG_512K_CLK(ENABLE, ENABLE, 0x4E);
  GLB_Set_PWM1_IO_Sel(GLB_PWM1_IO_SINGLE_END);
  GLB_Set_IR_CLK(ENABLE, GLB_IR_CLK_SRC_XCLK, 19);
  GLB_Set_CAM_CLK(ENABLE, GLB_CAM_CLK_WIFIPLL_96M, 3);
  
  GLB_Set_PKA_CLK_Sel(GLB_PKA_CLK_MCU_MUXPLL_160M);
  
  GLB_Set_USB_CLK_From_WIFIPLL(1);
  GLB_Swap_MCU_SPI_0_MOSI_With_MISO(0);
}

static void console_init() {
  struct bflb_device_s *gpio;
  
  gpio = bflb_device_get_by_name("gpio");
  
#ifdef M0S_DOCK
  // M0S Dock has debug uart on default pins 21 and 22
  bflb_gpio_uart_init(gpio, GPIO_PIN_21, GPIO_UART_FUNC_UART0_TX);
  bflb_gpio_uart_init(gpio, GPIO_PIN_22, GPIO_UART_FUNC_UART0_RX);
#else
  // the internal TN20K BL616 is supposed to use GPIO2 for the SPI
  // connection to the FPGA. This pin is also connected to the UPDATE
  // button and has thus been equipped with a low pass filter cap on
  // early TN20K boards. This in turn prevents proper use as a SPI
  // data pin. The MiSTeryNano thus uses one of the JTAG pins between
  // the FPAG and the BL616 for SPI data transmission instead.

  // This in turn leaves GPIO2 unused on MiSTeryNano when running on
  // the TN20K's internal BL616. This pin is connected to the pin
  // headers and FPGA pin 75. It can therefore be used to expose
  // a UART TX for debugging. As this is also affected by the
  // filter cap this only works on later TN20k which don't have
  // the filter cap. These are coincidentially the board we want
  // to debug as they also have the signed firmware.
  
  bflb_gpio_uart_init(gpio, GPIO_PIN_2, GPIO_UART_FUNC_UART0_TX);
#endif
  
  struct bflb_uart_config_s cfg;
  cfg.baudrate = CONSOLE_BAUDRATE;
  cfg.data_bits = UART_DATA_BITS_8;
  cfg.stop_bits = UART_STOP_BITS_1;
  cfg.parity = UART_PARITY_NONE;
  cfg.flow_ctrl = 0;
  cfg.tx_fifo_threshold = 7;
  cfg.rx_fifo_threshold = 7;
  
  uart0 = bflb_device_get_by_name("uart0");
  
  bflb_uart_init(uart0, &cfg);
  bflb_uart_set_console(uart0);
}
    
// local board_init used as a replacemement for global board_init
void mn_board_init(void) {
    int ret = -1;
    uintptr_t flag;
    size_t heap_len;

    flag = bflb_irq_save();
#ifndef CONFIG_PSRAM_COPY_CODE
    ret = bflb_flash_init();
#endif
    system_clock_init();
    peripheral_clock_init();
    bflb_irq_initialize();

    console_init();

    heap_len = ((size_t)&__HeapLimit - (size_t)&__HeapBase);
    kmem_init((void *)&__HeapBase, heap_len);

    bl_show_log();
    if (ret != 0) {
        printf("flash init fail!!!\r\n");
    }
    bl_show_flashinfo();

    printf("dynamic memory init success, ocram heap size = %d Kbyte \r\n", ((size_t)&__HeapLimit - (size_t)&__HeapBase) / 1024);

    printf("sig1:%08x\r\n", BL_RD_REG(GLB_BASE, GLB_UART_CFG1));
    printf("sig2:%08x\r\n", BL_RD_REG(GLB_BASE, GLB_UART_CFG2));
    printf("cgen1:%08x\r\n", getreg32(BFLB_GLB_CGEN1_BASE));

    log_start();

#if (defined(CONFIG_LUA) || defined(CONFIG_BFLOG) || defined(CONFIG_FATFS))
    // we use FATFS ... so the RTC should be set ...    
    // rtc = bflb_device_get_by_name("rtc");
#endif
    bflb_irq_restore(flag);
}

int main(void) {
  TaskHandle_t osd_handle;

  mn_board_init();
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
#else
  usbd_deinitialize();
#endif
  
  // message queue from USB to OSD
  xQueue = xQueueCreate(10, sizeof( long ) );

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
  
  // timer to blink led
  xTimerCreate("LED timer", pdMS_TO_TICKS(1000), pdTRUE, NULL, led_timer);
  
#ifndef M0S_DOCK
  // Return to flasher mode if the FPGA could not be accessed. This
  // will also happen if the user pressed S1 or S2 during power-on
  // as these are connected to the mode lines of the FPGA.  
  if(!timeout) {
    *(uint32_t *)0x2000f93c = 0xc0ffee42;
    bflb_mtimer_delay_ms(10);
    GLB_SW_POR_Reset(); 
    return 0;  // this would actually never return ...
  }
#else
  // in the m0s dock case there's not much to do ...  
#endif

  // initialize bluetooth
  // bt_ble_init(spi);
  
  // init audio and test play chime
  //  audio_init(spi);
  //  audio_chime();
  
  usb_host(spi); 

  // start a thread for the on screen display    
  xTaskCreate(osd_task, (char *)"osd_task", 2048, spi, configMAX_PRIORITIES-3, &osd_handle);
  
  vTaskStartScheduler();
  
  // will never get here
  while (1);
}


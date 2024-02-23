#include <assert.h>
#include <stdint.h>
#include <ctype.h>

#include "board.h"

#include "csi_core.h"
#include "bflb_gpio.h"
#include "bflb_uart.h"
#include "bflb_mtimer.h"
#include "usbd_core.h"
#include "usbd_cdc.h"
#include "ring_buffer.h"

// debugging via uart0 does not really work. Our uart1 seems to interfere
// #define DEBUG_RTS_DTR
// #define DEBUG_LINE

// keep track of activity after bootloader has been activated to be able
// to return to app after timeout
static volatile bool bootloader_active = false;
static volatile uint64_t bootloader_activity;

Ring_Buffer_Type uart1_rx_rb;
static volatile struct cdc_line_coding s_cdc_line_coding;

static struct bflb_device_s *gpio;
static struct bflb_device_s *uart1;

static void uart1_gpio_init(void);
static void uart1_init(void);

// variables for reset state machine
static int reset_state = 0;
static uint64_t reset_timer;
static int reset_ms;

void schedule_reset(bool bootloader) {
  if(reset_state) return;
  
  if(bootloader) {
    bflb_gpio_set(gpio, GPIO_PIN_BOOT);     // drive boot pin high for bootloader
    bflb_gpio_reset(gpio, GPIO_PIN_27);     // LED on indicating that BOOT is active
    bootloader_activity = bflb_mtimer_get_time_ms();
    bootloader_active = true;
  } else {
    bootloader_active = false;
    bflb_gpio_reset(gpio, GPIO_PIN_BOOT);   // drive boot pin low for app
    bflb_gpio_set(gpio, GPIO_PIN_27);       // LED off indicating that BOOT is inactive
  }
    
  reset_state = 1;    // state 1 wait for event to set reset low
  reset_timer = bflb_mtimer_get_time_ms();
  reset_ms = 10;
  bflb_gpio_reset(gpio, GPIO_PIN_28);       // LED on indicating reset is in progress
}

void trigger_bootloader(void) {	
  // activity seen
  if(bootloader_active)
    bootloader_activity = bflb_mtimer_get_time_ms();
}
  
int main(void)
{
    board_init();
    uart1_gpio_init();

    static uint8_t uartx_rx_buffer[2 * 512];
    Ring_Buffer_Init(&uart1_rx_rb, uartx_rx_buffer, sizeof(uartx_rx_buffer), NULL, NULL);
    uart1_init();

    extern void usbd_cdc_acm_template_init(void);
    usbd_cdc_acm_template_init();

    for (size_t loop_count = 0;;) {

      // check for timeut in bootloader activity. If bootloader is active and
      // there's no activity in the UART for 1 second, then the device is
      // returned to regular app mode
      if(bootloader_active) {
	// the result t is by purpose stored in a signed integer as
	// in rate occasions the interupt updates the activity timer after
	// the time has been read. As a result bootloader_activity may be
	// in the future resulting in a negative t
	int t = bflb_mtimer_get_time_ms() - bootloader_activity;
	if(t > 1000) {
	  bootloader_active = 0;
	  schedule_reset(false);
	}
      }
      
      // handle the boot/en state machine
      if(reset_state) {
	// check if event time has been reached
	if(bflb_mtimer_get_time_ms() - reset_timer >= reset_ms) {
	  switch(reset_state) {
	  case 1:
	    // drive reset low
	    bflb_gpio_reset(gpio, GPIO_PIN_EN);
	    reset_timer = bflb_mtimer_get_time_ms();
	    reset_ms = 500;  // next event in 500ms
	    reset_state = 2;
	    break;
	    
	  case 2:
	    // drive reset high
	    bflb_gpio_set(gpio, GPIO_PIN_EN);
	    reset_state = 0;
	    bflb_gpio_set(gpio, GPIO_PIN_28);       // LED off indicating reset is done
	    break;
	  }
	}
      }

        extern volatile bool ep_tx_busy_flag;
        if (ep_tx_busy_flag)
            continue;

        size_t uart1_rx_rb_len = Ring_Buffer_Get_Length(&uart1_rx_rb);
        if (!uart1_rx_rb_len)
            continue;

        if (uart1_rx_rb_len < 512 && loop_count++ < 1000) {
            continue;
        }
        loop_count = 0;

        uint8_t data[uart1_rx_rb_len];
        size_t uart1_rx_rb_len_acc = Ring_Buffer_Read(&uart1_rx_rb, data, uart1_rx_rb_len);
        if (!uart1_rx_rb_len_acc)
            continue;

        csi_dcache_clean_invalid_range(data, uart1_rx_rb_len_acc);
        ep_tx_busy_flag = true;
        usbd_ep_start_write(CDC_IN_EP, data, uart1_rx_rb_len_acc);

	trigger_bootloader();
    }
}

void usbd_cdc_acm_bulk_out_cb(uint8_t *buf, size_t len, uint8_t ep)
{
  assert(ep == CDC_OUT_EP);
  bflb_uart_txint_mask(uart1, false);
  for (size_t i = 0; i < len; i++) 
    bflb_uart_putchar(uart1, buf[i]);

  trigger_bootloader();
}

static void uart1_gpio_init(void)
{
    gpio = bflb_device_get_by_name("gpio");
    bflb_gpio_uart_init(gpio, GPIO_PIN_UART1_TX, GPIO_UART_FUNC_UART1_TX);
    bflb_gpio_uart_init(gpio, GPIO_PIN_UART1_RX, GPIO_UART_FUNC_UART1_RX);

    // init on-board LEDs
    bflb_gpio_init(gpio, GPIO_PIN_27, GPIO_OUTPUT | GPIO_PULLUP | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_28, GPIO_OUTPUT | GPIO_PULLUP | GPIO_DRV_0);

    // both leds off
    bflb_gpio_set(gpio, GPIO_PIN_27);
    bflb_gpio_set(gpio, GPIO_PIN_28);

    // BOOT and EN
    // default state: BOOT = 0, EN = 1
    bflb_gpio_init(gpio, GPIO_PIN_BOOT, GPIO_OUTPUT | GPIO_PULLDOWN | GPIO_DRV_0);
    bflb_gpio_reset(gpio, GPIO_PIN_BOOT);

    bflb_gpio_init(gpio, GPIO_PIN_EN,   GPIO_OUTPUT | GPIO_PULLUP | GPIO_DRV_0);
    bflb_gpio_set(gpio, GPIO_PIN_EN); 
}

static void uart_isr(int irq, void *arg)
{
    uint32_t intstatus = bflb_uart_get_intstatus(uart1);

    // push any byte received via UART into the ring buffer
    if (intstatus & UART_INTSTS_RX_FIFO) {
        while (bflb_uart_rxavailable(uart1)) {
            char c = bflb_uart_getchar(uart1);
            Ring_Buffer_Write_Byte(&uart1_rx_rb, c);
        }
    }
    
    if (intstatus & UART_INTSTS_RTO) {
        while (bflb_uart_rxavailable(uart1)) {
            char c = bflb_uart_getchar(uart1);
            Ring_Buffer_Write_Byte(&uart1_rx_rb, c);
        }
        bflb_uart_int_clear(uart1, UART_INTCLR_RTO);
    }
    
    if (intstatus & UART_INTSTS_TX_FIFO) {
        bflb_uart_txint_mask(uart1, true);
    }
}

static void uart1_init(void)
{
    uart1 = bflb_device_get_by_name("uart1");

    // set default line coding 9600 8N1
    s_cdc_line_coding.dwDTERate = 9600;
    s_cdc_line_coding.bDataBits = 8;
    s_cdc_line_coding.bParityType = 0;
    s_cdc_line_coding.bCharFormat = 0;
    
    bflb_uart_init(
	   uart1,
	   &(struct bflb_uart_config_s){
	     .baudrate = (s_cdc_line_coding.dwDTERate),
	     .data_bits = UART_DATA_BITS_5 + (s_cdc_line_coding.bDataBits - 5),
	     .stop_bits = UART_STOP_BITS_0_5 + (s_cdc_line_coding.bCharFormat + 1),
	     .parity = UART_PARITY_NONE + (s_cdc_line_coding.bParityType),
	     .flow_ctrl = 0,
	     .tx_fifo_threshold = 7,
	     .rx_fifo_threshold = 0,
	   });
    
    bflb_irq_attach(uart1->irq_num, uart_isr, NULL);
    bflb_irq_enable(uart1->irq_num);
    bflb_uart_rxint_mask(uart1, false);
}

// direct map is probably how bouffalo labs intended this to be used
static bool dtr_state = false;
static bool rts_state = false;

void usbd_cdc_acm_set_dtr(uint8_t intf, bool dtr) {
#ifdef DEBUG_RTS_DTR
  if(dtr != dtr_state) 
    printf("DTR %d\r\n", dtr);
#endif
  
  dtr_state = dtr;
  trigger_bootloader();
}

void usbd_cdc_acm_set_rts(uint8_t intf, bool rts) {
#ifdef DEBUG_RTS_DTR
  if(rts != rts_state) 
    printf("RTS %d\r\n", rts);
#endif
  
  // rts rising with dtr low
  if(rts && !rts_state)
    if(!dtr_state)
      schedule_reset(true); 
  
  rts_state = rts;
  trigger_bootloader();
}

void usbd_cdc_acm_set_line_coding(uint8_t intf, struct cdc_line_coding *line_coding)
{
#ifdef DEBUG_LINE
  char *stop_str[] = { "1", "1.5", "2" };
  char *parity_str[] = { "N", "O", "E" };
  
  printf("SET %lu %d%s%s\r\n", line_coding->dwDTERate, line_coding->bDataBits,
	 parity_str[line_coding->bParityType], stop_str[line_coding->bCharFormat]);
#endif
  
  memcpy((void *)&s_cdc_line_coding, line_coding, sizeof(struct cdc_line_coding));
  
  // a 1200 bit/s setting can be used to trigger a regular app reset
  if(line_coding->dwDTERate == 1200)
    schedule_reset(false);                    // app reset
  
  bflb_uart_disable(uart1);
  bflb_uart_feature_control(uart1, UART_CMD_SET_BAUD_RATE, (s_cdc_line_coding.dwDTERate));
  bflb_uart_feature_control(uart1, UART_CMD_SET_DATA_BITS, (s_cdc_line_coding.bDataBits - 5));
  bflb_uart_feature_control(uart1, UART_CMD_SET_STOP_BITS, (s_cdc_line_coding.bCharFormat + 1));
  bflb_uart_feature_control(uart1, UART_CMD_SET_PARITY_BITS, (s_cdc_line_coding.bParityType));
  bflb_uart_enable(uart1);

  trigger_bootloader();
}

void usbd_cdc_acm_get_line_coding(uint8_t intf, struct cdc_line_coding *line_coding)
{
#ifdef DEBUG_LINE
  printf("get_line_coding(intf %d)\r\n", intf);
#endif
    memcpy(line_coding, (void *)&s_cdc_line_coding, sizeof(struct cdc_line_coding));
}

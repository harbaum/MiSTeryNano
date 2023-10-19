#include <FreeRTOS.h>
#include "semphr.h"
#include "usbh_core.h"
#include "board.h"
#include "bflb_gpio.h"

struct bflb_device_s *gpio;

extern void usbh_class_test(void);

int main(void)
{
    board_init();

    // init on-board LEDs
    gpio = bflb_device_get_by_name("gpio");
    bflb_gpio_init(gpio, GPIO_PIN_27, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_28, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);

    // both leds off
    bflb_gpio_set(gpio, GPIO_PIN_27);
    bflb_gpio_set(gpio, GPIO_PIN_28);
    
    // init eight digital outputs
    bflb_gpio_init(gpio, GPIO_PIN_10, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_11, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_12, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_13, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_14, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_15, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_16, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    bflb_gpio_init(gpio, GPIO_PIN_17, GPIO_OUTPUT | GPIO_PULLUP | GPIO_SMT_EN | GPIO_DRV_0);
    
    // all outputs high/inactive
    bflb_gpio_set(gpio, GPIO_PIN_10);
    bflb_gpio_set(gpio, GPIO_PIN_11);
    bflb_gpio_set(gpio, GPIO_PIN_12);
    bflb_gpio_set(gpio, GPIO_PIN_13);
    bflb_gpio_set(gpio, GPIO_PIN_14);
    bflb_gpio_set(gpio, GPIO_PIN_15);
    bflb_gpio_set(gpio, GPIO_PIN_16);
    bflb_gpio_set(gpio, GPIO_PIN_17);   
    
    printf("Starting usb host task...\r\n");
    usbh_initialize();
    usbh_class_test();

    vTaskStartScheduler();

    // will never get here
    while (1);
}

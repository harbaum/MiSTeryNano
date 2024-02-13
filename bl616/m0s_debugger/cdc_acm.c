#include <assert.h>

#include "usbd_core.h"
#include "usbd_cdc.h"

#include "cdc_acm.h"
#include "usbd_descriptor.h"

USB_NOCACHE_RAM_SECTION USB_MEM_ALIGNX static uint8_t cdc_out_buffer[USBD_CDC_ACM_BUFFER_SIZE_DEVIDED_BY_CDC_MAX_MPS * CDC_MAX_MPS];

volatile bool ep_tx_busy_flag = false;

static void usbd_cdc_acm_bulk_out(uint8_t ep, uint32_t nbytes)
{
    assert(ep == CDC_OUT_EP);
    USB_LOG_DBG("actual out len:%d\r\n", nbytes);

    usbd_cdc_acm_bulk_out_cb(cdc_out_buffer, nbytes, ep);

    /* setup next out ep read transfer */
    usbd_ep_start_read(ep, cdc_out_buffer, sizeof(cdc_out_buffer));
}

static void usbd_cdc_acm_bulk_in(uint8_t ep, uint32_t nbytes)
{
    assert(ep == CDC_IN_EP);
    USB_LOG_DBG("actual in len:%d\r\n", nbytes);

    if ((nbytes % CDC_MAX_MPS) == 0 && nbytes) {
        /* send zlp */
        usbd_ep_start_write(CDC_IN_EP, NULL, 0);
    } else {
        ep_tx_busy_flag = false;
    }
}

#include "compiler/compiler_gcc.h"
__WEAK void usbd_cdc_acm_bulk_out_cb(uint8_t *buf, size_t len, uint8_t ep)
{
    assert(ep == CDC_OUT_EP);
    //    for (size_t i = 0; i < len; i++) {
    //        USB_LOG_RAW("%c", buf[i]);
    //    }
    //    USB_LOG_RAW("\r\n");
    usbd_ep_start_write(CDC_IN_EP, buf, len);
}

/* function ------------------------------------------------------------------*/
void usbd_event_handler(uint8_t event) {
  switch (event) {
  case USBD_EVENT_RESET:
    break;
  case USBD_EVENT_CONNECTED:
    break;
  case USBD_EVENT_DISCONNECTED:
    break;
  case USBD_EVENT_RESUME:
    break;
  case USBD_EVENT_SUSPEND:
    break;
  case USBD_EVENT_CONFIGURED:
    /* setup first out ep read transfer */
    usbd_ep_start_read(CDC_OUT_EP, cdc_out_buffer, sizeof(cdc_out_buffer));
    break;
  case USBD_EVENT_SET_REMOTE_WAKEUP:
    break;
  case USBD_EVENT_CLR_REMOTE_WAKEUP:
    break;
    
  default:
    break;
  }
}

void usbd_cdc_acm_template_init(void)
{
    usbd_desc_register(usbd_descriptor);

    static struct usbd_interface intf0_cdc_ctrl;
    static struct usbd_interface intf1_cdc_data;
    usbd_add_interface(usbd_cdc_acm_init_intf(&intf0_cdc_ctrl));
    usbd_add_interface(usbd_cdc_acm_init_intf(&intf1_cdc_data));

    /*!< endpoint call back */
    struct usbd_endpoint cdc_out_ep = {
        .ep_addr = CDC_OUT_EP,
        .ep_cb = usbd_cdc_acm_bulk_out
    };
    struct usbd_endpoint cdc_in_ep = {
        .ep_addr = CDC_IN_EP,
        .ep_cb = usbd_cdc_acm_bulk_in
    };
    usbd_add_endpoint(&cdc_out_ep);
    usbd_add_endpoint(&cdc_in_ep);

    usbd_initialize();
}

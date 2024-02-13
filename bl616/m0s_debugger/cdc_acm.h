#pragma once

#include <stdint.h>
#include <stddef.h>

extern void usbd_cdc_acm_bulk_out_cb(uint8_t *buf, size_t len, uint8_t ep);

#define USBD_CDC_ACM_BUFFER_SIZE_DEVIDED_BY_CDC_MAX_MPS 2

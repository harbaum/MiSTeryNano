#pragma once

#include "usbd_core.h"
#include "usbd_cdc.h"

#include "usb_config.h"

#define USBD_MAX_POWER     100
#define USBD_LANGID_STRING 1033

#ifdef CONFIG_USB_HS
#define CDC_MAX_MPS 512
#else
#define CDC_MAX_MPS 64
#endif

/*!< config descriptor size */
#define USB_CONFIG_SIZE (9 + CDC_ACM_DESCRIPTOR_LEN)

/*!< global descriptor */
static const uint8_t usbd_descriptor[] = {
    USB_DEVICE_DESCRIPTOR_INIT(USB_2_0, 0xEF, 0x02, 0x01, USBD_VID, USBD_PID, 0x0100, 0x01),
    USB_CONFIG_DESCRIPTOR_INIT(USB_CONFIG_SIZE, 0x02, 0x01, USB_CONFIG_BUS_POWERED, USBD_MAX_POWER),
    //    CDC_ACM_DESCRIPTOR_INIT(0x00, CDC_INT_EP, CDC_OUT_EP, CDC_IN_EP, 0x02),
    CDC_ACM_DESCRIPTOR_INIT(0x00, CDC_INT_EP, CDC_OUT_EP, CDC_IN_EP, CDC_MAX_MPS, 0x02),
    ///////////////////////////////////////
    /// string0 descriptor
    ///////////////////////////////////////
    USB_LANGID_INIT(USBD_LANGID_STRING),
    ///////////////////////////////////////
    /// string1 descriptor
    ///////////////////////////////////////
    10,                         /* bLength */
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */
    'M', 0x00,                  /* wcChar0 */
    'i', 0x00,                  /* wcChar1 */
    'S', 0x00,                  /* wcChar2 */
    'T', 0x00,                  /* wcChar3 */
    ///////////////////////////////////////
    /// string2 descriptor
    ///////////////////////////////////////
    26,                         /* bLength */
    USB_DESCRIPTOR_TYPE_STRING, /* bDescriptorType */
    'M', 0x00,                  /* wcChar0 */
    '0', 0x00,                  /* wcChar1 */
    'S', 0x00,                  /* wcChar2 */
    ' ', 0x00,                  /* wcChar3 */
    'D', 0x00,                  /* wcChar4 */
    'e', 0x00,                  /* wcChar5 */
    'b', 0x00,                  /* wcChar6 */
    'u', 0x00,                  /* wcChar7 */
    'g', 0x00,                  /* wcChar8 */
    'g', 0x00,                  /* wcChar9 */
    'e', 0x00,                  /* wcChar10 */
    'r', 0x00,                  /* wcChar11 */
#ifdef CONFIG_USB_HS
    ///////////////////////////////////////
    /// device qualifier descriptor
    ///////////////////////////////////////
    0x0a,
    USB_DESCRIPTOR_TYPE_DEVICE_QUALIFIER,
    0x00,
    0x02,
    0x02,
    0x02,
    0x01,
    0x40,
    0x01,
    0x00,
#endif
    0x00
};

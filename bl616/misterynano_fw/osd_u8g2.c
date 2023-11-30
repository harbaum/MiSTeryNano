//
// osd_u8g2.c
//

// spi
#include "bflb_gpio.h"

#include "spi.h"
#include "osd.h"
#include "menu.h"
#include "sdc.h"

static const u8x8_display_info_t u8x8_mn_128x64_info =
  { 0, 1, 0, 0, 0, 0, 0, 0, 4000000UL, 1, 0, 0, 0, 16, 8, 0, 0, 128, 64 };

uint8_t u8x8_d_mn_128x64(u8x8_t *u8g2, uint8_t msg, uint8_t arg_int, void *arg_ptr) {
  uint8_t x, y, c;
  uint8_t *ptr;

  switch(msg)
  {
    case U8X8_MSG_DISPLAY_SETUP_MEMORY:
      printf("U8X8_MSG_DISPLAY_SETUP_MEMORY\r\n");
      u8x8_d_helper_display_setup_memory(u8g2, &u8x8_mn_128x64_info);
      break;
    case U8X8_MSG_DISPLAY_INIT:
      printf("U8X8_MSG_DISPLAY_INIT\r\n");
      u8x8_d_helper_display_init(u8g2);
      break;
    case U8X8_MSG_DISPLAY_SET_POWER_SAVE:
      break;
    case U8X8_MSG_DISPLAY_SET_FLIP_MODE:
      break;
    case U8X8_MSG_DISPLAY_SET_CONTRAST:
      break;
    case U8X8_MSG_DISPLAY_DRAW_TILE:
      x = ((u8x8_tile_t *)arg_ptr)->x_pos;
      x *= 8;
      x += u8g2->x_offset;
    
      y = ((u8x8_tile_t *)arg_ptr)->y_pos;
      y *= 8;
    
      do
      {
	spi_t *spi = (spi_t *)u8g2_GetUserPtr(u8g2);     
        c = ((u8x8_tile_t *)arg_ptr)->cnt;
        ptr = ((u8x8_tile_t *)arg_ptr)->tile_ptr;
	// printf("DRAW TILE %d: %d %d %d\r\n", arg_int, x, y, c); 

	spi_begin(spi);
      
	/* send data */
	spi_tx_u08(spi, SPI_TARGET_OSD);
	spi_tx_u08(spi, SPI_OSD_WRITE);           // command byte data
	spi_tx_u08(spi, ((y/8)<<4)+x/8); // tile address

	for(int i=0;i<c*8;i++)
	  spi_tx_u08(spi, ptr[i]);

	spi_end(spi);
	
        arg_int--;
	x+=c*8;
      } while( arg_int > 0 );

      break;

    default:
      return 0;
  }
  return 1;
}

static uint8_t u8x8_d_mn_gpio(u8x8_t *u8x8, uint8_t msg, U8X8_UNUSED uint8_t arg_int, U8X8_UNUSED void *arg_ptr) {
  return 1;
}

void u8x8_Setup_mn_128x64(u8x8_t *u8x8) {
  /* setup defaults */
  u8x8_SetupDefaults(u8x8);
  
  /* setup specific callbacks */
  u8x8->display_cb = u8x8_d_mn_128x64;
	
  u8x8->gpio_and_delay_cb = u8x8_d_mn_gpio;

  /* setup display info */
  u8x8_SetupMemory(u8x8);  
}

void osd_enable(osd_t *osd, char en) {
  osd->state = en;
  
  // show/hide OSD
  spi_begin(osd->spi);  
  spi_tx_u08(osd->spi, SPI_TARGET_OSD);
  spi_tx_u08(osd->spi, SPI_OSD_ENABLE);  // enable/disable command
  spi_tx_u08(osd->spi, en);    // enable
  spi_end(osd->spi);  
}

// TODO: reorg to make space for floppy b and acsi
void osd_message(osd_t *osd, char *message) {
  u8g2_SetFont(&(osd->u8g2), u8g2_font_6x10_tf);
  u8g2_SetFontRefHeightAll(&(osd->u8g2));  	/* this will add some extra space for the text inside the buttons */
  u8g2_UserInterfaceMessage(&(osd->u8g2), message, "Title2", "Title3", " Ok ");

  osd_enable(osd, 1);
}

osd_t *osd_init(spi_t *spi) {
  // prepare u8g2
  static osd_t osd;

  osd.spi = spi;

  sdc_init(spi);
  
  osd.spi->dev->user_data = osd.buf;
  u8x8_Setup_mn_128x64(u8g2_GetU8x8(&osd.u8g2));
  u8g2_SetupBuffer(&osd.u8g2, osd.buf, 8, u8g2_ll_hvline_vertical_top_lsb, &u8g2_cb_r0);
  u8g2_SetUserPtr(&osd.u8g2, osd.spi);
  
  u8x8_ConnectBitmapToU8x8(u8g2_GetU8x8(&osd.u8g2));
  u8g2_SetFontMode(&osd.u8g2, 1);

  // make sure OSD is initially hidden
  osd.state = OSD_INVISIBLE;
  osd_enable(&osd, osd.state);
  
  return &osd;
}

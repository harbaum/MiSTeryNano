/*
  menu.c - MiSTeryNano menu based in u8g2/MUI
*/
  
#include <stdio.h>

#include "menu.h"

// a global OSD pointer as mui has no userdata or the like
osd_t *osd = NULL;

void menu_do(menu_t *menu, int event) {
  if(event) {
    if(event == MENU_EVENT_DOWN)   mui_NextField(&menu->ui);
    if(event == MENU_EVENT_UP)     mui_PrevField(&menu->ui);
    if(event == MENU_EVENT_SELECT) mui_SendSelect(&menu->ui);
    if(event == MENU_EVENT_SHOW)   osd_enable(menu->osd, OSD_VISIBLE);
    if(event == MENU_EVENT_HIDE)   osd_enable(menu->osd, OSD_INVISIBLE);
  }
  
  u8g2_SetFontRefHeightExtendedText(&menu->osd->u8g2);
  u8g2_FirstPage(&menu->osd->u8g2);
  do
    mui_Draw(&menu->ui);
  while( u8g2_NextPage(&menu->osd->u8g2) );
}

/* ------------------ MUI ----------------------- */

uint8_t mui_style_helv_r_08(mui_t *ui, uint8_t msg) {
  if(msg == MUIF_MSG_DRAW)
    u8g2_SetFont(mui_get_U8g2(ui), u8g2_font_helvR08_tr);  // _te is with some unicode
  
  return 0;
}

uint8_t mui_style_helv_b_08(mui_t *ui, uint8_t msg) {
  if(msg == MUIF_MSG_DRAW)
    u8g2_SetFont(mui_get_U8g2(ui), u8g2_font_helvB08_tr);
  
  return 0;
}

uint8_t mui_hrule(mui_t *ui, uint8_t msg)
{
  u8g2_t *u8g2 = mui_get_U8g2(ui);
  if(msg == MUIF_MSG_DRAW)
    u8g2_DrawHLine(u8g2, 0, mui_get_y(ui), u8g2_GetDisplayWidth(u8g2));
  
  return 0;
}

/*
  global variables which form the communication gateway between the user interface and the rest of the code
*/

uint8_t system_chipset = 0;  // ST/MegaST/STE
uint8_t system_memory  = 0;  // 4MB/8MB
uint8_t system_video   = 0;  // COL/MONO
uint8_t fs             = 0;  // file selection

#define CURRENT_FORM_ID(ui)  (ui->current_form_fds[1])

#include "sdc.h"

// taken from XBM bitmaps
static const unsigned char folder_icon[] = { 0x70,0x8e,0xff,0x81,0x81,0x81,0x81,0x7e };
static const unsigned char up_icon[] =     { 0x04,0x0e,0x1f,0x0e,0xfe,0xfe,0xfe,0x00 };

uint8_t file_selection(mui_t *ui, uint8_t msg) {
  static sdc_dir_t *dir = NULL;

  // load directory on form start for first file entry
  if ( msg == MUIF_MSG_FORM_START ) {
    if( !ui->arg ) {
      dir = sdc_readdir(NULL);
      
      ui->form_scroll_total = dir->len;
      ui->form_scroll_top = 0;

      ui->form_scroll_visible = 1;
    } else
      ui->form_scroll_visible++;
  }

  // at this point dir must be valid
  sdc_dir_entry_t *entry = &(dir->files[ui->form_scroll_top+ui->arg]);
  
  if ( msg == MUIF_MSG_CURSOR_SELECT ) {      
    if(entry->is_dir) {
      dir = sdc_readdir(entry->name);
      
      ui->form_scroll_total = dir->len;
      ui->form_scroll_top = 0;

      // go to first entry of newly opened subdir
      int scroll_up = ui->form_scroll_top+ui->arg;
      for(int i=0;i<scroll_up;i++) mui_PrevField(ui);
      
      return 0;
    } else {
      // request insertion of this image
      sdc_image_open(entry->name);
      
      // return to parent form, second entry
      // printf("PRE = %d\n", ui->last_form_id);
      
      mui_GotoForm(ui, 0, 2);
      return 0;
    }
  }

  if ( msg == MUIF_MSG_DRAW ) {
    char str[32];
    static const int icon_skip = 10;

    // check if we are supposed to draw an entry which arg is higher
    // then the number file entries. This means that there are less
    // files then entries on screen
    if(ui->form_scroll_top+ui->arg >= dir->len)
      return 1;

    strncpy(str, entry->name, sizeof(str));
    str[sizeof(str)-1] = 0;   // terminate possibly truncated string

    int width = u8g2_GetDisplayWidth(mui_get_U8g2(ui)) - 2*mui_get_x(ui);
    
    // properly ellipsize string
    int dotlen = u8g2_GetUTF8Width(mui_get_U8g2(ui), "...");
    if(u8g2_GetUTF8Width(mui_get_U8g2(ui), str) > width-icon_skip) {
      while(u8g2_GetUTF8Width(mui_get_U8g2(ui), str) > width-icon_skip-dotlen) str[strlen(str)-1] = 0;
      if(strlen(str) < sizeof(str)-4) strcat(str, "...");
    }

    // draw folder icon in front of directories
    if(entry->is_dir)
	u8g2_DrawXBM(mui_get_U8g2(ui), mui_get_x(ui), mui_get_y(ui)-8,
		     8, 8, strcmp(entry->name, "..")?folder_icon:up_icon);
    
    u8g2_DrawUTF8(mui_get_U8g2(ui), mui_get_x(ui) + icon_skip, mui_get_y(ui), str);
    if(ui->dflags & 1)
      u8g2_DrawButtonFrame(mui_get_U8g2(ui), mui_get_x(ui), mui_get_y(ui), U8G2_BTN_INV, width, 1, 1);
  }

  // prev and next events are eaten (retval 1), so we can scroll through
  // the file list while keeping focus on the same line
  if ( msg == MUIF_MSG_EVENT_PREV || msg == MUIF_MSG_EVENT_NEXT) {
    // check if we need scrolling at all or if all files fit on screen
    if(ui->form_scroll_visible >= dir->len) {

      // if we are on the last used entry and there are unused ones ahead, then
      // skip these
      if( (msg == MUIF_MSG_EVENT_NEXT )&&( ui->form_scroll_visible > dir->len)) {
	if( ui->arg == dir->len - 1) {
	  extern void mui_next_field(mui_t *ui);
	  for(int i=0;i<ui->form_scroll_visible - dir->len;i++) mui_next_field(ui);
	}
      }

      // if we are on the first entry and there are unused ones at the end, then
      // skip these
      if( (msg == MUIF_MSG_EVENT_PREV )&&( ui->form_scroll_visible > dir->len)) {
	if( ui->arg == 0) {
	  // there is no mui_prev_field(ui), so we use mui_next_field(ui)
	  extern void mui_next_field(mui_t *ui);
	  for(int i=0;i<dir->len;i++) mui_next_field(ui);
	}
      }
      return 0;
    }
    
    // check if we'd leave the menu at top
    if(ui->arg == 0 && msg == MUIF_MSG_EVENT_PREV && ui->form_scroll_top == 0)
      ui->form_scroll_top = ui->form_scroll_total - ui->form_scroll_visible;
    
    // check if we'd leave the menu at bottom
    if(ui->arg == ui->form_scroll_visible-1 && msg == MUIF_MSG_EVENT_NEXT &&
       ui->form_scroll_top == ui->form_scroll_total - ui->form_scroll_visible)
      ui->form_scroll_top = 0;
      
    // scrolling only happens on the middle entry
    if(ui->arg == (ui->form_scroll_visible-1)/2) {
      if( msg == MUIF_MSG_EVENT_PREV && ui->form_scroll_top > 0) {
	ui->form_scroll_top--;
	return 1;
      }
    }
      
    if(ui->arg == ui->form_scroll_visible/2) {      
      if( msg == MUIF_MSG_EVENT_NEXT && ui->form_scroll_top <
	  ui->form_scroll_total - ui->form_scroll_visible) {
	ui->form_scroll_top++;
	return 1;
      }
    }
  }

  return 0;
}

/*
  System: SC,SM,SV
 */

uint8_t btn_goto(mui_t *ui, uint8_t msg) {
  // the form to go to is stored in arg. There are special forms with arg >= 128
  if((msg == MUIF_MSG_CURSOR_SELECT) && (ui->arg >= 128)) {

    if(ui->arg == 255) {       // send reset
      osd_emit(osd, "SR", 1);  // activate reset signal
      osd_emit(osd, "SR", 0);  // de-activate reset signal
    }

    // hiding the OSD here won't work as the USB side needs to know about this
    // as well ....
    
    // osd_enable(osd, OSD_INVISIBLE);   // hide OSD
    // mui_GotoForm(ui, 0, 0);           // return to main form
    return 0;
  }
  
  return mui_u8g2_btn_goto_w1_pi(ui, msg);
}

// used for "ok" and "cancel" buttons
uint8_t btn_dialog(mui_t *ui, uint8_t msg) {
  static uint8_t form = 0xff;
  static uint8_t backup[3];
  
  // if a cancel button is to be drawn, then the forms values have to be backed up,
  // to allow to restore them on cancel
  if(ui->id1 == 'C' && msg == MUIF_MSG_DRAW && form != CURRENT_FORM_ID(ui)) {
    form = CURRENT_FORM_ID(ui);    
    printf("prepare cancel of form %d\n", form);

    if(form == 10) {
      backup[0] = system_chipset;
      backup[1] = system_memory;
      backup[2] = system_video;
    }
  }

  // ok/cancel has been selcted
  if(msg == MUIF_MSG_CURSOR_SELECT) {
    if(CURRENT_FORM_ID(ui) == 10 && ui->id1 == 'C') printf("system form canceled\n");
    if(CURRENT_FORM_ID(ui) == 10 && ui->id1 == 'O') printf("system form ok\n");
    
    if(ui->id1 == 'C') {
      // restore old values

      if(CURRENT_FORM_ID(ui) == 10) {
	system_chipset = backup[0];
	system_memory = backup[1];
	system_video = backup[2];
      }
    }
    
    if(ui->id1 == 'O') {
      // transmit new values to fpga
      // ...

      if(CURRENT_FORM_ID(ui) == 11) {
	printf("disk a: ok\r\n");
      }
	
      if(CURRENT_FORM_ID(ui) == 10) {
	osd_emit(osd, "SC", system_chipset);
	osd_emit(osd, "SM", system_memory);
	osd_emit(osd, "SV", system_video);

	// send reset if chipset or memory has changed
	if(system_chipset != backup[0] || system_memory != backup[1]) {      
	  osd_emit(osd, "SR", 1);
	  osd_emit(osd, "SR", 0);
	}
      }
    }
    
    form = 0xff;
  }
  
  return mui_u8g2_btn_goto_wm_fi(ui, msg);
}

muif_t muif_list[] MUI_PROGMEM = {
  /* normal text style */
  MUIF_STYLE(0, mui_style_helv_r_08),
  
  /* bold text style */
  MUIF_STYLE(1, mui_style_helv_b_08),

  /* horizontal line (hrule) */
  MUIF_RO("HR", mui_hrule),

  // System variables
  MUIF_VARIABLE("SC", &system_chipset, mui_u8g2_u8_opt_line_wa_mse_pi),
  MUIF_VARIABLE("SM",  &system_memory, mui_u8g2_u8_opt_line_wa_mse_pi),
  MUIF_VARIABLE("SV",   &system_video, mui_u8g2_u8_opt_line_wa_mse_pi),

  // file selection
  MUIF_VARIABLE("FS",   &fs, file_selection),

  /* Goto Form Button where the width is equal to the size of the text, spaces can be used to extend the size */
  //MUIF("G1",MUIF_CFLAG_IS_CURSOR_SELECTABLE,0,mui_u8g2_btn_goto_wm_fi),
  MUIF_BUTTON("GO", btn_dialog),
  MUIF_BUTTON("GC", btn_dialog),
  MUIF_BUTTON("G1", mui_u8g2_btn_goto_wm_fi),
  
  /* MUI_GOTO uses the fixed ".G" id and is intended for goto buttons. This is a full display width style button */  
  MUIF_GOTO(btn_goto),
  
  /* MUI_LABEL uses the fixed ".L" id and is used to place read only text on a form */
  //MUIF(".L",0,0,mui_u8g2_draw_text),
  MUIF_LABEL(mui_u8g2_draw_text),
};

fds_t fds[] = 

// --- form 0: main menu
MUI_FORM(0)
MUI_STYLE(1)
MUI_LABEL(5,10, "MiSTeryNano")
MUI_XY("HR", 0,13)
MUI_STYLE(0)
MUI_GOTO(5,25,10, "System")
  // MUI_GOTO(5,37,1, "Storage")
MUI_GOTO(5,37,11, "Disk A:")
MUI_GOTO(5,49,255, "Reset")

// --- form 1: Storage handling
MUI_FORM(1)
MUI_STYLE(1)
MUI_LABEL(5,10, "Storage")
MUI_XY("HR", 0,13)
MUI_STYLE(0)
MUI_GOTO(5,25,12, "SD card")
MUI_GOTO(5,37,11, "Disk A:")
MUI_GOTO(5,49,11, "Disk B:")
MUI_GOTO(5,61,0, "Back...")

/* form 10: system setup dialog */
MUI_FORM(10)
MUI_STYLE(1)
MUI_LABEL(5,8, "System") MUI_XY("HR", 0,11) MUI_STYLE(0)

MUI_LABEL(5,22, "Chipset:") MUI_XYAT("SC", 60, 22, 60, "ST|MegaST|STE")
MUI_LABEL(5,34, "Memory:")  MUI_XYAT("SM", 60, 34, 60, "4MB|8MB")
MUI_LABEL(5,46, "Video:")   MUI_XYAT("SV", 60, 46, 60, "Color|Mono")

MUI_XYAT("GO", 32, 60, 0, "   Ok   ")
MUI_XYAT("GC", 90, 60, 0, " Cancel ")
  
/* form 11: disk file selection */
MUI_FORM(11)
MUI_STYLE(1)
MUI_LABEL(0,8, "Disk A:") MUI_XY("HR", 0,11) MUI_STYLE(0)

MUI_XYA("FS", 0, 22, 0)
MUI_XYA("FS", 0, 34, 1)
MUI_XYA("FS", 0, 46, 2)
MUI_XYA("FS", 0, 58, 3)
;

#ifndef SDL
menu_t *menu_init(spi_t *spi)
#else
  menu_t *menu_init(u8g2_t *u8g2, mui_t *ui)
#endif
{
  static menu_t menu;
  
#ifndef SDL
  menu.osd = osd_init(spi);
#else
  static osd_t losd;
  menu.ui = *ui;
  menu.osd = &losd;
  menu.osd->u8g2 = *u8g2;
#endif
  
  osd = menu.osd;
  mui_Init(&menu.ui, &menu.osd->u8g2, fds, muif_list, sizeof(muif_list)/sizeof(muif_t));
  mui_GotoForm(&menu.ui, 0, 0);
  
  return &menu;
}

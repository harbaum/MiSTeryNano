/*
  menu.c - MiSTeryNano menu based in u8g2
*/
  
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ff.h>

#include "sdc.h"
#include "menu.h"
#include "sysctrl.h"

// this is the u8g2_font_helvR08_te with any trailing
// spaces removed
#include "font_helvR08_te.c"

#define MENU2U8G2(a)  (&(a->osd->u8g2))

char *disk_a = NULL;

// variable ids must match the ones in the menu string
menu_variable_t variables[] = {
  { 'C', { 0 }},    // default chipset = ST
  { 'M', { 0 }},    // default memory = 4MB
  { 'V', { 0 }},    // default video = color
  { 'S', { 0 }},    // default scanlines = none
  { 'A', { 1 }},    // default volume = 33%
  { '\0',{ 0 }}
};

#define MENU_FORM_FSEL           -1

#define MENU_ENTRY_INDEX_ID       0
#define MENU_ENTRY_INDEX_LABEL    1
#define MENU_ENTRY_INDEX_FORM     2
#define MENU_ENTRY_INDEX_OPTIONS  2
#define MENU_ENTRY_INDEX_VARIABLE 3

static const char main_form[] =
  "MiSTeryNano,;"                       // main form has no parent
  // --------
  "S,System,1;"                         // System submenu is form 1
  "F,Disk A:,0;"                        // fileselector for Disk A:
  "F,Disk B:,1;"                        // fileselector for Disk B:
  "B,Reset,R;";                         // system reset

static const char system_form[] =
  "System,0;"                           // parent form is 0
  // --------
  "L,Chipset:,ST|Mega ST|STE,C;"        // selection stored in variable "C"
  "L,Memory:,4MB|8MB,M;"                // ...
  "L,Video:,Color|Mono,V;"
  "L,Scanlines:,None|25%|50%|75%,S;"
  "L,Volume:,Mute|33%|66%|100%,A;"
  "B,Cold Boot,B;"                      // system reset with memory reset
  "B,Save settings,S;";

static const char *forms[] = {
  main_form,
  system_form
};

static void menu_goto_form(menu_t *menu, int form) {
  menu->form = form;
  menu->entry = 1;
  menu->entries = -1;
  menu->offset = 0;
}

#define SETTINGS_FILE  "/sd/atarist.ini"

static void menu_settings_load(menu_t *menu) {
  printf("Read settings\r\n");

  sdc_lock();  // get exclusive access to the file system

  FIL fil;
  if(f_open(&fil, SETTINGS_FILE, FA_OPEN_EXISTING | FA_READ) == FR_OK) {    
    char buffer[8];

    printf("Settings file opened\r\n");
    while(f_gets(buffer, sizeof(buffer), &fil) != NULL) {
      int value = atoi(buffer+1);
      printf("  %c:%d\r\n", buffer[0], value);

      for(int i=0;menu->vars[i].id;i++)
	if(menu->vars[i].id == buffer[0])
	  menu->vars[i].value = value;
    }
    f_close(&fil);
  } else
    printf("Error opening file\r\n");
  
  sdc_unlock();
}

static void menu_settings_save(menu_t *menu) {
  printf("Write settings\r\n");
  
  sdc_lock();  // get exclusive access to the file system
  
  // saving does not work, yet, as there is no SD card write support by now
  FIL file;
  if(f_open(&file, SETTINGS_FILE, FA_WRITE | FA_CREATE_ALWAYS) == FR_OK) {
    char str[8];
    for(int i=0;menu->vars[i].id;i++) {
      sprintf(str, "%c%d\n", menu->vars[i].id, menu->vars[i].value);
      f_puts(str, &file);
    }
    f_close(&file);  
  } else
    printf("Error opening file\r\n");
  
  sdc_unlock();
}

#ifndef SDL
menu_t *menu_init(spi_t *spi)
#else
menu_t *menu_init(u8g2_t *u8g2)
#endif
{
  static menu_t menu;

  menu.forms = forms;
  menu.vars = variables;
  menu_goto_form(&menu, 0); // first form selected at start
      
#ifndef SDL
  menu.osd = osd_init(spi);
#else
  static osd_t losd;
  menu.osd = &losd;
  menu.osd->u8g2 = *u8g2;
#endif

  // give sd card 2 seconds to become ready
  int timeout = 200;
  while(timeout && !sdc_is_ready()) {
    vTaskDelay(pdMS_TO_TICKS(10));
    timeout--;
  }

  // load data from sd card if available
  if(timeout) {
    printf("SD ready after %dms\r\n", (200-timeout)*10);
    
    // try to restore variables from eeprom
    menu_settings_load(&menu);  
  } else
    printf("SD wasn't ready, not loading settings\r\n");
    
  // send initial values for all variables
  for(int i=0;menu.vars[i].id;i++)
    sys_set_val(menu.osd->spi, menu.vars[i].id, menu.vars[i].value);

  // and cold reset the core, just in case ...
  sys_set_val(menu.osd->spi, 'R', 3);
  sys_set_val(menu.osd->spi, 'R', 0);
  
  return &menu;
}

// find first occurence of any char in chrs within str
const char *strchrs(const char *str, char *chrs) {
  while(*str) {
    for(int i=0;i<strlen(chrs);i++)
      if(*str == chrs[i]) return str;
    str++;
  }
  return NULL;
}

// get the n'th substring in colon separated string
static char *menu_get_str(menu_t *menu, const char *s, int n) {
  while(n--) s = strchr(s, ',')+1;   // skip n substrings

  const char *sub = strchrs(s, ";,");
  if(!sub)
    strcpy(menu->buffer, s);
  else {
    strncpy(menu->buffer, s, sub-s);  // copy characters
    menu->buffer[sub-s] = '\0';       // terminate string
  }
    
  return menu->buffer;
}

// get the n'th char in colon separated string
static char menu_get_chr(menu_t *menu, const char *s, int n) {
  while(n--) s = strchr(s, ',')+1;   // skip n substrings
  return s[0];
}

// get the n'th substring in | separated string in a colon string
static char *menu_get_substr(menu_t *menu, const char *s, int n, int m) {
  while(n--) s = strchr(s, ',')+1;   // skip n substrings
  while(m--) s = strchr(s, '|')+1;   // skip m subsubstrings

  const char *sub = strchrs(s, ";,|");
  strncpy(menu->buffer, s, sub-s);  // copy characters
  menu->buffer[sub-s] = '\0';       // terminate string

  return menu->buffer;
}
  
static int menu_get_int(menu_t *menu, const char *s, int n) {
  char *str = menu_get_str(menu, s, n);
  return atoi(str);
}

static int menu_variable_get(menu_t *menu, const char *s) {
  char id = menu_get_chr(menu, s, MENU_ENTRY_INDEX_VARIABLE);

  for(int i=0;menu->vars[i].id;i++)
    if(menu->vars[i].id == id)
      return menu->vars[i].value;    

  return -1;
}

static void menu_variable_set(menu_t *menu, const char *s, int val) {
  char id = menu_get_chr(menu, s, MENU_ENTRY_INDEX_VARIABLE);
  
  for(int i=0;menu->vars[i].id;i++) {
    if(menu->vars[i].id == id) {
      menu->vars[i].value = val;

      // also set this in the core
      sys_set_val(menu->osd->spi, id, val);

      // trigger cold reset if memory or chipset have been changed a
      // video change will also trigger a reset, but that's handled by
      // the ST itself
      if((id == 'C') || (id == 'M') ) {
	sys_set_val(menu->osd->spi, 'R', 3);
	sys_set_val(menu->osd->spi, 'R', 0);
      }
    }
  }
}
  
static int menu_get_options(menu_t *menu, const char *s, int n) {
  // get possible number of values
  int num = 1;
  char *v = menu_get_str(menu, s, n);
  while((v = strchr(v, '|'))) { v++; num++; }
  return num;
}

// various 8x8 icons
const static unsigned char icn_right_bits[]  = { 0x00,0x04,0x0c,0x1c,0x3c,0x1c,0x0c,0x04 };
const static unsigned char icn_left_bits[]   = { 0x00,0x20,0x30,0x38,0x3c,0x38,0x30,0x20 };
const static unsigned char icn_floppy_bits[] = { 0xff,0x81,0x83,0x81,0xbd,0xad,0x6d,0x3f };

// Draw menu title. Submenu titles are selectable and can be used to return to the
// parent menu.
static void menu_draw_title(menu_t *menu, const char *s) {
  int x = 1;

  // draw left arrow for submenus
  if(menu->form) {
    u8g2_DrawXBM(MENU2U8G2(menu), 0, 1, 8, 8, icn_left_bits);    
    x = 8;
  }

  // draw title in bold and seperator line
  u8g2_SetFont(MENU2U8G2(menu), u8g2_font_helvB08_tr);
  u8g2_DrawStr(MENU2U8G2(menu), x, 9, menu_get_str(menu, s, 0));
  u8g2_DrawHLine(MENU2U8G2(menu), 0, 13, u8g2_GetDisplayWidth(MENU2U8G2(menu)));

  if(x > 0 && menu->entry == 0)
    u8g2_DrawButtonFrame(MENU2U8G2(menu), 0, 9, U8G2_BTN_INV, u8g2_GetDisplayWidth(MENU2U8G2(menu)), 1, 1);
  
  // draw the rest with normal font
  u8g2_SetFont(MENU2U8G2(menu), font_helvR08_te);
}

static void menu_draw_entry(menu_t *menu, int y, const char *s) {
  char *buf = menu_get_str(menu, s, MENU_ENTRY_INDEX_LABEL);

  int ypos = 13 + 12 * y;
  int width = u8g2_GetDisplayWidth(MENU2U8G2(menu));

  // all menu entries are a plain text
  u8g2_DrawStr(MENU2U8G2(menu), 1, ypos, buf);
    
  // prepare highlight
  int hl_x = 0;
  int hl_w = width;
  
  // handle second string for 'L'ist entries
  if(s[0] == 'L') {
    // get variable
    int value = menu_variable_get(menu, s);
    
    buf = menu_get_substr(menu, s, MENU_ENTRY_INDEX_OPTIONS, value);
    u8g2_DrawStr(MENU2U8G2(menu), width/2, ypos, buf);
    
    hl_x = width/2;
    hl_w = width/2;
  }
  
  // some entries have a small arrow to the right    
  if(s[0] == 'S') u8g2_DrawXBM(MENU2U8G2(menu), hl_w-8, ypos-8, 8, 8, icn_right_bits);    
  if(s[0] == 'F') u8g2_DrawXBM(MENU2U8G2(menu), hl_w-9, ypos-8, 8, 8, icn_floppy_bits);    
  
  if(y+menu->offset == menu->entry)
    u8g2_DrawButtonFrame(MENU2U8G2(menu), hl_x, ypos, U8G2_BTN_INV, hl_w, 1, 1);
}

static void menu_fileselector(menu_t *menu, int state) {
  static const unsigned char folder_icon[] = { 0x70,0x8e,0xff,0x81,0x81,0x81,0x81,0x7e };
  static const unsigned char up_icon[] =     { 0x04,0x0e,0x1f,0x0e,0xfe,0xfe,0xfe,0x00 };
  
  static sdc_dir_t *dir = NULL;
  const static char *s;
  static int parent;
  static int drive;
  
  if(state == 0) {
    // init
    s = menu->forms[menu->form];
    for(int i=0;i<menu->entry;i++) s = strchr(s, ';')+1;
    
    // scan files
    dir = sdc_readdir(NULL);
    menu->entry = 1;               // start by highlighting first file entry
    menu->entries = dir->len + 1;  // incl. title
    menu->offset = 0;
    parent = menu->form;
    drive = menu_get_int(menu, s, 2);    
    
  } else if(state == 1) {
    // draw
    menu_draw_title(menu, menu_get_str(menu, s, MENU_ENTRY_INDEX_LABEL));

    // draw up to four files
    for(int i=0;i<((dir->len<4)?dir->len:4);i++) {
      char str[32];
      static const int icon_skip = 10;
      int y =  13 + 12 * (i+1);
      sdc_dir_entry_t *entry = &(dir->files[i+menu->offset]);

      strncpy(str, entry->name, sizeof(str));
      str[sizeof(str)-1] = 0;   // terminate possibly truncated string

      int width = u8g2_GetDisplayWidth(MENU2U8G2(menu));
    
      // properly ellipsize string
      int dotlen = u8g2_GetStrWidth(MENU2U8G2(menu), "...");
      if(u8g2_GetStrWidth(MENU2U8G2(menu), str) > width-icon_skip) {
	while(u8g2_GetStrWidth(MENU2U8G2(menu), str) > width-icon_skip-dotlen) str[strlen(str)-1] = 0;
	if(strlen(str) < sizeof(str)-4) strcat(str, "...");
      }
      u8g2_DrawStr(MENU2U8G2(menu), icon_skip, y, str);      

      // draw folder icon in front of directories
      if(entry->is_dir)
        u8g2_DrawXBM(MENU2U8G2(menu), 1, y-8, 8, 8, strcmp(entry->name, "..")?folder_icon:up_icon);

      if(menu->entry == i+menu->offset+1)
	u8g2_DrawButtonFrame(MENU2U8G2(menu), 0, y, U8G2_BTN_INV, width, 1, 1);   
    }
  } else if(state == 4) {

    if(!menu->entry) 
      menu_goto_form(menu, parent);
    else {
      sdc_dir_entry_t *entry = &(dir->files[menu->entry - 1]);

      if(entry->is_dir) {
	dir = sdc_readdir(entry->name);
	menu->entry = 1;               // start by highlighting first file entry
	menu->entries = dir->len + 1;  // incl. title
	menu->offset = 0;
      } else {
	// request insertion of this image
	sdc_image_open(drive, entry->name);	
	menu_goto_form(menu, parent);
      }
    }
  }   
}

static void menu_draw_form(menu_t *menu, const char *s) {
  u8g2_ClearBuffer(MENU2U8G2(menu));

  // regular entry?
  if(menu->form >= 0) {
    // count menu entries if not done yet
    if(menu->entries < 0) {
      menu->entries = 0;

      for(const char *p = s;*p && strchr(p, ';');p=strchr(p, ';')+1)
	menu->entries++;
    }

    // -------- draw title -----------
    menu_draw_title(menu, s);
    s = strchr(s, ';')+1;

    // ------- draw menu entries ------

    // skip 'offset' entries
    for(int i=0;i<menu->offset;i++)
      s = strchr(s, ';')+1;      // skip to next entry
    
    // walk over menu string
    int y = 1;
    while(*s) {
      menu_draw_entry(menu, y++, s);    
      s = strchr(s, ';')+1;      // skip to next entry
    }
  } else if(menu->form == MENU_FORM_FSEL)
    menu_fileselector(menu, 1);
  
  u8g2_SendBuffer(MENU2U8G2(menu));
}

static void menu_select(menu_t *menu) {
  if(menu->form == MENU_FORM_FSEL) {
    menu_fileselector(menu, 4);
    return;
  }
    
  const char *s = menu->forms[menu->form];
  // skip to current entry (incl. title)
  for(int i=0;i<menu->entry;i++) s = strchr(s, ';')+1;
  
  printf("Selected: %s\r\n", s);

  // if the title was selected, then goto parent form
  if(!menu->entry) {
    menu_goto_form(menu, menu_get_int(menu, s, 1));
    return;
  }
  
  switch(*s) {
  case 'F':
    menu_fileselector(menu, 0);   // init
    menu->form = MENU_FORM_FSEL;
    menu->entry = 1;
    break;
    
  case 'S':
    menu_goto_form(menu, menu_get_int(menu, s, MENU_ENTRY_INDEX_FORM));
    break;

  case 'L': {
    int value = menu_variable_get(menu, s) + 1;
    int max_value = menu_get_options(menu, s, MENU_ENTRY_INDEX_OPTIONS)-1;
    if(value > max_value) value = 0;    
    menu_variable_set(menu, s, value);
  } break;

  case 'B': {
    char id = menu_get_chr(menu, s, 2);
    
    if(id == 'S')
      menu_settings_save(menu);

    // normal reset
    if(id == 'R') {    
      sys_set_val(menu->osd->spi, 'R', 1);
      sys_set_val(menu->osd->spi, 'R', 0);
    }

    // cold boot
    if(id == 'B') {    
      sys_set_val(menu->osd->spi, 'R', 3);
      sys_set_val(menu->osd->spi, 'R', 0);
    }
  } break;
	
  default:
    printf("unknown %c\r\n", *s);    
  }
}

static int menu_entry_is_usable(menu_t *menu) {
  // check the current entry in the menu is actually selectable
  // (currently only the title of the start form is not)

  // not start form? -> ok
  if(menu->form) return 1;

  return (menu->entry == 0)?0:1;
}

static void menu_entry_go(menu_t *menu, int step) {
  do {
    menu->entry += step;
    
    if(menu->entry < 0) menu->entry = menu->entries-1;
    if(menu->entry >= menu->entries) menu->entry = 0;

    // scrolling needed?
    if(step == 1) {
      if(menu->entries <= 5)                   menu->offset = 0;
      else {
	if(menu->entry <= 3)                   menu->offset = 0;
	else if(menu->entry < menu->entries-2) menu->offset = menu->entry - 3;
	else                                   menu->offset = menu->entries-5;
      }
    }

    if(step == -1) {
      if(menu->entries <= 5)                   menu->offset = 0;
      else {
	if(menu->entry <= 2)                   menu->offset = 0;
	else if(menu->entry < menu->entries-3) menu->offset = menu->entry - 2;
	else                                   menu->offset = menu->entries-5;
      }
    }
    
    // give file selector a chance to adjust scroll
    if(menu->form == MENU_FORM_FSEL)
      menu_fileselector(menu, (step>0)?2:3);
    
  } while(!menu_entry_is_usable(menu));
}

void menu_do(menu_t *menu, int event) {
  if(event)  {
    if(event == MENU_EVENT_SHOW)   osd_enable(menu->osd, OSD_VISIBLE);
    if(event == MENU_EVENT_HIDE)   osd_enable(menu->osd, OSD_INVISIBLE);
    
    if(event == MENU_EVENT_UP)     menu_entry_go(menu, -1);
    if(event == MENU_EVENT_DOWN)   menu_entry_go(menu,  1);

    if(event == MENU_EVENT_SELECT) menu_select(menu);
  }  
  menu_draw_form(menu, menu->forms[menu->form]);
}


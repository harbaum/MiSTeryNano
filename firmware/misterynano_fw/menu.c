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

#define MENU_FORM_FSEL           -1

#define MENU_ENTRY_INDEX_ID       0
#define MENU_ENTRY_INDEX_LABEL    1
#define MENU_ENTRY_INDEX_FORM     2
#define MENU_ENTRY_INDEX_OPTIONS  2
#define MENU_ENTRY_INDEX_VARIABLE 3

// ------------------------------------------------------------------
// ---------------------  Atari ST menu -----------------------------
// ------------------------------------------------------------------

static const char main_form_atari_st[] =
  "MiSTeryNano,;"                       // main form has no parent
  // --------
  "F,Disk A:,0|st;"                     // fileselector for Disk A:
  "S,System,1;"                         // System submenu is form 1
  "S,Drives,2;"                         // Storage submenu
  "S,Settings,3;"                       // Settings submenu is form 3
  "B,Reset,R;";                         // system reset

static const char system_form_atari_st[] =
  "System,0|2;"                         // return to form 0, entry 2
  // --------
  "L,Chipset:,ST|Mega ST|STE,C;"        // selection stored in variable "C"
  "L,Memory:,4MB|8MB,M;"                // ...
  "L,Video:,Color|Mono,V;"
  "L,Cartridge:,None|Cubase 2&3,Q;"     // Cubase dongle support
  "L,Mouse:,USB|Atari ST|Amiga,J;"      // Mouse (DB9) mapping
  "L,TOS Slot:,Primary|Secondary,T;"    // Select TOS
  "B,Cold Boot,B;";                     // system reset with memory reset

static const char storage_form_atari_st[] =
  "Drives,0|3;"                         // return to form 0, entry 3
  // --------
  "F,Disk A:,0|st;"                     // fileselector for Disk A:
  "F,Disk B:,1|st;"                     // fileselector for Disk B:
  "F,ACSI #0:,2|hd+img;"                // fileselector for ACSI 0
  "F,ACSI #1:,3|hd+img;"                // fileselector for ACSI 1
  "L,Disk prot.:,None|A:|B:|Both,P;";   // Enable/Disable Floppy write protection

static const char settings_form_atari_st[] =
  "Settings,0|4;"                       // return to form 0, entry 4
  // --------
  "L,Screen:,Normal|Wide,W;"
  "L,Scanlines:,None|25%|50%|75%,S;"
  "L,Volume:,Mute|33%|66%|100%,A;"
  "B,Save settings,S;";

static const char *forms_atari_st[] = {
  main_form_atari_st,
  system_form_atari_st,
  storage_form_atari_st,
  settings_form_atari_st
};

// variable ids must match the ones in the menu string
menu_variable_t variables_atari_st[] = {
  { 'C', { 0 }},    // default chipset = ST
  { 'M', { 0 }},    // default memory = 4MB
  { 'V', { 0 }},    // default video = color
  { 'S', { 0 }},    // default scanlines = none
  { 'A', { 1 }},    // default volume = 33%
  { 'W', { 0 }},    // default normal (4:3) screen
  { 'P', { 0 }},    // default no floppy write protected
  { 'Q', { 0 }},    // default cubase dongle not enabled
  { 'J', { 0 }},    // default mouse USB, DB9 connector joystick
  { 'T', { 0 }},    // default primary TOS slot
  { '\0',{ 0 }}
};

// ------------------------------------------------------------------
// ------------------------  C64 menu -------------------------------
// ------------------------------------------------------------------

static const char main_form_c64[] =
  "C64Nano,;"                           // main form has no parent
  // --------
  "F,Floppy 8:,0|d64+g64;"              // fileselector for Floppy 8:
  "S,System,1;"                         // System submenu is form 1
  "S,Storage,2;"                        // Storage submenu
  "S,Settings,3;"                       // Settings submenu is form 2
  "B,Reset,R;";                         // system reset

static const char system_form_c64[] =
  "System,0|2;"                         // return to form 0, entry 2
  // --------
  "L,Joyport 1:,Retro D9|USB #1|USB #2|NumPad|DualShock|Mouse|Paddle|Off,Q;" // Joystick port 1 mapping
  "L,Joyport 2:,Retro D9|USB #1|USB #2|NumPad|DualShock|Mouse|Paddle|Off,J;" // Joystick port 2 mapping, default c64 Joystick port
  "L,REU 1750:,Off|On,V;"                  // REU enable
  "L,c1541 ROM:,Dolphin DOS|CBM DOS|Speed DOS P|Jiffy DOS,D;"  // c1541 compatibility
  "L,Turbo mode:,Off|C128|Smart,X;"
	"L,Turbo speed:,2x|3x|4x,Y;"
  "L,Video Std:,PAL|NTSC,E;"
  "L,Midi:,Off|Sequential|Passport|DATEL|Namesoft,N;"
  "L,Pause OSD:,Off|On,G;"
  "L,VIC-II:,656x|856x|Early 856x,C;"
  "L,CIA:,6526|8521,M;"
  "L,SID:,6581|8580,O;"
  "L,SID Digifix:,Off|On,U;"
  "L,Right SID:,Same|DE00|D420|D500|DF00,K;"
  "B,c1541 Reset,Z;"
  "B,Cold Boot,B;"; 

static const char storage_form_c64[] =
  "Storage,0|3;"                        // return to form 0, entry 3
  // --------
  "F,Floppy 8:,0|d64+g64;"              // fileselector for Disk Drive 8:
  "F,CRT ROM:,1|crt;"                   // fileselector for CRT
  "F,PRG BASIC:,2|prg;"                       // fileselector for PRG
  "F,C64 Kernal:,3|bin;"                // fileselector for Kernal ROM
  "F,TAP Tape:,4|tap;"                       // fileselector for TAP
  "L,Disk prot.:,None|8:,P;";           // Enable/Disable Floppy write protection

static const char settings_form_c64[] =
  "Settings,0|4;"                       // return to form 0, entry 3
  // --------
  "L,Screen:,Normal|Wide,W;"
  "L,Scanlines:,None|25%|50%|75%,S;"
  "L,Volume:,Mute|33%|66%|100%,A;"
  "B,Save settings,S;";

static const char *forms_c64[] = {
  main_form_c64,
  system_form_c64,
  storage_form_c64,
  settings_form_c64
};

menu_variable_t variables_c64[] = {
  { 'U', { 1 }},    // default digifix = active
  { 'X', { 0 }},    // default turbo mode = off
  { 'Y', { 0 }},    // default turbo speed = 2x
  { 'D', { 0 }},    // default c1541 dos = dolphin
  { 'V', { 0 }},    // default reu = disabled
  { 'S', { 0 }},    // default scanlines = none
  { 'A', { 2 }},    // default volume = 66%
  { 'W', { 0 }},    // default normal (4:3) screen
  { 'P', { 0 }},    // default no floppy write protected
  { 'Q', { 7 }},    // Joystick port 1 mapping, OFF
  { 'J', { 0 }},    // Joystick port 2 mapping, DB9
  { 'E', { 0 }},    // default standard = PAL
  { 'N', { 0 }},    // default MIDI = Off
  { 'G', { 0 }},    // default OSD Pause = Off
  { 'C', { 0 }},    // default CIA 6526
  { 'M', { 0 }},    // default VIC-II 656x
  { 'O', { 0 }},    // default SID 6581
  { 'K', { 0 }},    // default right SID addr same
  { '\0',{ 0 }}
};

// ------------------------------------------------------------------
// ------------------------  VIC20 menu -------------------------------
// ------------------------------------------------------------------

static const char main_form_vic20[] =
  "VIC20Nano,;"                         // main form has no parent
  // --------
  "F,Floppy 8:,0|d64+g64;"              // fileselector for Floppy 8:
  "S,System,1;"                         // System submenu is form 1
  "S,Storage,2;"                        // Storage submenu
  "S,Settings,3;"                       // Settings submenu is form 2
  "B,Reset,R;";                         // system reset

static const char system_form_vic20[] =
  "System,0|2;"                         // return to form 0, entry 2
  // --------
  "L,Joyport:,Retro D9|USB #1|USB #2|NumPad|DualShock|Mouse|Paddle|Off,Q;" // Joystick port 1 mapping
  "L,c1541 ROM:,Dolphin DOS|CBM DOS|Speed DOS P|Jiffy DOS,D;"  // c1541 compatibility
  "L,RAM $04 3K:,Off|On,U;"
  "L,RAM $20 8K:,Off|On,X;"
  "L,RAM $40 8K:,Off|On,Y;"
  "L,RAM $60 8K:,Off|On,N;"
  "L,RAM $A0 8K:,Off|On,G;"
  "L,Video Std:,PAL|NTSC,E;"
  "L,Vid. cent:,Off|Both|Horz|Vert,J;"
  "L,CRT write:,Off|On,V;"
  "B,c1541 Reset,Z;"
  "B,Cold Boot,B;"; 

static const char storage_form_vic20[] =
  "Storage,0|3;"                        // return to form 0, entry 3
  // --------
  "F,Floppy 8:,0|d64+g64;"              // fileselector for Disk Drive 8:
  "F,CRT ROM:,1|prg+crt;"               // fileselector for CRT (special VIC20 prg)
  "F,PRG BASIC:,2|prg;"                       // fileselector for PRG
  "F,VIC20 Kernal:,3|bin;"              // fileselector for Kernal ROM
  "F,TAP Tape:,4|tap;"                       // fileselector for TAP
  "L,Disk prot.:,None|8:,P;";           // Enable/Disable Floppy write protection

static const char settings_form_vic20[] =
  "Settings,0|4;"                       // return to form 0, entry 3
  // --------
  "L,Screen:,Normal|Wide,W;"
  "L,Scanlines:,None|25%|50%|75%,S;"
  "L,Volume:,Mute|33%|66%|100%,A;"
  "B,Save settings,S;";

static const char *forms_vic20[] = {
  main_form_vic20,
  system_form_vic20,
  storage_form_vic20,
  settings_form_vic20
};

menu_variable_t variables_vic20[] = {
  { 'U', { 0 }},    // default 3k, $0400
  { 'X', { 0 }},    // default 8k, $2000
  { 'Y', { 0 }},    // default 8k, $4000
  { 'N', { 0 }},    // default 8k, $6000
  { 'G', { 0 }},    // default 8k, $A000 Cartridge area
  { 'D', { 1 }},    // default c1541 dos = CBM
  { 'S', { 0 }},    // default scanlines = none
  { 'A', { 2 }},    // default volume = 66%
  { 'W', { 0 }},    // default normal (4:3) screen
  { 'P', { 0 }},    // default no floppy write protected
  { 'Q', { 0 }},    // Joystick port 1 mapping = DB9
  { 'E', { 0 }},    // default standard = PAL
  { 'J', { 1 }},    // Screen center = Both
  { 'V', { 1 }},    // Cartridge writable = On
  { '\0',{ 0 }}
};

// ------------------------------------------------------------------
// -----------------------  Amiga menu ------------------------------
// ------------------------------------------------------------------

static const char main_form_amiga[] =
  "NanoMig,;"                           // main form has no parent
  // --------
  "B,Reset,R;";                         // system reset

static const char *forms_amiga[] = {
  main_form_amiga
};

menu_variable_t variables_amiga[] = {
  { '\0',{ 0 }}
};

static void menu_goto_form(menu_t *menu, int form, int entry) {
  menu->form = form;
  menu->entry = entry;
  menu->entries = -1;
  menu->offset = 0;
}

static const char *settings_file[] = {
  NULL,
  CARD_MOUNTPOINT "/atarist.ini",  // core id = 1
  CARD_MOUNTPOINT "/c64.ini",       // core id = 2
  CARD_MOUNTPOINT "/vic20.ini"     // core id = 3
};

static int iswhite(char c) {
  return c == ' ' || c == '\r' || c == '\n' || c == '\t';
}

static int menu_settings_load(menu_t *menu) {
  printf("Read settings\r\n");

  sdc_lock();  // get exclusive access to the file system

  FIL fil;
  if(f_open(&fil, settings_file[core_id], FA_OPEN_EXISTING | FA_READ) == FR_OK) {    
    char buffer[FF_LFN_BUF+10];

    printf("Settings file opened\r\n");
    
    // read file line by line
    while(f_gets(buffer, sizeof(buffer), &fil) != NULL) {
      // ignore everything after semicolon
      char *pos = strchr(buffer, ';');
      if(pos) *pos = '\0';

      // also skip all trailing white space
      while(strlen(buffer) > 0 && iswhite(buffer[strlen(buffer)-1]))
	buffer[strlen(buffer)-1] = 0;

      // printf("Line = '%s'\n", buffer);
	
      // check for old style entries which were just two characters long
      if(strlen(buffer) == 2) {
	int value = atoi(buffer+1);
	printf("  %c:%d\r\n", buffer[0], value);

	for(int i=0;menu->vars[i].id;i++)
	  if(menu->vars[i].id == buffer[0])
	    menu->vars[i].value = value;
      } else {
	// check for drives
	if(strncasecmp(buffer, "drive", 5) == 0) {
	  char * p = buffer+5;  // skip 'drive'
	  while(*p && iswhite(*p)) p++;
	  if(*p) {
	    int drive = *p-'0';
	    // skip after '='
	    while(*p && *p != '=') p++;
	    p++;
	    if(*p) {
	      // skip to begin of filename
	      while(*p && iswhite(*p)) p++;
	      if(*p) {
		// tell SDC layer what images to use as default
		printf("drive %d = %s\r\n", drive, p);		
		sdc_set_default(drive, p);
	      }
	    }
	  }
	}
	  
	// check for variables
	if(strncasecmp(buffer, "var ", 4) == 0) {
	  
	  // --- parse 'var x=0` style lines ---
	  // skip "var"
	  char *p = buffer+4;
	  // skip to first char
	  while(*p && iswhite(*p)) p++;
	  if(*p) {	  
	    char id = *p++;
	    // skip until '='
	    while(*p && *p != '=') p++;
	    p++;  // skip =
	    if(*p) {
	      // skip all whites
	      while(*p && iswhite(*p)) p++;
	      if(*p) {
		int value = atoi(p);
		printf("var %c = %d\r\n", id, value);
		
		for(int i=0;menu->vars[i].id;i++)
		  if(menu->vars[i].id == id)
		    menu->vars[i].value = value;
	      }
	    }
	  }
	}
	
      }
    }
    f_close(&fil);
  } else {
    printf("Error opening file %s\r\n", settings_file[core_id]);
    sdc_unlock();
    return -1;
  }
  
  sdc_unlock();
  return 0;
}

static void menu_settings_save(menu_t *menu) {
  printf("Write settings\r\n");
  
  sdc_lock();  // get exclusive access to the file system
  
  // saving does not work, yet, as there is no SD card write support by now
  FIL file;
  if(f_open(&file, settings_file[core_id], FA_WRITE | FA_CREATE_ALWAYS) == FR_OK) {
    f_puts("; MiSTeryNano settings\n", &file);

    // write variable values
    f_puts("\n; variables\n", &file);
    for(int i=0;menu->vars[i].id;i++) {
      char str[10];
      sprintf(str, "var %c=%d\n", menu->vars[i].id, menu->vars[i].value);
      f_puts(str, &file);
    }

    // write image file names
    f_puts("\n; image files\n", &file);

    for(int drive=0;drive<MAX_DRIVES;drive++) {
      char *cwd = sdc_get_cwd(drive);
      char *image = sdc_get_image_name(drive);

      if(cwd && image) {
	char str[strlen(cwd) + strlen(image) + 12];
	sprintf(str, "drive%d=%s/%s\n", drive, cwd, image);
	f_puts(str, &file);
      }      
    }
    
    f_puts("\n", &file);
    
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
  memset(&menu, 0, sizeof(menu));

  if(core_id == CORE_ID_ATARI_ST) {
    menu.vars = variables_atari_st;
    menu.forms = forms_atari_st;
  } else if(core_id == CORE_ID_C64) {
    menu.vars = variables_c64;
    menu.forms = forms_c64;
  } else if(core_id == CORE_ID_VIC20) {
    menu.vars = variables_vic20;
    menu.forms = forms_vic20;
  } else if(core_id == CORE_ID_AMIGA) {
    menu.vars = variables_amiga;
    menu.forms = forms_amiga;
  } else {
    menu.vars = NULL;
    menu.forms = NULL;
  }
  
  menu_goto_form(&menu, 0, 1); // first form selected at start
      
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
    if(menu_settings_load(&menu) != 0) {
      // if no settings could be loaded, then set default
      // image names

      if(core_id == CORE_ID_ATARI_ST) {
	static const char *default_names[] = {
	  CARD_MOUNTPOINT "/disk_a.st",
	  CARD_MOUNTPOINT "/disk_b.st",
	  CARD_MOUNTPOINT "/acsi_0.hd",
	  CARD_MOUNTPOINT "/acsi_1.hd" };
	
	for(int drive=0;drive<MAX_DRIVES;drive++)
	  sdc_set_default(drive, default_names[drive]);
      } else if(core_id == CORE_ID_C64) {
    // C64 core
	static const char *c64_default_names[] = {
	  CARD_MOUNTPOINT "/disk8.d64",
	  CARD_MOUNTPOINT "/c64crt.crt",
	  CARD_MOUNTPOINT "/c64prg.prg",
	  CARD_MOUNTPOINT "/c64kernal.bin",
	  CARD_MOUNTPOINT "/c64tap.tap"};

	for(int drive=0;drive<MAX_DRIVES;drive++)
	  sdc_set_default(drive, c64_default_names[drive]);
    } else if(core_id == CORE_ID_VIC20) {
	// VIC20 core
	static const char *vic20_default_names[] = {
	  CARD_MOUNTPOINT "/disk8.d64",
	  CARD_MOUNTPOINT "/vic20crt.crt",
	  CARD_MOUNTPOINT "/vic20prg.prg",
	  CARD_MOUNTPOINT "/vic20kernal.bin",
	  CARD_MOUNTPOINT "/vic20tap.tap"};

	for(int drive=0;drive<MAX_DRIVES;drive++)
	  sdc_set_default(drive, vic20_default_names[drive]);
    } else if(core_id == CORE_ID_AMIGA) {
	// Amiga core
	static const char *amiga_default_names[] = {
	  CARD_MOUNTPOINT "/disk0.adf",
	  CARD_MOUNTPOINT "/disk1.adf",
	  CARD_MOUNTPOINT "/disk2.adf",
	  CARD_MOUNTPOINT "/disk3.adf" };

	for(int drive=0;drive<MAX_DRIVES;drive++)
	  sdc_set_default(drive, amiga_default_names[drive]);
    }
    }
  
  // try to mount (default) images
  for(int drive=0;drive<MAX_DRIVES;drive++) {
    char *name = sdc_get_image_name(drive);
    
    if(name) {
      // create a local copy as sdc_image_open frees its own copy
      char local_name[strlen(name)+1];
      strcpy(local_name, name);
      
      sdc_image_open(drive, local_name);
    }
  }
  } else
    printf("SD wasn't ready, not loading settings\r\n");
   
  // send initial values for all variables
  for(int i=0;menu.vars[i].id;i++)
    sys_set_val(menu.osd->spi, menu.vars[i].id, menu.vars[i].value);

  // release the core's reset, so it can start
  // and cold reset the core, just in case ...
  sys_set_val(menu.osd->spi, 'R', 3);
  sys_set_val(menu.osd->spi, 'R', 0);

  if(core_id == CORE_ID_C64||core_id == CORE_ID_VIC20) {  // c64 core, c1541 reset at power-up
    sys_set_val(menu.osd->spi, 'Z', 1);
    sys_set_val(menu.osd->spi, 'Z', 0);
  }
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
static const char *menu_get_str(menu_t *menu, const char *s, int n) {
  while(n--) {
    s = strchr(s, ',');   // skip n substrings
    if(!s) return NULL;
    s = s + 1;
  }
  return s;
}

// get the n'th char in colon separated string
static char menu_get_chr(menu_t *menu, const char *s, int n) {
  while(n--) {
    s = strchr(s, ',');   // skip n substrings
    if(!s) return '\0';
    s = s + 1;
  }
  return s[0];
}

// get the n'th substring in | separated string in a colon string
static const char *menu_get_substr(menu_t *menu, const char *s, int n, int m) {
  while(n--) {
    s = strchr(s, ',');   // skip n substrings
    if(!s) return NULL;
    s = s + 1;
  }
  
  while(m--) {
    s = strchr(s, '|');   // skip m subsubstrings
    if(!s) return NULL;
    s = s + 1;
  }
  return s;
}
  
static int menu_get_int(menu_t *menu, const char *s, int n) {
  const char *str = menu_get_str(menu, s, n);
  if(!str) return(-1);

  // The string may not be 0 terminated, but rather ; or : terminated.
  // This is fine as atoi stops parsing at the first non-digit
  return atoi(str);
}

static int menu_get_subint(menu_t *menu, const char *s, int n, int m) {
  const char *str = menu_get_substr(menu, s, n, m);
  if(!str) return(-1);
  return atoi(str);
}

static int menu_variable_get(menu_t *menu, const char *s) {
  char id = menu_get_chr(menu, s, MENU_ENTRY_INDEX_VARIABLE);
  if(id == -1) return -1;

  for(int i=0;menu->vars[i].id;i++)
    if(menu->vars[i].id == id)
      return menu->vars[i].value;    

  return -1;
}

static void menu_variable_set(menu_t *menu, const char *s, int val) {
  char id = menu_get_chr(menu, s, MENU_ENTRY_INDEX_VARIABLE);
  if(id == -1) return;
  
  for(int i=0;menu->vars[i].id;i++) {
    if(menu->vars[i].id == id) {
      menu->vars[i].value = val;

      // also set this in the core
      sys_set_val(menu->osd->spi, id, val);

      if(core_id == CORE_ID_ATARI_ST) {      
	// trigger cold reset if memory, chipset or TOS have been changed a
	// video change will also trigger a reset, but that's handled by
	// the ST itself
	if((id == 'C') || (id == 'M') || (id == 'T')) {
	  sys_set_val(menu->osd->spi, 'R', 3);
	  sys_set_val(menu->osd->spi, 'R', 0);
	}
      }
  if(core_id == CORE_ID_C64||core_id == CORE_ID_VIC20){
    // c64 core, trigger core reset if Video mode / PLL changes
    if(id == 'E') {
      sys_set_val(menu->osd->spi, 'R', 3);
      sys_set_val(menu->osd->spi, 'R', 0); }
    // c64 core, trigger c1541 reset in case DOS ROM changed
    if(id == 'D') {  
        sys_set_val(menu->osd->spi, 'Z', 1);
        sys_set_val(menu->osd->spi, 'Z', 0); }
    }
    }
  }
}
  
static int menu_get_options(menu_t *menu, const char *s, int n) {
  // get possible number of values
  int num = 1;
  const char *v = menu_get_str(menu, s, n);
  // count all '|' before next ';', ',' or '\0'
  while(*v && *v != ';' && *v != ',') {
    if(*v == '|') num++;
    v++;
  }
  return num;
}

// various 8x8 icons
const static unsigned char icn_right_bits[]  = { 0x00,0x04,0x0c,0x1c,0x3c,0x1c,0x0c,0x04 };
const static unsigned char icn_left_bits[]   = { 0x00,0x20,0x30,0x38,0x3c,0x38,0x30,0x20 };
const static unsigned char icn_floppy_bits[] = { 0xff,0x81,0x83,0x81,0xbd,0xad,0x6d,0x3f };
const static unsigned char icn_empty_bits[] =  { 0xc3,0xe7,0x7e,0x3c,0x3c,0x7e,0xe7,0xc3 };

void u8g2_DrawStrT(u8g2_t *u8g2, u8g2_uint_t x, u8g2_uint_t y, const char *s) {
  // get length of string
  int n = 0;
  while(s[n] && s[n] != ';' && s[n] != ',' && s[n] != '|') n++;

  // create a 0 terminated copy in the stack
  char buffer[n+1];
  strncpy(buffer, s, n);
  buffer[n] = '\0';
  
  u8g2_DrawStr(u8g2, x, y, buffer);
}

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
  u8g2_DrawStrT(MENU2U8G2(menu), x, 9, menu_get_str(menu, s, 0));
  u8g2_DrawHLine(MENU2U8G2(menu), 0, 13, u8g2_GetDisplayWidth(MENU2U8G2(menu)));

  if(x > 0 && menu->entry == 0)
    u8g2_DrawButtonFrame(MENU2U8G2(menu), 0, 9, U8G2_BTN_INV, u8g2_GetDisplayWidth(MENU2U8G2(menu)), 1, 1);
  
  // draw the rest with normal font
  u8g2_SetFont(MENU2U8G2(menu), font_helvR08_te);
}

static void menu_draw_entry(menu_t *menu, int y, const char *s) {
  const char *buf = menu_get_str(menu, s, MENU_ENTRY_INDEX_LABEL);

  int ypos = 13 + 12 * y;
  int width = u8g2_GetDisplayWidth(MENU2U8G2(menu));

  // all menu entries are a plain text
  u8g2_DrawStrT(MENU2U8G2(menu), 1, ypos, buf);
    
  // prepare highlight
  int hl_x = 0;
  int hl_w = width;
  
  // handle second string for 'L'ist entries
  if(s[0] == 'L') {
    // get variable
    int value = menu_variable_get(menu, s);

    u8g2_DrawStrT(MENU2U8G2(menu), width/2, ypos, 
		  menu_get_substr(menu, s, MENU_ENTRY_INDEX_OPTIONS, value));
		  
    hl_x = width/2;
    hl_w = width/2;
  }
  
  // some entries have a small icon to the right    
  if(s[0] == 'S')
    u8g2_DrawXBM(MENU2U8G2(menu), hl_w-8, ypos-8, 8, 8, icn_right_bits);    
  if(s[0] == 'F') {
    // icon depends if floppy is inserted
    u8g2_DrawXBM(MENU2U8G2(menu), hl_w-9, ypos-8, 8, 8,
	sdc_get_image_name(menu_get_subint(menu, s, 2, 0))?icn_floppy_bits:icn_empty_bits);
  }
  
  if(y+menu->offset == menu->entry)
    u8g2_DrawButtonFrame(MENU2U8G2(menu), hl_x, ypos, U8G2_BTN_INV, hl_w, 1, 1);
}

static const int icon_skip = 10;

static void menu_fs_scroll_entry(menu_t *menu, sdc_dir_entry_t *entry) {
  int row = menu->entry - menu->offset - 1;
  int y =  13 + 12 * (row+1);
  int width = u8g2_GetDisplayWidth(MENU2U8G2(menu));
  int swid = u8g2_GetStrWidth(MENU2U8G2(menu), entry->name) + 1;

  // fill the area where the scrolling entry would show
  u8g2_SetClipWindow(MENU2U8G2(menu), icon_skip, y-9, width, y+12-9);  
  u8g2_DrawBox(MENU2U8G2(menu), icon_skip, y-9, width-icon_skip, 12);
  u8g2_SetDrawColor(MENU2U8G2(menu), 0);
  
  int scroll = menu->fs_scroll_cur++ - 25;   // 25 means 1 sec delay
  if(menu->fs_scroll_cur > swid-width+icon_skip+50) menu->fs_scroll_cur = 0;
  if(scroll < 0) scroll = 0;
  if(scroll > swid-width+icon_skip) scroll = swid-width+icon_skip;
  
  u8g2_DrawStr(MENU2U8G2(menu), icon_skip-scroll, y, entry->name);      

  // restore previous draw mode
  u8g2_SetDrawColor(MENU2U8G2(menu), 1);
  u8g2_SetMaxClipWindow(MENU2U8G2(menu));
  u8g2_SendBuffer(MENU2U8G2(menu));
}

static void menu_fs_draw_entry(menu_t *menu, int row, sdc_dir_entry_t *entry) {      
  static const unsigned char folder_icon[] = { 0x70,0x8e,0xff,0x81,0x81,0x81,0x81,0x7e };
  static const unsigned char up_icon[] =     { 0x04,0x0e,0x1f,0x0e,0xfe,0xfe,0xfe,0x00 };
  static const unsigned char empty_icon[] =  { 0xc3,0xe7,0x7e,0x3c,0x3c,0x7e,0xe7,0xc3 };
  
  char str[strlen(entry->name)+1];
  int y =  13 + 12 * (row+1);

  // ignore leading / used by special entries
  if(entry->name[0] == '/') strcpy(str, entry->name+1);
  else                      strcpy(str, entry->name);
  
  int width = u8g2_GetDisplayWidth(MENU2U8G2(menu));
  
  // properly ellipsize string
  int dotlen = u8g2_GetStrWidth(MENU2U8G2(menu), "...");
  if(u8g2_GetStrWidth(MENU2U8G2(menu), str) > width-icon_skip) {
    // the entry is too long to fit the menu.    
    if(menu->entry == row+menu->offset+1) {
      menu->fs_scroll_cur = 0;
      menu->fs_scroll_entry = entry;
#ifndef SDL
      // enable timer, to allow animations
      xTimerStart(menu->osd->timer, 0);
#endif
    }
    
    while(u8g2_GetStrWidth(MENU2U8G2(menu), str) > width-icon_skip-dotlen) str[strlen(str)-1] = 0;
    if(strlen(str) < sizeof(str)-4) strcat(str, "...");
  }
  u8g2_DrawStr(MENU2U8G2(menu), icon_skip, y, str);      
  
  // draw folder icon in front of directories
  if(entry->is_dir)
    u8g2_DrawXBM(MENU2U8G2(menu), 1, y-8, 8, 8,
		 (entry->name[0] == '/')?empty_icon:
		 strcmp(entry->name, "..")?folder_icon:
		 up_icon);

  if(menu->entry == row+menu->offset+1)
    u8g2_DrawButtonFrame(MENU2U8G2(menu), 0, y, U8G2_BTN_INV, width, 1, 1);     
}

// file selector events
#define FSEL_INIT   0
#define FSEL_DRAW   1
#define FSEL_DOWN   2
#define FSEL_UP     3
#define FSEL_SELECT 4

// process file selector events
static void menu_fileselector(menu_t *menu, int event) {
  static sdc_dir_t *dir = NULL;
  const static char *s;
  static int parent;
  static int drive;
  static const char *exts;
  
  if(event == FSEL_INIT) {
    // init
    s = menu->forms[menu->form];
    for(int i=0;i<menu->entry;i++) s = strchr(s, ';')+1;

    // get extensions
    exts = menu_get_substr(menu, s, 2, 1);

    // scan files
    drive = menu_get_subint(menu, s, 2, 0);
    
    dir = sdc_readdir(drive, NULL, exts);

    menu->entry = 1;               // start by highlighting first file entry
    menu->entries = dir->len + 1;  // incl. title
    menu->offset = 0;
    parent = menu->form;
    menu->form = MENU_FORM_FSEL;

    // try to jump to current file. Get the current image name and path
    char *name = sdc_get_image_name(drive);
    if(name) {
      // try to find name in file list
      for(int i=0;i<dir->len;i++) {
	if(strcmp(dir->files[i].name, name) == 0) {
	  // file found, adjust entry and offset
	  menu->entry = i+1;
	  
	  if(menu->entries > 5 && menu->entry > 3) {
	    if(menu->entry < menu->entries-2) menu->offset = menu->entry - 3;
	    else                              menu->offset = menu->entries-5;
	  }
	}
      }
    }
  } else if(event == FSEL_DRAW) {
    // draw
    menu_draw_title(menu, menu_get_str(menu, s, MENU_ENTRY_INDEX_LABEL));
    
    // draw up to four files
    menu->fs_scroll_entry = NULL;  // assume no scrolling needed
#ifndef SDL
    xTimerStop(menu->osd->timer, 0);
#endif
    
    for(int i=0;i<((dir->len<4)?dir->len:4);i++)
      menu_fs_draw_entry(menu, i, &(dir->files[i+menu->offset]));
  } else if(event == FSEL_SELECT) {

    if(!menu->entry)
      menu_goto_form(menu, parent, 1);
    else {
      sdc_dir_entry_t *entry = &(dir->files[menu->entry - 1]);

      if(entry->is_dir) {
	if(entry->name[0] == '/') {
	  // User selected the "No Disk" entry
	  // Eject it and return to parent menu
	  menu_goto_form(menu, parent, 1);
	  sdc_image_open(drive, NULL);
	} else {	
	  // check if we are going up one dir and try to select the
	  // directory we are coming from
	  char *prev = NULL; 
	  if(strcmp(entry->name, "..") == 0) {
	    prev = strrchr(sdc_get_cwd(drive), '/');
	    if(prev) prev++;
	  }
	  
	  menu->entry = 1;               // start by highlighting '..'
	  menu->offset = 0;
	  dir = sdc_readdir(drive, entry->name, exts);	
	  menu->entries = dir->len + 1;  // incl. title
	  
	  // prev is still valid, since sdc_readdir doesn't free the old string when going
	  // up one directory. Instead it just terminates it in the middle	
	  if(prev) {	
	    // try to find previous dir entry in current dir	  
	    for(int i=0;i<dir->len;i++) {
	      if(dir->files[i].is_dir && strcmp(dir->files[i].name, prev) == 0) {
		// file found, adjust entry and offset
		menu->entry = i+1;
		
		if(menu->entries > 5 && menu->entry > 3) {
		  if(menu->entry < menu->entries-2) menu->offset = menu->entry - 3;
		  else                              menu->offset = menu->entries-5;
		}
	      }
	    }
	  }
	}
      } else {
	// request insertion of this image
	sdc_image_open(drive, entry->name);
	// return to parent form
	menu_goto_form(menu, parent, 1);
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

      // this is a newly opened form and we just determined the number
      // of menu entries. Therefore, adjust the scroll offset if needed
      if(menu->entries > 5 && menu->entry > 3) {
	if(menu->entry < menu->entries-2) menu->offset = menu->entry - 3;
	else                              menu->offset = menu->entries-5;
      }
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
    menu_fileselector(menu, FSEL_DRAW);
  
  u8g2_SendBuffer(MENU2U8G2(menu));
}

static void menu_select(menu_t *menu) {
  if(menu->form == MENU_FORM_FSEL) {
    menu_fileselector(menu, FSEL_SELECT);
    return;
  }
    
  const char *s = menu->forms[menu->form];
  // skip to current entry (incl. title)
  for(int i=0;i<menu->entry;i++) s = strchr(s, ';')+1;
  
  printf("Selected: %s\r\n", s);

  // if the title was selected, then goto parent form
  if(!menu->entry) {
    printf("parent\n");
    menu_goto_form(menu, menu_get_subint(menu, s, 1,0), menu_get_subint(menu, s, 1,1));
    return;
  }
  
  switch(*s) {
  case 'F':
    // user has choosen a file selector
    menu_fileselector(menu, FSEL_INIT);
    break;
    
  case 'S':
    // user has choosen a submenu
    menu_goto_form(menu, menu_get_int(menu, s, MENU_ENTRY_INDEX_FORM), 1);
    break;

  case 'L': {
    // user has choosen a selection list
    int value = menu_variable_get(menu, s) + 1;
    int max_value = menu_get_options(menu, s, MENU_ENTRY_INDEX_OPTIONS)-1;
    if(value > max_value) value = 0;    
    menu_variable_set(menu, s, value);
  } break;

  case 'B': {
    // user has choosen a button
    char id = menu_get_chr(menu, s, 2);
    
    if(id == 'S')
      menu_settings_save(menu);

    // normal reset
    if(id == 'R') {    
      sys_set_val(menu->osd->spi, 'R', 1);
      sys_set_val(menu->osd->spi, 'R', 0);
      osd_enable(menu->osd, OSD_INVISIBLE);  // hide OSD
    }

    // cold boot
    if(id == 'B') {    
      sys_set_val(menu->osd->spi, 'R', 3);
      sys_set_val(menu->osd->spi, 'R', 0);
      osd_enable(menu->osd, OSD_INVISIBLE);  // hide OSD
    }

    // c64 and vic20 core, c1541 reset
    if(id == 'Z') {    
      sys_set_val(menu->osd->spi, 'Z', 1);
      sys_set_val(menu->osd->spi, 'Z', 0);
      osd_enable(menu->osd, OSD_INVISIBLE);  // hide OSD
    }
  } break;
	
  default:
    printf("unknown %c\r\n", *s);    
  }
}

static int menu_entry_is_usable(menu_t *menu) {
  // check if the current entry in the menu is actually selectable
  // (currently only the title of the start form is not)

  // not start form? -> ok
  if(menu->form) return 1;

  return (menu->entry == 0)?0:1;
}

static void menu_entry_go(menu_t *menu, int step) {
  do {
    menu->entry += step;

    // single step wraps top/bottom, paging does not
    if(abs(step) == 1) {    
      if(menu->entry < 0) menu->entry = menu->entries + menu->entry;
      if(menu->entry >= menu->entries) menu->entry = menu->entry - menu->entries;
    } else {
      // limit to top/bottom. Afterwards step 1 in opposite direction to skip unusable entries
      if(menu->entry < 1) { menu->entry = 1; step = 1; }	
      if(menu->entry >= menu->entries) { menu->entry = menu->entries - 1; step = -1; }
    }

    // scrolling needed?
    if(step > 0) {
      if(menu->entries <= 5)                   menu->offset = 0;
      else {
	if(menu->entry <= 3)                   menu->offset = 0;
	else if(menu->entry < menu->entries-2) menu->offset = menu->entry - 3;
	else                                   menu->offset = menu->entries-5;
      }
    }

    if(step < 0) {
      if(menu->entries <= 5)                   menu->offset = 0;
      else {
	if(menu->entry <= 2)                   menu->offset = 0;
	else if(menu->entry < menu->entries-3) menu->offset = menu->entry - 2;
	else                                   menu->offset = menu->entries-5;
      }
    }
    
    // give file selector a chance to adjust scroll
    if(menu->form == MENU_FORM_FSEL)
      menu_fileselector(menu, (step>0)?FSEL_DOWN:FSEL_UP);
    
  } while(!menu_entry_is_usable(menu));
}

void menu_do(menu_t *menu, int event) {
  // -1 is a timer event used to scroll the current file name if it's to long
  // for the OSD
  if(event < 0) {
    if((menu->form == MENU_FORM_FSEL) && (menu->fs_scroll_entry))
      menu_fs_scroll_entry(menu, menu->fs_scroll_entry);
    
    return;
  }
  
  if(event)  {
    if(event == MENU_EVENT_SHOW)   osd_enable(menu->osd, OSD_VISIBLE);
    if(event == MENU_EVENT_HIDE)   osd_enable(menu->osd, OSD_INVISIBLE);
    
    if(event == MENU_EVENT_UP)     menu_entry_go(menu, -1);
    if(event == MENU_EVENT_DOWN)   menu_entry_go(menu,  1);

    if(event == MENU_EVENT_PGUP)   menu_entry_go(menu, -4);
    if(event == MENU_EVENT_PGDOWN) menu_entry_go(menu,  4);

    if(event == MENU_EVENT_SELECT) menu_select(menu);
  }  
  menu_draw_form(menu, menu->forms[menu->form]);
}


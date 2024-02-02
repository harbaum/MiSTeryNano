COMX?=/dev/ttyUSB0
BAUDRATE?=921600

SDK_DEMO_PATH ?= .
BL_SDK_BASE ?= $(SDK_DEMO_PATH)/../../..

CHIP ?= bl616
BOARD ?= bl616dk -DCMAKE_C_FLAGS="-DM0S_DOCK=1"
CROSS_COMPILE ?= riscv64-unknown-elf-

include $(BL_SDK_BASE)/project.build

term:
	term.sh $(COMX) $(BAUDRATE)

FATFS_SRC=$(BL_SDK_BASE)/components/fs/fatfs
SDL_TEST_CFLAGS=-I. -I$(FATFS_SRC) -Iu8g2/csrc `sdl2-config --cflags` -DSDL
SDL_TEST_SRC=u8g2/csrc/*.c u8g2/sys/bitmap/common/*.c u8g2/sys/sdl/common/*.c
FATFS_FILES=$(FATFS_SRC)/ff.c $(FATFS_SRC)/diskio.c $(FATFS_SRC)/ffunicode.c

sdl_menu_test: sdl_menu_test.c menu.c menu.h fatfs_conf_user.h 
	gcc $(SDL_TEST_CFLAGS) -o sdl_menu_test sdl_menu_test.c menu.c $(SDL_TEST_SRC) $(FATFS_FILES) `sdl2-config --libs`

test: sdl_menu_test
	./sdl_menu_test

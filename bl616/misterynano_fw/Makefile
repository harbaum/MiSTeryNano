COMX?=/dev/ttyUSB0
BAUDRATE?=921600

SDK_DEMO_PATH ?= .
BL_SDK_BASE ?= $(SDK_DEMO_PATH)/../../..

export BL_SDK_BASE

CHIP ?= bl616
BOARD ?= bl616dk
CROSS_COMPILE ?= riscv64-unknown-elf-

include $(BL_SDK_BASE)/project.build

splash.c: splash.png Makefile
	convert splash.png -depth 1 GRAY:splash.raw
	bin2c -C splash.c splash.raw

term:
	term.sh $(COMX) $(BAUDRATE)

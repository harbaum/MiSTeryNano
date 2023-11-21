#
# Makefile
#

PRJ=floppy_tb
TOP=floppy_tb

OBJ_DIR=obj_dir

VERILATOR_DIR=/usr/local/share/verilator/include
VERILATOR_FILES=verilated.cpp verilated_vcd_c.cpp verilated_threads.cpp

HDL_FILES = floppy_tb.v sd_fake.v ../../src/misc/sd_card.v ../../src/misc/sdcmd_ctrl.v ../../src/misc/sd_reader.v ../../src/fdc1772/fdc1772.v ../../src/fdc1772/floppy.v

FATFS=../../../../firmware/bouffalo_sdk/components/fs/fatfs

VFLAGS=-CFLAGS "-I.. -I$(FATFS) -fpermissive" -Wno-fatal --trace --trace-max-array 512 --trace-max-width 512

C_FILES=$(FATFS)/ff.c $(FATFS)/diskio.c $(FATFS)/ffunicode.c

all: $(PRJ)

$(PRJ): $(PRJ).cpp ${HDL_FILES} Makefile
	verilator -cc $(VFLAGS) --top-module $(TOP) ${HDL_FILES} $(C_FILES) --exe $(PRJ).cpp -o ../$(PRJ)
	make -j -C ${OBJ_DIR} -f V$(TOP).mk

$(TOP).vcd: $(PRJ) disk_a.st
	./$(PRJ)

wave: $(TOP).vcd
	gtkwave $(TOP).gtkw

clean:
	rm -rf *~ obj_dir $(PRJ) $(TOP).vcd

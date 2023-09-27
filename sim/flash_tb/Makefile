#
# Makefile
#

PRJ=flash_tb
TOP=flash

OBJ_DIR=obj_dir

VERILATOR_DIR=/usr/local/share/verilator/include
VERILATOR_FILES=verilated.cpp verilated_vcd_c.cpp verilated_threads.cpp

HDL_FILES = ../../src/tangnano20k/flash_dspi.v

all: $(PRJ)

$(PRJ): $(PRJ).cpp ${HDL_FILES} Makefile
	verilator -Wno-fatal --trace --top-module $(TOP) -cc ${HDL_FILES} --exe $(PRJ).cpp -o ../$(PRJ)
	make -j -C ${OBJ_DIR} -f V$(TOP).mk

$(TOP).vcd: $(PRJ)
	./$(PRJ)

wave: $(TOP).vcd
	gtkwave $(TOP).gtkw

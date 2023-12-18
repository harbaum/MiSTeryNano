#
# Makefile
#

PRJ=sdc_tb
TOP=sd_rw

OBJ_DIR=obj_dir

VERILATOR_DIR=/usr/local/share/verilator/include
VERILATOR_FILES=verilated.cpp verilated_vcd_c.cpp verilated_threads.cpp

HDL_FILES = ../../src/misc/$(TOP).v ../../src/misc/sdcmd_ctrl.v

VFLAGS=-GSIMULATE=1\'b1 -CFLAGS "-I.. -fpermissive" -Wno-fatal --trace --trace-max-array 512 --trace-max-width 512

all: $(PRJ)

$(PRJ): $(PRJ).cpp ${HDL_FILES} Makefile
	verilator -cc $(VFLAGS) --top-module $(TOP) ${HDL_FILES} $(C_FILES) --exe $(PRJ).cpp -o ../$(PRJ)
	make -j -C ${OBJ_DIR} -f V$(TOP).mk

$(PRJ).vcd: $(PRJ)
	./$(PRJ)

wave: $(PRJ).vcd
	gtkwave $(PRJ).gtkw

clean:
	rm -rf *~ obj_dir $(PRJ) $(PRJ).vcd

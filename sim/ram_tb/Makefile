#
# Makefile
#

PRJ=ste_tb

OBJ_DIR=obj_dir

GSTMCU_DIR=../../src/gstmcu/hdl
GSTMCU_FILES=gstmcu.v clockgen.v mcucontrol.v hsyncgen.v hdegen.v vsyncgen.v vdegen.v vidcnt.v sndcnt.v latch.v register.v modules.v gstshifter.v shifter_video.v shifter_video_async.v

# the original fx68k won't simulate. Thus we use this special version for simulation
FX68K_DIR=../fx68x_verilator
FX68K_FILES= fx68k.sv fx68kAlu.sv uaddrPla.sv fx68k_MicroRom.v fx68k_NanoRom.v

ATARIST_DIR=../../src/atarist
ATARIST_FILES= mfp.v mfp_hbit16.v  mfp_srff16.v mfp_timer.v io_fifo.v acia.v

VERILATOR_DIR=/usr/local/share/verilator/include
VERILATOR_FILES=verilated.cpp verilated_vcd_c.cpp verilated_threads.cpp

HDL_FILES = $(GSTMCU_FILES:%=$(GSTMCU_DIR)/%) $(FX68K_FILES:%=$(FX68K_DIR)/%) $(ATARIST_FILES:%=$(ATARIST_DIR)/%)

all: $(PRJ)

$(PRJ): $(PRJ).v $(PRJ).cpp ${HDL_FILES} Makefile
	verilator -Wno-fatal --trace --threads 4 --top-module $(PRJ) -cc $(PRJ).v ${HDL_FILES} --exe $(PRJ).cpp -o ../$(PRJ)
	make -j -C ${OBJ_DIR} -f V$(PRJ).mk

$(PRJ).vcd: $(PRJ) ram_test.img
	./$(PRJ)

video.rgb: $(PRJ)
	./$(PRJ)

video.png: video.rgb
	rm -f video.png
	ffmpeg -vcodec rawvideo -f rawvideo -pix_fmt rgb444 -s 420x283 -i video.rgb -f image2 -vcodec png video.png  # ST PAL

video: video.png
	display video.png

wave: $(PRJ).vcd
	gtkwave clocks.gtkw

ram_test.img: ram_test.s
	vasmm68k_mot -Fbin ram_test.s -o ram_test.img

flash: ram_test.img
	openFPGALoader --external-flash -o 1048576 ram_test.img

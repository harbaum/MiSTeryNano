#
# Makefile
#

PRJ=ste_tb

OBJ_DIR=obj_dir

GSTMCU_DIR=../../src/gstmcu/hdl
GSTMCU_FILES=gstmcu.v clockgen.v mcucontrol.v hsyncgen.v hdegen.v vsyncgen.v vdegen.v vidcnt.v sndcnt.v latch.v register.v modules.v gstshifter.v shifter_video.v shifter_video_async.v

VERILATOR_DIR=/usr/local/share/verilator/include
VERILATOR_FILES=verilated.cpp verilated_vcd_c.cpp verilated_threads.cpp

HDL_FILES = $(GSTMCU_FILES:%=$(GSTMCU_DIR)/%) ../../src/misc/scandoubler.v ../../src/misc/video_analyzer.v ../../src/tangnano20k/sdram.v ../../src/tangnano20k/flash_dspi.v

all: $(PRJ)

$(PRJ): $(PRJ).v $(PRJ).cpp ${HDL_FILES} Makefile
	verilator -Wno-fatal --trace --top-module $(PRJ) -cc $(PRJ).v ${HDL_FILES} --exe $(PRJ).cpp -o ../$(PRJ)
	make -j -C ${OBJ_DIR} -f V$(PRJ).mk

gstmcu.vcd: $(PRJ)
	./$(PRJ)

wave: gstmcu.vcd
	gtkwave sdram.gtkw 

video: video.png
	display video.png

video.rgb: $(PRJ)
	./$(PRJ)

video.png: video.rgb
	rm -f video.png
# NTSC = 848x484
	@if [ $$(du -b $< | cut -f 1) = 820864 ]; then\
          echo "scandoubled ST NTSC";\
	  ffmpeg -vcodec rawvideo -f rawvideo -pix_fmt rgb444 -s 848x484 -i video.rgb -f image2 -vcodec png video.png;\
	elif [ $$(du -b $< | cut -f 1) = 941824 ]; then\
          echo "scandoubled ST PAL";\
	  ffmpeg -vcodec rawvideo -f rawvideo -pix_fmt rgb444 -s 832x566 -i video.rgb -f image2 -vcodec png video.png;\
	else \
          echo "Unknown format";\
	fi;



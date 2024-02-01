set_device GW2AR-LV18QN88C8/I7 -name GW2AR-18C

add_file src/misterynano.sv
add_file src/atarist/acia.v
add_file src/atarist/acsi.v
add_file src/atarist/atarist.v
add_file src/atarist/dma.v
add_file src/atarist/io_fifo.v
add_file src/atarist/mfp.v
add_file src/atarist/mfp_hbit16.v
add_file src/atarist/mfp_srff16.v
add_file src/atarist/mfp_timer.v
add_file src/atarist/stBlitter.sv
add_file src/atarist/ste_joypad.v
add_file src/atarist/cubase2_dongle.v
add_file src/atarist/cubase3_dongle.v
add_file src/fdc1772/fdc1772.v
add_file src/fdc1772/floppy.v
add_file src/fx68k/fx68k.sv
add_file src/fx68k/fx68kAlu.sv
add_file src/fx68k/uaddrPla.sv
add_file src/gstmcu/hdl/clockgen.v
add_file src/gstmcu/hdl/gstmcu.v
add_file src/gstmcu/hdl/gstshifter.v
add_file src/gstmcu/hdl/hdegen.v
add_file src/gstmcu/hdl/hsyncgen.v
add_file src/gstmcu/hdl/latch.v
add_file src/gstmcu/hdl/mcucontrol.v
add_file src/gstmcu/hdl/modules.v
add_file src/gstmcu/hdl/register.v
add_file src/gstmcu/hdl/shifter_video.v
add_file src/gstmcu/hdl/sndcnt.v
add_file src/gstmcu/hdl/vdegen.v
add_file src/gstmcu/hdl/vidcnt.v
add_file src/gstmcu/hdl/vsyncgen.v
add_file src/hdmi/audio_clock_regeneration_packet.sv
add_file src/hdmi/audio_info_frame.sv
add_file src/hdmi/audio_sample_packet.sv
add_file src/hdmi/auxiliary_video_information_info_frame.sv
add_file src/hdmi/hdmi.sv
add_file src/hdmi/packet_assembler.sv
add_file src/hdmi/packet_picker.sv
add_file src/hdmi/serializer.sv
add_file src/hdmi/source_product_description_info_frame.sv
add_file src/hdmi/tmds_channel.sv
add_file src/ikbd/hd63701/HD63701.v
add_file src/ikbd/hd63701/HD63701_ALU.v
add_file src/ikbd/hd63701/HD63701_CORE.v
add_file src/ikbd/hd63701/HD63701_EXEC.v
add_file src/ikbd/hd63701/HD63701_MCODE.i
add_file src/ikbd/hd63701/HD63701_MCROM.v
add_file src/ikbd/hd63701/HD63701_SEQ.v
add_file src/ikbd/hd63701/HD63701_defs.i
add_file src/ikbd/ikbd.sv
add_file src/ikbd/rom/MCU_BIROM.v
add_file src/jt49/filter/jt49_dcrm.v
add_file src/jt49/filter/jt49_dcrm2.v
add_file src/jt49/filter/jt49_dly.v
add_file src/jt49/filter/jt49_mave.v
add_file src/jt49/jt49.v
add_file src/jt49/jt49_bus.v
add_file src/jt49/jt49_cen.v
add_file src/jt49/jt49_div.v
add_file src/jt49/jt49_eg.v
add_file src/jt49/jt49_exp.v
add_file src/jt49/jt49_noise.v
add_file src/misc/hid.v
add_file src/misc/mcu_spi.v
add_file src/misc/osd_u8g2.v
add_file src/misc/scandoubler.v
add_file src/misc/sd_card.v
add_file src/misc/sd_rw.v
add_file src/misc/sdcmd_ctrl.v
add_file src/misc/sysctrl.v
add_file src/misc/video_analyzer.v
add_file src/tangnano20k/flash_dspi.v
add_file src/tangnano20k/gowin_clkdiv/gowin_clkdiv.v
add_file src/tangnano20k/gowin_dpb/fdc_dpram.v
add_file src/tangnano20k/gowin_dpb/sector_dpram.v
add_file src/tangnano20k/gowin_rpll/flash_pll.v
add_file src/tangnano20k/gowin_rpll/pll_160m.v
add_file src/tangnano20k/sdram.v
add_file src/tangnano20k/top.sv
add_file src/tangnano20k/video.v
add_file src/tangnano20k/video2hdmi.v
add_file src/tangnano20k/ws2812.v
add_file src/tangnano20k/atarist.cst
add_file src/tangnano20k/atarist.sdc
add_file src/fx68k/microrom.mem
add_file src/fx68k/nanorom.mem
add_file src/ikbd/rom/ikbd.hex

set_option -synthesis_tool gowinsynthesis
set_option -output_base_name atarist
set_option -verilog_std sysv2017
set_option -top_module top
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -loading_rate 10000000

run all

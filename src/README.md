# MiSTeryNano FPGA core source code

This is the source code of the FPGA side of the MiSTeryNano project. To be
fully functional this also needs a [MCU with matching firmware](../bl616).

## Build variants

The FPGA core exists in several build variants depending on the FPGA board
to be used and the feature set needed. FPGA variants may e.g. include the
Tang Nano 20K, the Tang Primer 25K or the Tang Mega 138K. Feature sets may
include interface options for e.g. MIDI or a exposed physical printer port
or display variantes for HDMI or an RGB LCD.

Currently supported variants are:

  * ```atari``` - Tang Nano 20K + HDMI + DB9 joystick + MIDI
  * ```atari_lcd``` - Tang Nano 20K + RGB LCD
  * ```atari_parport``` - Tang Nano 20K + HDMI + parallel port
  * ```atari_tp25k``` - Tang Primer 25K + HMDI
  * ```atari_tm138k``` - Tang Mega 138K + HMDI

Some of these variants use the ID and come with config files for the
GoWin IDE (files ending in ```.gprj```), some use TCL based command
line scripts (files ending in ```.tcl```) and some use both.

The ```.gprj``` files can be opened from within the GoWin IDE. The
```.tcl``` files can be given as a parmater to the GoWin shell:

```
$ gw_sh ./build.tcl
```

## Pre-built FPGA cores

Some variants are distributed as [pre-built cores in the
releases](https://github.com/harbaum/MiSTeryNano/releases).

## Related projects

The MiSTeryNano is based on several other projects. These include:

  * [FX68K cycle exact 68000 CPU core](https://github.com/ijor/fx68k)
  * [Verilator compatible version of FX68K](https://github.com/emoon/fx68x_verilator)
  * [GSTMCU Atari ST chipset implementation](https://github.com/gyurco/gstmcu)
  * [MiSTery Atari ST core](https://github.com/gyurco/MiSTery)
  * [JT49 YM2149 sound chip implementation in verilog](https://github.com/jotego/jt49)
  * [SD card reader in verilog](https://github.com/WangXuan95/FPGA-SDcard-Reader)
  * [HDMI video/audio output on an FPGA](https://github.com/hdl-util/hdmi)
  * [Hitachi HD6301/IKBD controller in verilog](https://github.com/harbaum/ikbd)
  * [FDC1772 floppy disk controller in verilog](https://github.com/harbaum/fdc1772-verilator)

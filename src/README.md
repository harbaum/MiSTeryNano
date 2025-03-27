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

  * ```atarist``` - Tang Nano 20K + HDMI + DB9 joystick + MIDI
  * ```atarist_lcd``` - Tang Nano 20K + RGB LCD
  * ```atarist_lcd_hdmi``` - Tang Nano 20K + HDMI but FPGA Companion attached on the same pins as it was on ```atarist_lcd``` option.
  * ```atarist_parport``` - Tang Nano 20K + HDMI + parallel port
  * ```atarist_tp25k``` - Tang Primer 25K + HMDI
  * ```atarist_tm138k``` - Tang Mega 138K + HMDI
  * ```atarist_tc60k``` - Tang Console 60K + HMDI

### ```atarist``` and ```atarist_lcd_hdmi```

This is the regular MiSTeryNano Atari ST implementation as described
elsewhere in this repository.

```atarist_lcd_hdmi``` differs only with FPGA companion pins.

### ```atarist_lcd```

This variant works with the 5inch 800x480 RGB LCD available as an odd-on
to the Tang nano 20K. Since the LCD uses most of the IO signals the
interface to the M0S/BL616/MCU uses different pins. See 
[atarist_lcd.cst](https://github.com/harbaum/MiSTeryNano/blob/main/src/tang/nano20k/atarist_lcd.cst) for the pin mapping.

Audio is output via the Tang Nano 20K audio amplifier.

### ```atarist_parport```

This is an mainly untested variant implementing a printer port instead
of the joystick interface. This can be used to control peripherals meant
to be connected to the Atari ST printer port like e.g. the
[fischertechnik computing interface 30566](https://www.ftcommunity.de/knowhow/computing/computing_interfaces/). Be aware that this likely needs
additional level shifting since the Tang Nano 20k runs its IOs at 3.3 volts
while the centronics printer port was 5 volts.

### ```atarist_tp25k```

This is a variant for the [Tang Primer 25k](https://github.com/harbaum/MiSTeryNano/blob/main/TANG_PRIMER_25K.md).

### ```atarist_tm138k```

This is a variant for the [Tang Mega 138k](https://github.com/harbaum/MiSTeryNano/blob/main/TANG_PRIMER_138K.md).

### ```atarist_tc60k```

This is a variant for the [Tang Console with 60k module](https://github.com/harbaum/MiSTeryNano/blob/main/TANG_CONSOLE_60K.md).

Some of these variants use the IDE and come with config files for the
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

# MiSTeryNano

The MiSTeryNano is a port of the
[MiSTery Atari STE FPGA core](https://github.com/gyurco/MiSTery) to the
[Tang Nano 20k FPGA board](https://wiki.sipeed.com/nano20k).

![MiSTeryNano photo](images/misterynano.jpeg)

## Current state

The MiSTeryNano is a work in progress. Current features are:

  * Atari ST/STE
    * Complete Atari ST/E chipset
    * ST or STE configurable
    * Cycle exact 8 MHz 68000 CPU
    * 4MB RAM, optional 8MB STRAM
    * color and monochrome video via HDMI
    * YM2149 and STE DMA sound via HDMI
    * Blitter
  * Supports most TOS versions
  * Full IKBD implementation
    * Mapped to USB via BL616 MCU
    * Mouse and keyboard via USB
    * Joystick via USB or dedicated IO pins of Tang Nano 20k
  * Floppy disk images
    * Read and write support for drive A: and drive B:
    * Images stored in .ST format on regular FAT/exFAT formatted SD card
  * ACSI harddisks
    * Read and write support for ACSI 0 and 1
    * Tested with AHDI, PP's driver and HDDriver 12.03
    * Images stored in .HD format
  * MIDI
    * Physical MIDI-IN and OUT

## Videos

These videos primarily document the progress during development:

  * [MiSTeryNano #1: Is the Tang Nano 20k the cheapest and smallest Atari ST?](https://www.youtube.com/shorts/qndojsbH9jw)
  * [MiSTeryNano #2: Booting TOS 1.04 for the first time](https://www.youtube.com/shorts/yLxXRR_04UE)
  * [MiSTeryNano #3: We got a rainbow!](https://www.youtube.com/shorts/9wFxQvKtOY8)
  * [MiSTeryNano #4: Drives and Blitter](https://www.youtube.com/shorts/FfL01D0Zg0o)
  * [MiSTeryNano #5: Playing Atari ST Frontier](https://www.youtube.com/shorts/xJHF-LlaHFo)
  * [MiSTeryNano #6: B.I.G. DEMO](https://www.youtube.com/shorts/EXPfdhlpuFI)
  * [MiSTeryNano #7: Tang Nano 20k running Atari ST Oxyd2](https://www.youtube.com/shorts/Ud1P1vE5j84)
  * [MiSTeryNano #8: Atari ST with USB keyboard and touchpad](https://www.youtube.com/shorts/jjps1x1NjhE)
  * [MiSTeryNano #9: Tang Nano 20k as USB host](https://www.youtube.com/shorts/bP5gK3nmv-o)
  * [MiSTeryNano #10: New OSD for the FPGA Atari ST](https://www.youtube.com/shorts/zsHYcolqtpc)
  * [MiSTeryNano #11: Advanced SD card for FPGA Atari ST](https://www.youtube.com/shorts/NP1EnRj4Fk0)
  * [MiSTeryNano #12: Atari ST first boot from virtual hard disk](https://www.youtube.com/shorts/UPiLkYA_o0o)
  * [MiSTeryNano #13: MiSTeryNano #13: Atari ST in Tang Nano 20k FPGA running Cubase 3 from Harddisk image](https://youtube.com/shorts/o6ABtje7zZ8)
  
## Getting started

In order to use the MiSTeryNano the following things are needed:

  * [Tang Nano 20k FPGA board](https://wiki.sipeed.com/nano20k) to run the MiSTeryNano core
  * [M0S Dock](https://wiki.sipeed.com/hardware/en/maixzero/m0s/m0s.html) to connect USB keyboard and mouse
  * a breadboard to wire everything up
  * some jumper wires
  * a USB-C to USB-A adapter to connect regular USB devices to the M0S Dock

![MiSTeryNano breadboard](images/misterynano_bb.jpeg)

## Installation

The installation of MiSTeryNano on the Tang Nano 20k using a Linux PC is described
[here](INSTALLATION_LINUX.md). Instructions for Windows will follow later.

#### Changing the floppy disk image

You can use the on-screen-display (OSD) to change disk images. The F12
key will open the on screen display.

### Wiring

Since version 1.2.3 the MiSTeryNano exposes physical
MIDI IN and OUT to be used with appropriate interfacing
(output driver + resistors, input via optocoupler).

A digital DB9 joystick can be attached directly to the board.

![MiSTeryNano wiring](images/wiring_spi_midi.png)


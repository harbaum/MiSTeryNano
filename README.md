# MiSTeryNano

The MiSTeryNano is a port of the
[MiSTery Atari STE FPGA core](https://github.com/gyurco/MiSTery) to the
[Tang Nano 20k FPGA board](https://wiki.sipeed.com/nano20k).

![MiSTeryNano photo](images/misterynano.jpeg)

## Current state

The MiSTeryNano is a work in progress. Current features are:

  * Atari ST
    * Complete Atari ST chipset
    * Cycle exact 8 MHz 68000 CPU
    * 4MB RAM
    * PAL color video via HDMI
    * YM2149 sound via HDMI
    * Blitter
  * Supports 192k PAL TOS
    * Tested with german TOS 1.04
  * Mouse via IO pins of Tang Nano
    * Full IKBD implementation
  * Single floppy disk image directly mapped to SD card

## Missing features

  * Support for keyboards
  * Support for NTSC color and monochrome video
  * Support for multiple ST floppy disk images stored on FAT formatted SD cards
  * User interface (OSD)
  * Full STE chipset support
  * Support for 8 MBytes RAM as available on the Tang Nano 20k
  * Floppy disk write support

Currently the FPGA on the Tang Nano 20k is already 70% full. It may thus
not be possible to add all missing features.

## Getting started

MiSTeryNano has been developed and tested under Linux. Thus the following
explanations expect a Linux system to be used. The installation consists
of three steps:

### Installation of the core

Use openFPGAloader install the MiSTeryNano core named ```atarist.fs```
on your Tang Nano 20k:

```
$ openFPGALoader -f impl/pnr/atarist.fs 
write to flash
Jtag frequency : requested 6.00MHz   -> real 6.00MHz  
Parse file Parse ../atarist/impl/pnr/atarist.fs: 
Done
DONE
Jtag frequency : requested 2.50MHz   -> real 2.00MHz  
Jtag frequency : requested 10.00MHz  -> real 6.00MHz  
erase SRAM Done
Detected: Winbond W25Q64 128 sectors size: 64Mb
Detected: Winbond W25Q64 128 sectors size: 64Mb
RDSR : 00
WIP  : 0
WEL  : 0
BP   : 0
TB   : 0
SRWD : 0
00000000 00000000 00000000 00
Erasing: [==================================================] 100.00%
Done
Writing: [==================================================] 100.00%
Done
```

### Installation of the TOS image

Currently only 192k TOS images (TOS 1.00 - TOS 1.04) are supported.
Also the HDMI video signal generation needs a PAL TOS. Currently
only the german TOS 1.04 has been tested. This needs to be flashed
into the flash ROM of the Tang Nano 20k at 1MB offset:

```
$ openFPGALoader --external-flash -o 1048576 tos104de.img
write to flash
Jtag frequency : requested 6.00MHz   -> real 6.00MHz  
Parse file DONE
Jtag frequency : requested 2.50MHz   -> real 2.00MHz  
Jtag frequency : requested 10.00MHz  -> real 6.00MHz  
erase SRAM Done
Detected: Winbond W25Q64 128 sectors size: 64Mb
Detected: Winbond W25Q64 128 sectors size: 64Mb
RDSR : 00
WIP  : 0
WEL  : 0
BP   : 0
TB   : 0
SRWD : 0
00100000 00000000 00000000 00
Erasing: [==================================================] 100.00%
Done
Writing: [==================================================] 100.00%
Done
```

Now the MiSTeryNano should already boot into the TOS desktop.

### Installation of a floppy disk image

Currently, the MiSTeryNano core only supports a single 720k (737280 bytes)
ST floppy disk image to be stored directly on SD card. This can e.g.
directly been dd'd to the raw disk image assuming e.g. your SD card reader
shows up as ```/dev/sdb```:

```
sudo dd if=disk_a.st of=/dev/sdb
1440+0 records in
1440+0 records out
737280 bytes (737 kB, 720 KiB) copied, 0,202815 s, 3,6 MB/s
```

This SD card can directly be inserted into slot on the bottom side
of the Tang Nano 20k and will be read by the MiSTeryNano.

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
    * PAL and NTSC color video via HDMI
    * YM2149 sound via HDMI
    * Blitter
  * Supports most TOS
    * Tested with german TOS 1.04, german TOS 2.06 and US TOS 1.00
  * Mouse via IO pins of Tang Nano
    * Full IKBD implementation
  * Single floppy disk image stored on regular FAT formatted SD card
    * Tested with 16 GB cards only

## Missing features

  * Support for keyboards
  * Support for monochrome video
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

Use [openFPGAloader](https://github.com/trabucayre/openFPGALoader) to install the MiSTeryNano core named [```atarist.fs```](https://github.com/harbaum/MiSTeryNano/releases) on your Tang Nano 20k:

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

Most TOS images should be supported by now. This has been tested with
US TOS 1.00 (60 Hz NTSC video) and german TOS 1.04 and TOS 2.06 (both
50 Hz PAL video).

This needs to be flashed into the flash ROM of the Tang Nano 20k at
1MB offset:

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

Since releae 0.9.0 MiSTeryNano supports reading floppy disk images from
a FAT formatted SD card. This has only been tested with 16GB cards.
Especially smaller cards may not work if the FAT file system uses less
then 16 sectors per cluster.

This SD card is then inserted into the slot on the bottom side of the
Tang Nano 20k inconveniently placed right below the USB connector.
The MiSTeryNano will automatically load a file named ```disk_a.st```
and use it as the image for floppy disk drive A.

### Using the mouse

The MiSTeryNano currently implements some basic mouse control via
five digital direction inputs on the Tang Nano 20k which need to be
switched to GND.

![MiSTeryNano wiring](images/wiring.png)

Alternally a [Blackberry
Trackball](https://www.sparkfun.com/products/retired/13169) can be
used on the same pins. In this case the ```TRACKB``` config switch
needs to be closed.

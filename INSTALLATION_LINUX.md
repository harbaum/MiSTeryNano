# Installation using a Linux PC

MiSTeryNano has been developed and tested under Linux. Thus the following
explanations expect a Linux system to be used. The installation consists
of four steps:

### Step 1: Installation of the core

Use [openFPGAloader](https://github.com/trabucayre/openFPGALoader) to install the MiSTeryNano core named [```atarist.fs```](https://github.com/harbaum/MiSTeryNano/releases) on your Tang Nano 20k:

```
$ openFPGALoader -f atarist.fs 
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

### Step 2: Installation of the TOS image(s)

Most [TOS images](https://www.atariworld.org/tos-rom/) should be
supported by now. This has been tested with US TOS 1.00 (60 Hz NTSC
video) and german TOS 1.04, TOS 1.62 and TOS 2.06 (all 50 Hz PAL
video).

This needs to be flashed into the flash ROM of the Tang Nano 20k at
1MB (1048576/0x100000 bytes) offset:

```
$ openFPGALoader --external-flash -o 0x100000 tos104de.img
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

Now the MiSTeryNano should already boot into the TOS desktop in ST mode.

For STE mode a STE capable TOS needs to be flashed to a different flash
location:

```
$ openFPGALoader --external-flash -o 0x140000 tos162de.img
```

This TOS image is always use when STE mode is selected.

For ST as well as STE an alternate TOS slot can be selected
in the OSD. The addresses for all TOS are:

| Address | TOS slot  |
|---------|-----------|
| 0x100000 | Primary ST TOS |
| 0x140000 | Primary STE TOS |
| 0x180000 | Secondary ST TOS |
| 0x1c0000 | Secondary STE TOS |

### Step 3: Installation of the MCU firmware

Releases V1.2.0 and later of MiSTeryNano expects a [M0S
Dock](https://wiki.sipeed.com/hardware/en/maixzero/m0s/m0s.html) to be
used for USB connectivity and system control. The
```misterynano_fw_bl616_cfg.ini``` and ```misterynano_fw_bl616.bin```
files from the [release
page](https://github.com/harbaum/MiSTeryNano/releases) contain the
firmware for the M0S Dock.

Use the graphical [BLFlashCube
too](https://github.com/bouffalolab/bouffalo_sdk/tree/master/tools/bflb_tools/bouffalo_flash_cube)
to flash the firmware onto the M0S Dock using these steps:

  * Unconnect the M0S from USB
  * Press the button labeled "BOOT" and keep it pressed
  * Connect the M0S to the PCs USB
  * Release the boot button (the M0S/BL616 will now be in "update" mode)
  * Open the bouffalo_flash_cube
  * Select ```misterynano_fw_bl616_cfg.ini``` as the config file using the Browse button
  * Select the correct COM port under "Port/SN"
  * Hit download, wait for completion
  * Unplug the M0S from USB and connect it to the Tang Nano 20k as depicted below

A USB keyboard and mouse can now be connected to the [M0S
Dock](https://wiki.sipeed.com/hardware/en/maixzero/m0s/m0s.html). Besides
the power LED on the M0S, two further LEDs should light up to indicate
that a keyboard and a mouse have been detected.

At this point mouse and keyboard should be working and you should be
able to use the F12 key to open the on-screen-display (OSD) to control
the core.

Look [here](firmware) for more info about the firmware.

### Step 4: Installation of a floppy disk image

Since releae 0.9.0 MiSTeryNano supports reading floppy disk images from
a FAT formatted SD card.

At least a file named [```DISK_A.ST```](sim/floppy_tb/disk_a.st) needs to be placed in the root
directory of the SD card. This file is by default used as a disk image
for floppy drive A. Further .ST disk images can be placed on the card
using subdirectories if needed.

The SD card is to be inserted into the slot on the bottom side of the
Tang Nano 20k inconveniently placed right below the USB connector.
The MiSTeryNano will initially try to automatically load a file named [```DISK_A.ST```](sim/floppy_tb/disk_a.st) and use it as the image for floppy disk drive A. The disk images to be used can later be changed using the On-Screen-Display (OSD).

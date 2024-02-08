# Installation using a Windows PC

This document explains how to install all the necessary files on the
Tang Nano 20K and the M0S Dock in order to use it as a MiSTeryNano
device.

This has been tested on Windows 11. It should work on older versions too.

Software needed:

  - [Gowin V1.9.9 Beta-4 Education](https://www.gowinsemi.com/en/support/home/) **to flash the FPGA or to synthesize the core**
  - [BouffaloLabDevCube](https://dev.bouffalolab.com/download) **to flash the BL616**
  - [TOS version for ST](https://www.atariworld.org/tos-rom/) (TOS 1.04 preferred)
  - TOS version for STE (TOS 1.62 preferred)
  - [Latest release](https://github.com/harbaum/MiSTeryNano/releases/latest) of MiSTeryNano

In order to use the SD card for disks and harddisk:

  - Atari floppy disk images in .ST format
  - An Atari harddisk file

# Flashing the Tang Nano 20k

First download the Gowin IDE. The Education version is sufficient and
won't need a licence.

Install the IDE on your system (follow the installation instructions
from Gowin).  After the Installation you should have it as an shortcut
on your desktop or in your start menu.

 - Press the ```S2``` button on the Tang Nano 20K and keep it pressed
 - Connect the Tang Nano 20k to the USB on your computer. You should hear the connecting sound of Windows.
 - Release the ```S2``` button
 - Start Gowin. **You should see the following screen**

Explanation: The MiSTerNano core makes use of the flash memory of the
Tang Nano 20k to store TOS ROMs. This may interfere with the FPGA
flash process. Pressing the ```S2``` during power up will prevent the
Tang Nano 20k from booting into the MiSTeryNano core and will make sure
the flash ROM can be updated.

![](https://github.com/harbaum/MiSTeryNano/blob/main/images/gowin1.jpg)

Now press on the “programmer” marked red on the picture above. **You
should see following screen:**

![](https://github.com/harbaum/MiSTeryNano/blob/main/images/device.png)

-   Press save on the dialog
-   From there you can add a device for programming by pressing on the little
    icon with the green plus
-   At least three files have to be flashed:
    - The core itself: ```atarist.fs```
    - Two TOS ROMs
-   Than you can choose from the drop downs the parameter you see on the
    pictures.

**Important**:

  - ```atarist.fs``` is written to address 0x000000
  - ```ST TOS (e.g. TOS 1.04)``` is written to address 0x100000
  - ```STE TOS (e.g. TOS 1.62)``` is written to address 0x140000

Optionally two additional TOS ROMs may be flashed to the alternate
addresses:

  - A secondary ```ST TOS (e.g. TOS 2.06)``` is written to address 0x180000
  - A secondary ```STE TOS (e.g. TOS 2.06)``` is written to address 0x1C0000

These secondary TOS' can later be selected from the on-screen-display (OSD).
Their use and installation is optional.

![](https://github.com/harbaum/MiSTeryNano/blob/main/images/flash_tos_104.png)

![](https://github.com/harbaum/MiSTeryNano/blob/main/images/flash_tos_206.png)

  - For the FS file please choose the ```atarist.fs``` you just downloaded
  - For the TOS files you have to rename the downloaded TOS roms to tosxxx.bin
  - User Code and IDCODE can be ignored
  - Mark each of your configs and press the little icon with the green play
    button. You should see a progress bar and then:

![](https://github.com/harbaum/MiSTeryNano/blob/main/images/flash_success.png)

**That´s it for the Tang Nano 20**

## Flashing the BL616

For the BL616 you have to extract and start the BuffaloLabDevCube. 

**If you use the internal BL616 present on the Tang Nano 20K you loose
your possibility to flash the Tang over the USB connection.** It is thus
strongly recommended to use an external BL616 (e.g. a M0S Dock).

However, when using the internal BL616 you will be able to flash the
[original firmware](https://github.com/harbaum/MiSTeryNano/tree/main/bl616/friend_20k)
to the internal BL616 again to restore the flasher functionality of
the Tang Nano 20K. Using an external M0S is nevertheless recommended.

-   Press the ```BOOT``` button on your M0S Dock before you plug the USB connection
    on your PC. You should hear the hardware detecting sound.
-   Start the BuffaloLabDevCube from the directory where you decompressed it it
    ask you what chip should be used. Select BL616/BL618 and press “finish”

![](https://github.com/harbaum/MiSTeryNano/blob/main/images/buffstart.png)

- You'll now see the program screen. On the right it should auto detect your
  device with a COM port. If not take a look in the device manager to check for
  the correct device detection.
- On the top click on MCU and browse to the firmware image file named
  ```misterynano_fw_bl616.bin```
- Choose “Open Uart” and than press “Create & Download”. The firmware should now be
  flashed

![](https://github.com/harbaum/MiSTeryNano/blob/main/images/bufffinish.png)

## Prepare the SD card

Format the SD card in FAT32. Copy your ST files and hard disk files on
it. You can organize your files in subdirectories. These files can later
be selected using the MiSTerNano on-screen-display (OSD).

That´s it for now. Have fun using the MiSTery Nano

# Installation using a Windows PC

This has been tested on Windows 11. It should work on older versions too.

Software needed:

  - [Gowin V1.9.9 Beta-4 Education](https://www.gowinsemi.com/en/support/home/) **to flash the FPGA or to synthesize the core**
  - [BouffaloLabDevCube](https://dev.bouffalolab.com/download) **to flash the BL616**
  - TOS version for ST
  - TOS version for STE
  - [Latest release](https://github.com/harbaum/MiSTeryNano/releases/latest) of MiSTeryNano

In order to use the SD card for disks and harddisk:

  - Atari floppy disk images in .ST format
  - An Atari harddisk file

# Flashing the Tang Nano 20k

First download the Gowin IDE. The Education version is sufficient
and won't need a licence.

Install the IDE on your system (follow the installation instructions from Gowin).
After the Installation you should have it as an shortcut on your desktop or in
your start menu.

 - Connect the Tang Nano 20k to the USB on your computer. You should hear the connecting sound of Windows.
 - Start Gowin. **You should see the following screen**

![](https://github.com/dna2496/MiSTeryNano/blob/main/images/gowin1.jpg)

I will only explain the programming not the compiling so:

 - please press on the “programmer” marked red on the picture above. **You
   should see following screen:**

![](https://github.com/dna2496/MiSTeryNano/blob/main/images/device.png)

-   press save on the dialog
-   from there you can add a device for programming by pressing on the little
    icon with the green plus
-   we need three one for the atarist.fs and two for the tos files.
-   than you can choose from the drop downs the parameter you see on the
    pictures.

**NOTE:**

  - **atarist.fs must be written to 0x000000**
  - **ST TOS (e.g. 1.04) must be written to 0x10000**
  - **STE TOS (e.g. 2.06) mut be written to 0x140000**

![](https://github.com/dna2496/MiSTeryNano/blob/main/images/flash_tos_104.png)

![](https://github.com/dna2496/MiSTeryNano/blob/main/images/flash_tos_206.png)

  - for the FS File please choose the one you downloaded from the git named “atarist.fs” on your harddisk
  - for the tos files you have to rename the downloaded TOS roms to tosxxx.bin
  - User Code and IDCODE can be ignored
  - mark each of your configs and press the little icon with the green play
    button. You should see a progress bar and than:

![](https://github.com/dna2496/MiSTeryNano/blob/main/images/flash_success.png)

**That´s it for the Tang Nano 20**

## Flashing the BL616

For the BL616 you have to extract and start the BuffaloLabDevCube. 

If you use the internal BL616 present on the Tang Nano 20K you loose
your possibility to flash the Tang over the USB connection. It is thus
recommended to use an external BL616 (e.g. a M0S Dock).

Using the internal BL616 You will be able to flash the [original
firmware](https://github.com/harbaum/MiSTeryNano/tree/main/bl616/friend_20k)
to the internal BL616 again to restore the flasher functionality of
the Tang Nano 20K.

-   Press the boot button on your BL616 board before you plug the USB connection
    on your PC. You should hear the hardware detecting sound.
-   Start the BuffaloLabDevCube from the directory where you decompressed it it
    ask you what chip should be used. Take the BL616/BL618 and press “finish”

![](https://github.com/dna2496/MiSTeryNano/blob/main/images/buffstart.png)

-   Than you see the program screen. on the right it should auto detect your
    device with a com port. If not take a look in the device manager to see
    whats wrong.
-   Klick on MCU on the top and only Browse at image file for your
    “misterynano_fw_bl616.bin”
-   Choose “Open Uart” and than press “Create & Download” the firmware should be
    updated

![](https://github.com/dna2496/MiSTeryNano/blob/main/images/bufffinish.png)

## Prepare the SD card

Format the SD card in fat or fat32 for larger files. Copy your ST files and hard
disk files on it.

That´s it for now. Have fun using the MiSTery Nano

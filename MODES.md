# MiSTeryNano operation modes

This description explains the way the on-board BL616 MCU and the FPGA
on the Tang Nano 20k cooperate when both being used for the
MiSTeryNano setup. This is not the case if a seperate M0S Dock is
installed providing a second BL616 MCU.

In order to be able to setup the MiSTeryNano on the Tang Nano 20k
without an additional MCU and to be able to update it later, three
fundamental operation modes are needed:

  * Normal mode:
    * The FPGA runs the Atari ST core
    * The BL616 runs the MiSTeryNano firmware
    * The Tang Nano 20k USB is connected to peripherals (keyboard, mouse)
  * MCU update mode:
    * The FPGAs state is unimportant
    * The MCU is in bootloader mode and can be updated
    * The Tang Nano 20k USB is connected to a PC
  * FPGA update mode:
    * The FPGAs state is unimportant
    * The MCU is in flasher mode and can update the FPGA and its flash
    * The Tang Nano 20k USB is connected to a PC

## Initial flashing

In factory state the MCU on the Tang Nano 20k comes with a flasher
firmware pre-installed and the device is bascially permanently in
"FPGA update mode". In this mode the FPGA can be flashed with the
MiSTeryNano core like with any other core. In this mode the Tang Nano
20k identifies itself on USB to the PC as "20K's FRIEND".

To get into "MCU update mode" the UPDATE button on the Tang Nano 20k
has to be pressed during power up. The FPGA will still boot normal and
runs its core but the MCU will go into self-update-mode and can be
flashed using the [tools from the bouffalo SDK](https://github.com/bouffalolab/bouffalo_sdk/tree/master/tools/bflb_tools/bouffalo_flash_cube). In
this mode the Tang Nano 20k identifies itself on USB to the PC as
"Bouffalo CDC DEMO". This mode can be used to update the MCU with a
version of the MiSTeryNano firmware that is suited to run on the
on-board BL616 MCU (in contrast to e.g. a version meant to run on an
externally connected M0S Dock).

Once FPGA and MCU have been flashed the board can be power-cycled and will
go into "Normal mode". It will not act as a USB device, anymore, even if
connected to a PC. Instead it waits for peripherals like keyboards and
mice to be connected to it's USB port. Neither the MCU nor the FPGA can
be flashed or uodated in this mode.

## Flashing with MiSTeryNano firmware installed

Since the MCU acts as a USB host by default with the MiSTeryNano firmware
installed it doesn't show up as a device when connected to a PC via USB.
Hence it cannot be flashed from a PC.

Flashing the MCU is however still possible as the MCU can still be
brought into its normal update mode by pressing and holding the UPDATE
button during power up. The MCU can then be flashed with the default
"20K's FRIEND" factory firmware. Once that's done, the FPGA can
subsequently be updated. Finally the MCU can be flashed with the
MiSTeryNano firmware again, so both, the MCU and the FPGA are
updated. However, this approach is rather cumbersome. Luckily there is
a simpler solution for this.

The MiSTeryNano firmware includes part of the original "20K's FRIEND"
firmware. These parts only allow FPGA flashing and don't include other
functions like the PLL configuration or UART or SPI redirection. In the
"Normal mode" this built-in flashing capability is not being activated.

There are two ways to activate the FPGA flasher and bring the Tang Nano
20k into "FPGA update mode" with the MiSTeryNano firmware installed:

  * It takes about 4 seconds for the FPGA to boot into the core. The
    MCU waits for the FPGA to start communicating during this time. If
    the UPDATE button on the Tang Nano 20k is pressed during the
    initial 5 seconds, then the MCU will enter "FPGA update
    mode". Please be aware that you must not press the UPDATE button
    during power-on as that will activate the MCUs own update
    mechanism as described above. Instead start pressing it a second
    after power-on and keep it pressed for five further seconds. Once
    successful the MCU then will instruct the FPGA to switch its RGB
    led to yellow to reflect that the board has successfully entered
    "FPGA update mode".
  
  * The MCU checks at boot time for a valid MiSTeryNano core to be installed
    on the FPGA. If the FPGA does not become available within 5 seconds after
    power in, then the MCU will enter "FPGA update mode". However, if a working
    MiSTeryNano core is installed then the MCU will stay in "Normal mode".
    The FPGA can be tricked in not booting properly by pressing the S1 and S2
    buttons during power-up. This will prevent a proper initialization of the
    FPGA and thus trigger the boot timeout of the MCU and in turn cause
    it to enter "FPGA update mode". The FPGA's leds will not reflect this as
    the FPGA has not booted properly. Stil it can be updated.

Once in "FPGA update mode" the Tang Nano 20k should show up as a USB
device on the PC and it can be used to update the FPGA as usual. After the
next power-cycle the MCU will return into "Normal mode".

## Summary

The tree operation modes of a MiSTeryNano installation can be reached
using the UPDATE button on the Tang Nano 20k:

  * Without the button pressed the MiSTeryNano will boot the FPGA
    and the on-board BL616 MCU into the normal use mode.
  * With the UPDATE button pressed during power-on the MCU will
    go into update mode and the MCU can be flashed from a PC
    via USB.
  * The UPDATE button pressed ~1 second _after_ power on for
    five further seconds the MCU will go into FPGA update mode
    and the FPGA can be flashed from a PC via USB.

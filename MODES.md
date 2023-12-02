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

This document descibes how the different operating mode of the MiSTeryNano
are used to flash and update the FPGA and the on-board MCU of the Tang
Nano 20k. The tools needed on PC side differ between the different PC
operating systems. This is not covered in this document as it only
describes the Tang Nano 20k related parts. TODO: Link to Linux
and Windows tools.

## Initial flashing

In factory state the MCU on the Tang Nano 20k comes with a flasher
firmware pre-installed and the device is bascially permanently in
"FPGA update mode".

### Initially flashing the FPGA

In this mode the FPGA can be flashed with the MiSTeryNano core like
with any other core. In this mode the Tang Nano 20k identifies itself
on USB to the PC as "20K's FRIEND".

Be aware that the MiSTeryNano makes extensive use of the FPGAs
capabilities.  Some of these may have an effect on future FPGA update
attempts, some sure have. One reason is that the MiSTeryNano itself
makes use of the FPGAs own flash memory to store ROM images (e.g. TOS
ROMS for the Atari ST).  The MiSTeryNano therefore configures the
flash memory for fast DSPI access.  Unfortunately the Gowin programmer
sometimes struggles to program flash memory in DSPI mode. Furthermore,
the core needs to disable the FPGAs JTAG interface to be able to use
the JTAG signals for its own purposes.  This prevents further updates
as these are supposed to happen using JTAG.

The solution for both problems is to supporess the booting of the
FPGA. This can be achieved by pressing and holding the ```S2``` button
during power-on. This temperarily changes the FPGA boot mode in a way
that prevents loading of a core from flash. As a result the FPGA can
be updated from the PC as usual.

### Initially flashing the BL616 MCU

To get into "MCU update mode" the ```UPDATE``` button on the Tang Nano
20k has to be pressed during power up. The FPGA will still boot normal
and runs its core but the MCU will go into self-update-mode and can be
flashed using the [tools from the bouffalo SDK](https://github.com/bouffalolab/bouffalo_sdk/tree/master/tools/bflb_tools/bouffalo_flash_cube). In
this mode the Tang Nano 20k identifies itself on USB to the PC as
"Bouffalo CDC DEMO". This mode can be used to update the MCU with a
version of the MiSTeryNano firmware that is suited to run on the
on-board BL616 MCU (in contrast to e.g. a version meant to run on an
externally connected M0S Dock).

Once FPGA and MCU have been flashed the board can be power-cycled and
will go into "Normal mode". It will not act as a USB device, anymore,
even if connected to a PC. Instead it waits for peripherals like
keyboards and mice to be connected to it's USB port. Neither the MCU
nor the FPGA can be flashed or updated in this mode.

## Flashing with MiSTeryNano firmware installed

Since the MCU acts as a USB host by default with the MiSTeryNano
firmware installed it doesn't show up as a device when connected to a
PC via USB.  Hence it cannot be flashed from a PC.

Flashing the MCU is however still possible as the MCU can still be
brought into its normal update mode by pressing and holding the
```UPDATE``` button during power up. The MCU can then be flashed with
the default "20K's FRIEND" factory firmware. Once that's done, the
FPGA can subsequently be updated. Finally the MCU can be flashed with
the MiSTeryNano firmware again, so both, the MCU and the FPGA are
updated. However, this approach is rather cumbersome. Luckily there is
a simpler solution for this.

The MiSTeryNano firmware includes part of the original "20K's FRIEND"
firmware. These parts only allow FPGA flashing and don't include other
functions like the PLL configuration or UART or SPI redirection. In the
"Normal mode" this built-in flashing capability is not being activated.
 
The MCU checks at boot time for a valid MiSTeryNano core to be
installed on the FPGA. If the FPGA does not become available within 5
seconds after power in, then the MCU will enter "FPGA update
mode". However, if a working MiSTeryNano core is installed then the
MCU will stay in "Normal mode".

As already explained, a fully functional MiSTeryNano FPGA core doesn't
allow itself to be updated easily as for proper operation it needs to
switch the SPI flash into a mode that isn't suited for updating and
also the JTAG needed for flashing/updating needs to be disabled at
runtime. To circumvent these, the Tang Nano 20k needs to be powered up
with the ```S2``` button pressed. This changes the FPGA boot sequence
in a wait that prevents loading of the core from flash. As a
consequence, the FPGA will not boot into the MiSTeryNano core and SPI
flash as well as JTAG are fully operational. Thus the MCU will time
out when trying to access the MiSTerNano core inside the FPGA and
enter "FPGA update mode".

Once in "FPGA update mode" the Tang Nano 20k should show up as a USB
device on the PC and it can be used to update the FPGA as usual. After
the next power-cycle the MCU will return into "Normal mode".

## Summary

The tree operation modes of a MiSTeryNano installation can be reached
using the buttons on the Tang Nano 20k:

  * Without the button pressed the MiSTeryNano will boot the FPGA
    and the on-board BL616 MCU into the normal use mode.
  * With the ```UPDATE``` button pressed during power-on the MCU will
    go into update mode and the MCU can be flashed from a PC
    via USB.
  * With the S2 button  pressed during power-on the FPGA will
    not boot and the MCU will go into FPGA update mode.
    The FPGA can then be flashed from a PC via USB.

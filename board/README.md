# MiSTeryNano board

The MiSTeryNano can be used with off-the-shelf components and
some breadboard setup.

To simplify this the MiSTeryNano project provides additional
hardware:

  - The [MiSTeryShield20k](misteryshield20k) is a base board for
  the Tang Nano 20k and the M0S Dock with a DB9 joystick connector and
  MIDI ports

  - The [MiSTeryShield20k lite](misteryshield20k_lite) is also a base
  board for the Tang Nano 20k. It includes the RP2040 and a USB-A
  port and is a minimal all-in-one solution for the Tang Nano 20k.

  - The [M0S PMOD](m0s_pmod) allows to use the M0S Dock on a PMOD
  port as e.g. available on the Tang Primer 25K or the Tang Mega 138K

  - The [Keyboard](keyboard) design is a tiny 50% Atari ST style keyboard which is meant to become the basis for a Mini Atari ST

  - The [T20 PMOD](t20_pmod) is an add-on for the Efinix T20BGA256 development board adding a PMOD for HDMI usage, the SD card slot and a Raspberry Pi PICO incl. USB-A header to it making it a complete MiSTeryNano setup.

## Related projects

Further hardware is available in related projects:

  - [MiSTeryShield20k RPiPico](https://github.com/vossstef/tang_nano_20k_c64/tree/main/board/misteryshield20k_rpipico) is a board similar to the [MiSTeryShield20k](misteryshield20k) but using a Raspberry Pi Pico instead of the M0S Dock and with a USB hub already built-in

  - [PMOD PiZero](https://github.com/vossstef/tang_nano_20k_c64/tree/main/board/pizero_pmod) us a board similar to the [M0S PMOD](m0s_pmod) using a Raspberry Pi Pico compatible RP2040-ZERO board instead of the M0S Dock

  - [MisteryShield20k DS2 Adapter](https://github.com/vossstef/tang_nano_20k_c64/blob/main/board/misteryshield20k_ds2_adapter/misteryshield20k_ds2_adapter_cable.md) is an add-on for the [MiSTeryShield20k](misteryshield20k) allowing to connect Playstation Dualshock 2 Game controllers to it
  
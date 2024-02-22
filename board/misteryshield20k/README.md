# MiSTeryNano MIDI shield for Tang Nano 20k

![Device](shield.jpeg)

This is a base board for the Tang Nano 20K and optionally the M0S Dock.
It features:

  * Headers to plug the Tang Nano 20K
  * A seperate USB power supply
    * Used if the Tang Nano 20K is being used as a USB host itself
    * Can be broken off to make room for a M0S Dock
  * M0S Dock connector
  * Atari style joystick
    * Supports two buttons
    * Including 5V supply and 5V level shifters
    * Works with DB9 joystcks and mice
  * MIDI
    * MIDI OUT with driver chip to protect Tang Nano 20K
    * MIDI IN with optocoupler to protect Tang Nano 20K

PCBA production files for JLCPCB are availble [here](jlcpcb).

![The PCB](pcb.png)

The part carrying the USB connector can be cut away making room for a
M0S Dock which will then also be used to provide power to the Tang
Nano 20K.

![Rendering](render.png)

![Schematic](schematic.png)
[PDF](misteryshield20k.pdf)
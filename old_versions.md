# Differences of previous versions

## Mouse/trackball up to version 1.0.1

The MiSTeryNano up to 1.0.1 implemented some basic mouse control via
five digital direction inputs on the Tang Nano 20k which needed to be
switched to GND.

![MiSTeryNano wiring](images/wiring.png)

Alternally a [Blackberry
Trackball](https://www.sparkfun.com/products/retired/13169) could be
used on the same pins. In this case the ```TRACKB``` config switch
needs to be closed.

![MiSTeryNano trackball](images/trackball.png)

The code is still in the main repository and can be activated in
[src/tangnano20k/top.sv](https://github.com/harbaum/MiSTeryNano/blob/main/src/tangnano20k/top.sv).

Since 1.1.0 mouse and keyboard are connected via USB and a seperate
MCU.
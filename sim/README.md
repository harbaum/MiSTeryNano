# MiSTeryNano Simulations

When used under Linux the ```Gowin Analyzer Oscilloscope (GAO)``` cannot
be used due to incompatibilities between the GoWin Programmer software and
the programmer hardware of the Tang Nano 20k.

To cope with this, most development of the MiSTeryNano was done using
a [Verilator](https://www.veripool.org/verilator/) simulation. At least
version 5.015 is needed for these simulations.

The simulations all work similar. E.g. a ```make wave``` will
compile and run the simulation and will show the resulting
waveforms in gtkview.

## floppy_tb

[Floppy_tb](floppy_tb) simulates the connection between the verilog
implementation of the fdc1772 floppy disk controller and the (Verilog
SD card reader)[https://github.com/WangXuan95/FPGA-SDcard-Reader]. It reads
a sector from the simulated SD card and reads the via the floppy disk
controller implementation.

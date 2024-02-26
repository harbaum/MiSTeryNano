# Troubleshooting MiSTerNano

Your MiSTeryNano setup does not work? These steps may
help to find the issue.

## 1. Does the display receive a signal?

Required:

- Tang Nano 20K flashed with ```atarist.fs```
- A HDMI display known to work at 848x480 @ 60Hz

The Tang Nano 20K with the core ```atarist.fs``` correctly installed
but nothing else will display an all-black 60Hz scan doubled video
signal and the HDMI screen should be able to sync to it. Many screens
have some kind of "menu" or "info" button and will tell the mode they
are seeing.

If this is "848x480 @ 60Hz" or similar, then the core has correctly
been flashed onto the Tang Nano 20K and the video part of the chipset
is working properly.

However, many screens (especially TVs) are quite picky regarding the
signals. Thus a screen not accepting the HDMI video doesn't necessarily
mean that the FPGA isn't working. It may also be the case that tge
screen isn't accepting the video signal.

## 2. Does the Tang Nano 20K boot?

Additionally required:

- A properly installed TOS

If step 1 works and at least one TOS image (preferrably a german TOS
1.04 as this has been tested most) has been flashed to flash address
0x100000 (decimal 1048575) then MiSTeryNano will boot TOS the display
will turn white and the video mode will switch to "832x576 @ 50Hz"
(PAL).

If the display turns white and switches to a PAL video mode, then
the Atari ST is actually booting. After a few seconds you should see
the green TOS desktop.

## 3. Does the M0S Dock work?

Additionally required:

- A M0S Dock flashed with the MiSTeryNano firmware connected
  correctly to the Tang Nano 20K

If step 2 works and a working M0S is conncted, the the M0S
will detect the presence of the FPGA and will instruct it
to switch the built-in RGB (ws2812) LED to blue and later
to green or red.

If the RGB LED on the Tang Nano 20K lights up green, red or
blue, then the M0S Dock is properly flashed and most of the
connections between M0S Dock and Tang nano 20K are fine.

## 3. Does the SD card work?

Additionally required:

- A formatted SD card inserted in the Tang Nano 20K

If A SD card is inserted then the LED should light up blue and then
green or even immediately green. Then the M0S Dock and the Tang Nano
20K are working properly an the SD card is detected. If it lights up red,
then the initialization of the SD card failed. Please try a different
SD card, preferrably 8, 16 or 32 GB in size and FAT32 formatted.

If the inserted SD card contains a file names ```disk_a.st``` then
the MiSTeryNano will by default try to use this as a default image
for drive A:. If this image contains some data that will make the
Atari ST react on (e.g. AUTO folder programs or a DESKTOP.INF that
opens windows by default), then these should now run.

## 4. Does USB host work?

Additionally required:

- A USB C-to USB-A adapter and a USB mouse, keyboard or combo device

If the SD card is detected correctly and a USB mouse or keyboard is
connected using a matching adapter, then the two additional LEDs on
the M0S (besides the power LED which is always lit) should light
up. Then the OSD can be opened via F12 and/or the TOS mouse cursor
should be controllable using a USB mouse.




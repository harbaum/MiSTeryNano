# BL616

The Tang Nano 20k contains a [BL616 microcontroller](https://en.bouffalolab.com/product/?type=detail&id=25) which is equipped with a firmware that emulates a [FT2232D](https://ftdichip.com/products/ft2232d/) to act as a USB debug and flash interface to the FPGA and its SPI flash. The Tang Nano 20k comes with a ```UPDATE``` button which can be used to update or replace the firmware of the BL616. It is thus possible to repurpose the BL616 to provide custom functionality in conjunction with the FPGA.

The [M0S Dock](https://wiki.sipeed.com/hardware/en/maixzero/m0s/m0s.html) contains the same BL616 controller and can thus be used to develop a replacement firmware while keeping the BL616 on the Tang Nano 20k intact.

## Using the M0S Dock

The M0S Dock itself is a rather simple device and updating it requires the user to press the ```BOOT``` button (which acts identical to the ```UPDATE``` button on the Tang Nano 20k) while resetting the board be un-plugging and re-plugging it to the PCs USB. Furthermore the board does not include a USB UART interface for debug and console messages. While this might not be a problem for end users, it makes development slightly difficult.

Development can be eased a little bit by adding an external USB UART like the CP2102 to the M0S Dock. The M0S Dock has a few solder pads right beside the USB-C connector to access the UART Rx and Tx signals as well as GND. If the M0S Dock is also to be powered from the USB UART, then 5V from the USB UART needs to be connected to the expansion connector of the M0S Dock. Finally to avoid to have to un- and re-plug the board during update it's possible to connect another connection from pin3 of the embedded M0S module of the M0S Dock via a 10µF capacitor to the DTR line of the USB UART. This will reset the M0S Dock whenever the flash utility opens the serial connection for update. However, the ```BOOT``` button still needs to be pressed during update.

![M0S DOCK USB UART](../images/m0s_dock_usb_uart.jpeg)

# USB HID on M0S Dock

The [usb_hid](usb_hid) code lets the
[M0S Dock](https://wiki.sipeed.com/hardware/en/maixzero/m0s/m0s.html)
act as a USB host accepting USB keyboards and mice and converting their
signals into [PS/2](https://en.wikipedia.org/wiki/PS/2_port)
compatible signals as used by many retro computing FPGA cores to
interface to keyboards and mice. See [Pacman on Tang Nano
9k](https://github.com/harbaum/Pacman-TangNano9k/tree/main/m0sdock_usb_joystick)
for details how to compile and upload code like this to the M0S Dock.

A LED on the M0S Dock will light up, when a HID device is detected (e.g. a keyboard,
mouse or joystick). Keyboard signals will be sent via IO10 (CLK) and IO11 (DATA) and
mouse signals will be sent via IO12 (CLK) and IO13 (DATA). Furthermore GND and +5V have to
be connected to the Tang Nano 20k to power the M0S Dock and its attached USB devices.

See a demo video [here](https://youtube.com/shorts/jjps1x1NjhE?si=LUqlXd3iTG0hus1-).

This has been tested with several wireless keyboard/touchpad combo devices incl.
the Rii X1 and the Rapoo E2710.

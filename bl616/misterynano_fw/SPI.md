# MiSTeryNano SPI protocol

In MiSTeryNano the workload is distributed between the FPGA and the
BL616 MCU. The FPGA implements the hardware of the original device (in
this case the Atari ST) and the BLC616 MCU mainly deals with modern
peripherals like USB keyboards and mice and SD cards with their file
systems (FAT, exFAT).

This setup requires that the FPGA and the MCU communicate permanently
so the MCU can instruct the FPGA to display the on-screen-display
(OSD), to send keyboard and mouse events into the core and to receive
floppy disk read requests from the FPGA. And since the SD card is
connected to the FPGA as well, the MCU needs to request SD card data
from the FPGA. This is all done via a SPI bus.

This part of MiSTeryNano is a work and progress and the information
below may be outdated. The basic principles should still be valid.

## SPI bus

The SPI bus between the MCU and the FPGA consists of four connections:

|      | M0S Dock <-> FPGA | int. MCU <-> FPGA |
|------|-------------------|-------------------|
| CSN  | GPIO12 -> 56      | GPIO0 -> 86       |
| SCK  | GPIO13 -> 54      | GPIO1 -> 13       |
| MOSI | GPIO11 -> 41      | GPIO3 -> 76       |
| MISO | GPIO10 <- 42      | GPIO2 <- 75       |

Currently the SPI bus is run at 20Mhz and only the M0S variant is
implemented and supported. Higher speeds and the use of the internal
MCU will come later.

The SPI master is the MCU and the SPI target is the FPGA. The SPI is
operated in MODE1 with clock idle state being low and data being
sampled on the falling edge of clock.

## Protocol

SPI communication is initiated by the MCU by driving CSN low.

The basic SPI communication runs between [```spi.c```](spi.c) on the
MCU side and [```mcu_spi.v```](../../src/misc/mcu_spi.v) on FPGA side.

The first byte of each message identifies the target inside the FPGA
the MCU wants to address. Currently implemented are:

| value | name | description | MCU implementation | FPGA implementation |
|-------|------|-------------|--------------------|---------------------|
| 1     | HID  | Human Interface Devices, e.g. keyboard & mice | [```usb_host.c```](usb_host.c) | [```hid.v```](../../src/misc/hid.v) |
| 2     | OSD  | On-Screen-Display | [```osd_u8g2.c```](osd_u8g2.c) | [```osd_u8g2.v```](../../src/misc/osd_u8g2.v) |
| 3     | SDC  | SD Card   | [```sdc.c```](sdc.c) | [```sd_card.v```](../../src/misc/sd_card.v) |

Any data after the first target byte is being sent to the target
inside the FPGA for further parsing. The communication inside the FPGA
between ```mcu_spi.v``` and the various targets is byte-wide using
four signals:

| signal  | description |
|---------|-------------|
| ```strobe```  | Indicate the arrival of a data byte for the target |
| ```start```   | Valid for the first byte of a message |
| ```dout[8]``` | Databyte from MCU to target |
| ```din[8]```  | Databyte from target to MCU |

The first byte transferred with ```start``` active (the second byte
within each SPI message) usually is a command byte for the target.

### HID target

The HID target currently supports three commands:

| value | name | description |
|---------|-------------|-------------|
| 0 | ```SPI_HID_STATUS```   | Request status from FPGA. Currently returns 0x5c and 0x42 in bytes 4 and 5 |
| 1 | ```SPI_HID_KEYBOARD``` | Send a keyboard data byte into the FPGA |
| 2 | ```SPI_HID_MOUSE``` | Send a mouse data byte into the FPGA |

The ```SPI_HID_STATUS``` message is currently unused. It will be used to report the
HID requirements. This may e.g. include the keycode mapping required
by the core.

The ```SPI_HID_KEYBOARD``` messages are core specific. Currently each message
consists of one byte only containing the press/release status and the
row and column of the key inside the keyboard matrix. Typically
the F12 key is not forwarded into the core. Instead the F12 key is
used to open and close the OSD. While the OSD is visible no keyboard
data is sent into the core. Instead the keyboard is being used to
control the OSD.

The ```SPI_HID_MOUSE``` messages contains three data bytes. The first byte contains
the state of the mouse buttons in the LSB and the second and third
byte contain relative x and y movements.

### OSD target

The OSD (on-screen-display) is a monochrome 128x64 frame buffer inside
the FPGA that can be displayed centered in the main screen on request
by the MCU. The 1024 bytes of video memory (128x64/8) are organized
"vertically" as typically used with small OLED displays. This is to
easy the use of the [u8g2](https://github.com/olikraus/u8g2) library
which is a graphics library for small monochrome displays and which
is being used in MiSTeryNano.

The OSD target supports the following commands:

| value | name | description |
|---------|-------------|-------------|
| 1 | ```SPI_OSD_ENABLE```  | Show or hide the OSD |
| 2 | ```SPI_OSD_WRITE``` | Send graphics data to the OSD |
| 3 | ```SPI_OSD_SET``` | Set a variable from OSD |

The ```SPI_OSD_ENABLE``` command has one data byte. The lowest bit of this
indicates whether the OSD is to be shown (1) or hidden (0).

The ```SPI_OSD_WRITE``` command is followed by a byte containing a offset value
and 1 or more data bytes. The offset indicates which tile the graphics data
starts at. E.g. a offset of 100 indicates that writing should start at tile column
100 which is the 800th pixel column. Since the display is 128 pixels wide the
800th column is the 32th pixel column in tile row 6 (6*128+32=800). This is exactly
how the u8g2 library expects to address a display.

The ```SPI_OSD_SET``` command has three data bytes. The first and second byte
are ASCII ID's of a variable to be set and the third byte is a 8 bit value. E.g.
the Atari ST core supports the configuration of the chipset between three
value (ST, Mega ST and STE) via the OSD. This setting is sent using the ID 'SC'
(for System Chipset) with a value of 0 to 2. The use of these values is core
specific.

### SDC target

The SDC (SD card) target allows the MCU to use the SD card connected
to the FPGA. It can either read whole sectors for its own purposed
(e.g. letting the user browse the file system) or it can assist the
FPGA core in accessing data inside files on the SD card. This is
necessary since most cores expect to deal with single media (e.g. a
single floppy disk). The MiSTeryNano instead stores these in media
files (e.g. Atari ST .ST disk image files) which in turn reside inside
the file system of the SD card. So these are basically core specific
file systems stored inside a SD card file system. While the FPGA core
deals with the core specific file system inside the image files it's
up to the MCU to handle the SD cards own file system.

The SDC target supports the following commands:

| value | name | description |
|---------|-------------|-------------|
| 1 | ```SPI_SDC_STATUS```  | Read SD card status |
| 2 | ```SPI_SDC_READ``` | Request the core to read a sector for it's own purpose |
| 3 | ```SPI_SDC_MCU_READ``` | Request to read data for MCU usage |
| 4 | ```SPI_SDC_INSERTED``` | Inform core about the selection of disk images |

The ```SPI_SDC_STATUS``` is used to poll the SD card status. The first
byte returned is a generic status byte indicating whether the card
could be initialized and the card type (SDv1, SDv2, SDHC). The lower
two bits are request bytes which are set by the core if it needs to
read a sector. In the Atari ST core bit 0 indicates a request for
floppy A: and bit 1 for floppy B: (currently only floppy A is
implemented). The following four bytes contain the sector number the
core wants to read.

The ```SPI_SDC_READ``` requests the core to read a sector from SD card
and use it for it's own purposes. The command is followed by four
bytes containing the sector number to be read. This command is usually
a sent in reply to bit 0 or 1 being set in the reply
to```SPI_SDC_STATUS```. The core has requested to read a sector
(e.g. sector if it wants to read the first sector from floppy) and the
MCU now instructs it to read a certain sector from SD card. This will
be the first sector of the disk images on SD card which will be the
first data sector if the image file. No actual data is being returned to
the MCU with this command.

In contrast ```SPI_SDC_MCU_READ``` requests the FPGA to return the contents
of a sector from the SD card is to be returned to the MCU. The following four
data bytes indicate again which sector is to be read. The FPGA will return
busy bytes (!=0) as long as the SD card is being read. Once data is ready, the
command returns a single 0 byte followed by 512 bytes of sector data. This
data is not visible to the core. Instead it used by the MCU to display the
contents of the SD card and to determine where data is stored inside the images
files stored on the SD card.

The ```SPI_SDC_INSERTED``` command and the following four data bytes
are used to inform the core about the size of the selected disk
image. This is needed to translate between the track/sector/side
values typically used when reading from floppy disk into sector
offsets into the image file. A size of 0 indicates that no image
is currently selected. The core should then behave as if e.g. no
floppy disk is inserted.
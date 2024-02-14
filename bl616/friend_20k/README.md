# Friend 20K firmware

This is the original firmware that came pre-installed with the BL616
on the Tang Nano 20K. These files should allow you to return the board
to factory state in case the firmware has been overwritten.

There are two variants, the regular one and an encrypted one. Both
provide a similar functionality. Sipeed decided to encrypt the
firmware on boards sold about the beginning of 2024. These newer
boards will not accept or run any non-encrypted firmware and replacing
its default firmware will essentially brick the Tang Nano 20K. This
encrypted firmware will allow to restore the newer boards to factory
state as well and thus unbrick the device.

It's currently unknown if the firmware versions can be identified
beforehand. So you might have to try both of them and to check which
one's the one working for your board.


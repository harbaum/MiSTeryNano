/*
  Keyboard.cpp

  Copyright (c) 2015, Arduino LLC
  Original code (pre-library): Copyright (c) 2011, Peter Barrett

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include "Keyboard.h"

#if defined(_USING_HID)

//================================================================================
//================================================================================
//  Keyboard

static const uint8_t _hidReportDescriptor[] PROGMEM = {

    //  Keyboard
    0x05, 0x01,                    // USAGE_PAGE (Generic Desktop)  // 47
    0x09, 0x06,                    // USAGE (Keyboard)
    0xa1, 0x01,                    // COLLECTION (Application)
    0x85, 0x02,                    //   REPORT_ID (2)
    0x05, 0x07,                    //   USAGE_PAGE (Keyboard)

    0x19, 0xe0,                    //   USAGE_MINIMUM (Keyboard LeftControl)
    0x29, 0xe7,                    //   USAGE_MAXIMUM (Keyboard Right GUI)
    0x15, 0x00,                    //   LOGICAL_MINIMUM (0)
    0x25, 0x01,                    //   LOGICAL_MAXIMUM (1)
    0x75, 0x01,                    //   REPORT_SIZE (1)

    0x95, 0x08,                    //   REPORT_COUNT (8)
    0x81, 0x02,                    //   INPUT (Data,Var,Abs)
    0x95, 0x01,                    //   REPORT_COUNT (1)
    0x75, 0x08,                    //   REPORT_SIZE (8)
    0x81, 0x03,                    //   INPUT (Cnst,Var,Abs)

    // for LED support
    0x95, 0x05,                    //   REPORT_COUNT (5)
    0x75, 0x01,                    //   REPORT_SIZE (1)
    0x05, 0x08,                    //   USAGE_PAGE (LEDs)
    0x19, 0x01,                    //   USAGE_MINIMUM (1)
    0x29, 0x05,                    //   USAGE_MAXIMUM (5)
    0x91, 0x02,                    //   OUTPUT (Data,Var,Abs) // LED report
    0x95, 0x01,                    //   REPORT_COUNT (1)
    0x75, 0x03,                    //   REPORT_SIZE (3)
    0x91, 0x01,                    //   OUTPUT (Constant) // padding 
    
    0x95, 0x06,                    //   REPORT_COUNT (6)
    0x75, 0x08,                    //   REPORT_SIZE (8)
    0x15, 0x00,                    //   LOGICAL_MINIMUM (0)
    0x25, 0x73,                    //   LOGICAL_MAXIMUM (115)
    0x05, 0x07,                    //   USAGE_PAGE (Keyboard)

    0x19, 0x00,                    //   USAGE_MINIMUM (Reserved (no event indicated))
    0x29, 0x73,                    //   USAGE_MAXIMUM (Keyboard Application)
    0x81, 0x00,                    //   INPUT (Data,Ary,Abs)
    0xc0,                          // END_COLLECTION
};

Keyboard_::Keyboard_(void)
{
	static HIDSubDescriptor node(_hidReportDescriptor, sizeof(_hidReportDescriptor));
	HID().AppendDescriptor(&node);
  _ledStatus = false;
}

void Keyboard_::sendReport(KeyReport* keys)
{
	HID().SendReport(2,keys,sizeof(KeyReport));
}

uint8_t Keyboard_::getLedStatus(void) {
  return _ledStatus;
}

void Keyboard_::recvReport(const uint8_t *buffer, size_t size) {
  // check for size and report id
  if(size == 2 && buffer[0] == 2)
    _ledStatus = buffer[1];
}

// press() adds the specified key (printing, non-printing, or modifier)
// to the persistent key report and sends the report.  Because of the way
// USB HID works, the host acts like the key remains pressed until we
// call release(), releaseAll(), or otherwise clear the report and resend.
size_t Keyboard_::press(uint8_t k)
{
	uint8_t i;
	if (k >= 0xf0) {	// it's a modifier key
		_keyReport.modifiers |= (1<<(k-0xf0));
	} else {
  	// Add k to the key report only if it's not already present
	  // and if there is an empty slot.
	  if (_keyReport.keys[0] != k && _keyReport.keys[1] != k &&
		  _keyReport.keys[2] != k && _keyReport.keys[3] != k &&
		  _keyReport.keys[4] != k && _keyReport.keys[5] != k) {

		  for (i=0; i<6; i++) {
			  if (_keyReport.keys[i] == 0x00) {
				  _keyReport.keys[i] = k;
				  break;
			  }
		  }
		  if (i == 6)
			  return 0;
  	}
  }
	sendReport(&_keyReport);
	return 1;
}

// release() takes the specified key out of the persistent key report and
// sends the report.  This tells the OS the key is no longer pressed and that
// it shouldn't be repeated any more.
size_t Keyboard_::release(uint8_t k)
{
	uint8_t i;
	if (k >= 0xf0) {	// it's a modifier key
		_keyReport.modifiers &= ~(1<<(k-0xf0));
	} else {
  	// Test the key report to see if k is present.  Clear it if it exists.
	  // Check all positions in case the key is present more than once (which it shouldn't be)
	  for (i=0; i<6; i++) {
		  if (0 != k && _keyReport.keys[i] == k) {
			  _keyReport.keys[i] = 0x00;
		  }
	  }
  }
	sendReport(&_keyReport);
	return 1;
}

Keyboard_ Keyboard;

#endif

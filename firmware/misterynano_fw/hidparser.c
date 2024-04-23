// http://www.frank-zhao.com/cache/hid_tutorial_1.php

#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "hidparser.h"
#include "debug.h"

#if 1
#define hidp_extreme_debugf(...) hidp_debugf(__VA_ARGS__)
#else
#define hidp_extreme_debugf(...)
#endif

typedef struct {
  uint8_t bSize: 2;
  uint8_t bType: 2;
  uint8_t bTag: 4;
} __attribute__((packed)) item_t;

// flags for joystick components required
#define JOY_MOUSE_REQ_AXIS_X  0x01
#define JOY_MOUSE_REQ_AXIS_Y  0x02
#define JOY_MOUSE_REQ_BTN_0   0x04
#define JOY_MOUSE_REQ_BTN_1   0x08
#define JOYSTICK_COMPLETE     (JOY_MOUSE_REQ_AXIS_X | JOY_MOUSE_REQ_AXIS_Y | JOY_MOUSE_REQ_BTN_0)
#define MOUSE_COMPLETE        (JOY_MOUSE_REQ_AXIS_X | JOY_MOUSE_REQ_AXIS_Y | JOY_MOUSE_REQ_BTN_0 | JOY_MOUSE_REQ_BTN_1)

#define USAGE_PAGE_GENERIC_DESKTOP  1
#define USAGE_PAGE_SIMULATION       2
#define USAGE_PAGE_VR               3
#define USAGE_PAGE_SPORT            4
#define USAGE_PAGE_GAMING           5
#define USAGE_PAGE_GENERIC_DEVICE   6
#define USAGE_PAGE_KEYBOARD         7
#define USAGE_PAGE_LEDS             8
#define USAGE_PAGE_BUTTON           9
#define USAGE_PAGE_ORDINAL         10
#define USAGE_PAGE_TELEPHONY       11
#define USAGE_PAGE_CONSUMER        12


#define USAGE_POINTER   1
#define USAGE_MOUSE     2
#define USAGE_JOYSTICK  4
#define USAGE_GAMEPAD   5
#define USAGE_KEYBOARD  6
#define USAGE_KEYPAD    7
#define USAGE_MULTIAXIS 8

#define USAGE_X       48
#define USAGE_Y       49
#define USAGE_Z       50
#define USAGE_RX      51
#define USAGE_RY      52
#define USAGE_RZ      53
#define USAGE_WHEEL   56
#define USAGE_HAT     57

// check if the current report 
bool report_is_usable(uint16_t bit_count, uint8_t report_complete, hid_report_t *conf) {
	hidp_debugf("  - total bit count: %d (%d bytes, %d bits)", 
	      bit_count, bit_count/8, bit_count%8);

	conf->report_size = bit_count/8;

	// check if something useful was detected
	if( ((conf->type == REPORT_TYPE_JOYSTICK) && ((report_complete & JOYSTICK_COMPLETE) == JOYSTICK_COMPLETE)) ||
	    ((conf->type == REPORT_TYPE_MOUSE)    && ((report_complete & MOUSE_COMPLETE) == MOUSE_COMPLETE)) ||
	    ((conf->type == REPORT_TYPE_KEYBOARD))) {
	hidp_debugf("  - report %d is usable", conf->report_id);
	return true;
	}

	hidp_debugf("  - unusable report %d", conf->report_id);
	return false;
}

bool parse_report_descriptor(uint8_t *rep, uint16_t rep_size, hid_report_t *conf, uint16_t *rbytes) {
	int8_t app_collection = 0;
	int8_t phys_log_collection = 0;
	uint8_t skip_collection = 0;
	int8_t generic_desktop = -1;   // depth at which first gen_desk was found
	uint8_t collection_depth = 0;

	uint8_t i;

	//
	uint8_t buttons = 0;
	uint8_t report_size, report_count;
	uint16_t bit_count = 0, usage_count = 0;
	uint16_t logical_minimum=0, logical_maximum=0;
	uint16_t physical_minimum=0, physical_maximum=0;
	memset(conf, 0, sizeof(hid_report_t));

	// mask used to check of all required components have been found, so
	// that e.g. both axes and the button of a joystick are ready to be used
	uint8_t report_complete = 0;

	// joystick/mouse components
	int8_t axis[MAX_AXES];
	uint8_t btns = 0;
	int8_t hat = -1;

	for (i=0; i<MAX_AXES; i++) axis[i] = -1;

	conf->type = REPORT_TYPE_NONE;

	while(rep_size) {
		// extract short item
		uint8_t tag = ((item_t*)rep)->bTag;
		uint8_t type = ((item_t*)rep)->bType;
		uint8_t size = ((item_t*)rep)->bSize;

		rep++;
		rep_size--;   // one byte consumed
		if(rbytes) (*rbytes)++;
		
		uint32_t value = 0;
		if(size) {      // size 1/2/3
			value = *rep++;
			rep_size--;
			if(rbytes) (*rbytes)++;
		}

		if(size > 1) {  // size 2/3
			value = (value & 0xff) + ((uint32_t)(*rep++)<<8);
			rep_size--;
			if(rbytes) (*rbytes)++;
		}

		if(size > 2) {  // size 3
			value &= 0xffff;
			value |= ((uint32_t)(*rep++)<<16);
			value |= ((uint32_t)(*rep++)<<24);
			rep_size-=2;
			if(rbytes) (*rbytes) += 2;
		}

		//    hidp_extreme_debugf("Value = %d (%u)\n", value, value);

		// we are currently skipping an unknown/unsupported collection) 
		if(skip_collection) {
			if(!type) {  // main item
				// any new collection increases the depth of collections to skip
				if(tag == 10) {
					skip_collection++;
					collection_depth++;
				}

				// any end collection decreases it
				if(tag == 12) {
					skip_collection--;
					collection_depth--;

					// leaving the depth the generic desktop was valid for
					if(generic_desktop > collection_depth)
						generic_desktop = -1;
				}
			}

		} else {
			//      hidp_extreme_debugf("-> Item tag=%d type=%d size=%d", tag, type, size);

			switch(type) {
			case 0:
			// main item

				switch(tag) {
				case 8:
					// handle found buttons 
					if(btns) {
						if((conf->type == REPORT_TYPE_JOYSTICK) ||
						   (conf->type == REPORT_TYPE_MOUSE)) {
						// scan for up to four buttons
							char b;
							for(b=0;b<12;b++) {
								if(report_count > buttons) {
								uint16_t this_bit = bit_count+b;

									hidp_debugf("BUTTON%d @ %d (byte %d, mask %d)", buttons, 
										this_bit, this_bit/8, 1 << (this_bit%8));

									conf->joystick_mouse.button[buttons].byte_offset = this_bit/8;
									conf->joystick_mouse.button[buttons].bitmask = 1 << (this_bit%8);
									buttons++;
								}
							}

							// we found at least one button which is all we want to accept this as a valid 
							// joystick
							report_complete |= JOY_MOUSE_REQ_BTN_0;
							if(report_count > 1) report_complete |= JOY_MOUSE_REQ_BTN_1;
						}
					}

					// handle found axes
					char c;
					for(c=0;c<MAX_AXES;c++) {
						if(axis[c] >= 0) {
							uint16_t cnt = bit_count + report_size * axis[c];
							hidp_debugf("  (%c-AXIS @ %d (byte %d, bit %d))", 'X'+c,
							  cnt, cnt/8, cnt&7);

							if((conf->type == REPORT_TYPE_JOYSTICK) || (conf->type == REPORT_TYPE_MOUSE)) {
								// save in joystick report
								conf->joystick_mouse.axis[c].offset = cnt;
								conf->joystick_mouse.axis[c].size = report_size;
								conf->joystick_mouse.axis[c].logical.min = logical_minimum;
								conf->joystick_mouse.axis[c].logical.max = logical_maximum;
								if(c==0) report_complete |= JOY_MOUSE_REQ_AXIS_X;
								if(c==1) report_complete |= JOY_MOUSE_REQ_AXIS_Y;
							}
						}
					}

					// handle found hat
					if(hat >= 0) {
						uint16_t cnt = bit_count + report_size * hat;
						hidp_debugf("  (HAT @ %d (byte %d, bit %d), size %d)",
						  cnt, cnt/8, cnt&7, report_size);
						if(conf->type == REPORT_TYPE_JOYSTICK) {
							conf->joystick_mouse.hat.offset = cnt;
							conf->joystick_mouse.hat.size = report_size;
							conf->joystick_mouse.hat.logical.min = logical_minimum;
							conf->joystick_mouse.hat.logical.max = logical_maximum;
							conf->joystick_mouse.hat.physical.min = physical_minimum;
							conf->joystick_mouse.hat.physical.max = physical_maximum;
						}
					}

					hidp_extreme_debugf("INPUT(%d)", value);

					// reset for next inputs
					bit_count += report_count * report_size;
					usage_count = 0;
					btns = 0;
					for (i=0; i<MAX_AXES; i++) axis[i] = -1;
					hat = -1;
					break;

				case 9:
					hidp_extreme_debugf("OUTPUT(%d)", value);
					break;

				case 11:
					hidp_extreme_debugf("FEATURE(%d)", value);
					break;

				case 10:
					hidp_extreme_debugf("COLLECTION(%d)", value);
					collection_depth++;
					usage_count = 0;

					if(value == 1) {   // app collection
						hidp_extreme_debugf("  -> application");
						app_collection++;
					} else if(value == 0) {  // physical collection
						hidp_extreme_debugf("  -> physical");
						phys_log_collection++;
					} else if(value == 2) {  // logical collection
						hidp_extreme_debugf("  -> logical");
						phys_log_collection++;
					} else {
						hidp_extreme_debugf("skipping unsupported collection");
						skip_collection++;
					}
					break;

				case 12:
					hidp_extreme_debugf("END_COLLECTION(%d)", value);
					collection_depth--;

					// leaving the depth the generic desktop was valid for
					if(generic_desktop > collection_depth)
						generic_desktop = -1;

					if(phys_log_collection) {
						hidp_extreme_debugf("  -> phys/log end");
						phys_log_collection--;
					} else if(app_collection) {
						hidp_extreme_debugf("  -> app end");
						app_collection--;

						// check if report is usable and stop parsing if it is
						if(report_is_usable(bit_count, report_complete, conf)) {
						        return true;
						} else {
							// retry with next report
							bit_count = 0;
							report_complete = 0;
						}

					} else {
						hidp_debugf(" -> unexpected");
						return false;
					}
					break;

				default:
					hidp_debugf("unexpected main item %d", tag);
					return false;
					break;
				}
				break;

			case 1:
				// global item
				switch(tag) {
				case 0:
					hidp_extreme_debugf("USAGE_PAGE(%d/0x%x)", value, value);

					if(value == USAGE_PAGE_KEYBOARD) {
						hidp_extreme_debugf(" -> Keyboard");
					} else if(value == USAGE_PAGE_GAMING) {
						hidp_extreme_debugf(" -> Game device");
					} else if(value == USAGE_PAGE_LEDS) {
						hidp_extreme_debugf(" -> LEDs");
					} else if(value == USAGE_PAGE_CONSUMER) {
						hidp_extreme_debugf(" -> Consumer");
					} else if(value == USAGE_PAGE_BUTTON) {
						hidp_extreme_debugf(" -> Buttons");
						btns = 1;
					} else if(value == USAGE_PAGE_GENERIC_DESKTOP) {
						hidp_extreme_debugf(" -> Generic Desktop");

						if(generic_desktop < 0)
							generic_desktop = collection_depth;
					} else
						hidp_extreme_debugf(" -> UNSUPPORTED USAGE_PAGE");

					break;

				case 1:
					hidp_extreme_debugf("LOGICAL_MINIMUM(%d/%d)", value, (int16_t)value);
					logical_minimum = value;
					break;

				case 2:
					hidp_extreme_debugf("LOGICAL_MAXIMUM(%d)", value);
					logical_maximum = value;
					break;

				case 3:
					hidp_extreme_debugf("PHYSICAL_MINIMUM(%d/%d)", value, (int16_t)value);
					physical_minimum = value;
					break;

				case 4:
					hidp_extreme_debugf("PHYSICAL_MAXIMUM(%d)", value);
					physical_maximum = value;
					break;

				case 5:
					hidp_extreme_debugf("UNIT_EXPONENT(%d)", value);
					break;

				case 6:
					hidp_extreme_debugf("UNIT(%d)", value);
					break;

				case 7:
					hidp_extreme_debugf("REPORT_SIZE(%d)", value);
					report_size = value;
					break;

				case 8:
					hidp_extreme_debugf("REPORT_ID(%d)", value);
					conf->report_id_present = 1;
					conf->report_id = value;
					break;

				case 9:
					hidp_extreme_debugf("REPORT_COUNT(%d)", value);
					report_count = value;
					break;

				default:
					hidp_debugf("unexpected global item %d", tag);
					return false;
					break;
				}
				break;

			case 2:
				// local item
				switch(tag) {
				case 0:
					// we only support mice, keyboards and joysticks
					hidp_extreme_debugf("USAGE(%d/0x%x)", value, value);

					if( !collection_depth && (value == USAGE_KEYBOARD)) {
						// usage(keyboard) is always allowed
						hidp_debugf(" -> Keyboard");
						conf->type = REPORT_TYPE_KEYBOARD;
					} else if(!collection_depth && (value == USAGE_MOUSE)) {
						// usage(mouse) is always allowed
						hidp_debugf(" -> Mouse");
						conf->type = REPORT_TYPE_MOUSE;
					} else if(!collection_depth && 
						((value == USAGE_GAMEPAD) || (value == USAGE_JOYSTICK))) {
							hidp_extreme_debugf(" -> Gamepad/Joystick");
							hidp_debugf("Gamepad/Joystick usage found");
							conf->type = REPORT_TYPE_JOYSTICK;
					} else if(value == USAGE_POINTER && app_collection) {
						// usage(pointer) is allowed within the application collection

						hidp_debugf(" -> Pointer");

					} else if(((value >= USAGE_X && value <= USAGE_RZ) || value == USAGE_WHEEL) && app_collection) {
						// usage(x) and usage(y) are allowed within the app collection
						hidp_extreme_debugf(" -> axis usage");

						// we support x and y axis on mice and joysticks (+wheel on mice)
						if((conf->type == REPORT_TYPE_JOYSTICK) || (conf->type == REPORT_TYPE_MOUSE)) {
							if(value == USAGE_X) {
								hidp_extreme_debugf("JOYSTICK/MOUSE: found x axis @ %d", usage_count);
								axis[0] = usage_count;
							}
							if(value == USAGE_Y) {
								hidp_extreme_debugf("JOYSTICK/MOUSE: found y axis @ %d", usage_count);
								axis[1] = usage_count;
							}
							if(value == USAGE_Z) {
								hidp_extreme_debugf("JOYSTICK/MOUSE: found z axis @ %d", usage_count);
								if (axis[2] == -1) axis[2] = usage_count; // don't override wheel
							}
							if(value == USAGE_RX || value == USAGE_RY || value == USAGE_RZ) {
								hidp_extreme_debugf("JOYSTICK/MOUSE: found R%c axis @ %d", 'X'+(value-USAGE_RX), usage_count);
								if (axis[3] == -1) axis[3] = usage_count;
							}
							if(value == USAGE_WHEEL) {
								hidp_extreme_debugf("MOUSE: found wheel @ %d", usage_count);
								axis[2] = usage_count;
							}
						}
					} else if((value == USAGE_HAT) && app_collection) {
						// usage(hat) is allowed within the app collection
						hidp_extreme_debugf(" -> hat usage");

						// we support hat on joysticks only
						if(conf->type == REPORT_TYPE_JOYSTICK) {
							hidp_extreme_debugf("JOYSTICK: found hat @ %d", usage_count);
							hat = usage_count;
						}
					} else {
						hidp_extreme_debugf(" -> UNSUPPORTED USAGE");
						//    return false;
					}

					usage_count++;
					break;

				case 1:
					hidp_extreme_debugf("USAGE_MINIMUM(%d)", value);
					usage_count -= (value-1);
					break;

				case 2:
					hidp_extreme_debugf("USAGE_MAXIMUM(%d)", value);
					usage_count += value;
					break;

				default:
					hidp_extreme_debugf("unexpected local item %d", tag);
					//  return false;
					break;
				}
				break;

			default:
				// reserved
				hidp_extreme_debugf("unexpected reserved item %d", tag);
				// return false;
				break;
			}
		}
	}

	// if we get here then no usable setup was found
	return false;
}

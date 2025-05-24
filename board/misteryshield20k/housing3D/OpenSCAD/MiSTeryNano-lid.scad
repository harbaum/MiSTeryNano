// A simple case for the MiSTeryNano (https://github.com/harbaum/MiSTeryNano)

// This is the top half lid of the case, with a cutaway to access the MIDI ports
// Comment line 40 out to remove the hole for the MIDI ports

// Original author: Oliver Jaksch
// CC BY-NC-SA 4.0 (https://creativecommons.org/licenses/by-nc-sa/4.0/)

// For the optional screws, use 4x M3 12mm
// Standoff 4.12 width / 6 height

// Lid
difference() {
    cube([57.5, 57.5, 2], true);
    translate([-10, 0, 0]) rotate([40, 90, 0]) scale([1.0,1.0,4.0]) sphere(d=4.0, $fn=100);
    translate([0, 0, 0]) rotate([40, 90, 0]) scale([1.0,1.0,4.0]) sphere(d=4.0, $fn=100);
    translate([10, 0, 0]) rotate([40, 90, 0]) scale([1.0,1.0,4.0]) sphere(d=4.0, $fn=100);
}

// Support
difference() {
    translate ([25.2, 25.2, 11.05]) cube([7, 7, 22], true);
    translate ([25.2, 25.2, 16]) cylinder(h=6.1, d1=4.12, d2=4.12, $fn=300);
}
difference() {
    translate ([-25.2, -25.2, 11.05]) cube([7, 7, 22], true);
    translate ([-25.2, -25.2, 16]) cylinder(h=6.1, d1=4.12, d2=4.12, $fn=300);
}
difference() {
    translate ([-25.2, 25.2, 11.05]) cube([7, 7, 22], true);
    translate ([-25.2, 25.2, 16]) cylinder(h=6.1, d1=4.12, d2=4.12, $fn=300);
}
difference() {
    translate ([25.2, -25.2, 11.05]) cube([7, 7, 22], true);
    translate ([25.2, -25.2, 16]) cylinder(h=6.1, d1=4.12, d2=4.12, $fn=300);
}
///*
// Frame MIDI
difference() {
    translate ([0, 29.7, 9.5]) cube([57.5, 2, 21], true);
    translate ([0, 29.7, 11.1]) cube([43, 2.1, 20.1], true); // Comment out this line to remove MIDI ports hole
}

// Frame Joystick
difference() {
    translate ([0, -29.7, 9.5]) cube([57.5, 2, 21], true);
    translate ([0, -29.7, 14.9]) cube([31, 2.1, 10.3], true);
}

// Rahmen HDMI
difference() {
    translate ([-29.7, 0, 9.5]) cube([2, 61.4, 21], true);
    translate ([-29.7, -3, 6]) cube([2.1, 20, 10], true);
}

// Frame M0S
difference() {
    translate ([29.7, 0, 9.5]) cube([2, 61.4, 21], true);
    translate ([29.7, -2.5, 12.51]) cube([2.1, 16, 15], true);
}

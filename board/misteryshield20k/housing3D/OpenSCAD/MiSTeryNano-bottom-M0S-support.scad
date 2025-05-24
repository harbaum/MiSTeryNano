// A simple case for the MiSTeryNano (https://github.com/harbaum/MiSTeryNano)

// This version of the case base features a support for the M0S dock that
// prevents the dock getting removed from its slot when removing USB devices.

// Original author: Oliver Jaksch
// Remixed by: Dan MacDonald
// CC BY-NC-SA 4.0 (https://creativecommons.org/licenses/by-nc-sa/4.0/)

difference() {
    translate ([24.8, 24.8, 2.5]) cube([8, 8, 3], true);
    translate ([24.8, 24.8, 0.4]) cylinder(h=5, d1=3.2, d2=3.2, $fn=300);
}
difference() {
    translate ([-24.8, -24.8, 2.5]) cube([8, 8, 3], true);
    translate ([-24.8, -24.8, -0.4]) cylinder(h=5, d1=3.2, d2=3.2, $fn=300);
}
difference() {
    translate ([-24.8, 24.8, 2.5]) cube([8, 8, 3], true);
    translate ([-24.8, 24.8, -0.4]) cylinder(h=5, d1=3.2, d2=3.2, $fn=300);
}
difference() {
    translate ([24.8, -24.8, 2.5]) cube([8, 8, 3], true);
    translate ([24.8, -24.8, -0.4]) cylinder(h=5, d1=3.2, d2=3.2, $fn=300);
}

// Boden
difference() {
    cube([57.5, 57.5, 2], true);

    // Drilling
    translate ([24.8, 24.8, -1.2]) cylinder(h=5, d1=3.2, d2=3.2, $fn=300);
    translate ([-24.8, -24.8, -1.2]) cylinder(h=4, d1=3.2, d2=3.2, $fn=300);
    translate ([24.8, -24.8, -1.2]) cylinder(h=4, d1=3.2, d2=3.2, $fn=300);
    translate ([-24.8, 24.8, -1.2]) cylinder(h=4, d1=3.2, d2=3.2, $fn=300);
}

// Frame
translate ([0, 29.7, 3.25]) cube([57.5, 2, 8.5], true);
translate ([0, -29.7, 3.25]) cube([57.5, 2, 8.5], true);
translate ([-29.7, 0, 3.25]) cube([2, 61.4, 8.5], true);

// Add a support for the M0S dock
difference() {
    translate ([29.7, 0, 3.25]) cube([2, 61.4, 8.5], true);
    translate ([28.7, 2.5, 7.5]) cube([2.1, 16, 7], true);
    translate ([29.7, 2.5, 9]) cube([2.1, 16, 7], true);
}

// Ktemata r1 - Internal top pull switch (Pi power)
// Holds a USB-C 180deg "U" adapter upright: the male plug goes into the Pi 5 USB-C,
// the battery cable plugs into the female socket below it. Pull the key ring to
// unplug the adapter (= Pi off), push back in to power on.
// Modelled in assembly position; export lays it on its side.
include <common.scad>

PS_X0 = PULL_SLOT_X0 + TOL; PS_X1 = PULL_SLOT_X0 + PULL_SLOT_W - TOL;
PS_Z0 = FLOOR - PULL_GROOVE + 0.2;
PS_Z1 = H_BOT - 0.3;
PS_D  = 1.5 + UADP[1];               // carrier depth (y)
UMALE_TOP = PI_USBC_Z + UADP_MALE_FROM_TOP;

module pull_switch() {
    difference() {
        union() {
            // carrier block
            at(PS_X0, 0, PS_Z0) translate([0,-PS_D,0]) cube([PS_X1-PS_X0, PS_D, PS_Z1-PS_Z0]);
            // ring tab sticking out of the top edge
            at((PS_X0+PS_X1)/2, 0, PS_Z1 - 3.5) hull() {   // flush with the top so it prints upside-down without supports
                translate([-5, -1, 0]) cube([10, 1, 3.5]);
                translate([0, 7, 0]) cylinder(d=10, h=3.5);   // +real y = outside the top edge
            }
        }
        // adapter pocket, open towards the Pi (+y) and at the bottom
        at(PI_USBC_X - (UADP[0]+0.3)/2, 1.5, PS_Z0 - 1)
            translate([0, -(PS_D), 0]) cube([UADP[0]+0.3, PS_D - 1.5 + 1, UMALE_TOP + 0.15 - PS_Z0 + 1]);
        // ring hole
        at((PS_X0+PS_X1)/2, -7, PS_Z1 - 5) cylinder(d=4.2, h=6);
        // lighten the left part of the block, keep a 2 mm skin
        at(PS_X0 + 2, 2, PS_Z0 + 2) translate([0,-(PS_D-4),0]) cube([PI_USBC_X - (UADP[0]+0.3)/2 - PS_X0 - 4, PS_D-4, PS_Z1-PS_Z0-4]);
    }
}
if (is_undef(ASSEMBLY)) pull_switch();

// Pi Flux - hand crank generator: crank arm
// Clamp hub on the crank shaft plus an offset boss for the knob; the knob bolts through
// with M6. Prints flat (D-bore vertical), no supports.
include <crank_common.scad>

module cr_arm() {
    difference() {
        union() {
            hull() {
                cylinder(d = CR_ARM_W, h = CR_ARM_T);
                translate([CR_ARM_R, 0, 0]) cylinder(d = CR_ARM_W, h = CR_ARM_T);
            }
            translate([0, 0, 0]) cylinder(d = CR_ARM_W + 8, h = CR_ARM_T + CR_HUB_TOP);
        }
        cr_dbore(h = CR_ARM_T + CR_HUB_TOP + 2);
        // clamp slit and its screw
        translate([-1.2, CR_FLAT, -0.5]) cube([2.4, CR_BORE_D, CR_ARM_T + CR_HUB_TOP + 1]);
        translate([-(CR_ARM_W + 8)/2 - 1, CR_FLAT + 6, CR_ARM_T/2 + 1]) rotate([0, 90, 0])
            cylinder(d = 3.4, h = CR_ARM_W + 10);
        // knob bolt (head recessed in the knob) and an M6 nut trap open at the arm's
        // UNDERSIDE, so the nut can be held while the bolt is turned from above
        translate([CR_ARM_R, 0, -1]) cylinder(d = CR_GRIP_BOLT, h = CR_ARM_T + 3);
        translate([CR_ARM_R, 0, -0.1]) rotate([0, 0, 30]) cylinder(d = 11.5, h = 5.6, $fn = 6);
        // lightening slots
        for (s = [-1, 1]) hull() {
            translate([CR_ARM_R/2 - 6, s*5, -0.5]) cylinder(d = 5, h = CR_ARM_T + 1);
            translate([CR_ARM_R/2 + 10, s*5, -0.5]) cylinder(d = 5, h = CR_ARM_T + 1);
        }
    }
}

if (is_undef(ASSEMBLY)) cr_arm();

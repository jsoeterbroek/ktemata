// Pi Flux - hand crank generator: top plate
// Rotor guide bore at the centre, crank-shaft bearing boss on top, spacer-tube seats
// underneath. Prints in assembly position (plate down, boss up) — no supports: the boss
// is a plain cylinder and the bores are vertical.
include <crank_common.scad>

module cr_top_plate() {
    difference() {
        union() {
            translate([0, 0, CR_Z_TPL0]) linear_extrude(CR_PLATE_T) cr_plate2d();
            // (no seats: the spacer tubes bear directly on the plate underside, which also
            // avoids a 0.2 mm thin pad that would print badly)
            // crank bearing boss
            translate([CR_CRANK_X, 0, CR_Z_TPL1]) cylinder(d = CR_BOSS_D, h = CR_BOSS_H);
        }
        // rotor guide bore (plain bushing)
        translate([0, 0, CR_Z_TPL0 - 1]) cylinder(d = CR_TOP_BORE, h = CR_PLATE_T + 2);
        // crank shaft: 608 seat open at the boss TOP face (flush), bore down through
        translate([CR_CRANK_X, 0, CR_Z_BOSS1 - CR_BRG_T]) cylinder(d = CR_BRG_D, h = CR_BRG_T + 0.1);
        translate([CR_CRANK_X, 0, CR_Z_TPL0 - 1]) cylinder(d = CR_BORE_D, h = CR_BOSS_H + CR_PLATE_T + 2);
        // post screws from the top, counterbored
        for (p = CR_POSTS) {
            translate([p[0], p[1], CR_Z_TPL0 - 1]) cylinder(d = CR_SCREW_D, h = CR_PLATE_T + 2);
            translate([p[0], p[1], CR_Z_TPL1 - CR_CB_DEPTH + 0.1]) cylinder(d = CR_CB_D, h = CR_CB_DEPTH + 1);
        }
    }
}

if (is_undef(ASSEMBLY)) cr_top_plate();

// Pi Flux - hand crank generator: stator (coil carrier)
// Prints flat, coil windows up. The wire channel runs around the top face; the four lugs
// take the M3 post screws that clamp the whole stack together (base posts below, spacer
// tubes above). Wind the 8 coils in place, then glue/solder them into the channel.
include <crank_common.scad>

module cr_stator() {
    difference() {
        union() {
            cylinder(d = CR_STATOR_D, h = CR_STATOR_T);
            for (p = CR_POSTS) let (a = atan2(p[1], p[0]))
                rotate([0, 0, a]) hull() {
                    translate([CR_STATOR_D/2 - 12, 0, 0]) cylinder(d = CR_LUG_W, h = CR_STATOR_T);
                    translate([CR_LUG_R1, 0, 0]) cylinder(d = CR_LUG_W, h = CR_STATOR_T);
                }
        }
        // shaft clearance
        translate([0, 0, -1]) cylinder(d = CR_STATOR_BORE, h = CR_STATOR_T + 2);
        // 8 coil windows, each centred between two magnets
        for (i = [0:CR_MAG_N-1]) rotate([0, 0, i*360/CR_MAG_N + 22.5])
            hull() for (r = [CR_COIL_R0, CR_COIL_R1])
                translate([r, 0, -1]) rotate([0, 0, (r == CR_COIL_R0 ? 90 : 0)])
                    cylinder(d = CR_COIL_W, h = CR_STATOR_T + 2);
        // interconnect channel: a shallow groove around the top face
        translate([0, 0, CR_STATOR_T - CR_WIRE_D])
            rotate_extrude() translate([CR_WIRE_R, 0]) square([CR_WIRE_W, CR_WIRE_D]);
        // post screws through the lugs, and a wire exit window at -x
        for (p = CR_POSTS) translate([p[0], p[1], -1]) cylinder(d = CR_SCREW_D, h = CR_STATOR_T + 2);
        translate([CR_WIRE_EXIT, 0, -1]) cylinder(d = CR_WIRE_HOLE, h = CR_STATOR_T + 2);
    }
}

if (is_undef(ASSEMBLY)) cr_stator();

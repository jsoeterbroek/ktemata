// Pi Flux - hand crank generator: rotor disc (used twice, one flipped)
// Print flat, magnet pockets up. 8 magnet pockets on a 42 mm pitch radius, alternating
// polarity (fill by hand), 4 screws to the clamp hub, D-bore for the keyed shaft.
include <crank_common.scad>

module cr_rotor() {
    difference() {
        cylinder(d = CR_ROTOR_D, h = CR_ROTOR_T);
        for (i = [0:CR_MAG_N-1]) rotate([0, 0, i*360/CR_MAG_N])
            translate([CR_MAG_R, 0, CR_ROTOR_T - CR_MAG_DEPTH])
                cylinder(d = CR_MAG_D + CR_MAG_CLR, h = CR_MAG_DEPTH + 0.1);
        cr_dbore(h = CR_ROTOR_T + 2);
        // 4 screws up into the clamp hub
        for (i = [0:3]) rotate([0, 0, 45 + i*90])
            translate([CR_HUB_SCREW_R, 0, -1]) cylinder(d = 3.4, h = CR_ROTOR_T + 2);
        // finger notches at the rim so the glued magnets can be checked/pressed out
        for (i = [0:CR_MAG_N-1]) rotate([0, 0, i*360/CR_MAG_N])
            translate([CR_ROTOR_D/2 - 5.5, 0, -1]) cylinder(d = 3.0, h = CR_ROTOR_T + 2);
    }
}

if (is_undef(ASSEMBLY)) cr_rotor();

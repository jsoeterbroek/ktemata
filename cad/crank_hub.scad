// Pi Flux - hand crank generator: clamp hub for the rotor discs
// Two of these per rotor shaft: one above and one below each disc, pulling the disc
// between them. Print with the boss up; no supports.
include <crank_common.scad>

module cr_hub(boss=true) {
    difference() {
        union() {
            cylinder(d = CR_HUB_D, h = CR_SPACER_H);                       // body
            if (boss) translate([0, 0, -CR_HUB_BOSS_H])
                cylinder(d = CR_HUB_BOSS_D, h = CR_HUB_BOSS_H + 0.1);      // rides the 608
        }
        cr_dbore(h = CR_SPACER_H + 3);
        // pinch-clamp slit across the shaft flat
        translate([-1.2, CR_FLAT, -0.5]) cube([2.4, CR_BORE_D, CR_SPACER_H + 2]);
        // clamp screw (M3) across the slit
        translate([-CR_HUB_D/2 - 1, CR_FLAT + 5.5, CR_SPACER_H/2 + 0.6]) rotate([0, 90, 0])
            cylinder(d = 3.4, h = CR_HUB_D + 2);
        for (i = [0:3]) rotate([0, 0, 45 + i*90])
            translate([CR_HUB_SCREW_R, 0, -1]) cylinder(d = 2.7, h = CR_SPACER_H + 3);  // M3 self-tap
    }
}

if (is_undef(ASSEMBLY)) cr_hub();

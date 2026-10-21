// Pi Flux - hand crank generator: base plate with the four stator posts.
// Assembly position: plate top face z = 0, plate body below (z = -CR_PLATE_T).
// Print orientation (see export_crank.scad): posts down, plate on top of them.
// Everything is vertical, so no supports. The tray is a separate part.

include <crank_common.scad>

module cr_base_plate() {
    difference() {
        union() {
            translate([0, 0, -CR_PLATE_T]) linear_extrude(CR_PLATE_T) cr_plate2d();
            for (p = CR_POSTS) translate([p[0], p[1], 0]) cylinder(d = CR_POST_D, h = CR_POST_H);
        }
        // rotor bearing: 608 pocket open at the plate's TOP face (flush bearing), shaft
        // bore continues down through the plate
        translate([0, 0, -CR_BRG_T - 0.1]) cylinder(d = CR_BRG_D, h = CR_BRG_T + 0.1);
        translate([0, 0, -CR_PLATE_T - 0.1]) cylinder(d = CR_BORE_D, h = CR_PLATE_T + 0.2);
        // M3 heat-set inserts in the posts, open at the top
        for (p = CR_POSTS) translate([p[0], p[1], CR_POST_H - 7.6]) cylinder(d = CR_INSERT_D, h = 7.7);
        // wire drop from the stator channel into the tray
        translate([CR_WIRE_EXIT, 0, -CR_PLATE_T - 1]) cylinder(d = CR_WIRE_HOLE, h = CR_PLATE_T + 2);
        // tray screws: M3 inserts in the plate underside (open downwards)
        for (s = CR_TRAY_SCREWS)
            translate([s[0], s[1], -CR_PLATE_T - 0.1]) cylinder(d = CR_INSERT_D, h = 7.0);
        // feet: M3 inserts in the plate underside
        for (f = CR_FEET)
            translate([f[0], f[1], -CR_PLATE_T - 0.1]) cylinder(d = CR_INSERT_D, h = 7.0);
    }
}

if (is_undef(ASSEMBLY)) cr_base_plate();

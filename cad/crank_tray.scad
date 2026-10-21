// Pi Flux - hand crank generator: knob and the electronics tray with lid
// The knob body is an off-the-shelf M6 star knob where possible; this printable version
// is for the 3D-printed build. The tray holds the rectifier, buffer caps and 5 V module
// and bolts under the base plate; print it opening up, lid separately.
include <crank_common.scad>

// ---------------- crank knob (prints standing up) ----------------
module cr_knob() {
    difference() {
        union() {
            cylinder(d = 38, h = 3);                                     // washer on the arm
            translate([0, 0, 3]) cylinder(d = 20, h = CR_GRIP_L - 6);    // grip barrel
            translate([0, 0, CR_GRIP_L - 6]) sphere(d = 18);             // rounded top
        }
        translate([0, 0, -1]) cylinder(d = CR_GRIP_BOLT, h = CR_GRIP_L + 10);
        translate([0, 0, CR_GRIP_L - 9]) rotate([0, 0, 30]) cylinder(d = 11.5, h = 9, $fn = 6);
    }
}

// ---------------- electronics tray ----------------
module cr_tray() {
    difference() {
        union() {
            // solid outer shell
            translate([CR_BOX_X0, CR_BOX_Y0, CR_Z_TRAY0]) linear_extrude(CR_BOX_H)
                cr_rrect(CR_BOX_X1 - CR_BOX_X0, CR_BOX_Y1 - CR_BOX_Y0, 3);
            // lid bosses stand inside, up from the floor
            for (s = CR_TRAY_SCREWS) translate([s[0], s[1], CR_Z_TRAY0])
                cylinder(d = 7, h = CR_BOX_H - CR_BOX_FLOOR);
        }
        // cavity, cut 0.01 above the floor so floor and walls stay one solid
        translate([CR_BOX_X0 + CR_BOX_WALL, CR_BOX_Y0 + CR_BOX_WALL, CR_Z_TRAY0 + CR_BOX_FLOOR])
            linear_extrude(CR_BOX_H) cr_rrect(CR_BOX_X1 - CR_BOX_X0 - 2*CR_BOX_WALL,
                                             CR_BOX_Y1 - CR_BOX_Y0 - 2*CR_BOX_WALL, 1.5);
        // plate screws, up through the floor into the plate inserts
        for (s = CR_TRAY_SCREWS) translate([s[0], s[1], CR_Z_TRAY0 - 1])
            cylinder(d = CR_SCREW_D, h = CR_BOX_H + 2);
        // electronics mounting holes (M2.5 self-tapping)
        for (m = [[CR_BOX_X0+12, -20], [CR_BOX_X0+12, 20], [CR_BOX_X1-12, -12], [CR_BOX_X1-12, 12]])
            translate([m[0], m[1], CR_Z_TRAY0 - 1]) cylinder(d = 2.8, h = CR_BOX_FLOOR + 2);
        // pigtail gland in the -x wall
        translate([CR_BOX_X0 + CR_BOX_WALL, 0, CR_Z_CABLE]) rotate([0, 90, 0])
            cylinder(d = CR_CABLE_D, h = CR_BOX_WALL + 2);
        // wire entry from the base plate above
        translate([CR_WIRE_EXIT, 0, CR_Z_TRAY0 - 1]) cylinder(d = CR_WIRE_HOLE, h = CR_BOX_FLOOR + 2);
    }
}

// ---------------- tray lid ----------------
module cr_lid() {
    difference() {
        translate([CR_BOX_X0, CR_BOX_Y0, CR_Z_TRAY0 - CR_BOX_LID_T]) linear_extrude(CR_BOX_LID_T)
            cr_rrect(CR_BOX_X1 - CR_BOX_X0, CR_BOX_Y1 - CR_BOX_Y0, 3);
        for (s = CR_TRAY_SCREWS) translate([s[0], s[1], CR_Z_TRAY0 - CR_BOX_LID_T - 1])
            cylinder(d = CR_SCREW_D, h = CR_BOX_LID_T + 2);
        // ventilation slot over the rectifier
        translate([CR_BOX_X0 + 8, -14, CR_Z_TRAY0 - CR_BOX_LID_T - 1]) linear_extrude(CR_BOX_LID_T + 2)
            cr_rrect(20, 28, 3);
    }
}

// ---------------- feet ----------------
module cr_foot() difference() {
    hull() {
        translate([0, 0, 0]) cylinder(d = CR_FOOT_D + 4, h = 2);
        translate([0, 0, 2]) cylinder(d = CR_FOOT_D, h = CR_FOOT_H - 2);
    }
    translate([0, 0, -1]) cylinder(d = CR_FOOT_SCREW, h = CR_FOOT_H + 2);
    translate([0, 0, CR_FOOT_H - 6]) rotate([0, 0, 30]) cylinder(d = 11.5, h = 7, $fn = 6);  // M3 nut trap
}

if (is_undef(ASSEMBLY)) cr_tray();

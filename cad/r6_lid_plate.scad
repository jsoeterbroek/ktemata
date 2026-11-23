// Ktemata R6 - keyboard lid plate
//
// This is the HOST LID plate, not the 7-inch display mount: R6's Waveshare panel belongs to the
// separate cassette deck. The K06 and its keys finish flush with the broad front face. The rear
// face tapes into the Peli lid. No host hole, OLED opening, button opening or harness channel.
//
// Prototype fit part: keyboard positions are shared with paint_probe_r6.scad through common.scad.
// Measure the actual lid and keyboard before painting or final assembly.
//
// Coordinates: x left->right, drawing y = 0 at the hinge, z = 0 at the rear/tape face and z = 15
// at the visible front. PRINT VISIBLE-FRONT DOWN (export.scad flips about x). The open keyboard
// recess and its 45-degree ledges print without support in that orientation.
include <common.scad>

module r6_lid_box(x0, y0, x1, y1, z, h)
    translate([x0, R6_LID_L-y1, z]) cube([x1-x0, y1-y0, h]);

module r6_lid_outline() rrect(R6_LID_W, R6_LID_L, R6_LID_R);
module r6_lid_slab() linear_extrude(R6_LID_T) r6_lid_outline();

// K06 through-opening, with the measured rounded outline and fitting clearance.
module r6_lid_kb_prism(z, h) {
    translate([R5_KB_X0, R6_LID_L-R5_KB_Y0-R5_KB_POCKET[1], z])
        linear_extrude(h)
            rrect(R5_KB_POCKET[0], R5_KB_POCKET[1], R5_KB_CORNER+R5_KB_CLR);
}
module r6_lid_kb_cut() r6_lid_kb_prism(-1, R6_LID_T+2);

// Two keyboard seat ledges, one on each long wall. The body rests at z = 4 and its keys finish
// at z = 15. The ledge's 45-degree underside prints cleanly when the front is on the bed; the
// 0.8 mm overlap into the wall prevents a tangent/non-manifold union.
module r6_lid_kb_ledge(y_in, s) {
    e = 0.05;
    ov = 0.8;
    zb = R6_LID_KB_SEAT_Z-R5_KB_SEAT;
    ya = s > 0 ? y_in-ov : y_in-R5_KB_SEAT;
    yb = s > 0 ? y_in+R5_KB_SEAT : y_in+ov;
    x0 = R5_KB_SEAT_X0;
    x1 = R5_KB_SEAT_X1;
    hull() {
        if (s > 0) r6_lid_box(x0, y_in-ov, x1, y_in+e, zb, R5_KB_SEAT);
        else       r6_lid_box(x0, y_in-e, x1, y_in+ov, zb, R5_KB_SEAT);
        r6_lid_box(x0, ya, x1, yb, R6_LID_KB_SEAT_Z-e, e);
    }
}

module r6_lid_plate() union() {
    // Cut the K06 opening before adding its ledges, so no floor appears across the opening.
    difference() {
        r6_lid_slab();
        r6_lid_kb_cut();
    }
    r6_lid_kb_ledge(R5_KB_Y0, 1);
    r6_lid_kb_ledge(R5_KB_Y0+R5_KB_POCKET[1], -1);
}

if (is_undef(ASSEMBLY)) r6_lid_plate();

// Ktemata R6 - keyboard / status-OLED lid plate
//
// This is the HOST LID plate, not the 7-inch display mount: R6's Waveshare panel belongs to the
// separate cassette display frame. The K06 and its keys finish flush with the broad front face;
// the OLED and PBS-33B sit in that same face. The rear face tapes into the Peli lid. No host hole.
//
// Prototype fit part: positions are shared with paint_probe_r6.scad through common.scad. Measure
// the actual lid and components before painting or final assembly.
//
// Coordinates: x left->right, drawing y = 0 at the hinge, z = 0 at the rear/tape face and z = 15
// at the visible front. PRINT VISIBLE-FRONT DOWN (export.scad flips about x). The open keyboard
// recess and its 45-degree ledges, the rear OLED/button pockets and the rear harness channels all
// print without support in that orientation.
include <common.scad>

module r6_lid_at(x, y, z=0) translate([x, R6_LID_L-y, z]) children();
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

// OLED: the glass window passes through the visible front; the larger pcb pocket opens at the
// rear and stops at the seat. This preserves R5's measured glass recess (1.85 mm below the face).
// Use thin adhesive pads on the two end seats; the rear opening provides service access.
module r6_lid_oled_window() {
    r6_lid_box(R5_OLED_WIN_X0, R5_OLED_WIN_Y0,
               R5_OLED_WIN_X0+R5_OLED_WIN[0], R5_OLED_WIN_Y0+R5_OLED_WIN[1],
               R6_LID_OLED_SEAT_Z, R6_LID_T-R6_LID_OLED_SEAT_Z+1);
}
module r6_lid_oled_pocket() {
    r6_lid_box(R5_OLED_X0, R5_OLED_Y0,
               R5_OLED_X0+R5_OLED_PCB[0], R5_OLED_Y0+R5_OLED_PCB[1],
               -1, R6_LID_OLED_SEAT_Z+1.02);
}

// PBS-33B: through-hole plus a rear spot-face that leaves 2.5 mm of panel for its short thread.
module r6_lid_oled_button() {
    r6_lid_at(R5_OLED_BTN_X, R5_OLED_BTN_Y, -1)
        cylinder(d=R5_OLED_BTN_D, h=R6_LID_T+2);
    r6_lid_at(R5_OLED_BTN_X, R5_OLED_BTN_Y, -1)
        cylinder(d=R5_OLED_BTN_CB_D, h=R6_LID_OBTN_CB_T+1);
}

// Rear-only channels for the five-conductor lid harness. The main run joins the OLED pocket to
// the hinge edge; a branch reaches the button's rear spot-face. Neither marks the visible face.
module r6_lid_harness_channels() {
    r6_lid_box(R6_LID_HARNESS_X, -1,
               R6_LID_HARNESS_X+R6_LID_HARNESS_W, R5_OLED_Y0+4,
               -1, R6_LID_HARNESS_D+1);
    r6_lid_box(R6_LID_HARNESS_X, R5_OLED_BTN_Y-R6_LID_HARNESS_W/2,
               R5_OLED_BTN_X+2, R5_OLED_BTN_Y+R6_LID_HARNESS_W/2,
               -1, R6_LID_HARNESS_D+1);
}

module r6_lid_plate() difference() {
    union() {
        // Cut the K06 opening before adding its ledges, so no floor appears across the opening.
        difference() {
            r6_lid_slab();
            r6_lid_kb_cut();
        }
        r6_lid_kb_ledge(R5_KB_Y0, 1);
        r6_lid_kb_ledge(R5_KB_Y0+R5_KB_POCKET[1], -1);
    }
    r6_lid_oled_window();
    r6_lid_oled_pocket();
    r6_lid_oled_button();
    r6_lid_harness_channels();
}

if (is_undef(ASSEMBLY)) r6_lid_plate();

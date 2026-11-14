// Ktemata r5 - display plate for the inside of the host lid
//
// The display hangs on the lid, glass towards the base, so opening the case shows it like the
// r4 face. This plate carries it: four M2.5 go through the plate into the Touch Display 2's own
// standoffs (pattern in common.scad), and the plate itself is fixed to the host lid with 3M VHB
// tape. No hole through the host case, so the host keeps its IP rating.
//
// Print flat, as modelled: z = 0 is the lid/tape side and the bed face; z = R5_LID_T is the
// standoff seat, so the glass finishes at R5_DISP_DEEP like the cover's. There is nothing to
// support.
include <common.scad>

module plate2d() rrect(R5_LID_PLATE[0], R5_LID_PLATE[1], 8);

module plate() linear_extrude(R5_LID_T) plate2d();

// ---- DIN 7991 M2.5 x 8: 90-degree seats on the lid/tape side, flush with the tape face ----
module screw_cut(p) {
    translate([p[0], p[1], -1]) cylinder(d=M25_CLR, h=R5_LID_T + 2);
    translate([p[0], p[1], -0.01]) cylinder(d1=M25_CSK, d2=M25_CLR, h=M25_CSK_T + 0.02);
}

// ---- relief for the display's ribbon ----
// The lead leaves the panel's rear and has to turn towards the hinge and tray without being
// pinched between plate and panel. The notch is the cover's own cable route (R5_CABLE_*, a cover
// coordinate), shifted into this plate's frame, which sits 6 mm outside the panel.
module cable_relief() {
    translate([R5_CABLE_X0 - PANEL_X + 6, -1, -1])
        cube([R5_CABLE_W, 1.01 + 10, R5_LID_T + 2]);
}

// ---- finger slots: 10 mm holes to lift the assembly off the lid tape line ----
module finger_slots() for (x=[14, R5_LID_PLATE[0] - 24])
    translate([x, R5_LID_PLATE[1] - 10, -1]) cylinder(d=10, h=R5_LID_T + 2);

module r5_lid_plate() difference() {
    plate();
    for (p=R5_DISP_HOLES) screw_cut([p[0] + 6, p[1] + 6]);
    cable_relief();
    finger_slots();
}

if (is_undef(ASSEMBLY)) r5_lid_plate();

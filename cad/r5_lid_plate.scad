// Ktemata r5 - display plate for the inside of the host lid
//
// The display hangs on the lid, glass towards the base, so opening the case shows it like the
// r4 face. This plate carries it: four M3 go through the plate into the Waveshare's rear M3
// inserts (pattern in common.scad), and the plate itself is fixed to the host lid with 3M VHB
// tape. No hole through the host case, so the host keeps its IP rating.
//
// Print flat, as modelled: z = 0 is the lid/tape side and the bed face; z = R5_LID_T is the
// display's PCB seat. There is nothing to support.
include <common.scad>

assert(R5, "r5 parts need -D R5=true");

module plate2d() rrect(R5_LID_PLATE[0], R5_LID_PLATE[1], 8);

module plate() linear_extrude(R5_LID_T) plate2d();

// ---- screw pockets: heads counterbored on the lid/tape side, flush with the tape face ----
module screw_cut(p) {
    translate([p[0], p[1], -1]) cylinder(d=M3_CLR, h=R5_LID_T + 2);
    translate([p[0], p[1], -0.01]) cylinder(d=M3_HEAD, h=1.6);       // counterbore, lid side
}

// Blind reliefs for the unused 58 x 49 Pi standoffs; a 0.5 mm tape-side skin remains.
module post_relief(p) translate([p[0], p[1], R5_LID_T - R5_PANEL_STUD])
    cylinder(d=5.8, h=R5_PANEL_STUD + 0.1);

// ---- relief for the display's ribbon and GPIO leads ----
// Both leave the right-hand rear PCB area; the plate is cut back over them so they can turn
// towards the hinge and tray without being pinched between plate and panel.
module cable_relief() {
    // 6 mm in, because the plate carries a 6 mm border round the panel
    translate([6 + R5_CABLE_X0, -1, -1]) cube([R5_CABLE_W, 1.01 + 10, R5_LID_T + 2]);
}

// ---- finger slots: 10 mm holes to lift the assembly off the lid tape line ----
module finger_slots() for (x=[14, R5_LID_PLATE[0] - 24])
    translate([x, R5_LID_PLATE[1] - 10, -1]) cylinder(d=10, h=R5_LID_T + 2);

module r5_lid_plate() difference() {
    plate();
    for (p=R5_DISP_HOLES) screw_cut([p[0] + 6, p[1] + 6]);
    for (p=R5_DISP_POSTS) post_relief([p[0] + 6, p[1] + 6]);
    cable_relief();
    finger_slots();
}

if (is_undef(ASSEMBLY)) r5_lid_plate();

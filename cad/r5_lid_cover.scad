// Ktemata r5 - lid cover: Touch Display 2 (7") bezel
//
// The cassette holds the electronics in the base; this is the other half. A cover taped into
// the host lid that carries the Raspberry Pi Touch Display 2 (7").
//
//   openscad -D R5=true cad/r5_lid_cover.scad                   # the default build
//   openscad -D R5=true -D 'HOST="1400"' cad/r5_lid_cover.scad   # the larger host
//
// Orientation as modelled: z = 0 is the LID side (the tape face and the print bed) and z grows
// into the case. So the plate is on the bed, the bezel rises off it, and the panel drops in
// from the interior side. Print it exactly like this - every wall is vertical, so no supports.
//
// The vertical stack is the TD2's own, and matches r5_lid_plate so the two are interchangeable:
//   plate 0..COVER_T, the panel's standoff base on the plate, 8.5 mm standoffs, 6.42 mm panel
//   body, and the glass right at the top. The panel is held by four M2.5 through the plate into
//   its standoffs - not by a lip, because the module outline is the glass outline (189.32 x
//   120.24) and there is no frame to trap.
//
// Panel numbers all come from common.scad, so the cover cannot disagree with the cassette:
//   module                189.32 x 120.24, corners R8   (R5_PANEL)
//   image                 154.6 x 86.9                   (R5_PANEL_ACTIVE, 720 x 1280 on 7.0")
//   body behind the glass  6.42                          (DISP_T_R2)
//   standoffs             168.55 x 99.71, 8.5 mm tall    (R5_DISP_HOLES, DISP_POST)
//   panel position        centred in both axes           (R5_DISP_X0/Y0)
//
// There is no power button here any more. A centred 7" panel leaves 28.93 mm of latch band and a
// 16 mm IP67 button needs 34.2 mm, so the button moved to the deck's right rail (R5_BTN_*).
include <common.scad>

assert(R5, "r5 parts need -D R5=true");

// ---------------- guards ----------------
// The values themselves are in common.scad (see the note there); these are the checks that make
// a bad host or a bad bezel a build error instead of a print.
assert(R5_PANEL[0] + 2*COVER_FRAME + 4 <= COVER_W,
       str("host ", HOST, ": ", COVER_W, " mm cover, the panel + bezel needs ",
           R5_PANEL[0] + 2*COVER_FRAME + 4));
assert(R5_PANEL[1] + 2*COVER_FRAME + 4 <= COVER_L,
       str("host ", HOST, ": ", COVER_L, " mm cover, the panel + bezel needs ",
           R5_PANEL[1] + 2*COVER_FRAME + 4));
assert(COVER_GAP < (R5_PANEL[0] - R5_PANEL_ACTIVE[0])/2
       && COVER_GAP < (R5_PANEL[1] - R5_PANEL_ACTIVE[1])/2,
       "COVER_GAP must stay inside the glass border, or the bezel crops the image");
assert(COVER_GLASS_Z + COVER_PROUD <= HOST_LID - 4,
       str("host ", HOST, ": lid ", HOST_LID, " mm, the cover + panel needs ",
           COVER_GLASS_Z + COVER_PROUD + 4));
// The cable notch has to be able to reach the bezel wall from inside the well and still leave
// the plate whole round the panel: the bezel is the only thing it should cut.
assert(PANEL_Y > COVER_FRAME, "the panel's hinge-side bezel would reach the cover edge");

// ---------------- geometry ----------------
module cover_outline() rrect(COVER_W, COVER_L, COVER_R);

// The module footprint and the bezel opening around it, both at the panel's position.
module panel_2d(pad=0) translate([PANEL_X, PANEL_Y])
    rrect(R5_PANEL[0] + 2*pad, R5_PANEL[1] + 2*pad, R5_PANEL[2]);

// Plate plus bezel: the plate is solid (it is the tape face and the lid-side skin), the bezel
// is a ring standing up around the panel well.
module cover_body() {
    linear_extrude(COVER_T) cover_outline();
    // 0.8 mm sink so the ring and the plate interpenetrate properly: a tangent contact is below
    // CGAL's tolerance and exports as a separate solid (>= 0.5 mm per AGENTS.md)
    translate([0, 0, COVER_T - 0.8]) linear_extrude(COVER_RIM_H + 0.8)
        difference() {
            translate([PANEL_X, PANEL_Y]) offset(COVER_FRAME)
                rrect(R5_PANEL[0] + 2*COVER_GAP, R5_PANEL[1] + 2*COVER_GAP, R5_PANEL[2]);
            panel_2d(COVER_GAP);
        }
}

// The panel well: everything inside the bezel, from the plate surface up and out. The panel's
// standoffs stand on the plate, so the well floor is the plate itself.
module panel_well() translate([0, 0, COVER_T - 0.5])
    linear_extrude(COVER_RIM_H + 1.2) panel_2d(COVER_GAP);

// Screws: M2.5 through the plate into the panel's own standoffs, heads counterbored on the lid
// side so the tape face stays flat.
module panel_screws() for (p=R5_DISP_HOLES) translate([PANEL_X + p[0], PANEL_Y + p[1], 0]) {
    cylinder(d=M25_CLR, h=COVER_T + 1);
    translate([0, 0, -0.01]) cylinder(d=M25_HEAD, h=1.6);
}

// Panel leads: the DSI/GPIO ribbon leaves at the panel's hinge-side long edge and turns down
// into the base. The cover is taped to the lid, so the ribbon cannot pass under it: the notch has
// to run from the panel's edge out through the bezel wall AND the plate to the cover's own hinge
// edge, and the ribbon then crosses the narrow strip of bare lid to the hinge. It is a notch in
// the edge, not a slit, so the plate stays one piece - 46 mm of the 233.5 mm edge.
module cable_relief() {
    translate([PANEL_X + R5_CABLE_X0, -1, -1])
        cube([R5_CABLE_W, PANEL_Y - COVER_GAP + 1.01, COVER_T + COVER_RIM_H + 2]);
}

// Finger slots to lift the cover off the lid tape - in the latch band, clear of the motto.
module finger_slots() for (x=[COVER_FRAME + 11, COVER_W - COVER_FRAME - 11])
    translate([x, COVER_L - COVER_FRAME - 5, -1]) cylinder(d=10, h=COVER_T + 2);

module r5_lid_cover() difference() {
    cover_body();
    panel_well();
    panel_screws();
    cable_relief();
    finger_slots();
}

if (is_undef(ASSEMBLY)) r5_lid_cover();

// Ktemata r5 - lid cover: Touch Display 2 bezel + power button
//
// The cassette holds the electronics in the base; this is the other half. A cover taped into
// the host lid that carries the Raspberry Pi Touch Display 2 (5") and adds a power button in
// the bezel at the latch end.
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
//   its standoffs - not by a lip, because the module outline is the glass outline (143.4 x
//   91.46) and there is no frame to trap.
//
// Panel numbers all come from common.scad, so the cover cannot disagree with the cassette:
//   glass                 143.4 x 91.46, corners R5      (DISP_W, DISP_H, DISP_R)
//   image                 110.7 x 62.3 landscape         (720 x 1280 on 5.0")
//   body behind the glass  6.42                            (DISP_T_R2)
//   standoffs             122.74 x 72.96, 8.5 mm tall      (R5_DISP_HOLES, DISP_POST)
include <common.scad>

assert(R5, "r5 parts need -D R5=true");

// ---------------- guards ----------------
// The values themselves are in common.scad (see the note there); these are the checks that make
// a bad host or a bad bezel a build error instead of a print.
assert(COVER_BAND >= COVER_BTN_D + 2*COVER_BTN_EDGE,
       str("host ", HOST, ": the latch band is ", COVER_BAND, " mm, the button needs ",
           COVER_BTN_D + 2*COVER_BTN_EDGE, " mm; reduce COVER_FRAME or use HOST=\"1400\""));
assert(DISP_W + 2*COVER_FRAME + 4 <= COVER_W,
       str("host ", HOST, ": ", COVER_W, " mm cover, the panel + bezel needs ",
           DISP_W + 2*COVER_FRAME + 4));
assert(COVER_GAP < (DISP_W - COVER_ACTIVE[0])/2,
       "COVER_GAP must stay inside the glass border, or the bezel crops the image");
assert(COVER_GLASS_Z + COVER_PROUD <= HOST_LID - 4,
       str("host ", HOST, ": lid ", HOST_LID, " mm, the cover + panel needs ",
           COVER_GLASS_Z + COVER_PROUD + 4));

// ---------------- geometry ----------------
module cover_outline() rrect(COVER_W, COVER_L, COVER_R);

// The module footprint and the bezel opening around it, both at the panel's position.
module panel_2d(pad=0) translate([PANEL_X, PANEL_Y])
    rrect(DISP_W + 2*pad, DISP_H + 2*pad, DISP_R);

// Plate plus bezel: the plate is solid (it is the tape face and the lid-side skin), the bezel
// is a ring standing up around the panel well.
module cover_body() {
    linear_extrude(COVER_T) cover_outline();
    // 0.8 mm sink so the ring and the plate interpenetrate properly: a tangent contact is below
    // CGAL's tolerance and exports as a separate solid (>= 0.5 mm per AGENTS.md)
    translate([0, 0, COVER_T - 0.8]) linear_extrude(COVER_RIM_H + 0.8)
        difference() {
            translate([PANEL_X, PANEL_Y]) offset(COVER_FRAME)
                rrect(DISP_W + 2*COVER_GAP, DISP_H + 2*COVER_GAP, DISP_R);
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

// Power button: a through-hole, with a recess for the nut cut from the *interior* face. The
// lid face is the print bed, so a counterbore there would need support; the nut instead seats
// inside the boss that button_boss() adds on the interior side.
module button_cut() {
    translate([COVER_BTN_X, COVER_BTN_Y, -1])
        cylinder(d=COVER_BTN_D, h=COVER_T + COVER_BTN_NUT + COVER_BTN_BOSS + 2);
    translate([COVER_BTN_X, COVER_BTN_Y, COVER_T - 0.5])
        cylinder(d=COVER_BTN_BODY, h=COVER_BTN_NUT + COVER_BTN_BOSS + 2);
}

module button_boss() translate([COVER_BTN_X, COVER_BTN_Y, COVER_T - 0.8])
    cylinder(d=COVER_BTN_BODY + 2*COVER_BTN_WALL, h=COVER_BTN_NUT - 0.8 + COVER_BTN_BOSS);

// Panel leads: the DSI/GPIO ribbon leaves at one long edge and turns down into the base. The
// notch is on the hinge edge, where the cassette's own cable path starts, and it cuts through
// the bezel so the ribbon does not have to fold under it.
module cable_relief() {
    translate([PANEL_X - COVER_GAP, -1, -1])
        cube([46, COVER_FRAME + COVER_GAP + 1.01, COVER_T + COVER_RIM_H + 2]);
}

// Finger slots to lift the cover off the lid tape - in the latch band, clear of the button.
module finger_slots() for (x=[COVER_W - 46, COVER_W - 24])
    translate([x, COVER_L - COVER_BTN_EDGE, -1]) cylinder(d=10, h=COVER_T + 2);

module r5_lid_cover() difference() {
    union() {
        cover_body();
        button_boss();
    }
    panel_well();
    panel_screws();
    cable_relief();
    finger_slots();
    // button last, after the boss: a hole cut before the boss is added gets filled again
    button_cut();
}

if (is_undef(ASSEMBLY)) r5_lid_cover();

// Ktemata r5 - lid cover: Waveshare 7inch DSI LCD (C) bezel
//
// The cassette holds the electronics in the base; this is the other half. A cover taped into
// the host lid that carries the Waveshare 7inch DSI LCD (C), 1024 x 600.
//
//   openscad -D R5=true cad/r5_lid_cover.scad                   # the default build
//   openscad -D R5=true -D 'HOST="1400"' cad/r5_lid_cover.scad   # the larger host
//
// Orientation as modelled: z = 0 is the LID side (the tape face and the print bed) and z grows
// into the case. So the plate is on the bed, the bezel rises off it, and the panel drops in
// from the interior side. Print it exactly like this - every wall is vertical, so no supports.
//
// The vertical stack is the Waveshare's own, and matches r5_lid_plate so the two are
// interchangeable:
//   plate 0..COVER_T, the PCB back on the plate, 10.50 mm to the glass; the bezel rises to the
//   glass plane, so the screen is flush with the cover's front. The panel is held by four M3
//   through the plate into its rear inserts - not by a lip, because the module outline is the
//   glass outline (192.96 x 110.76) and a lip would stand proud of the glass.
//
// Panel numbers all come from common.scad, so the cover cannot disagree with the cassette:
//   module                192.96 x 110.76, corners R8   (R5_PANEL)
//   image                 154.88 x 86.72                 (R5_PANEL_ACTIVE, 1024 x 600)
//   glass to PCB back      10.50                         (R5_PANEL_DEPTH)
//   M3 inserts            126.25 x 65.49 span            (R5_DISP_HOLES)
//   Pi standoffs (unused) 58 x 49, 3.5 mm behind the PCB (R5_DISP_POSTS, R5_PANEL_STUD)
//   panel position        centred in both axes           (PANEL_X/Y)
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

// The display's PCB back sits on the plate, so the plate stays whole under the panel; the bezel
// is the ring around the glass. The panel is held by M3 screws through the plate into its rear
// inserts, heads counterbored on the lid side so the tape face stays flat.
module panel_screws() for (p=R5_DISP_HOLES) translate([PANEL_X + p[0], PANEL_Y + p[1], 0]) {
    cylinder(d=M3_CLR, h=COVER_T + 1);
    translate([0, 0, -0.01]) cylinder(d=M3_HEAD, h=1.6);
}

// The display's unused 58 x 49 Pi standoffs (M2.5, 5.5 mm OD) protrude 3.5 mm behind its PCB;
// blind reliefs keep the PCB flat on the plate without breaking the tape face.
module post_reliefs() for (p=R5_DISP_POSTS)
    translate([PANEL_X + p[0], PANEL_Y + p[1], COVER_T - R5_PANEL_STUD])
        cylinder(d=5.8, h=R5_PANEL_STUD + 0.1);

// Panel leads: the Waveshare's DSI FPC leaves at the centre of its hinge-side long edge; the
// 4-pin 5 V/I2C lead leaves at the opposite right corner and is routed inside the case. The
// cover is taped to the lid, so the FPC cannot pass under it: the notch runs from the panel's
// edge out through the bezel wall AND the plate to the cover's own hinge edge, and the FPC then
// crosses the narrow strip of bare lid to the hinge. It is a notch in the edge, not a slit, so
// the plate stays one piece - 46 mm of the 233.5 mm edge.
module cable_relief() {
    translate([PANEL_X + R5_CABLE_X0, -1, -1])
        cube([R5_CABLE_W, PANEL_Y - COVER_GAP + 1.01, COVER_T + COVER_RIM_H + 2]);
}

// Finger slots to lift the cover off the lid tape - in the latch band, clear of the motto.
module finger_slots() for (x=[COVER_FRAME + 11, COVER_W - COVER_FRAME - 11])
    translate([x, COVER_L - COVER_FRAME - 5, -1]) cylinder(d=10, h=COVER_T + 2);

module r5_lid_cover() difference() {
    cover_body();
    panel_screws();
    post_reliefs();
    cable_relief();
    finger_slots();
}

if (is_undef(ASSEMBLY)) r5_lid_cover();

// Ktemata r5 - lid cover: recessed Raspberry Pi Touch Display 2, 5"
//
// The cassette holds the electronics in the base; this is the other half. A full-face cover taped
// into the host lid carries the Raspberry Pi Touch Display 2, 5", the same panel r4 hangs.
//
//   openscad cad/r5_lid_cover.scad                   # the default build
//   openscad -D 'HOST="1400"' cad/r5_lid_cover.scad   # the larger host
//
// Orientation as modelled: z = 0 is the LID side (the tape face and the print bed) and z grows
// into the case. The rear mounting skin is on the bed and the display recess opens upwards.
// Print it exactly like this - every wall is vertical, so no supports.
//
// The vertical stack is the TD2's own, and matches r5_lid_plate so the two are interchangeable:
//   rear skin 0..COVER_T, the four standoff end faces seat at COVER_T, glass and the ENTIRE broad
//   cover front at COVER_FRONT_Z. The display drops into a 14.92 mm recess instead of sitting on a
//   thin plate inside a raised rim. Four M2.5 screws pass through the rear skin into the display's
//   own standoffs; no retaining lip stands over or proud of the glass.
//
// The 7" Waveshare build is a separate part: ktemata_r5_lid_cover_waveshare_7in, modelled by
// cad/r5_lid_cover_waveshare_7in.scad from its own panel numbers and connector reliefs.
//
// Panel numbers all come from common.scad, so the cover cannot disagree with the cassette:
//   body/glass outline   143.4 x 91.46, corners R5     (R5_PANEL)
//   image                110.7 x 62.3                  (R5_PANEL_ACTIVE, 720 x 1280)
//   glass to the seat    14.92 = 6.42 body + 8.5 studs  (R5_PANEL_DEPTH)
//   M2.5 standoffs       122.74 x 72.96, the mount      (R5_DISP_HOLES)
//   panel position       centred in both axes           (PANEL_X/Y)
//   recess opening       the body + 1.0 mm a side       (COVER_GAP)
//
// There is no power button here any more. A centred 7" panel (what this cover carried while the
// Waveshare build was the default) leaves 28.93 mm of latch band and a 16 mm IP67 button needs
// 34.2 mm, so the button moved to the deck's right rail (R5_BTN_*).
include <common.scad>

// ---------------- guards ----------------
// The values themselves are in common.scad (see the note there); these are the checks that make
// a bad host or an inadequate display border a build error instead of a print.
assert(R5_PANEL[0] + 2*COVER_FRAME + 4 <= COVER_W,
       str("host ", HOST, ": ", COVER_W, " mm cover, the panel + minimum front border needs ",
           R5_PANEL[0] + 2*COVER_FRAME + 4));
assert(R5_PANEL[1] + 2*COVER_FRAME + 4 <= COVER_L,
       str("host ", HOST, ": ", COVER_L, " mm cover, the panel + minimum front border needs ",
           R5_PANEL[1] + 2*COVER_FRAME + 4));
assert(COVER_GAP < (R5_PANEL[0] - R5_PANEL_ACTIVE[0])/2
       && COVER_GAP < (R5_PANEL[1] - R5_PANEL_ACTIVE[1])/2,
       "COVER_GAP must stay inside the glass border, or the front opening crops the image");
assert(COVER_FRONT_Z + 4 <= HOST_LID,
       str("host ", HOST, ": lid ", HOST_LID, " mm, the recessed cover + lead fold needs ",
           COVER_FRONT_Z + 4));
// The cable notch must reach the recess from the hinge edge without severing the cover.
assert(PANEL_Y > COVER_FRAME, "the panel's hinge-side front border would reach the cover edge");
assert(R5_CABLE_X0 >= PANEL_X - COVER_GAP
       && R5_CABLE_X0 + R5_CABLE_W <= PANEL_X + R5_PANEL[0] + COVER_GAP,
       "the cable notch must stay inside the display recess");

// ---------------- geometry ----------------
module cover_outline() rrect(COVER_W, COVER_L, COVER_R);

// The module footprint and its clearance opening, both at the panel's position.
module panel_2d(pad=0) translate([PANEL_X - pad, PANEL_Y - pad])
    rrect(R5_PANEL[0] + 2*pad, R5_PANEL[1] + 2*pad, R5_PANEL[2] + pad);

// Full-height front panel with a blind display recess. The cut starts at COVER_T, leaving the
// rear mounting skin intact, and over-runs the front by 1 mm for a clean boolean. The opening
// matches the body outline plus clearance; there is no raised rim or lip over the display.
module cover_body() difference() {
    linear_extrude(COVER_FRONT_Z) cover_outline();
    translate([0, 0, COVER_T])
        linear_extrude(COVER_FRONT_Z - COVER_T + 1) panel_2d(COVER_GAP);
}

// The display's standoff end faces sit on the rear skin at COVER_T. Four DIN 7991 M2.5 x 8 screws
// pass through that skin into them: 2.65 mm of skin, then 4 mm of the standoff's thread. Their
// countersunk heads use the same 90-degree seats as the deck, opening on the lid side so the tape
// face stays flat. M2.5 x 10 is 2 mm further in - fine if your standoffs are tapped through, and
// it will bottom out if they are not.
module panel_screws() for (p=R5_DISP_HOLES) translate([PANEL_X + p[0], PANEL_Y + p[1], 0]) {
    cylinder(d=M25_CLR, h=COVER_T + 1);
    translate([0, 0, -0.01]) cylinder(d1=M25_CSK, d2=M25_CLR, h=M25_CSK_T + 0.02);
}

// Panel leads: the DSI lead leaves the panel's rear and has to reach the hinge edge from the
// covered face. The cover is taped to the lid, so the FPC cannot pass under it: the notch is a
// full-height slot from the recess edge out to the hinge edge, 20 mm wide at the case-side
// position (R5_CABLE_*, a cover coordinate - it has to line up with the deck and tray openings,
// not with the panel). It over-runs the recess edge by 1.5 mm, so no web remains.
module cable_relief() {
    translate([R5_CABLE_X0, -1, -1])
        cube([R5_CABLE_W, PANEL_Y - COVER_GAP + 1.5, COVER_FRONT_Z + 2]);
}

module r5_lid_cover() difference() {
    cover_body();
    panel_screws();
    cable_relief();
}

// Thin dimension template: the four standoff positions and the cable notch are through-cuts.
// Keep the display seat solid so the pattern can be tested; the recess is omitted, because the
// template is thinner than the display is deep.
module r5_lid_cover_test_dimensions() difference() {
    linear_extrude(COVER_TEST_T) cover_outline();
    for (p=R5_DISP_HOLES)
        translate([PANEL_X + p[0], PANEL_Y + p[1], -1]) cylinder(d=M25_CLR, h=COVER_TEST_T + 2);
    cable_relief();
}

if (is_undef(ASSEMBLY)) r5_lid_cover();

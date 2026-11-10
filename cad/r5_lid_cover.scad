// Ktemata r5 - lid cover: recessed Waveshare 7inch DSI LCD (C)
//
// The cassette holds the electronics in the base; this is the other half. A full-face cover taped
// into the host lid carries the Waveshare 7inch DSI LCD (C), 1024 x 600.
//
//   openscad -D R5=true cad/r5_lid_cover.scad                   # the default build
//   openscad -D R5=true -D 'HOST="1400"' cad/r5_lid_cover.scad   # the larger host
//
// Orientation as modelled: z = 0 is the LID side (the tape face and the print bed) and z grows
// into the case. The rear mounting skin is on the bed and the display recess opens upwards.
// Print it exactly like this - every wall is vertical, so no supports.
//
// The vertical stack is the Waveshare's own, and matches r5_lid_plate so the two are
// interchangeable:
//   rear skin 0..COVER_T, PCB back at COVER_T, glass and the ENTIRE broad cover front at
//   COVER_FRONT_Z. The display drops into a 10.50 mm recess instead of sitting on a thin plate
//   inside a raised rim. Four M3 screws pass through the rear skin into the display's inserts;
//   no retaining lip stands over or proud of the glass.
//
// Panel numbers all come from common.scad, so the cover cannot disagree with the cassette:
//   module                192.96 x 110.76, corners R8   (R5_PANEL)
//   image                 154.88 x 86.72                 (R5_PANEL_ACTIVE, 1024 x 600)
//   glass to PCB back      10.50                         (R5_PANEL_DEPTH)
//   M3 inserts            126.25 x 65.49 span            (R5_DISP_HOLES)
//   Pi standoffs (unused) 58 x 49, 3.5 mm behind the PCB (R5_DISP_POSTS, R5_PANEL_STUD)
//   panel position        centred in both axes           (PANEL_X/Y)
//   recess opening        the module + 1.0 mm a side     (COVER_GAP)
//   FFC fold pocket       36 x 33, 3 mm deep             (R5_RIBBON_*)
//
// There is no power button here any more. A centred 7" panel leaves 28.93 mm of latch band and a
// 16 mm IP67 button needs 34.2 mm, so the button moved to the deck's right rail (R5_BTN_*).
include <common.scad>

assert(R5, "r5 parts need -D R5=true");

// Distance from a point to an axis-aligned rectangle in the panel's drawing plane; zero inside.
function rect_gap(p, x0, y0, w, h) =
    norm([max(x0 - p[0], p[0] - (x0 + w), 0), max(y0 - p[1], p[1] - (y0 + h), 0)]);

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
assert(R5_4PIN_X0 >= -COVER_GAP && R5_4PIN_Y0 >= -COVER_GAP
       && R5_4PIN_X0 + R5_4PIN_W <= R5_PANEL[0] + COVER_GAP
       && R5_4PIN_Y0 + R5_4PIN_H <= R5_PANEL[1] + COVER_GAP,
       "the 4PIN relief must stay inside the display recess");
// The fold pocket is a blind cut in the seat skin: it has to stay inside the recess (or it would
// break the tape/painted face at the front border) and clear every screw and standoff seat.
assert(R5_RIBBON_X0 >= -COVER_GAP && R5_RIBBON_Y0 >= -COVER_GAP
       && R5_RIBBON_X0 + R5_RIBBON_W <= R5_PANEL[0] + COVER_GAP
       && R5_RIBBON_Y0 + R5_RIBBON_H <= R5_PANEL[1] + COVER_GAP,
       "the FFC fold pocket must stay inside the display recess");
assert(R5_RIBBON_SKIN >= 0.8 && R5_RIBBON_SKIN <= COVER_T - 2,
       str("the FFC fold pocket leaves ", R5_RIBBON_SKIN, " mm of the ", COVER_T,
           " mm skin: keep it between 0.8 and ", COVER_T - 2));
for (p = concat(R5_DISP_HOLES, R5_DISP_POSTS))
    assert(rect_gap(p, R5_RIBBON_X0, R5_RIBBON_Y0, R5_RIBBON_W, R5_RIBBON_H) >= 4,
           str("the FFC fold pocket reaches the display seat at ", p));

// ---------------- geometry ----------------
module cover_outline() rrect(COVER_W, COVER_L, COVER_R);

// The module footprint and its clearance opening, both at the panel's position.
module panel_2d(pad=0) translate([PANEL_X - pad, PANEL_Y - pad])
    rrect(R5_PANEL[0] + 2*pad, R5_PANEL[1] + 2*pad, R5_PANEL[2] + pad);

// Full-height front panel with a blind display recess. The cut starts at COVER_T, leaving the
// rear mounting skin intact, and over-runs the front by 1 mm for a clean boolean. The opening
// matches the glass outline plus clearance; there is no raised rim or lip over the display.
module cover_body() difference() {
    linear_extrude(COVER_FRONT_Z) cover_outline();
    translate([0, 0, COVER_T])
        linear_extrude(COVER_FRONT_Z - COVER_T + 1) panel_2d(COVER_GAP);
}

// The display's PCB back sits on the rear skin at COVER_T. Four DIN 7991 M3 x 6 screws pass
// through that skin into the display's inserts. Their 6 mm / 1.7 mm heads use the same 90-degree
// seats as the deck, opening on the lid side so the tape face stays flat. Do not use M3 x 8: its
// tip reaches the far end of the display's ~3 mm insert.
module panel_screws() for (p=R5_DISP_HOLES) translate([PANEL_X + p[0], PANEL_Y + p[1], 0]) {
    cylinder(d=M3_CLR, h=COVER_T + 1);
    translate([0, 0, -0.01]) cylinder(d1=M3_HEAD, d2=M3_CLR, h=M3_CSK_T + 0.02);
}

// The display's unused 58 x 49 Pi standoffs (M2.5, 5.5 mm OD) protrude 3.5 mm behind its PCB;
// blind reliefs keep the PCB flat on the rear skin without breaking the tape face.
module post_reliefs() for (p=R5_DISP_POSTS)
    translate([PANEL_X + p[0], PANEL_Y + p[1], COVER_T - R5_PANEL_STUD])
        cylinder(d=5.8, h=R5_PANEL_STUD + 0.1);

// Panel leads: the Waveshare's 15-pin DSI socket is on the right-hand rear PCB; the 4-pin
// 5 V/I2C lead is routed inside the case. The cover is taped to the lid, so the FPC cannot pass
// under it. The 20 mm notch runs from the panel edge to the hinge edge at R5_CABLE_X = 140.60,
// placing its centre over the existing deck/tray opening overlap at x 160.87 on the default host.
// The cut over-runs the recess edge by 1.5 mm, so no web remains; the cover stays one piece.
module cable_relief() {
    translate([PANEL_X + R5_CABLE_X0, -1, -1])
        cube([R5_CABLE_W, PANEL_Y - COVER_GAP + 1.5, COVER_FRONT_Z + 2]);
}

// The 4PIN connector protrudes into the rear skin inside the display recess.
module aux_relief() translate([PANEL_X + R5_4PIN_X0, PANEL_Y + R5_4PIN_Y0, -1])
    cube([R5_4PIN_W, R5_4PIN_H, COVER_FRONT_Z + 2]);

// The 15-pin DSI lead has to fold on itself before it reaches the hinge-edge notch, and the seat
// skin is only COVER_T thick. Pocket it from the recess side down to R5_RIBBON_SKIN, so the fold
// gets 3 mm and the tape face stays one flat, painted surface. Blind, not through: the display
// bridges the pocket on the surrounding seat.
module ribbon_relief() translate([PANEL_X + R5_RIBBON_X0, PANEL_Y + R5_RIBBON_Y0, R5_RIBBON_SKIN])
    linear_extrude(COVER_T - R5_RIBBON_SKIN + 1)
        rrect(R5_RIBBON_W, R5_RIBBON_H, R5_RIBBON_R);

module r5_lid_cover() difference() {
    cover_body();
    panel_screws();
    post_reliefs();
    cable_relief();
    aux_relief();
    ribbon_relief();
}

// Thin dimension template: all eight positions and the connector relief are through-cuts.
// Keep the display seat solid so those positions can be tested; the unchanged recess is omitted,
// and so is the fold pocket, which is deeper than this template is thick.
module r5_lid_cover_test_dimensions() difference() {
    linear_extrude(COVER_TEST_T) cover_outline();
    for (p=R5_DISP_HOLES)
        translate([PANEL_X + p[0], PANEL_Y + p[1], -1]) cylinder(d=M3_CLR, h=COVER_TEST_T + 2);
    for (p=R5_DISP_POSTS)
        translate([PANEL_X + p[0], PANEL_Y + p[1], -1]) cylinder(d=5.8, h=COVER_TEST_T + 2);
    cable_relief();
    aux_relief();
}

if (is_undef(ASSEMBLY)) r5_lid_cover();

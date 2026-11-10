// Ktemata r5 - lid cover, Waveshare 7inch DSI LCD (C) variant
//
// The 7" build r5 was first drawn for, kept as its own part: the Waveshare 7inch DSI LCD (C),
// 1024 x 600, sunk into a full-face cover taped into the host lid. The shipped part is the 5"
// Touch Display 2 cover (cad/r5_lid_cover.scad); this one is the alternative, and it carries its
// own panel numbers because nothing else uses them.
//
//   openscad -D R5=true cad/r5_lid_cover_waveshare_7in.scad
//   python3 cad/tools/export.py --r5 r5_lid_cover_waveshare_7in
//
// Orientation as modelled: z = 0 is the LID side (the tape face and the print bed) and z grows
// into the case. The rear mounting skin is on the bed and the display recess opens upwards.
// Print it exactly like this - every wall is vertical, so no supports.
//
// The vertical stack is the Waveshare's own, and matches r5_lid_plate's TD2 build in interface
// only (both tape to the same lid):
//   rear skin 0..COVER_T, PCB back at COVER_T, glass and the ENTIRE broad cover front at
//   W7_FRONT_Z. The display drops into a 10.50 mm recess instead of sitting on a thin plate
//   inside a raised rim. Four M3 screws pass through the rear skin into the display's inserts;
//   no retaining lip stands over or proud of the glass.
//
// Panel numbers (Waveshare, from the product drawing and STEP):
//   module                192.96 x 110.76, corners R8   (W7_PANEL)
//   image                 154.88 x 86.72                 (W7_PANEL_ACTIVE, 1024 x 600)
//   glass to PCB back      10.50                         (W7_DEPTH)
//   M3 inserts            126.25 x 65.49 span            (W7_HOLES)
//   Pi standoffs (unused) 58 x 49, 3.5 mm behind the PCB (W7_POSTS, W7_STUD)
//   panel position        centred in both axes           (W7_X0/Y0)
include <common.scad>

assert(R5, "r5 parts need -D R5=true");

// ---------------- the 7" panel ----------------
W7_PANEL        = [192.96, 110.76, 8];                  // w (along x), h (along y), corner R
W7_PANEL_ACTIVE = [154.88, 86.72];                      // lit area, same axes
W7_DEPTH        = 10.50;                                // front glass to PCB back
W7_STUD         = 3.5;                                  // M2.5 Pi standoffs behind the PCB
// The four M3 inserts and the four M2.5 standoffs, relative to the panel's left/top edge in the
// drawing, measured from Waveshare's STEP (the pattern is not symmetric about the glass centre).
// Two fit checks corrected them, both towards the latch/top: the first moved all eight positions
// 5 mm off the STEP values, the second moved the four M3 inserts another 5 mm because the screws
// still missed the tapped inserts. The standoffs keep the first correction only, so the two
// patterns are now 7.4 mm out of step; they are independent features of the panel and only the
// inserts are tapped, so nothing has to line up between them.
W7_HOLES = [[34.42, 31.58], [160.67, 31.58],
            [34.42, 97.07], [160.67, 97.07]];
W7_POSTS = [[73.97, 32.43], [131.97, 32.43],
            [73.97, 81.43], [131.97, 81.43]];
// 4PIN 5 V/I2C connector relief, panel-relative; measured from the fit-check annotation.
W7_4PIN_X0 = 114;
W7_4PIN_Y0 = 86;
W7_4PIN_W  = 30;
W7_4PIN_H  = 25;
// DSI FFC fold pocket, also panel-relative and off the same fit check: the 15-pin lead has to
// fold on itself between the panel's rear PCB and the hinge-edge notch, and the 4 mm skin the
// display seats on gives the fold no room. The area marked on the printed cover is pocketed from
// the recess side, leaving W7_RIBBON_SKIN on the tape face: 3 mm of depth for the fold, with the
// flat painted/tape face intact. The pocket sits between the right-hand display positions, clear
// of all eight (nearest: the M3 insert at y 31.58 and the standoff at y 81.43).
W7_RIBBON_X0   = 132;
W7_RIBBON_Y0   = 41;
W7_RIBBON_W    = 36;
W7_RIBBON_H    = 33;
W7_RIBBON_R    = 3;                                     // corner radius of the pocket
W7_RIBBON_SKIN = 1;                                     // skin left under it, tape face stays flat
// Centred in both axes: 20.27 mm of plate either side, 33.67 mm above and below on the 1200.
W7_X0 = (COVER_W - W7_PANEL[0])/2;
W7_Y0 = (COVER_L - W7_PANEL[1])/2;
W7_FRONT_Z = COVER_T + W7_DEPTH;                        // 14.50, glass and cover face

// Distance from a point to an axis-aligned rectangle in the panel's drawing plane; zero inside.
function w7_rect_gap(p, x0, y0, w, h) =
    norm([max(x0 - p[0], p[0] - (x0 + w), 0), max(y0 - p[1], p[1] - (y0 + h), 0)]);

// ---------------- guards ----------------
assert(W7_PANEL[0] + 2*COVER_FRAME + 4 <= COVER_W,
       str("host ", HOST, ": ", COVER_W, " mm cover, the panel + minimum front border needs ",
           W7_PANEL[0] + 2*COVER_FRAME + 4));
assert(W7_PANEL[1] + 2*COVER_FRAME + 4 <= COVER_L,
       str("host ", HOST, ": ", COVER_L, " mm cover, the panel + minimum front border needs ",
           W7_PANEL[1] + 2*COVER_FRAME + 4));
assert(COVER_GAP < (W7_PANEL[0] - W7_PANEL_ACTIVE[0])/2
       && COVER_GAP < (W7_PANEL[1] - W7_PANEL_ACTIVE[1])/2,
       "COVER_GAP must stay inside the glass border, or the front opening crops the image");
assert(W7_FRONT_Z + 4 <= HOST_LID,
       str("host ", HOST, ": lid ", HOST_LID, " mm, the recessed cover + lead fold needs ",
           W7_FRONT_Z + 4));
// The cable notch must reach the recess from the hinge edge without severing the cover.
assert(W7_Y0 > COVER_FRAME, "the panel's hinge-side front border would reach the cover edge");
assert(R5_CABLE_X0 >= W7_X0 - COVER_GAP
       && R5_CABLE_X0 + R5_CABLE_W <= W7_X0 + W7_PANEL[0] + COVER_GAP,
       "the cable notch must stay inside the display recess");
assert(W7_4PIN_X0 >= -COVER_GAP && W7_4PIN_Y0 >= -COVER_GAP
       && W7_4PIN_X0 + W7_4PIN_W <= W7_PANEL[0] + COVER_GAP
       && W7_4PIN_Y0 + W7_4PIN_H <= W7_PANEL[1] + COVER_GAP,
       "the 4PIN relief must stay inside the display recess");
// The fold pocket is a blind cut in the seat skin: it has to stay inside the recess (or it would
// break the tape/painted face at the front border) and clear every screw and standoff seat.
assert(W7_RIBBON_X0 >= -COVER_GAP && W7_RIBBON_Y0 >= -COVER_GAP
       && W7_RIBBON_X0 + W7_RIBBON_W <= W7_PANEL[0] + COVER_GAP
       && W7_RIBBON_Y0 + W7_RIBBON_H <= W7_PANEL[1] + COVER_GAP,
       "the FFC fold pocket must stay inside the display recess");
assert(W7_RIBBON_SKIN >= 0.8 && W7_RIBBON_SKIN <= COVER_T - 2,
       str("the FFC fold pocket leaves ", W7_RIBBON_SKIN, " mm of the ", COVER_T,
           " mm skin: keep it between 0.8 and ", COVER_T - 2));
for (p = concat(W7_HOLES, W7_POSTS))
    assert(w7_rect_gap(p, W7_RIBBON_X0, W7_RIBBON_Y0, W7_RIBBON_W, W7_RIBBON_H) >= 4,
           str("the FFC fold pocket reaches the display seat at ", p));

// ---------------- geometry ----------------
module w7_cover_outline() rrect(COVER_W, COVER_L, COVER_R);

// The module footprint and its clearance opening, both at the panel's position.
module w7_panel_2d(pad=0) translate([W7_X0 - pad, W7_Y0 - pad])
    rrect(W7_PANEL[0] + 2*pad, W7_PANEL[1] + 2*pad, W7_PANEL[2] + pad);

// Full-height front panel with a blind display recess, cut from COVER_T upwards and over-running
// the front by 1 mm for a clean boolean. No raised rim or lip over the display.
module w7_cover_body() difference() {
    linear_extrude(W7_FRONT_Z) w7_cover_outline();
    translate([0, 0, COVER_T])
        linear_extrude(W7_FRONT_Z - COVER_T + 1) w7_panel_2d(COVER_GAP);
}

// Four DIN 7991 M3 x 6 screws through the rear skin into the display's inserts, heads in
// 90-degree seats on the lid side. Do not use M3 x 8: its tip reaches the far end of the
// display's ~3 mm insert.
module w7_panel_screws() for (p=W7_HOLES) translate([W7_X0 + p[0], W7_Y0 + p[1], 0]) {
    cylinder(d=M3_CLR, h=COVER_T + 1);
    translate([0, 0, -0.01]) cylinder(d1=M3_HEAD, d2=M3_CLR, h=M3_CSK_T + 0.02);
}

// The display's unused 58 x 49 Pi standoffs (M2.5, 5.5 mm OD) protrude 3.5 mm behind its PCB;
// blind reliefs keep the PCB flat on the rear skin without breaking the tape face.
module w7_post_reliefs() for (p=W7_POSTS)
    translate([W7_X0 + p[0], W7_Y0 + p[1], COVER_T - W7_STUD])
        cylinder(d=5.8, h=W7_STUD + 0.1);

// The 20 mm DSI notch runs from the panel edge to the hinge edge at the case-side position
// (R5_CABLE_*, a cover coordinate - it lines up with the deck and tray openings, not with the
// panel) and over-runs the recess edge by 1.5 mm, so no web remains.
module w7_cable_relief() {
    translate([R5_CABLE_X0, -1, -1])
        cube([R5_CABLE_W, W7_Y0 - COVER_GAP + 1.5, W7_FRONT_Z + 2]);
}

// The 4PIN connector protrudes into the rear skin inside the display recess.
module w7_aux_relief() translate([W7_X0 + W7_4PIN_X0, W7_Y0 + W7_4PIN_Y0, -1])
    cube([W7_4PIN_W, W7_4PIN_H, W7_FRONT_Z + 2]);

// The 15-pin DSI lead has to fold on itself before it reaches the hinge-edge notch, and the seat
// skin is only COVER_T thick. Pocket it from the recess side down to W7_RIBBON_SKIN, so the fold
// gets 3 mm and the tape face stays one flat, painted surface. Blind, not through: the display
// bridges the pocket on the surrounding seat.
module w7_ribbon_relief() translate([W7_X0 + W7_RIBBON_X0, W7_Y0 + W7_RIBBON_Y0, W7_RIBBON_SKIN])
    linear_extrude(COVER_T - W7_RIBBON_SKIN + 1)
        rrect(W7_RIBBON_W, W7_RIBBON_H, W7_RIBBON_R);

module r5_lid_cover_waveshare_7in() difference() {
    w7_cover_body();
    w7_panel_screws();
    w7_post_reliefs();
    w7_cable_relief();
    w7_aux_relief();
    w7_ribbon_relief();
}

if (is_undef(ASSEMBLY)) r5_lid_cover_waveshare_7in();

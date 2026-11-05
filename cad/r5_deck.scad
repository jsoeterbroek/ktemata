// Ktemata r5 - deck (keyboard / OLED / Pi clamp)
//
// Sits on the tray rim (r5_tray) and is fixed with seven M3 x 10 into heat-set inserts. It carries the
// Rii K06 keyboard, the status OLED, the power button and the 8.4 V charge socket on top, and
// clears the Pi + HAT (B) stack below. The display is not here: it hangs on the lid
// (r5_lid_plate.scad), so the deck is what you see when the host case is open.
//
// PRINT TOP FACE DOWN, not plate down. The keyboard recess hangs below the plate (see kb_well
// below), so printed plate-down that recess would be a floating island. Flipped, the deck's top
// face is the bed, every recess wall is vertical, and the two seat bands are short straight
// bridges. The fan grille is on the top face, so it prints into the bed - see fan_grille() for
// how that is kept flush.
include <common.scad>

assert(R5, "r5 parts need -D R5=true");

// The plate overhangs the cassette: R5_DECK_* (common.scad) is the host's cavity at the height the
// plate lands at, centred on the cassette, with a corner radius big enough to clear the host's
// moulded corners. Every cut below is placed in absolute coordinates, so growing the rim leaves
// the seven screws, the keyboard, the OLED, the fan and the button exactly where they were.
module deck2d() translate([R5_DECK_X0, R5_DECK_Y0])
    rrect(R5_DECK_W, R5_DECK_L, R5_DECK_R);
module deck_slab() translate([0, 0, R5_DECK_Z]) linear_extrude(R5_DECK_T) deck2d();

// span drawing y0..y1 at x0..x1
// r5_at puts the box's min-y corner at y1 in drawing coords, and a cube grows towards +y,
// which is why no extra flip is needed here.
module dbox(x0, y0, x1, y1, z, h) r5_at(x0, y1, z) cube([x1 - x0, y1 - y0, h]);

// ---- screw seats: Ø3.4 clearance + Ø6.2 x 1.8 counterbore for an M3 button head ----
// M3, not M2.5: the deck comes off for every service, and the insert in the tray boss below is
// what survives that. 1.8 mm of counterbore keeps the head just under the deck's top face, which
// is the surface the keyboard and the closed lid sit on.
module screw_cut(p) {
    r5_at(p[0], p[1], R5_DECK_Z - 1) cylinder(d=M3_CLR, h=R5_DECK_T + 2);
    r5_at(p[0], p[1], R5_DECK_TOP - 1.8) cylinder(d=M3_HEAD, h=1.81);
}

// ---- keyboard recess ----
// The K06 is 11 mm thick and the plate is 4.5 mm, so a pocket that merely dropped the body into
// the plate would leave 6.5 mm of keyboard proud. It is sunk instead: the plate gets a hole of
// the keyboard's plan, and the body's underside rests on two ledges 11 mm below the deck's top
// face, which puts the keys exactly level with it.
//
// The K06's corners are rounded, and so is this cut. A square hole leaves four corner pockets of
// air where the body's shell should be touching, and the plate's corners stand in view inside the
// keyboard's own outline. R5_KB_CORNER is measured off the manual's outline drawing.
//
// The whole 11 mm column between R5_KB_WELL_BOT and the top face belongs to the keyboard, so
// NOTHING may sit in it. That was the bug this replaces: the two "carry ribs" stood full height
// inside the pocket, the plate cut sheared their tops off at the plate's underside, and the body
// could then only land 5.5 mm below the top face instead of 11.
//
// Support: it used to be a well with a solid 1.2 mm floor, and printed top-face down that floor
// is a 151 x 59 mm ceiling - ~4100 s of tree support. There is no floor now. The skirt walls grow
// straight up from the bed and the seat ledges hang off the long walls with a 45 deg underside.
module kb_2d(d=0) rrect(R5_KB_POCKET[0] + 2*d, R5_KB_POCKET[1] + 2*d,
                        R5_KB_CORNER + R5_KB_CLR + d);
// the pocket profile at drawing coords, extruded from z up. Growing it (d > 0) grows it outwards
// about its own centre, which is the cassette's centre in x but not in y, so the placement is
// recomputed from the grown size: in real coords the pocket runs from R5_L - R5_KB_Y0 - P down,
// and a grown profile starts d lower again.
module kb_prism(z, h, d=0) {
    translate([R5_KB_X0 - d, R5_L - R5_KB_Y0 - R5_KB_POCKET[1] - d, z])
        linear_extrude(h) kb_2d(d);
}

// the hole through the plate: the keyboard's whole 11 mm column has to be empty
module kb_plate_cut() kb_prism(R5_KB_WELL_BOT, R5_DECK_TOP - R5_KB_WELL_BOT + 1);

// One seat ledge against the wall at drawing y = y_in, hanging into the pocket. Cross-section is a
// right triangle: a vertical leg against the wall, a flat top at the resting plane, and a 45 deg
// underside from the wall's bottom to the seat's inner edge. The hull of those two legs is exactly
// that prism, and hull avoids a hand-rolled rotation for a cross-section in the y-z plane.
// s = +1 for the low-y (hinge-side) wall, -1 for the other. Both legs run OV into the wall so the
// ledge is one solid with it instead of a tangent contact.
module kb_ledge(y_in, s) {
    e = 0.05;                                       // thin dimension of the two hulled legs
    ov = 0.8;                                       // how far each leg runs into the wall
    zb = R5_KB_WELL_BOT - R5_KB_SEAT;
    ya = s > 0 ? y_in - ov : y_in - R5_KB_SEAT;     // ledge span across the pocket, in drawing y
    yb = s > 0 ? y_in + R5_KB_SEAT : y_in + ov;
    x0 = R5_KB_SEAT_X0; x1 = R5_KB_SEAT_X1;
    hull() {
        if (s > 0) r5_box(x0, y_in - ov, x1, y_in + e, zb, R5_KB_SEAT);
        else       r5_box(x0, y_in - e, x1, y_in + ov, zb, R5_KB_SEAT);
        r5_box(x0, ya, x1, yb, R5_KB_WELL_BOT - e, e);
    }
}

// The skirt: a wall ring hanging below the plate, plus the two seat ledges. The ring's bottom is
// the ledges' underside and it runs 0.8 mm up into the plate, so plate, ring and ledges are one
// solid rather than tangent contacts. Its inner face is the pocket outline, so it follows the
// keyboard's corners.
module kb_well() {
    sb = R5_KB_WELL_BOT - R5_KB_SEAT;               // ledge underside (45 deg down from the seat)
    zh = (R5_DECK_Z + 0.8) - sb;                    // ... up into the plate
    difference() {
        kb_prism(sb, zh, R5_KB_WALL);               // ring: pocket outline + R5_KB_WALL
        // open the middle: no floor, so the slicer has no ceiling to support
        kb_prism(sb - 1, zh + 2);
    }
    // Two ledges, one per long wall, running the pocket's straight x run. Two edges rather than
    // one line, so the body cannot rock; the K06's shell carries its rim there, which is also where
    // r4's support frame touched it.
    kb_ledge(R5_KB_Y0, 1);
    kb_ledge(R5_KB_Y0 + R5_KB_POCKET[1], -1);
}

// ---- status OLED: window over the glass, pocket for the pcb in the underside ----
// The module is measured, not assumed: pcb 35.5 x 33.7 x 1.2, the glass on it 34.5 x 23 x 1.45,
// and the lit 128 x 64 area inside the glass border 29.42 x 14.7. What you must see is the glass;
// sizing one through-hole to the pcb, as this did, left the board's edge in view all round the
// panel and a 35.8 x 34.8 hole in a 4.5 mm plate for a 1.3" screen.
//
// So there are two cuts, and the 4.5 mm plate separates them:
//   - R5_OLED_WIN, the glass plus 0.15 mm a side, through the top face;
//   - R5_OLED_PCB, the pcb plus 0.4 mm a side, sunk R5_OLED_BOARD[2] = 1.2 mm into the underside.
// The pcb drops in from below until its front face meets the pocket's ceiling, which is the seat
// (R5_OLED_SEAT) - flush with the deck's underside, so the module's back is exposed and can be
// taped across to hold it. The ring of plate between the two cuts is the bezel: it stops the
// module going any further and hides the board. The glass then stands in a 3.3 mm deep well and
// finishes 1.85 mm below the top face, so nothing can press on the panel.
//
// Print note: with the deck printed top-face down (see export.scad), the seat ring is the lowest
// 3.3 mm of the part and the pocket is an upward-facing recess - no support, no bridge, and the
// window is a straight hole through to the bed. Printed as modelled it would instead be a 36 x 34
// mm ceiling, which is why the export flips it. If you would rather have a plain hole, tape the
// module to the deck's underside and delete oled_pocket().
module oled_window() {
    dbox(R5_OLED_WIN_X0, R5_OLED_WIN_Y0,
         R5_OLED_WIN_X0 + R5_OLED_WIN[0], R5_OLED_WIN_Y0 + R5_OLED_WIN[1],
         R5_OLED_SEAT, R5_DECK_TOP - R5_OLED_SEAT + 2);
}
module oled_pocket() {
    dbox(R5_OLED_X0, R5_OLED_Y0,
         R5_OLED_X0 + R5_OLED_PCB[0], R5_OLED_Y0 + R5_OLED_PCB[1],
         R5_DECK_Z - 1, R5_OLED_SEAT - R5_DECK_Z + 1);
}

// ---- openings ----
module openings() {
    // Pi hinge edge: USB-C, the two micro-HDMI sockets and the 22-pin MIPI connectors must stay
    // reachable, the M.2 FPC has to drop through to the BASE, and the display FFC leaves through
    // here on its way to the lid. Bounds and why they are not simply "over the Pi": common.scad,
    // R5_OPEN_X0/X1/D - the right end stops 1 mm short of deck screw 5 and 1 mm below the right
    // fan, so the screw keeps its head seat and the two openings stay separate. The cut starts at
    // the PLATE's edge, not the tray's: the plate overhangs the tray by R5_DECK_Y0, and a cut that
    // stopped at drawing y 0 would leave a 4.4 mm lip over the Pi's hinge-edge connectors.
    dbox(R5_OPEN_X0, R5_DECK_Y0, R5_OPEN_X1, R5_OPEN_D, R5_DECK_Z - 1, R5_DECK_T + 2);
    // FireBeetle 2: gives its USB-C port access for flashing and lets its OLED / button leads
    // rise to the deck. The module sits under the deck, so without this hole it is sealed in.
    // R5_FB_HOLE_Y0 places it 44 mm along the module (was 30): at 30 the hole abutted the left
    // fan opening, which read as clutter in the print view. Still well inside the 60 mm module.
    dbox(R5_FB_X + 6, R5_FB_Y + R5_FB_HOLE_Y0, R5_FB_X + 22, R5_FB_Y + R5_FB_HOLE_Y0 + 10,
         R5_DECK_Z - 1, R5_DECK_T + 2);
    // (the OLED cable slot that used to be here is gone: the module now sits in the deck's
    //  underside, so its 4-pin header looks straight into the tray cavity where the FireBeetle
    //  is. The old slot would be a 16 x 4 mm hole in the visible top face for nothing.)
    // (the right-wall opening that used to be here is gone: it was cut for "DS3231 and charger
    //  module leads", but the DS3231 (y 26-52) and the MPPT charger (y 62-86) sit BELOW the deck
    //  - the lowest is at z 2.4 and the deck underside is z 40.4 - so neither lead crosses it.
    //  Measured, not assumed: the opening's only overlap with anything was 3.1 x 24 mm of the
    //  MPPT pad's outer edge. A 12 mm hole that opened the deck's edge for nothing was 12 mm of
    //  lost stiffness. The 8.4 V charge socket is in the deck now, not below it.)
}

// ---- cooling: one round fan opening in the free top-left corner, with a grille over it ----
// The old five-slot bank is gone. Its y span (101-108.4) crossed the keyboard pocket's hinge
// wall at 100.7-102.5, so it cut the pocket rather than venting anything, and slots move little
// air. A 40 mm fan opening sits in the free corner instead - clear of the keyboard, clear of
// the deck screws (nearest is 40 mm away). DECK_FANS=2 adds a second at the top right; it is off
// by default because it buys little and its rim cramped the hinge opening (see common.scad,
// R5_OPEN_D).
//
// The grille is printed as part of the deck: DECK_GRILL_BARS bars across the opening, standing
// DECK_GRILL_RIB above the top face. Bars rather than concentric rings because everything here
// is a straight bridge - a bridge over a 38 mm span prints cleanly, and the bars also stiffen
// the plate where a 38 mm hole removed its middle.
module fan_holes() {
    for (i=[0:DECK_FANS-1]) {
        c = DECK_FAN_CTRL[i];
        // the opening is cut through the full plate thickness. The grille bars are unioned
        // back in afterwards (see r5_deck()): they live inside the plate's own volume, so a
        // cut that spares them impossible and a cut that keeps the plate leaves it solid.
        r5_at(c[0], c[1], R5_DECK_Z - 1) cylinder(d=DECK_FAN_D, h=R5_DECK_T + 2);
        // the fan's own M3 mounting holes, on a 32 mm square pattern
        for (dx=[-DECK_FAN_HOLE_SP/2, DECK_FAN_HOLE_SP/2])
            for (dy=[-DECK_FAN_HOLE_SP/2, DECK_FAN_HOLE_SP/2])
                r5_at(c[0] + dx, c[1] + dy, R5_DECK_Z - 1)
                    cylinder(d=DECK_FAN_SCREW_D, h=R5_DECK_T + 1.05);
    }
}

// Bars across each opening, FLUSH with the deck's top face. The deck now prints top-face down,
// so anything standing proud of that face would be pressed into the bed; the bars are recessed to
// sit level instead, which also keeps the face flat for the lid's display. They span the hole and
// sink 0.8 mm into the plate at both ends so they fuse to it (a tangent contact exports as a
// separate solid).
module fan_grille() {
    for (i=[0:DECK_FANS-1]) {
        c = DECK_FAN_CTRL[i];
        for (b=[-(DECK_GRILL_BARS-1)/2 : (DECK_GRILL_BARS-1)/2]) {
            y = c[1] + b * (DECK_FAN_D / (DECK_GRILL_BARS + 0.5));
            half = sqrt(max(0, (DECK_FAN_D/2)*(DECK_FAN_D/2) - (b*(DECK_FAN_D/(DECK_GRILL_BARS+0.5)))^2));
            dbox(c[0] - half - 1.5, y - DECK_GRILL_BAR/2,
                 c[0] + half + 1.5, y + DECK_GRILL_BAR/2,
                 R5_DECK_TOP - DECK_GRILL_RIB - 0.8, DECK_GRILL_RIB + 0.3);
        }
    }
}

// ---- charge socket: 5.5 x 2.1 DC jack through the right rail ----
// The host stays sealed: the 8.4 V charge lead ends here instead of through a hole in the Peli
// wall. The socket goes in from the TOP - bezel on the painted face, nut on the underside - and
// its plug is fitted with the lid open (the display is only 4.6 mm above this face when shut).
// R5_CHG_* in common.scad derives the position and guards it against the Pi's plugs, the right
// rail's screws, the keyboard pocket, the fan and the button. Printed top-face down, the hole is
// a vertical wall in the plate and needs no support.
module charge_cut() r5_at(R5_CHG_X, R5_CHG_Y, R5_DECK_Z - 1)
    cylinder(d=R5_CHG_D, h=R5_DECK_T + 2);

// ---- power button ----
// The 16 mm IP67 panel button moved here from the lid: a centred 7" panel leaves 28.93 mm of
// latch band and the button needs 34.2 mm, so the lid cannot carry both (see common.scad,
// R5_BTN_*). The deck's right rail is 40.95 mm of plate over free floor at the latch end - the
// boards and cells all stop at y 101 - so the plate is the whole mount: a plain hole, and the
// nut seats on the deck's underside. No boss, because anything hanging into the tray cavity
// there would foul the leads to the Pi's J2 pads.
//
// Printed top-face down, the button's hole is a vertical wall in the plate and prints clean.
module button_cut() r5_at(R5_BTN_X, R5_BTN_Y, R5_DECK_Z - 1)
    cylinder(d=R5_BTN_D, h=R5_DECK_T + 2);

module r5_deck() union() {
    difference() {
        union() {
            deck_slab();
            kb_well();
        }
        for (p=R5_SCREWS) screw_cut(p);
        oled_window();
        oled_pocket();
        openings();
        fan_holes();
        kb_plate_cut();
        button_cut();
        charge_cut();
    }
    // the grille goes in after the cut: the bars occupy the plate's own volume inside the
    // opening, so they can only exist as a union on top of an already-cut plate
    fan_grille();
}

if (is_undef(ASSEMBLY)) r5_deck();

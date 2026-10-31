// Ktemata r5 - deck (keyboard / OLED / Pi clamp)
//
// Sits on the tray rim (r5_tray) and is fixed with six M2.5 x 10 from above. It carries the
// Rii K06 keyboard and the status OLED on top, and clamps the Pi + HAT (B) stack below with
// four pillars. The display is not here: it hangs on the lid (r5_lid_plate.scad), so the deck
// is what you see when the host case is open.
//
// PRINT TOP FACE DOWN, not plate down. The keyboard is sunk 8 mm below the plate (see kb_well
// below), so the well hangs under it; printed plate-down that well would be a floating island.
// Flipped, the deck's top face is the bed, every well wall is vertical, and nothing overhangs.
// The fan grille is on the top face, so it prints into the bed - see fan_grille() for how that is
// kept flush.
include <common.scad>

assert(R5, "r5 parts need -D R5=true");

module plate2d(d=0) offset(delta=d) rrect(R5_W, R5_L, R5_R);
module deck_slab() translate([0, 0, R5_DECK_Z]) linear_extrude(R5_DECK_T) plate2d();

// span drawing y0..y1 at x0..x1
// r5_at puts the box's min-y corner at y1 in drawing coords, and a cube grows towards +y,
// which is why no extra flip is needed here.
module dbox(x0, y0, x1, y1, z, h) r5_at(x0, y1, z) cube([x1 - x0, y1 - y0, h]);

// ---- screw seats: Ø2.8 clearance + Ø5.2 x 1.8 counterbore, flush heads
module screw_cut(p) {
    r5_at(p[0], p[1], R5_DECK_Z - 1) cylinder(d=M25_CLR, h=R5_DECK_T + 2);
    r5_at(p[0], p[1], R5_DECK_TOP - 1.8) cylinder(d=M25_HEAD, h=1.81);
}

// ---- keyboard recess ----
// The K06 is 11 mm thick, so it is sunk into the deck: the plate gets a hole the size of the
// keyboard, the body stands R5_KB_SINK = 6.5 mm below the plate's underside, and the keys finish
// level with the deck's top face. The body is located by the four walls (R5_KB_WALL clearance on
// top of the 0.6 mm already in R5_KB_POCKET) and kept down by the lid's display pressing on it
// with the case shut.
//
// It used to be a well with a solid 1.2 mm floor, and that floor was the whole support problem:
// printed top-face down it is a 151 x 59 mm ceiling, and the slicer filled it with ~4100 s of
// tree support. It is now an open recess instead - the floor is gone, so there is no ceiling to
// support, and only two narrow bands cross the cavity to carry the keyboard.
//
// The walls still run all the way down to the body's resting plane, because that skirt is what
// the keyboard is glued to. Nothing here overhangs the bed: the plate is on the bed, the walls
// grow straight up from it, and the two bands are short bridges at the top of the print.
module kb_body_2d(d=0) rrect(R5_KB_POCKET[0] + 2*d, R5_KB_POCKET[1] + 2*d, 3);

// the hole through the plate: the keyboard occupies this volume, so the plate must be absent
module kb_plate_cut() dbox(R5_KB_X0, R5_KB_Y0, R5_KB_X0 + R5_KB_POCKET[0],
                           R5_KB_Y0 + R5_KB_POCKET[1], R5_DECK_Z - 1, R5_DECK_T + 2);

// The skirt: four walls hanging below the plate, open at the bottom, plus two bands that carry
// the keyboard. The walls stop at the body's resting plane (R5_KB_WELL_BOT) and run 0.8 mm up
// into the plate so the two are one solid rather than a tangent contact.
module kb_well() {
    w = R5_KB_POCKET[0]; h = R5_KB_POCKET[1];
    x0 = R5_KB_X0; y0 = R5_KB_Y0; x1 = x0 + w; y1 = y0 + h;
    t = R5_KB_WALL;
    zb = R5_KB_WELL_BOT;                            // the body's resting plane = skirt bottom
    zh = (R5_DECK_Z + 0.8) - zb;                    // ... up into the plate
    difference() {
        dbox(x0 - t, y0 - t, x1 + t, y1 + t, zb, zh);
        // open the middle: no floor, so the slicer has no ceiling to support
        dbox(x0, y0, x1, y1, zb - 1, zh + 1);
    }
    // Two ribs that carry the keyboard, full height like the walls (zb up into the plate) and
    // R5_KB_BAND wide. Full height matters: printed top-face down they grow straight up from the
    // plate, so they are ordinary vertical walls with nothing under them to support. A rib that
    // were only a strip at the resting plane would instead be a 59.6 mm bridge at the top of the
    // print, and one running the other way would bridge 151.6 mm.
    // They run along y, so each spans the 59.6 mm depth and lands on both long walls. Two rather
    // than one, so the body cannot rock about a single line.
    for (fx=[R5_KB_BAND_X0, R5_KB_BAND_X1])
        dbox(fx, y0, fx + R5_KB_BAND, y1, zb, zh);
}

// ---- status OLED: through-pocket with retaining ledges ----
// The module lies face up in a pocket cut clean through the 3 mm plate, so nothing shadows the
// 128 x 64 area and its glass sits just above the deck. Four corner ledges carry it; the lid and
// the cables hold it down. (A recess with a window, as r4's face needed, would put the plate over
// the panel - here the module is on the outside of the deck, so the plate must be absent.)
module oled_pocket() {
    x0 = R5_OLED_X0; y0 = R5_OLED_Y0; x1 = x0 + R5_OLED_W; y1 = y0 + R5_OLED_H;
    dbox(x0, y0, x1, y1, R5_DECK_Z - 1, R5_DECK_T + 2);
}
module oled_ledges() {
    k = 5.5; t = 1.4; h = 1.0;                     // size, inward bite, height
    for (sx=[0, 1]) for (sy=[0, 1]) {
        px = sx ? R5_OLED_X0 + R5_OLED_W - k : R5_OLED_X0;
        py = sy ? R5_OLED_Y0 + R5_OLED_H - k : R5_OLED_Y0;
        // each ledge grows 0.8 mm outwards into the plate (shared volume, so it is fused) and
        // 5 mm inwards under the module's corner
        dbox(sx ? px - t : px - 0.8, sy ? py - t : py - 0.8,
             sx ? px + k : px + k + 0.8, sy ? py + k : py + k + 0.8, R5_DECK_Z, h);
    }
}

// ---- openings ----
module openings() {
    // Pi hinge edge: USB-C, the two micro-HDMI sockets and the 22-pin MIPI connectors must stay
    // reachable, the M.2 FPC has to drop through to the BASE, and the display FFC leaves through
    // here on its way to the lid. The boards now sit at y 16, so the opening tracks them.
    dbox(R5_PI_X - 2, 0, R5_PI_X + R5_PI_W + 2, R5_PI_Y + 4, R5_DECK_Z - 1, R5_DECK_T + 2);
    // FireBeetle 2: gives its USB-C port access for flashing and lets its OLED / button leads
    // rise to the deck. The module sits under the deck, so without this hole it is sealed in.
    // R5_FB_HOLE_Y0 places it 44 mm along the module (was 30): at 30 the hole abutted the left
    // fan opening, which read as clutter in the print view. Still well inside the 60 mm module.
    dbox(R5_FB_X + 6, R5_FB_Y + R5_FB_HOLE_Y0, R5_FB_X + 22, R5_FB_Y + R5_FB_HOLE_Y0 + 10,
         R5_DECK_Z - 1, R5_DECK_T + 2);
    // OLED module cable drops to the FireBeetle
    dbox(R5_OLED_X0 + 8, R5_OLED_Y0 + R5_OLED_H, R5_OLED_X0 + 24, R5_OLED_Y0 + R5_OLED_H + 4,
         R5_DECK_Z - 1, R5_DECK_T + 2);
    // (the right-wall opening that used to be here is gone: it was cut for "DS3231 and charger
    //  module leads", but the DS3231 (y 26-52), the MPPT charger (y 62-86) and the charge socket
    //  (y 107-129) all sit BELOW the deck - the lowest is at z 2.4 and the deck underside is
    //  z 45.95 - so none of their leads cross it. Measured, not assumed: the opening's only
    //  overlap with anything was 3.1 x 24 mm of the MPPT pad's outer edge. A 12 mm hole that
    //  opened the deck's edge for nothing was 12 mm of lost stiffness.)
}

// ---- cooling: a round fan opening in each top corner, with a grille over it ----
// The old five-slot bank is gone. Its y span (101-108.4) crossed the keyboard pocket's hinge
// wall at 100.7-102.5, so it cut the pocket rather than venting anything, and slots move little
// air. A 40 mm fan opening sits in the free corner instead - clear of the keyboard, clear of
// the deck screws (nearest is 40 mm away).
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

module r5_deck() union() {
    difference() {
        union() {
            deck_slab();
            kb_well();
            oled_ledges();
        }
        for (p=R5_SCREWS) screw_cut(p);
        oled_pocket();
        openings();
        fan_holes();
        kb_plate_cut();
    }
    // the grille goes in after the cut: the bars occupy the plate's own volume inside the
    // opening, so they can only exist as a union on top of an already-cut plate
    fan_grille();
}

if (is_undef(ASSEMBLY)) r5_deck();

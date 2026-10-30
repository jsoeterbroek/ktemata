// Ktemata r5 - deck (keyboard / OLED / Pi clamp)
//
// Sits on the tray rim (r5_tray) and is fixed with six M2.5 x 10 from above. It carries the
// Rii K06 keyboard and the status OLED on top, and clamps the Pi + HAT (B) stack below with
// four pillars. The display is not here: it hangs on the lid (r5_lid_plate.scad), so the deck
// is what you see when the host case is open.
//
// Print as modelled, deck plate down: the pocket walls and the lip rise vertically off the plate
// and the printer bridges nothing. The lip's underside is unsupported for 2.5 mm at a height of
// 3.2 mm, which is a 38 deg overhang from vertical - inside the 45 deg limit this repo prints to.
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

// ---- keep-outs: the deck caps the Pi stack, so the header and FFC connectors need air ----
// The 40-pin header is 3.5 mm in from the GPIO edge and 5.1 mm wide, i.e. its body sits over
// the Pi's own mounting holes: a clamp pillar there would crush it. Nothing touches the Pi,
// which is why the stack is held by cell cradles on the tray floor instead.
module pi_keepout() {
    // one opening over the whole header + FFC edge strip, so nothing can foul them
    r5_box(R5_PI_X0 + 2, R5_PI_Y0 + 2, R5_PI_X0 + 83, R5_PI_Y0 + 14, R5_DECK_Z - 1, R5_DECK_T + 2);
}

// ---- keyboard pocket ----
// The K06 is a complete body whose keys are flush to its shell on three edges (0.6-0.7 mm), so
// the sides and the latch end get 1.8 mm walls only up to the body's back and the body drops in
// from above. The hinge-facing edge is the one with a bezel above the Esc row: there the wall
// continues 3.2 mm above the body and forms the lip that traps it.
module kb_pocket() {
    w = R5_KB_POCKET[0]; h = R5_KB_POCKET[1];
    x0 = R5_KB_X0; y0 = R5_KB_Y0; x1 = x0 + w; y1 = y0 + h;
    t = R5_KB_WALL;
    // all four walls sink 0.5 mm into the slab: flush (tangent) faces make non-manifold edges
    zb = R5_DECK_TOP - 0.5; zh = R5_DECK_TOP + KB_BODY[2] - zb;
    dbox(x0 - t, y0 - t, x0, y1, zb, zh);              // left
    dbox(x1, y0 - t, x1 + t, y1, zb, zh);              // right
    dbox(x0 - t, y1, x1 + t, y1 + t, zb, zh);          // latch end (overlaps both sides)
    // hinge side: full body height plus the lip's height, so the lip has something to hang from
    dbox(x0 - t, y0 - t, x1 + t, y0, zb, R5_DECK_TOP + KB_BODY[2] + 3.2 - zb);
    // lip: 2.5 mm over the Esc row's bezel, 0.2 mm above the body's top face so it retains the
    // keyboard without pressing on it. Its underside overhangs 2.5 mm at a height of 3.2 mm,
    // i.e. 38 deg from vertical, which prints without support.
    dbox(x0 - t, y0 - t, x1 + t, y0 + R5_KB_LIP,
         R5_DECK_TOP + KB_BODY[2] + 0.2, 3.0);
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
    // Pi connector edge: USB-C, HDMI and the two 22-pin MIPI connectors must stay reachable,
    // and the display FFC leaves through here on its way to the lid.
    dbox(R5_PI_X0 - 2, 0, R5_PI_X0 + 87, 17, R5_DECK_Z - 1, R5_DECK_T + 2);
    // FireBeetle USB port and its OLED / button leads
    dbox(R5_FB_X + 6, R5_FB_Y + 30, R5_FB_X + 22, R5_FB_Y + 40, R5_DECK_Z - 1, R5_DECK_T + 2);
    // OLED module cable drops to the FireBeetle
    dbox(R5_OLED_X0 + 8, R5_OLED_Y0 + R5_OLED_H, R5_OLED_X0 + 24, R5_OLED_Y0 + R5_OLED_H + 4,
         R5_DECK_Z - 1, R5_DECK_T + 2);
    // DS3231 and charger module leads rise at the right wall
    dbox(R5_W - R5_WALL - 16, 60, R5_W - R5_WALL + 1, 100, R5_DECK_Z - 1, R5_DECK_T + 2);
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
        // cut the plate only: the grille bars stand above R5_DECK_TOP, and a cut that ran
        // through them would erase the bars it is supposed to sit under
        r5_at(c[0], c[1], R5_DECK_Z - 1) cylinder(d=DECK_FAN_D, h=R5_DECK_T + 1.05);
        // the fan's own M3 mounting holes, on a 32 mm square pattern
        for (dx=[-DECK_FAN_HOLE_SP/2, DECK_FAN_HOLE_SP/2])
            for (dy=[-DECK_FAN_HOLE_SP/2, DECK_FAN_HOLE_SP/2])
                r5_at(c[0] + dx, c[1] + dy, R5_DECK_Z - 1)
                    cylinder(d=DECK_FAN_SCREW_D, h=R5_DECK_T + 1.05);
    }
}

// Bars across each opening, on the deck's top face. They span the hole and sink 0.8 mm into the
// plate at both ends so they fuse to it (a tangent contact exports as a separate solid).
module fan_grille() {
    for (i=[0:DECK_FANS-1]) {
        c = DECK_FAN_CTRL[i];
        for (b=[-(DECK_GRILL_BARS-1)/2 : (DECK_GRILL_BARS-1)/2]) {
            y = c[1] + b * (DECK_FAN_D / (DECK_GRILL_BARS + 0.5));
            half = sqrt(max(0, (DECK_FAN_D/2)*(DECK_FAN_D/2) - (b*(DECK_FAN_D/(DECK_GRILL_BARS+0.5)))^2));
            dbox(c[0] - half - 1.5, y - DECK_GRILL_BAR/2,
                 c[0] + half + 1.5, y + DECK_GRILL_BAR/2,
                 R5_DECK_TOP - 0.8, DECK_GRILL_RIB + 0.8);
        }
    }
}

module r5_deck() difference() {
    union() {
        deck_slab();
        kb_pocket();
        oled_ledges();
        fan_grille();
    }
    for (p=R5_SCREWS) screw_cut(p);
    oled_pocket();
    openings();
    pi_keepout();
    fan_holes();
}

if (is_undef(ASSEMBLY)) r5_deck();

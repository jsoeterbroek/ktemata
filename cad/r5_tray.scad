// Ktemata r5 - internal bottom tray (floor cassette)
//
// Not a case shell: plain walls, no exterior styling. It drops into the host hard case
// (HOST in common.scad; default Peli 1200) on a closed-cell pad and carries:
//   - two 18650 cell cradles that locate the HAT (B) + Pi stack laterally (the stack rests on
//     the cells: Waveshare's holders hold the cells, its 6 mm standoffs hold the Pi),
//   - the FireBeetle 2, DS3231 and charger module on shallow floor pads,
//   - the bulkhead charge socket bracket,
//   - six M2.5 bosses for the deck (r5_deck.scad).
//
// Print floor down. Every wall is vertical, no supports, nothing overhangs the bed face.
include <common.scad>

assert(R5, "r5 parts need -D R5=true");

module cassette2d(d=0) offset(delta=d) rrect(R5_W, R5_L, R5_R);

module tray_shell() difference() {
    linear_extrude(R5_H_BOT) cassette2d();
    translate([0, 0, R5_FLOOR]) linear_extrude(R5_H_BOT) cassette2d(-R5_WALL);
}

// ---- deck screws: columns straddling the inner wall face ----
// Ø7 boss centred 2.5 mm inside the wall: 1 mm of overlap fuses it to the wall, the rest stands
// in the cavity, and a Ø2.2 pilot takes the M2.5 through the deck above.
module boss_solid(p) r5_at(p[0], p[1]) translate([0, 0, R5_FLOOR]) cylinder(d=BOSS_D, h=R5_H_BOT - R5_FLOOR);
module boss_cut(p)   r5_at(p[0], p[1]) translate([0, 0, R5_H_BOT - 9]) cylinder(d=M25_PIL, h=10);

// ---- cell cradles ----
// U-saddles under each cell. The bore is 1.2 mm larger than the cell, so the cell locates but is
// not pinched, and the HAT (B)'s own holder keeps the pair together.
module cell_cradle(x, yc) {
    r5_box(x - (CELL_D + 2.6)/2, yc - 3, x + (CELL_D + 2.6)/2, yc + 3, R5_FLOOR,
           CELL_D*0.62);
}

// ---- shallow floor trays ----
// A 1.8 mm floor with a 1.6 mm perimeter rim, cut as a box minus a smaller box: no corner posts
// and no tangent faces, so the solid is trivially manifold. The rim locates the module; a zip
// tie through the floor slots (below) holds it down.
module tray_pad(x0, y0, w, h, t=1.8, t_rim=3.4) difference() {
    r5_box(x0, y0, x0 + w, y0 + h, R5_FLOOR, t_rim);
    r5_box(x0 + 1.6, y0 + 1.6, x0 + w - 1.6, y0 + h - 1.6, R5_FLOOR + t, t_rim);
}

module firebeetle_tray() {
    tray_pad(R5_FB_X, R5_FB_Y, FB_W + 4, FB_H + 4);
    // zip-tie tunnels through the pad floor (they stay below the board)
    for (y=[R5_FB_Y + 12, R5_FB_Y + FB_H - 14])
        r5_box(R5_FB_X + 2 + FB_W/2 - 1.5, y, R5_FB_X + 2 + FB_W/2 + 1.5, y + 3, R5_FLOOR, 1.8);
}

module rtc_tray() tray_pad(R5_RTC_X, R5_RTC_Y, RTC_W + 4, RTC_H + 4);

module mppt_tray() tray_pad(R5_MPPT_X, R5_MPPT_Y, MPPT_W + 4, MPPT_H + 4);

// ---- charge socket: bulkhead 5.5 x 2.1 DC jack in the host's right wall ----
// The host wall carries the sealed socket (its own gasket, drilled by the builder); this
// bracket holds the socket's body and keeps its lead away from the cells.
module charge_bracket() {
    r5_box(R5_W - R5_WALL - 12, R5_CHG_Y - 11, R5_W - R5_WALL, R5_CHG_Y + 11, R5_FLOOR, 5);
    for (dy=[-11, 11])
        r5_box(R5_W - R5_WALL - 12, R5_CHG_Y + dy - 2, R5_W - R5_WALL, R5_CHG_Y + dy + 2,
               R5_FLOOR + 5, 11);
}
module charge_cut() {
    // clearance through the wall for the socket barrel and its nut
    r5_box(R5_W - R5_WALL - 8, R5_CHG_Y - 6, R5_W + 1, R5_CHG_Y + 6, CHG_Z_R5 - 6, 12);
}

// ---- vents: under the Pi's free edge, between the HAT and the keyboard end ----
module vents() for (i=[0:5])
    r5_box(96, 96 + i*3.2, 140, 98.8 + i*3.2, -1, R5_FLOOR + 2);

// ---- hinge-side rim notch: the display FFC and module leads cross the rim ----
module rim_notch() r5_box(R5_W/2 - 55, R5_WALL - 1, R5_W/2 + 55, R5_WALL + 2, R5_H_BOT - 2.5, 3);

module floor_text() r5_at(R5_W/2, R5_L - 6, R5_FLOOR - 0.5) linear_extrude(1)
    text("KTEMATA  r5", size=6, halign="center", valign="center", font="Liberation Sans:style=Bold");

module r5_tray() difference() {
    union() {
        tray_shell();
        for (p=R5_SCREWS) boss_solid(p);
        // two saddles per cell, so the can cannot rock about a single central one
        for (p=R5_CELL_POS) for (dy=[-CELL_L/2 + 8, CELL_L/2 - 8])
            cell_cradle(p[0], p[1] + dy);
        firebeetle_tray(); rtc_tray(); mppt_tray();
        charge_bracket();
    }
    for (p=R5_SCREWS) boss_cut(p);
    // saddle bore: along y (the cell axis), centred on the cell centre height
    // bore each saddle, not the whole span: the gap between the pair is the cell's free length
    for (p=R5_CELL_POS) for (dy=[-CELL_L/2 + 8, CELL_L/2 - 8])
        r5_at(p[0], p[1] + dy - 4, CELL_ZC_R5) rotate([90, 0, 0]) cylinder(d=CELL_D + 1.2, h=8);
    charge_cut();
    vents();
    rim_notch();
    floor_text();
    translate([-1, -1, R5_H_BOT]) cube([R5_W + 2, R5_L + 2, 20]);
}

if (is_undef(ASSEMBLY)) r5_tray();

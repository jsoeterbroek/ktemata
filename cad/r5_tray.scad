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

// ---- board posts: the HAT (B) and the Pi sandwich each bolt to the floor ----
// One Ø8 column under each of the four Pi-standard mounting holes, rising to the height that
// board's lowest pcb sits at, with a Ø2.2 pilot for an M2.5. The column is a straight cylinder
// (vertical wall, no support) and the pilot stops 2 mm below its top face so the screw cannot
// break through into the cavity.
//
// The two assemblies do NOT share a height: the HAT (B)'s pcb is carried 23.35 mm above its cells
// by Waveshare's own holder, while the Pi's post must stop at the M.2 BASE's underside (7.4 mm).
// They do not share a position - each board's four holes are computed from its own corner
// (R5_UPS_HOLES / R5_PI_HOLES) - but they do share the 58 x 49 Pi-standard hole pattern.
//
// The HAT (B)'s four 3 mm holes are its mounting holes: the M2.5s go up through them into the
// posts, which is why the post top must be exactly R5_HAT_BOT. Its cells and holder hang in the
// cradles below the pcb, and the posts stand clear of them (the holes are inboard of the cell
// pair on the 49 mm axis and the cells run between them on the 58 mm axis).
// The pilot is blind: it runs from the post's top face down to 1.5 mm above the tray's outer
// floor face (z = 0), so it never breaks through into whatever is underneath. That gives the
// 24.35 mm HAT post 9 mm of thread and the 5 mm Pi post 6 mm (post plus floor), which is what an
// M2.5 self-tapper wants.
module board_post(p, top, d=8) {
    dep = min(9, top - 1.5);
    r5_at(p[0], p[1]) translate([0, 0, R5_FLOOR]) cylinder(d=d, h=top - R5_FLOOR);
    r5_at(p[0], p[1]) translate([0, 0, top - dep]) cylinder(d=M25_PIL, h=dep + 0.01);
}
module ups_posts() for (p=R5_UPS_HOLES) board_post(p, R5_HAT_BOT);
module pi_posts()  for (p=R5_PI_HOLES)  board_post(p, R5_M2_BOT);

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

// ---- wall windows: take the middle band out of the four free wall runs ----
// The walls do three jobs only: locate the cassette in the host, carry the six deck bosses and
// close the side of the tray. The stack's weight goes through the floor (cells, HAT and Pi all
// rest on it), so a wall only has to stay stiff in its own plane. Removing a 23.55 mm band saves
// ~21 cm3 of PETG (~27 g) and leaves a frame: an 8 mm band above the floor (the print's first
// 27 layers stay closed), a 12 mm rim band that the deck bolts to (the boss pilots start at
// 36.95), the 14 mm corner radii, and a solid zone round every boss.
//
WIN = is_undef(WIN) ? true : WIN;   // -D WIN=false prints the tray with solid walls
WIN_Z0 = R5_FLOOR + 8;              // 10.4, clear of the floor and the cell saddles
WIN_Z1 = R5_H_BOT - 12;            // 33.95, below the boss pilots (36.95)
WIN_RIB = 6;                       // solid rib between two openings
WIN_TARGET = 24;                   // opening width to aim at
WIN_MIN = 12;                      // below this the wall stays solid
WIN_BOSS = BOSS_D/2 + 3;           // run ends this far from a deck-boss centre (6.5)
//
// The head of an opening is a 45 deg gable, not a flat ceiling and not a semicircle. Measured
// with the project's own profile (Bambu P1S, PETG, 0.3 mm layers, tree(auto)) on the identical
// tray, support filament for the whole part:
//     flat head      4616 mm     (a 24 mm ceiling in the wall is an unsupported span)
//     semicircle     3205 mm     (overhangs beside the wall until its slope shallows)
//     45 deg gable    497 mm
// 45 deg is this project's existing printable-overhang limit (see the design constraints in
// AGENTS.md), so the gable is printed as two slopes that support themselves; only the last two
// layers at the apex bridge a short span. It also means the opening narrows going up, so each
// layer starts on the wall and closes inwards. WIN_GABLE is the rise; it is clamped to w/2 so the
// two slopes always meet inside the opening.
WIN_GABLE = 12;                    // rise of the 45 deg gable (w/2 at the 24 mm target)
module win_profile(w) {
    r = min(WIN_GABLE, w/2);
    polygon([[0, WIN_Z0], [w, WIN_Z0], [w, WIN_Z1 - r], [w/2, WIN_Z1], [0, WIN_Z1 - r]]);
}

// The profile is 2D (u = along the wall, v = height). Both cutters map u to the wall run, v to
// +z and the extrusion to straight through the wall, as a proper rotation (det +1, so the solid
// is not mirrored): win_x pierces along +x (the long walls), win_y along -y (the two ends).
module win_x(x0, x1, ay0, ay1, w)
    translate([x0 - 1, R5_L - ay1, 0]) multmatrix([[0, 0, 1, 0], [1, 0, 0, 0],
                                                   [0, 1, 0, 0], [0, 0, 0, 1]])
        linear_extrude(x1 - x0 + 2) win_profile(w);
module win_y(y0, y1, ax0, ax1, w)
    translate([ax0, R5_L - y0 + 1, 0]) multmatrix([[1, 0, 0, 0], [0, 0, -1, 0],
                                                   [0, 1, 0, 0], [0, 0, 0, 1]])
        linear_extrude(y1 - y0 + 2) win_profile(w);

// One row of windows along a run. n follows WIN_TARGET so a long run becomes several openings
// with solid ribs between them instead of one wide hole: each rib keeps the wall stiff in its own
// plane. A run shorter than WIN_MIN is left solid, and so is one so long that its arch radius
// (w/2) would exceed the band - the opening then has no straight sides left.
module win_row_x(x0, x1, ay0, ay1) {
    len = ay1 - ay0;
    n = max(1, round((len + WIN_RIB)/(WIN_TARGET + WIN_RIB)));
    w = (len - (n - 1)*WIN_RIB)/n;
    if (w >= WIN_MIN && w/2 < WIN_Z1 - WIN_Z0) for (i=[0 : n - 1])
        win_x(x0, x1, ay0 + i*(w + WIN_RIB), ay0 + i*(w + WIN_RIB) + w, w);
}
module win_row_y(y0, y1, ax0, ax1) {
    len = ax1 - ax0;
    n = max(1, round((len + WIN_RIB)/(WIN_TARGET + WIN_RIB)));
    w = (len - (n - 1)*WIN_RIB)/n;
    if (w >= WIN_MIN && w/2 < WIN_Z1 - WIN_Z0) for (i=[0 : n - 1])
        win_y(y0, y1, ax0 + i*(w + WIN_RIB), ax0 + i*(w + WIN_RIB) + w, w);
}

// The four wall runs, in drawing coordinates. Each starts 6 mm inside the 14 mm corner (the
// tangent point is at y=14), ends WIN_BOSS short of a deck boss, and — on the right wall — keeps
// out of the charge-socket bracket (y 107..129, solid against the wall) with a rib's margin.
module wall_windows() {
    // left wall: boss at y=40, the long free span, boss at y=R5_L-40
    win_row_x(0, R5_WALL, 20, 40 - WIN_BOSS);
    win_row_x(0, R5_WALL, 40 + WIN_BOSS, R5_L - 40 - WIN_BOSS);
    win_row_x(0, R5_WALL, R5_L - 40 + WIN_BOSS, R5_L - 20);
    // right wall: same bosses, but the bracket leaves only 46.5..101 free in the middle (the
    // 3.1 mm between the bracket and the lower boss is not worth a window and stays solid)
    win_row_x(R5_W - R5_WALL, R5_W, 20, 40 - WIN_BOSS);
    win_row_x(R5_W - R5_WALL, R5_W, 40 + WIN_BOSS, R5_CHG_Y - 17);
    win_row_x(R5_W - R5_WALL, R5_W, R5_L - 40 + WIN_BOSS, R5_L - 20);
    // hinge and keyboard ends: the boss pair sits at x 26 / R5_W-26 (see R5_SCREWS), so each end
    // gets one long run between the two boards' post rows plus a short one at each corner
    win_row_y(0, R5_WALL, 20, 26 - WIN_BOSS);
    win_row_y(0, R5_WALL, 26 + WIN_BOSS, R5_W - 26 - WIN_BOSS);
    win_row_y(0, R5_WALL, R5_W - 26 + WIN_BOSS, R5_W - 20);
    win_row_y(R5_L - R5_WALL, R5_L, 20, 26 - WIN_BOSS);
    win_row_y(R5_L - R5_WALL, R5_L, 26 + WIN_BOSS, R5_W - 26 - WIN_BOSS);
    win_row_y(R5_L - R5_WALL, R5_L, R5_W - 26 + WIN_BOSS, R5_W - 20);
}


// ---- vents: through the floor, in the strip between the boards and the keyboard ----
// The old slots sat at x 96..140, y 96..115, which is now under the HAT (B)'s pcb and its 2x
// 18650s. They move to x 96..140, y 104..112 - the free floor between the boards' +y edge (101)
// and the keyboard well's wall (102.5 is the well, this is its underside at 102.5-1.8), so they
// vent the cavity without opening anything under a board. Six 3 mm slots, as before.
module vents() for (i=[0:5])
    r5_box(96, 104 + i*3.2, 140, 106.8 + i*3.2, -1, R5_FLOOR + 2);

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
        ups_posts(); pi_posts();
    }
    for (p=R5_SCREWS) boss_cut(p);
    // saddle bore: along y (the cell axis), centred on the cell centre height
    // bore each saddle, not the whole span: the gap between the pair is the cell's free length
    for (p=R5_CELL_POS) for (dy=[-CELL_L/2 + 8, CELL_L/2 - 8])
        r5_at(p[0], p[1] + dy - 4, CELL_ZC_R5) rotate([90, 0, 0]) cylinder(d=CELL_D + 1.2, h=8);
    charge_cut();
    if (WIN) wall_windows();
    vents();
    rim_notch();
    floor_text();
    translate([-1, -1, R5_H_BOT]) cube([R5_W + 2, R5_L + 2, 20]);
}

if (is_undef(ASSEMBLY)) r5_tray();

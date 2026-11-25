// Ktemata R6 - cassette tray (the base's floor, display well and power band)
//
// The tray is the R6 cassette floor. It carries everything that is not bolted to the display:
// the Waveshare UPS Module 3S with its three 18650 cells, and the PCH carrier. The Pi 5 and the
// NVMe Base Duo are bolted to the back of the display (docs/R6.md "Display/Pi/Duo structural
// assembly"), so they hang inside the display well and the tray never touches them.
//
// Coordinates: x left->right, drawing y = 0 at the hinge end, z = 0 at the underside, rising.
// PRINT FLOOR DOWN as modelled: walls and bosses grow upward and the vent grid drops straight
// through the floor, so nothing needs support. The UPS sits directly on the flat floor.
//
// This is a fit part, not a released design: the deck carries the panel (see r6_deck.scad); the
// DSI/PCIe lead routing and the UPS harness bends are unmodelled. The asserts below guard the
// published envelope only.
include <common.scad>

// ---------------------------------------------------------------- host and tray
R6T_W        = HOST_L - 2*HOST_CLR;        // 233.5, Peli 1200 interior less 1.5 mm a side
R6T_L        = HOST_W - 2*HOST_CLR;        // 178.1
R6T_PAD      = 8;                          // tray underside -> host floor (r5's pad height)
R6T_H        = 65;                         // underside -> rim
R6T_FLOOR    = 3;
R6T_WALL     = 2.5;
R6T_R        = 8;                          // outer corner radius

// ---------------------------------------------------------------- display well
R6T_DISP_W   = 192.96;                     // Waveshare 7inch DSI LCD (C) panel width
R6T_DISP_L   = 110.76;                     // panel height
R6T_DISP_T   = 10.50;                      // glass to rear envelope
R6T_DISP_CLR = 0.7;                        // well -> display pocket, per side
R6T_WELL_W   = R6T_DISP_W + 2*R6T_DISP_CLR;
R6T_WELL_L   = R6T_DISP_L + 2*R6T_DISP_CLR;
R6T_WELL_X0  = (R6T_W - R6T_WELL_W)/2;
R6T_WELL_Y0  = R6T_L - R6T_WALL - R6T_WELL_L - 4;   // 4 mm in from the far wall; the display sits
                                                // at the FAR end: in the flat-open posture the
                                                // keyboard (lid) is behind the hinge, so the glass
                                                // wants to be the furthest thing from it

// Deck (full-face top) interface: four Ø8 bosses, tops at R6T_BOSS_Z, Ø2.6 pilots. The pattern is
// shared with r6_deck.scad (R6D_BOSS) and sits outside the panel's 192.96 x 110.76 outline, so the
// deck's four screws never pass through the display. All four stand on free floor; the PCH board
// ends at y 68.55, clear of the 70 mm boss edge.
R6T_DECK_BOSS = [[9, 74], [9, 150], [224.5, 74], [224.5, 150]];
R6T_BOSS_Z   = R6T_H - 12;                 // deck underside; 12 mm of deck + panel above it
R6T_BOSS_D   = 8;
R6T_M3_PILOT = 2.6;                        // M3 thread-forming screw into PLA
R6T_M3_DEPTH = 10;

// Display stack below the glass, for the assert: panel + 15 mm M2.5 extensions (Pi plane at 29) +
// the Duo's 12 mm standoffs + Duo pcb + drive.
R6T_PI_PLANE = 29;
R6T_DUO_STAND = 12;
R6T_DUO_PCB   = 1.6;
R6T_DRIVE     = 4;
R6T_STACK     = R6T_DISP_T + R6T_PI_PLANE + R6T_DUO_STAND + R6T_DUO_PCB + R6T_DRIVE;

// ---------------------------------------------------------------- power band
// The display is carried on bosses at R6T_BOSS_Z, so it overhangs the floor in front of the well:
// the power band is not a separate pocket, just the free floor from the hinge wall to the well.
// The 93 x 60 mm UPS Module 3S rests directly on that floor, without raised posts or a battery cradle.
R6T_UPS_W    = 93;
R6T_UPS_L    = 60;
R6T_UPS_X0   = 74;
R6T_UPS_Y0   = R6T_WALL + 0.5;

// PCH carrier, taken from cad/kicad/r6/PCH/PCH.kicad_pcb as the source of truth: 63.05 x 66.05 mm
// outline (100..163 x 100..166), four O2.7 M2.5 holes as offsets from that outline's origin.
R6T_PCH_W     = 63.05;
R6T_PCH_L     = 66.05;
R6T_PCH_HOLES = [[2, 2], [61, 2], [2, 35], [61, 36.5]];   // H1..H4, H3/H4 are 1.5 mm out of step
R6T_PCH_X0    = R6T_W - R6T_WALL - R6T_PCH_W;             // 167.95
R6T_PCH_Y0    = R6T_WALL;                                 // its 5 mm tail runs under the display
R6T_PCH_POST  = 6;
R6T_PCH_LIFT  = 8;
R6T_PCH_PILOT = 2.2;

// Vent grid under the Pi/Duo so the Active Cooler is not breathing against a sealed floor.
R6T_VENT_D   = 4;
R6T_VENT_P   = 11;
R6T_VENT_W   = 85;                        // Pi footprint
R6T_VENT_L   = 56;

// ---------------------------------------------------------------- envelope guards
assert(R6T_PAD + R6T_H <= HOST_BOT - 1,
       str("host ", HOST, ": pad + tray = ", R6T_PAD + R6T_H, " mm, the base is ", HOST_BOT));
assert(R6T_STACK + R6T_FLOOR + 4 <= R6T_H,
       str("display + Pi + Duo stack is ", R6T_STACK, " mm; the tray is ", R6T_H,
           " mm with a ", R6T_FLOOR, " mm floor - raise R6T_H or shorten the extensions"));
assert(R6T_UPS_Y0 + R6T_UPS_L <= R6T_L - R6T_WALL - 2,
       str("UPS board ends at ", R6T_UPS_Y0 + R6T_UPS_L, " mm, the inner floor at ",
           R6T_L - R6T_WALL, " - the deck's flat underside is above it"));
assert(R6T_UPS_X0 + R6T_UPS_W + 0.5 <= R6T_PCH_X0,
       str("UPS ends at ", R6T_UPS_X0 + R6T_UPS_W, ", PCH starts at ", R6T_PCH_X0));
assert(R6T_PCH_X0 + R6T_PCH_W <= R6T_W - R6T_WALL + 0.05,
       str("PCH is ", R6T_PCH_W, " mm wide; the inner floor is ", R6T_W - 2*R6T_WALL));
assert(R6T_PCH_LIFT + 20 <= R6T_BOSS_Z,
       "the PCH and its tallest part must stay under the deck");
// The deck's bosses stand on free floor beyond the PCH carrier and outside the display well.
for (b = R6T_DECK_BOSS) {
    assert(b[1] - R6T_BOSS_D/2 > R6T_PCH_Y0 + R6T_PCH_L,
           str("deck boss at y ", b[1], " runs into the PCH carrier"));
    assert(b[0] < R6T_WELL_X0 - R6T_BOSS_D/2 || b[0] > R6T_WELL_X0 + R6T_WELL_W + R6T_BOSS_D/2,
           str("deck boss at x ", b[0], " stands in the display well"));
}

// ---------------------------------------------------------------- helpers
module r6t_at(x, y, z=0) translate([x, R6T_L - y, z]) children();
// Post with a thread-forming pilot. The post starts 0.01 mm inside the floor (never coplanar with
// the bed face, never proud of it) and its top is exactly h.
module r6t_post(x, y, d, h, pilot, depth) {
    translate([x, R6T_L - y, 0.01]) difference() {
        cylinder(d=d, h=h - 0.01);
        translate([0, 0, h - depth]) cylinder(d=pilot, h=depth + 1);
    }
}

// One deck screw boss.
module r6t_deck_bosses()
    for (b = R6T_DECK_BOSS)
        r6t_post(b[0], b[1], R6T_BOSS_D, R6T_BOSS_Z, R6T_M3_PILOT, R6T_M3_DEPTH);

module r6t_pch_posts()
    for (h = R6T_PCH_HOLES)
        r6t_post(R6T_PCH_X0 + h[0], R6T_PCH_Y0 + h[1],
                 R6T_PCH_POST, R6T_PCH_LIFT, R6T_PCH_PILOT, 6);

module r6t_vent_grid() {
    x0 = R6T_W/2 - R6T_VENT_W/2;
    y0 = R6T_WELL_Y0 + R6T_WELL_L/2 - R6T_VENT_L/2;
    nx = floor(R6T_VENT_W/R6T_VENT_P);
    ny = floor(R6T_VENT_L/R6T_VENT_P);
    for (i = [0:nx])
        for (j = [0:ny])
            translate([x0 + i*R6T_VENT_P + (R6T_VENT_W - nx*R6T_VENT_P)/2,
                       R6T_L - (y0 + j*R6T_VENT_P + (R6T_VENT_L - ny*R6T_VENT_P)/2), -1])
                cylinder(d=R6T_VENT_D, h=R6T_FLOOR + 2);
}

// ---------------------------------------------------------------- the part
module r6_tray() {
    difference() {
        union() {
            // shell: floor + walls, square edges so the whole part prints floor-down without support
            difference() {
                linear_extrude(R6T_H) rrect(R6T_W, R6T_L, R6T_R);
                translate([R6T_WALL, R6T_L - R6T_L + R6T_WALL, R6T_FLOOR])
                    linear_extrude(R6T_H)
                        rrect(R6T_W - 2*R6T_WALL, R6T_L - 2*R6T_WALL, R6T_R - R6T_WALL);
            }
            r6t_deck_bosses();
            r6t_pch_posts();
        }
        r6t_vent_grid();
    }
}

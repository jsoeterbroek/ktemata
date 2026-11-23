// Ktemata R6 - deck (full-face cassette top: display, charge jack, power switch, guarded vent)
//
// r5's deck was the cassette's whole top face. R6 keeps that: the keyboard moved to the host lid
// (r6_lid_plate), so this deck carries the Waveshare 7inch DSI LCD (C) in a 10.5 mm pocket, the
// 12.6 V DC5521 charge jack, the 10 mm latching switch and a guarded air-flow opening, and it closes
// the whole tray opening. There is no separate display frame any more.
//
// One joint: four M3 countersunk screws down through the top face into the tray's four Ø8 bosses
// (pattern shared with r6_tray.scad). Those four points sit outside the panel's 192.96 x 110.76
// outline, so no screw ever passes through the display. The panel is held by its own four M3
// inserts through the 3 mm pocket floor, entered from below once the deck is out - the same
// service order r5 used.
//
// Coordinates: deck-local, y = 0 at the hinge edge, z = 0 at the underside (the plane that lands on
// the bosses) and z = 13.5 at the visible top face. In the cassette the underside is at z 53, so the
// glass lands at 66.5: 1.5 mm proud of the tray's 65 mm rim and 7.9 mm under the Peli 1200 base's
// 74.4 mm interior.
//
// PRINT AS MODELLED: underside on the bed. The panel pocket, the two connector recesses, the
// countersinks and the fan opening face upward; the lead slot and screw holes are through. The
// full-height guard bars grow from the bed, so nothing needs support. The deck is a solid 13.5 mm
// slab: a 3 mm skin would need a 190 mm ceiling over the pocket or a 57 mm unsupported rim over the
// power band.
//
// Fit prototype: the panel's insert depth, standoff-extension diameter and two lead exits are not
// measured. The opening aids convection in the open operating posture; it is not matched to a fan curve.
include <common.scad>

// ---------------------------------------------------------------- tray interface (assembly)
R6D_TRAY_X0   = 2.5;                       // tray inner wall
R6D_TRAY_Y0   = 2.5;
R6D_TRAY_W    = 228.5;                    // 233.5 - 2 x 2.5
R6D_TRAY_L    = 173.1;                    // 178.1 - 2 x 2.5
R6D_CLR       = 0.3;                      // deck -> tray wall, per side
R6D_W         = R6D_TRAY_W - 2*R6D_CLR;   // 227.9
R6D_L         = R6D_TRAY_L - 2*R6D_CLR;   // 172.5
R6D_R         = 5.2;                      // tray inner corner 5.5 less the clearance
R6D_T         = 13.5;                     // underside -> visible top face
R6D_BASE      = 3;                        // material under the panel

// The deck's four screws, in assembly (tray) coordinates. They are outside the panel outline by
// more than a screw head; r6_tray.scad's R6T_DECK_BOSS must equal this list.
R6D_BOSS      = [[9, 74], [9, 150], [224.5, 74], [224.5, 150]];

// ---------------------------------------------------------------- panel
R6D_PANEL     = [192.96, 110.76];         // Waveshare 7inch DSI LCD (C)
R6D_PANEL_T   = 10.50;                    // glass to rear envelope
R6D_PANEL_CLR = 0.35;                     // pocket wall clearance per side
R6D_PANEL_C   = [116.75 - R6D_TRAY_X0 - R6D_CLR,
                 115.52 - R6D_TRAY_Y0 - R6D_CLR];   // 113.95 x 112.72, centred over the tray's well
R6D_PANEL_X0  = R6D_PANEL_C[0] - R6D_PANEL[0]/2;
R6D_PANEL_Y0  = R6D_PANEL_C[1] - R6D_PANEL[1]/2;
// Measured panel-relative rear features from r5_lid_cover_waveshare_7in.scad. Neither pattern is
// centred on the glass: the outer inserts and inner Pi standoffs are independent mounting interfaces.
R6D_PANEL_INSETS = [[34.42, 31.58], [160.67, 31.58],
                    [34.42, 97.07], [160.67, 97.07]];  // M3, 126.25 x 65.49 span
R6D_PI_POSTS     = [[73.97, 32.43], [131.97, 32.43],
                    [73.97, 81.43], [131.97, 81.43]];  // M2.5, 58 x 49 span
R6D_PI_POST_D    = 6.5;                     // standoff-extension passage; measure the fitted hardware
R6D_POCKET    = [R6D_PANEL[0] + 2*R6D_PANEL_CLR,
                 R6D_PANEL[1] + 2*R6D_PANEL_CLR];   // 193.66 x 111.46

// Panel leads: a through-slot in the 3 mm pocket floor, under the panel, near its hinge edge. The
// DSI/touch tails drop straight into the tray volume where the Pi already hangs.
R6D_SLOT      = [34, 6];
R6D_SLOT_Y    = 58;                       // 1 mm clear of the pocket edge at 56.99
R6D_SLOT_CX   = R6D_PANEL_C[0];

// ---------------------------------------------------------------- connectors
// Both nuts go on top, inside an 8 mm recess: the plate below them stays 5.5 mm. Printing the nut
// pocket from the underside would put a bridge over it, and a separate collar cannot hang below a
// slab whose underside is on the bed.
R6D_JACK      = [40, 25];
R6D_JACK_D    = 8.2;                      // DC5521 panel jack: 8 mm mounting hole + print clearance
R6D_SW        = [120, 25];
R6D_SW_D      = 10.2;                     // 10 mm latching switch + print clearance
R6D_RECESS    = 25;                       // nut recess
R6D_RECESS_D  = 8;

// ---------------------------------------------------------------- guarded fan opening
// One 40 mm fan opening between the existing jack and switch. The guard bars occupy the full
// plate thickness, so they grow from the bed instead of bridging the opening at the top face.
R6D_FAN_C        = [80, 28.5];
R6D_FAN_D        = 38;                     // 38 mm clear opening for a 40 mm fan
R6D_FAN_HOLE_SP  = 32;                     // 40 mm fan mounting pattern
R6D_FAN_SCREW_D  = 3.4;
R6D_GRILLE_BARS  = 7;
R6D_GRILLE_BAR   = 1.4;
R6D_GRILLE_EMBED = 1.5;

R6D_SCREW     = 3.4;                      // M3 clearance
R6D_CSK       = 6.4;                      // 90 deg countersink for an M3 countersunk head

// Pocket edges, deck-local (the pocket is the panel plus clearance).
R6D_POCKET_X0 = R6D_PANEL_C[0] - R6D_POCKET[0]/2;   // 17.12
R6D_POCKET_X1 = R6D_PANEL_C[0] + R6D_POCKET[0]/2;   // 210.78
R6D_POCKET_Y0 = R6D_PANEL_C[1] - R6D_POCKET[1]/2;   // 56.99
R6D_POCKET_Y1 = R6D_PANEL_C[1] + R6D_POCKET[1]/2;   // 168.45

function r6d_edge_dist(x, y, x0, y0, x1, y1) =
    sqrt(pow(max(max(x0 - x, 0), x - x1), 2) + pow(max(max(y0 - y, 0), y - y1), 2));

// ---------------------------------------------------------------- guards
assert(R6D_W <= R6D_TRAY_W - 2*R6D_CLR + 1e-9 && R6D_L <= R6D_TRAY_L - 2*R6D_CLR + 1e-9,
       "the deck is wider than the tray's inner walls allow");
assert(R6D_POCKET_X0 > R6D_CSK/2 + 3,
       "no room between the panel pocket and the deck's side edge for a screw head");
assert(R6D_L - R6D_POCKET_Y1 > 3,
       "the panel pocket reaches the deck's far edge");
assert(R6D_POCKET_Y0 > R6D_RECESS + 15,
       "the hinge strip is too short for the connector recesses and the pocket");
for (p = R6D_PANEL_INSETS)
    assert(p[0] > R6D_SCREW/2 + 1 && p[0] < R6D_PANEL[0] - R6D_SCREW/2 - 1
           && p[1] > R6D_SCREW/2 + 1 && p[1] < R6D_PANEL[1] - R6D_SCREW/2 - 1,
           "a panel fixing screw would break out of the pocket floor");
for (p = R6D_PI_POSTS)
    assert(p[0] > R6D_PI_POST_D/2 + 1 && p[0] < R6D_PANEL[0] - R6D_PI_POST_D/2 - 1
           && p[1] > R6D_PI_POST_D/2 + 1 && p[1] < R6D_PANEL[1] - R6D_PI_POST_D/2 - 1,
           "a Pi standoff passage would break out of the pocket floor");
assert(R6D_SLOT_Y > R6D_POCKET_Y0 && R6D_SLOT_Y + R6D_SLOT[1] < R6D_POCKET_Y1,
       "the panel lead slot must stay under the panel");
assert(R6D_JACK[1] - R6D_RECESS/2 > 2 && R6D_SW[1] - R6D_RECESS/2 > 2,
       "a connector recess would break out of the deck's hinge edge");
assert(abs(R6D_JACK[0] - R6D_SW[0]) > R6D_RECESS + 2,
       "the jack and switch recesses touch");
for (b = R6D_BOSS)
    assert(r6d_edge_dist(b[0] - R6D_TRAY_X0 - R6D_CLR, b[1] - R6D_TRAY_Y0 - R6D_CLR,
                         R6D_POCKET_X0, R6D_POCKET_Y0, R6D_POCKET_X1, R6D_POCKET_Y1)
             > R6D_CSK/2 + 1,
           "a deck screw or its head would land in the panel pocket");
assert(R6D_FAN_C[1] - R6D_FAN_D/2 > 2
       && R6D_FAN_C[1] + R6D_FAN_D/2 < R6D_POCKET_Y0 - 2,
       "the fan opening must leave material at the hinge edge and panel pocket");
for (c = [R6D_JACK, R6D_SW])
    assert(sqrt(pow(R6D_FAN_C[0] - c[0], 2) + pow(R6D_FAN_C[1] - c[1], 2))
               > R6D_FAN_D/2 + R6D_RECESS/2 + 2,
           "the fan opening runs into a connector recess");

// ---------------------------------------------------------------- geometry
module r6d_box(x0, y0, x1, y1, z, h) translate([x0, y0, z]) cube([x1 - x0, y1 - y0, h]);

// 90 deg M3 countersink opening in the visible top face at z = R6D_T.
module r6d_csk(x, y)
    translate([x, y, R6D_T - (R6D_CSK - R6D_SCREW)/2 - 0.02])
        cylinder(d1=R6D_SCREW, d2=R6D_CSK + 1.4, h=(R6D_CSK - R6D_SCREW)/2 + 0.03);

module r6d_fan_cut() {
    translate([R6D_FAN_C[0], R6D_FAN_C[1], -1])
        cylinder(d=R6D_FAN_D, h=R6D_T + 2);
    for (dx = [-R6D_FAN_HOLE_SP/2, R6D_FAN_HOLE_SP/2])
        for (dy = [-R6D_FAN_HOLE_SP/2, R6D_FAN_HOLE_SP/2])
            translate([R6D_FAN_C[0] + dx, R6D_FAN_C[1] + dy, -1])
                cylinder(d=R6D_FAN_SCREW_D, h=R6D_T + 2);
}

module r6d_fan_grille() {
    for (b = [-(R6D_GRILLE_BARS-1)/2 : (R6D_GRILLE_BARS-1)/2]) {
        y = R6D_FAN_C[1] + b * (R6D_FAN_D / (R6D_GRILLE_BARS + 0.5));
        half = sqrt(max(0, pow(R6D_FAN_D/2, 2)
                          - pow(b * (R6D_FAN_D/(R6D_GRILLE_BARS + 0.5)), 2)));
        r6d_box(R6D_FAN_C[0] - half - R6D_GRILLE_EMBED, y - R6D_GRILLE_BAR/2,
                R6D_FAN_C[0] + half + R6D_GRILLE_EMBED, y + R6D_GRILLE_BAR/2,
                0, R6D_T);
    }
}

module r6_deck() union() {
    difference() {
        linear_extrude(R6D_T) rrect(R6D_W, R6D_L, R6D_R);
        // panel pocket, opening in the top face
        translate([R6D_PANEL_C[0] - R6D_POCKET[0]/2,
                   R6D_PANEL_C[1] - R6D_POCKET[1]/2, R6D_BASE])
            linear_extrude(R6D_PANEL_T + 1)
                rrect(R6D_POCKET[0], R6D_POCKET[1], 0.5);   // sharp enough for any panel corner radius
        // panel lead slot through the pocket floor
        r6d_box(R6D_SLOT_CX - R6D_SLOT[0]/2, R6D_SLOT_Y,
                R6D_SLOT_CX + R6D_SLOT[0]/2, R6D_SLOT_Y + R6D_SLOT[1], -1, R6D_BASE + 2);
        // 4 x M3 down into the tray's bosses
        for (b = R6D_BOSS) {
            bx = b[0] - R6D_TRAY_X0 - R6D_CLR;
            by = b[1] - R6D_TRAY_Y0 - R6D_CLR;
            translate([bx, by, -1]) cylinder(d=R6D_SCREW, h=R6D_T + 2);
            r6d_csk(bx, by);
        }
        // 4 x M3 up into the panel's measured outer inserts, heads below the deck
        for (p = R6D_PANEL_INSETS)
            translate([R6D_PANEL_X0 + p[0], R6D_PANEL_Y0 + p[1], -1])
                cylinder(d=R6D_SCREW, h=R6D_BASE + 2);
        // 4 passages for the display's inner standoff extensions; the Pi bolts to them below the floor
        for (p = R6D_PI_POSTS)
            translate([R6D_PANEL_X0 + p[0], R6D_PANEL_Y0 + p[1], -1])
                cylinder(d=R6D_PI_POST_D, h=R6D_BASE + 2);
        // charge jack and power switch: nut recess in the top face, bore through
        translate([R6D_JACK[0], R6D_JACK[1], R6D_T - R6D_RECESS_D])
            cylinder(d=R6D_RECESS, h=R6D_RECESS_D + 1);
        translate([R6D_JACK[0], R6D_JACK[1], -1])
            cylinder(d=R6D_JACK_D, h=R6D_T + 2);
        translate([R6D_SW[0], R6D_SW[1], R6D_T - R6D_RECESS_D])
            cylinder(d=R6D_RECESS, h=R6D_RECESS_D + 1);
        translate([R6D_SW[0], R6D_SW[1], -1])
            cylinder(d=R6D_SW_D, h=R6D_T + 2);
        // guarded 40 mm fan opening
        r6d_fan_cut();
    }
    // Union the guard after the cut so the opening does not delete its bars.
    r6d_fan_grille();
}

// Ktemata R6 - deck (full-face cassette top: display, charge jack, power switch, vents)
//
// r5's deck was the cassette's whole top face. R6 keeps that: the keyboard and status OLED moved to
// the host lid (r6_lid_plate), so this deck carries the Waveshare 7inch DSI LCD (C) in a 10.5 mm
// pocket, the 12.6 V charge jack, the 16 mm latching switch and the air-flow vents, and it closes
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
// countersinks and every vent open upward, and the panel lead slot and screw holes are through.
// Nothing needs support. The deck is a solid 13.5 mm slab (0.30 L, about 370 g of PLA): a 3 mm skin
// would need a 190 mm ceiling over the pocket or a 57 mm unsupported rim over the power band.
//
// Fit prototype: the panel's insert depth and the positions of its two lead exits are not measured.
// The vents are sized for convection through the sealed case, not against a fan curve.
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
R6D_INSET     = [126.25, 65.49];          // the panel's own M3 inserts
R6D_POCKET    = [R6D_PANEL[0] + 2*R6D_PANEL_CLR,
                 R6D_PANEL[1] + 2*R6D_PANEL_CLR];   // 193.66 x 111.46

// Panel leads: a through-slot in the 3 mm pocket floor, under the panel, near its hinge edge. The
// DSI/touch tails drop straight into the tray volume where the Pi already hangs.
R6D_SLOT      = [34, 6];
R6D_SLOT_Y    = 58;                       // 1 mm clear of the pocket edge at 56.99
R6D_SLOT_CX   = R6D_PANEL_C[0];

// ---------------------------------------------------------------- connectors
// Both nuts go on top, inside an 8 mm recess: the plate below them stays 5.5 mm, so a standard
// M16 switch or DC-099 jack barrel reaches. Printing the nut pocket from the underside would put
// a bridge over it, and a separate collar cannot hang below a slab whose underside is on the bed.
R6D_JACK      = [40, 25];
R6D_JACK_D    = 11.2;                     // DC-099 mounting hole
R6D_SW        = [120, 25];
R6D_SW_D      = 16.2;                     // M16 latching switch
R6D_RECESS    = 25;                       // nut recess, clears a 22 mm nut
R6D_RECESS_D  = 8;

// ---------------------------------------------------------------- vents
R6D_VENT_D    = 4;
R6D_VENT_P    = 12;
R6D_VENT_X    = [10 : R6D_VENT_P : 218];  // hinge-strip rows
R6D_VENT_Y    = [7, 48];
R6D_SIDE_X    = [13.5, 214.4];            // side columns, beside the panel pocket
R6D_SIDE_Y    = [62 : R6D_VENT_P : 165];

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
assert(R6D_INSET[0]/2 + R6D_SCREW/2 + 1 < R6D_POCKET[0]/2
       && R6D_INSET[1]/2 + R6D_SCREW/2 + 1 < R6D_POCKET[1]/2,
       "the panel's fixing screws would break out of the pocket floor");
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
assert(R6D_VENT_Y[0] - R6D_VENT_D/2 > 2
       && R6D_VENT_Y[1] + R6D_VENT_D/2 < R6D_POCKET_Y0,
       "a hinge-strip vent row runs into the panel pocket");
assert(R6D_SIDE_X[0] - R6D_VENT_D/2 - (R6D_BOSS[0][0] - R6D_TRAY_X0 - R6D_CLR + R6D_CSK/2) > 0.5
       && R6D_POCKET_X0 - (R6D_SIDE_X[0] + R6D_VENT_D/2) > 1,
       "the left vent column has no material around it");
assert((R6D_W - (R6D_BOSS[0][0] - R6D_TRAY_X0 - R6D_CLR) - R6D_CSK/2)
           - (R6D_SIDE_X[1] + R6D_VENT_D/2) > 0.5
       && (R6D_SIDE_X[1] - R6D_VENT_D/2) - R6D_POCKET_X1 > 1,
       "the right vent column has no material around it");

// ---------------------------------------------------------------- geometry
module r6d_box(x0, y0, x1, y1, z, h) translate([x0, y0, z]) cube([x1 - x0, y1 - y0, h]);

// 90 deg M3 countersink opening in the visible top face at z = R6D_T.
module r6d_csk(x, y)
    translate([x, y, R6D_T - (R6D_CSK - R6D_SCREW)/2 - 0.02])
        cylinder(d1=R6D_SCREW, d2=R6D_CSK + 1.4, h=(R6D_CSK - R6D_SCREW)/2 + 0.03);

module r6d_vents() {
    for (y = R6D_VENT_Y)
        for (x = R6D_VENT_X)
            translate([x, y, -1]) cylinder(d=R6D_VENT_D, h=R6D_T + 2);
    for (x = R6D_SIDE_X)
        for (y = R6D_SIDE_Y)
            translate([x, y, -1]) cylinder(d=R6D_VENT_D, h=R6D_T + 2);
}

module r6_deck() {
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
        // 4 x M3 up into the panel's inserts, heads below the deck
        for (sx = [-1, 1])
            for (sy = [-1, 1])
                translate([R6D_PANEL_C[0] + sx*R6D_INSET[0]/2,
                           R6D_PANEL_C[1] + sy*R6D_INSET[1]/2, -1])
                    cylinder(d=R6D_SCREW, h=R6D_BASE + 2);
        // charge jack and power switch: nut recess in the top face, bore through
        translate([R6D_JACK[0], R6D_JACK[1], R6D_T - R6D_RECESS_D])
            cylinder(d=R6D_RECESS, h=R6D_RECESS_D + 1);
        translate([R6D_JACK[0], R6D_JACK[1], -1])
            cylinder(d=R6D_JACK_D, h=R6D_T + 2);
        translate([R6D_SW[0], R6D_SW[1], R6D_T - R6D_RECESS_D])
            cylinder(d=R6D_RECESS, h=R6D_RECESS_D + 1);
        translate([R6D_SW[0], R6D_SW[1], -1])
            cylinder(d=R6D_SW_D, h=R6D_T + 2);
        // air-flow vents
        r6d_vents();
    }
}

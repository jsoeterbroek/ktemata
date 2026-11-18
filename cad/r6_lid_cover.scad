// Ktemata R6 - cassette lid cover (the display frame)
//
// The r6 counterpart of r5's lid cover: r6 puts the panel in the base cassette, so the cover is the
// frame that carries the Waveshare 7inch DSI LCD (C), bolts to the tray's four bosses, and closes the
// top of the cassette with the glass sitting proud of the tray rim.
//
// Two independent screw sets, which is why the tray's bosses are NOT on the panel's insert pattern:
//   * 4 x M3 from below, through this frame at R6C_TRAY_DX x R6C_TRAY_DY, into the tray's bosses.
//   * 4 x M3 from below, through the frame's base plate at the panel's own R6C_PANEL_DX x R6C_PANEL_DY
//     inserts. Remove the frame to reach the panel, exactly as R6.md asks for a serviceable frame.
//
// Coordinates: as assembled in the tray (x left->right, drawing y = 0 at the hinge end, z = 0 at the
// tray floor). r6_tray.scad sits underneath; its bosses' tops are at z 53. PRINT AS MODELLED, base plate
// on the bed: the pocket opens upward, the bezel is a plain wall and the lead slot bridges only 5 mm.
//
// Fit prototype: the panel's insert depth, the DSI/touch lead exits and the bezel width are not
// measured. The asserts guard the published envelope only.
include <common.scad>

// ---------------------------------------------------------------- panel
R6C_PANEL_W  = 192.96;                     // Waveshare 7inch DSI LCD (C)
R6C_PANEL_L  = 110.76;
R6C_PANEL_T  = 10.50;                      // glass to rear envelope
R6C_PANEL_CLR = 0.35;                      // pocket wall clearance per side
R6C_PANEL_DX = 126.25;                     // panel's own M3 inserts
R6C_PANEL_DY = 65.49;

// ---------------------------------------------------------------- frame
R6C_BEZEL    = 4;                          // land around the glass on the three free sides
R6C_LAND     = 10;                         // wider land on the hinge side: it carries the deck
R6C_W        = R6C_PANEL_W + 2*R6C_BEZEL;  // 200.96
R6C_L        = R6C_PANEL_L + R6C_BEZEL + R6C_LAND;   // 124.76, y = 0 at the hinge edge
R6C_BASE     = 3;                          // base plate under the panel pocket
R6C_T        = R6C_BASE + R6C_PANEL_T;     // 13.5: z 0..13.5 as printed
R6C_R        = 6;                          // outer corner radius

// Assembly z, taken from the tray: the frame's underside lands on the bosses.
R6C_BOSS_Z   = 53;
R6C_GLASS_Z  = R6C_BOSS_Z + R6C_T;         // 66.5, i.e. 1.5 mm proud of the tray's 65 mm rim

// Trays' bosses: must avoid the panel's insert pattern, so they sit further out.
R6C_TRAY_DX  = 180;
R6C_TRAY_DY  = 96;
R6C_POCKET_CY = R6C_LAND + R6C_PANEL_L/2;   // 65.38: the screws are centred on the PANEL,
                                            // not on the frame, because the tray's bosses are
R6C_SCREW    = 3.4;                        // M3 clearance
R6C_CBORE    = 6.2;                        // M3 socket-head counterbore
R6C_CBORE_T  = 1.8;

// Panel lead exit: a slot in the hinge-side land so the DSI and touch tails leave the pocket.
R6C_SLOT_W   = 34;
R6C_SLOT_D   = 5;

// Deck joint: the hinge-side land is rebated 1.5 mm deep over 8 mm, so the deck sits in it flush
// with the frame's top face and is screwed down into three inserts in the rebate floor.
R6C_REBATE_D = 8;
R6C_REBATE_T = 2.5;
R6C_DECK_HOLE_X = [40, R6C_W/2, R6C_W - 40];
R6C_DECK_HOLE_Y = 4;                        // 4 mm in from the hinge edge
R6C_PILOT    = 2.6;                         // M3 thread-forming pilot for the deck's screws

assert(R6C_TRAY_DX/2 + R6C_SCREW <= R6C_W/2 - R6C_BEZEL/2 + 1e-9,
       "tray screws would land on the bezel's outer edge");
assert(R6C_TRAY_DX/2 > R6C_PANEL_DX/2 + 6,
       "tray screws sit on the panel's insert pattern; the two screw sets must not collide");
assert(R6C_GLASS_Z <= R6C_BOSS_Z + 12 + 2,
       "frame stack taller than the tray's 12 mm headroom under its rim");

module r6c_at(x, y, z=0) translate([x, R6C_L - y, z]) children();
module r6c_box(x0, y0, x1, y1, z, h)
    translate([x0, R6C_L - y1, z]) cube([x1 - x0, y1 - y0, h]);

// ---------------------------------------------------------------- the part
module r6_lid_cover() {
    difference() {
        // body: rounded outer plate, pocket opened in the top face
        difference() {
            linear_extrude(R6C_T) rrect(R6C_W, R6C_L, R6C_R);
            // panel pocket
            translate([R6C_BEZEL - R6C_PANEL_CLR, R6C_LAND - R6C_PANEL_CLR, R6C_BASE])
                linear_extrude(R6C_PANEL_T + 1)
                    rrect(R6C_PANEL_W + 2*R6C_PANEL_CLR, R6C_PANEL_L + 2*R6C_PANEL_CLR, 2);
            // deck rebate along the hinge edge
            r6c_box(-1, -1, R6C_W + 1, R6C_REBATE_D, R6C_T - R6C_REBATE_T, R6C_REBATE_T + 1);
        }
        // lead slot through the hinge-side bezel, from the pocket floor outwards
        r6c_box(R6C_W/2 - R6C_SLOT_W/2, -1, R6C_W/2 + R6C_SLOT_W/2, R6C_SLOT_D,
                R6C_BASE - 0.01, R6C_PANEL_T + 2);
        // 3 x M3 through the deck into inserts in the rebate floor
        for (x = R6C_DECK_HOLE_X)
            translate([x, R6C_L - R6C_DECK_HOLE_Y, R6C_T - R6C_REBATE_T - 8])
                cylinder(d=R6C_PILOT, h=8 + R6C_REBATE_T + 1);
        // 4 x M3 to the tray bosses
        for (x = [R6C_W/2 - R6C_TRAY_DX/2, R6C_W/2 + R6C_TRAY_DX/2])
            for (y = [R6C_POCKET_CY - R6C_TRAY_DY/2, R6C_POCKET_CY + R6C_TRAY_DY/2]) {
                translate([x, R6C_L - y, -1]) cylinder(d=R6C_SCREW, h=R6C_T + 2);
                translate([x, R6C_L - y, R6C_T - R6C_CBORE_T])
                    cylinder(d=R6C_CBORE, h=R6C_CBORE_T + 1);      // socket head, top face
            }
        // 4 x M3 into the panel's inserts, from the frame's underside
        for (x = [R6C_W/2 - R6C_PANEL_DX/2, R6C_W/2 + R6C_PANEL_DX/2])
            for (y = [R6C_L/2 - R6C_PANEL_DY/2, R6C_L/2 + R6C_PANEL_DY/2]) {
                // heads stay below the frame: there is 50 mm of space down to the tray floor,
                // and a counterbore here would open on the bed face
                translate([x, R6C_L - y, -1]) cylinder(d=R6C_SCREW, h=R6C_BASE + 2);
            }
    }
}

// Ktemata R6 - deck (cassette top over the power band)
//
// r5's deck carried the keyboard, the OLED, the fan and the button, and screwed to the tray with seven
// M3s. In r6 the keyboard and OLED moved to the host lid (r6_lid_plate), so the deck is what is left:
// the hinge-side top cover over the UPS, cells and PCH, carrying the 12.6 V charge socket and the
// 16 mm latching switch. The display frame (r6_lid_cover) covers the rest of the cassette.
//
// Fixing, without touching the tray: three M3s down into heat-set inserts in the display frame's
// hinge-side land (the rebate cut there for exactly this), and the tray's walls locate the other three
// edges. Remove three screws and the cells, UPS and PCH are exposed from above.
//
// Coordinates: deck-local, z = 0 at the visible top face and material growing to z = 5.5. PRINT AS
// MODELLED (visible face on the bed): the countersinks open into the bed and the two connector
// counterbores are vertical walls, so nothing needs support. In the cassette the part is inverted,
// visible face up at z 66.5, flush with the display frame's top face.
//
// Fit prototype: the jack and switch are placed for harness convenience, not against a measured
// cassette opening; the tray, frame and deck share the numbers below.
include <common.scad>

// ---- shared with r6_tray.scad / r6_lid_cover.scad (assembled coordinates, y = 0 at the hinge end)
R6D_TRAY_X0   = 2.5;                       // tray inner wall
R6D_TRAY_W    = 228.5;                     // tray inner width
R6D_W         = R6D_TRAY_W;                // 228.5
R6D_FRAME_X0  = 16.27;                     // frame's hinge edge, assembled
R6D_FRAME_Y0  = 50.14;                     // frame's near edge, assembled
R6D_REBATE_D  = 8;                         // frame's rebate depth along the hinge land
R6D_HOLE_X    = [40, 200.96/2, 200.96 - 40];   // frame-local, from r6_lid_cover.scad
R6D_HOLE_Y    = 4;
R6D_L         = R6D_FRAME_Y0 + R6D_REBATE_D - R6D_TRAY_X0;   // 55.64

R6D_PLATE     = 2.5;                       // plate thickness (visible face at z 0), = the frame's rebate
R6D_COLLAR    = 4;                         // connector collar below the plate
R6D_R         = 6;                         // corner radius, matching the tray's interior
R6D_SCREW     = 3.4;                       // M3 clearance
R6D_CSK       = 6.4;                       // countersink, 90 deg, for an M3 flat head

// DC-099 panel jack: 11 mm mounting hole, nut behind. 16 mm latching switch: M16 thread.
R6D_JACK      = [40, 25];
R6D_JACK_D    = 11.2;
R6D_JACK_NUT  = 22;
R6D_SW        = [120, 25];
R6D_SW_D      = 16.2;
R6D_SW_NUT    = 22;

assert(R6D_JACK[0] - R6D_JACK_NUT/2 > 4 && R6D_SW[0] + R6D_SW_NUT/2 < R6D_W - 4,
       "a connector collar would run off the deck's edge");
assert(abs(R6D_JACK[0] - R6D_SW[0]) > (R6D_JACK_NUT + R6D_SW_NUT)/2 + 2,
       "jack and switch collars touch");
assert(R6D_JACK[1] > R6D_JACK_NUT/2 + 2 && R6D_SW[1] > R6D_SW_NUT/2 + 2,
       "connector collar too close to the deck's hinge edge");

module r6d_box(x0, y0, x1, y1, z, h) translate([x0, y0, z]) cube([x1 - x0, y1 - y0, h]);

// 90 deg countersink for an M3 flat head, opening at z = 0
module r6d_csk(x, y)
    translate([x, y, -0.01]) cylinder(d1=R6D_CSK + 2*0.7, d2=R6D_SCREW, h=(R6D_CSK - R6D_SCREW)/2 + 0.01);

module r6_deck() {
    difference() {
        union() {
            // plate, visible face down
            linear_extrude(R6D_PLATE) rrect(R6D_W, R6D_L, R6D_R);
            // connector collars below the plate
            translate([R6D_JACK[0], R6D_JACK[1], R6D_PLATE]) cylinder(d=R6D_JACK_NUT + 3, h=R6D_COLLAR);
            translate([R6D_SW[0], R6D_SW[1], R6D_PLATE]) cylinder(d=R6D_SW_NUT + 3, h=R6D_COLLAR);
        }
        // three M3s to the frame's inserts
        for (x = R6D_HOLE_X) {
            translate([R6D_FRAME_X0 - R6D_TRAY_X0 + x, R6D_FRAME_Y0 - R6D_TRAY_X0 + R6D_HOLE_Y, -1])
                cylinder(d=R6D_SCREW, h=R6D_PLATE + 2);
            r6d_csk(R6D_FRAME_X0 - R6D_TRAY_X0 + x, R6D_FRAME_Y0 - R6D_TRAY_X0 + R6D_HOLE_Y);
        }
        // jack and switch: through hole plus a nut pocket under the collar
        translate([R6D_JACK[0], R6D_JACK[1], -1]) cylinder(d=R6D_JACK_D, h=R6D_PLATE + R6D_COLLAR + 2);
        translate([R6D_JACK[0], R6D_JACK[1], R6D_PLATE])
            cylinder(d=R6D_JACK_NUT + 0.4, h=R6D_COLLAR + 1);   // nut pocket inside the collar
        translate([R6D_SW[0], R6D_SW[1], -1]) cylinder(d=R6D_SW_D, h=R6D_PLATE + R6D_COLLAR + 2);
        translate([R6D_SW[0], R6D_SW[1], R6D_PLATE])
            cylinder(d=R6D_SW_NUT + 0.4, h=R6D_COLLAR + 1);
    }
}

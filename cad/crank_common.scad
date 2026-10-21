// Pi Flux - hand crank generator: shared parameters and helpers.
//
// A separate unit: it does not fit in the case and must not load the sealed USB-C
// port. An axial-flux alternator (two 8-magnet rotors either side of an 8-coil stator)
// is driven 3:1 from a crank handle. Rectifier, buffer caps and a 5 V USB module sit in
// a tray under the base plate; the pigtail plugs into the case's charge port.
// Assembly, cut list and winding notes: docs/CRANK.md.
//
// Assembly position:
//   z = 0 at the base-plate TOP face; the plate hangs below (z = -CR_PLATE_T).
//   Rotor axis at x = y = 0; crank axis at (CR_CRANK_X, 0); +z up the shafts.
//   The unit stands on four feet; bench plane z = CR_Z_BENCH.
// Both rotors are the SAME printed part: one as printed, one flipped, so their magnets
// face the stator. The disc has no hub boss, so it prints flat.
// Units mm. Every level is derived, so changing a component moves the frame.

$fn = 48;

// ---------------- alternator ----------------
CR_MAG_N      = 8;          // magnets per rotor, alternating polarity
CR_MAG_D      = 15.0;       // N52 disc, 15 x 3 mm
CR_MAG_T      = 3.0;
CR_MAG_R      = 42.0;       // magnet pitch radius
CR_MAG_CLR    = 0.5;        // pocket clearance on the diameter
CR_MAG_DEPTH  = 3.3;        // pocket depth (magnet + glue)
CR_ROTOR_D    = 120.0;
CR_ROTOR_T    = 7.0;
CR_HUB_D      = 26.0;       // clamp hub diameter
CR_HUB_BOSS_D = 10.0;       // boss that rides on the 608 inner race (bottom rotor only)
CR_HUB_BOSS_H = 1.5;
CR_SPACER_H   = 4.3;        // clamp hub body height
CR_HUB_TOP    = CR_SPACER_H;
CR_HUB_SCREW_R = 10.5;      // disc-to-hub screw circle
CR_HUB_CB_D   = 6.2;        // M3 socket-head counterbore in the rotor, both sides
CR_BOSS_H     = CR_HUB_TOP + 6.0;   // crank bearing boss above the plate
CR_BOSS_D     = 30.0;       // crank bearing boss OD (608 needs 22.2; 30 clears the
                            // 66T gear addendum circle: 66.4 - 15 = 51.4 > 51.0)

CR_STATOR_D   = 120.0;
CR_STATOR_T   = 6.0;
CR_COIL_R0    = 29.0;       // coil window, radial
CR_COIL_R1    = 55.0;
CR_COIL_W     = 14.0;       // coil window, tangential
CR_STATOR_BORE = 12.0;
CR_LUG_R1     = 81.0;       // stator lug outer radius = post bolt circle
CR_LUG_W      = 22.0;
CR_WIRE_W     = 2.8;        // interconnect channel, stator top face
CR_WIRE_D     = 1.6;
CR_WIRE_R     = 56.0;
CR_WIRE_HOLE  = 6.0;        // wire drop through the base plate

// ---------------- shafting / bearings ----------------
CR_SHAFT_D    = 8.0;        // silver-steel rod, one ground flat
CR_BORE_D     = 8.2;
CR_FLAT       = 2.6;        // bore centre -> flat (6.6 mm across the flat)
CR_BRG_D      = 22.2;       // 608 OD
CR_BRG_T      = 7.3;
CR_TOP_BORE   = 9.0;        // top-plate guide bore for the rotor shaft

// ---------------- frame ----------------
CR_BASE_X0    = -78.0;
CR_BASE_W     = 174.0;
CR_BASE_L     = 126.0;
CR_PLATE_T    = 8.0;
CR_ROUND      = 8.0;
CR_CRANK_X    = 66.4;       // big + small pitch radii (66.0) + 0.4 mm backlash for printed gears
CR_POSTS      = [[62,52], [-62,52], [-62,-52], [62,-52]];   // r = 81
CR_POST_D     = 12.0;
CR_TPOST_D    = 14.0;       // spacer tube, stator lug -> top plate
CR_SCREW_D    = 3.4;
CR_INSERT_D   = 4.0;        // M3 heat-set insert
CR_CB_D       = 6.4;        // M3 socket-head counterbore
CR_CB_DEPTH   = 3.4;
CR_FOOT_D     = 16.0;
CR_FOOT_H     = 20.0;
CR_FOOT_SCREW = 3.4;
CR_FEET       = [[-62, 44], [-62, -44], [60, 44], [60, -44]];

// ---------------- electronics tray ----------------
CR_BOX_X0     = -70.0;
CR_BOX_X1     = -16.0;
CR_BOX_Y0     = -30.0;
CR_BOX_Y1     = 30.0;
CR_BOX_H      = 16.0;       // tray depth (plate underside to lid)
CR_BOX_WALL   = 2.5;
CR_BOX_FLOOR  = 2.5;
CR_BOX_LID_T  = 2.5;
CR_CABLE_D    = 10.0;
CR_WIRE_EXIT  = -58.0;
CR_TRAY_SCREWS = [[CR_BOX_X0+6, CR_BOX_Y0+6], [CR_BOX_X1-6, CR_BOX_Y0+6],
                  [CR_BOX_X0+6, CR_BOX_Y1-6], [CR_BOX_X1-6, CR_BOX_Y1-6]];

// ---------------- gears and crank ----------------
CR_MOD        = 1.5;
CR_T_BIG      = 66;                                  // pitch r 49.5
CR_T_SM       = 22;                                  // pitch r 16.5
CR_GEAR_T     = 12.0;
CR_ARM_T      = 8.0;
CR_ARM_W      = 22.0;
CR_ARM_R      = 75.0;
CR_GRIP_D     = 26.0;
CR_GRIP_L     = 40.0;
CR_GRIP_BOLT  = 6.4;                                 // M6 clearance

// ---------------- vertical stack (everything derived) ----------------
// Shafting: the 608s are flush with the faces they are pressed into.
//   Bottom: pocket in the base plate's TOP face, so the rotor rides just above the plate.
//   Top:    pocket in the crank boss's TOP face.
// Each rotor gets one clamp hub on its outboard face, bolted through the disc; the hub has
// a 10 mm boss that sits on the 608 inner race, and a 26 mm body that lies in a
// counterbore in the rotor disc (so the disc face nearest the stator stays flat).
CR_Z_BRG_TOP  = 0;                                   // bottom bearing top face = plate top
CR_Z_HUB0     = CR_Z_BRG_TOP + CR_HUB_BOSS_H;        // bottom hub body underside (1.5)
CR_Z_ROT0     = CR_Z_HUB0 + CR_HUB_TOP;              // bottom disc underside (5.8): the disc
                                                     // sits ON the hub and is bolted to it
CR_Z_ROT1     = CR_Z_ROT0 + CR_ROTOR_T;              // bottom disc top face (faces stator)
CR_GAP        = 0.6;                                 // disc face -> stator face
CR_Z_ST0      = CR_Z_ROT1 + CR_GAP;                  // stator underside
CR_Z_ST1      = CR_Z_ST0 + CR_STATOR_T;              // stator top face
CR_Z_TROT0    = CR_Z_ST1 + CR_GAP;                   // top disc underside (faces stator)
CR_Z_TROT1    = CR_Z_TROT0 + CR_ROTOR_T;             // top disc top face
CR_Z_TPL0     = CR_Z_TROT1 + CR_HUB_TOP + 0.5;       // top plate underside (hub body clears)
CR_Z_TPL1     = CR_Z_TPL0 + CR_PLATE_T;              // plate top face
CR_Z_BOSS1    = CR_Z_TPL1 + CR_BOSS_H;               // crank boss top (= top 608 seat)
CR_Z_GEAR     = CR_Z_TPL1 + 0.6;                     // big-gear underside
CR_Z_GEAR1    = CR_Z_GEAR + CR_GEAR_T;
CR_Z_ARM      = CR_Z_GEAR1 + 1.8;
CR_Z_CRANK_BRG = CR_Z_BOSS1 - CR_BRG_T;              // top 608 seat underside
CR_POST_H     = CR_Z_ST0;                            // base post height (11.2)
CR_TPOST_H    = CR_Z_TPL0 - CR_Z_ST1;                // 11.9 spacer tube
CR_SHAFT_L    = CR_Z_GEAR1 + 2.0;                    // 51.7 rotor shaft (cut 55 mm)
CR_CRANK_L    = CR_Z_ARM + CR_ARM_T - CR_Z_CRANK_BRG + CR_BRG_T;  // 22.4 above the bearing
CR_Z_BENCH    = -CR_PLATE_T - CR_FOOT_H;             // -28
CR_Z_TRAY0    = -CR_PLATE_T - CR_BOX_H;              // -24 tray bottom
CR_Z_CABLE    = -CR_PLATE_T - 5.0;                   // gland centre in the tray wall

// ---------------- helpers ----------------
module cr_rrect(w, h, r) offset(r=r) offset(delta=-r) square([w, h]);

module cr_plate2d() translate([CR_BASE_X0, -CR_BASE_L/2]) cr_rrect(CR_BASE_W, CR_BASE_L, CR_ROUND);

// D-bore: round bore with one flat (the shaft's ground flat), cut from -y.
module cr_dbore(h=20, d=CR_BORE_D, flat=CR_FLAT) {
    translate([0, 0, -0.5]) cylinder(d=d, h=h+1);
    translate([-d/2-1, flat, -0.5]) cube([d+2, d, h+1]);
}

// 608 seat, pressed in from z0 downwards.
module cr_brg_seat(z0=-CR_BRG_T) translate([0, 0, z0]) cylinder(d=CR_BRG_D, h=CR_BRG_T);

// involute spur gear profile: one flank generated, mirrored about the tooth centre.
// The root disc fills the valleys, so the union stays manifold for any tooth count.
// involute function inv(a) = tan(a) - a, returned in DEGREES. OpenSCAD trig takes
// degrees, so the argument must be converted to radians before subtracting.
function cr_inv(a) = (tan(a) - PI*a/180) * 180 / PI;

module cr_gear2d(z, m=CR_MOD, pa=20, n=6) {
    rp = m*z/2;
    rb = rp*cos(pa);
    ra = rp + m;
    rf = rp - 1.25*m;
    rr = rf - 0.5;                          // root disc, 0.5 mm under the tooth roots so the
                                            // tooth polygons overlap it (no coincident faces)
    half = 180/(2*z);                       // half tooth thickness at rp, deg
    // half tooth thickness at radius r, from the involute function (degrees throughout)
    function th(r) = half + cr_inv(pa) - cr_inv(acos(min(1, rb/r)));
    union() {
        circle(r = rr);
        for (i=[0:z-1]) rotate([0,0,i*360/z]) polygon(concat(
            [[rr*cos(th(rf)), -rr*sin(th(rf))]],                       // root, left
            [for (k=[0:n]) let(r = rf + (ra-rf)*k/n) let(a = th(r))
                [r*cos(a), -r*sin(a)]],                                // left flank, root -> tip
            [for (k=[n:-1:0]) let(r = rf + (ra-rf)*k/n) let(a = th(r))
                [r*cos(a), r*sin(a)]],                                 // right flank, tip -> root
            [[rr*cos(th(rf)), rr*sin(th(rf))]]                         // root, right
        ));
    }
}

// gear body: D-bore (2-D cut, then a single extrude - avoids CGAL on the tooth caps),
// pinch-clamp slit across the flat, optional lightening holes.
module cr_gear(z, t=CR_GEAR_T, clamp=true, holes=0, hole_d=0, hole_r=0) {
    linear_extrude(t) difference() {
        cr_gear2d(z);
        // D-bore, cut as one 2-D outline
        union() {
            circle(d = CR_BORE_D);
            translate([-CR_BORE_D/2, CR_FLAT]) square([CR_BORE_D, CR_BORE_D]);
        }
        for (i=[0:max(0,holes-1)]) if (holes > 0)
            rotate([0,0,i*360/holes]) translate([hole_r, 0]) circle(d=hole_d);
        if (clamp) translate([-1.2, CR_FLAT]) square([2.4, CR_BORE_D]);
    }
}

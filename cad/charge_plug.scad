// Ktemata - TPU plug for the sealed charge port
// r2/r3: round-nosed plug for the USB-C rectangular opening.
// r4: round plug for the Ø9.5 mm DC socket hole (the HAT (B) charges from 8.4 V DC).
// Print in TPU, flange on the bed. The flange seats in the outside O-ring recess
// (`CHG_REC_W` across); the body fills the opening.
include <common.scad>

module charge_plug() {
    fw = CHG_REC_W - 0.5;
    // flange (sits in the outside recess)
    if (R4) {
        translate([0, 0, 0]) cylinder(d=fw, h=1.2);
        // round body, 0.3 mm clearance all round, 6.6 mm deep into the socket bore
        translate([0, 0, 1.0]) cylinder(d=CHG_W - 0.6, h=6.6);
    } else {
        fh = CHG_REC_H - 0.5;
        translate([-fw/2, -fh/2, 0]) cube([fw, fh, 1.2]);
        // USB-C body, 0.3 mm clearance all round
        translate([-(CHG_W-0.6)/2, -(CHG_H-0.6)/2, 1.0])
            linear_extrude(6.6) rrect(CHG_W-0.6, CHG_H-0.6, 1.2);
        // pull tab
        translate([-fw/2-6, -fh/2, 1.0]) cube([6.2, fh, 2.2]);
    }
    // pull tab (both variants)
    if (R4) translate([-fw/2-6, -1.1, 1.0]) cube([6.2, 2.2, 2.2]);
}
charge_plug();

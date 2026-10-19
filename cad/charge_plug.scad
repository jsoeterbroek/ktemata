// Pi Flux r2 - TPU plug for the sealed USB-C charge port
// Print in TPU, flange on the bed. The plug seats in the 16 x 8 x 1.2 mm
// outside recess in the top wall; the body fills the USB-C opening.
include <common.scad>

module charge_plug() {
    fw = CHG_REC_W - 0.5; fh = CHG_REC_H - 0.5;
    // flange (sits in the outside recess)
    translate([-fw/2, -fh/2, 0]) cube([fw, fh, 1.2]);
    // USB-C body, 0.3 mm clearance all round
    translate([-(CHG_W-0.6)/2, -(CHG_H-0.6)/2, 1.0])
        linear_extrude(6.6) rrect(CHG_W-0.6, CHG_H-0.6, 1.2);
    // pull tab
    translate([-fw/2-6, -fh/2, 1.0]) cube([6.2, fh, 2.2]);
}
charge_plug();

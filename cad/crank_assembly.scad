// Pi Flux - hand crank generator: assembly view and interference checks
// Not for printing. Open this file in OpenSCAD to inspect the whole unit:
//   openscad cad/crank_assembly.scad
//   openscad -D 'EXPLODE=40' cad/crank_assembly.scad
//   openscad -D 'CHECK="rotor:stator"' cad/crank_assembly.scad   (volumetric overlap check)
ASSEMBLY = true;
CHECK = "";
EXPLODE = 0;
SECTION = false;     // cut at x = SECTION_X to look inside the stack
SECTION_Y = 0;     // cut plane through the rotor and crank axes
include <crank_common.scad>
use <crank_base.scad>
use <crank_stator.scad>
use <crank_top.scad>
use <crank_rotor.scad>
use <crank_hub.scad>
use <crank_gears.scad>
use <crank_arm.scad>
use <crank_tray.scad>

module c_bearing(p, z) translate([p[0], p[1], z]) difference() {
    color("silver") cylinder(d = CR_BRG_D, h = CR_BRG_T);
    translate([0, 0, -1]) cylinder(d = CR_SHAFT_D, h = CR_BRG_T + 2);
}
module c_shaft_rotor() color("silver")
    translate([0, 0, CR_Z_BRG_TOP - 2]) cylinder(d = CR_SHAFT_D, h = CR_SHAFT_L + 2);
module c_shaft_crank() color("silver")
    translate([CR_CRANK_X, 0, CR_Z_CRANK_BRG - 1]) cylinder(d = CR_SHAFT_D, h = CR_CRANK_L + 2);
module c_foot(f) color("dimgray")
    translate([f[0], f[1], CR_Z_BENCH]) cr_foot();

module cr_unit() {
    // frame (the top plate and everything above it lift by EXPLODE for an exploded view)
    color("#3a6ea5") cr_base_plate();
    color("#3a6ea5") translate([0, 0, EXPLODE*0.35]) cr_stator();
    color("#2c5282") translate([0, 0, EXPLODE]) cr_top_plate();
    color("#4682b4") cr_tray();
    // spacer tubes between the stator lugs and the top plate
    for (p = CR_POSTS) color("#7f8c8d") translate([p[0], p[1], CR_Z_ST1]) cr_spacer();
    color("#5b7fa5") cr_lid_asm();
    for (f = CR_FEET) c_foot(f);
    // rotating group
    rotate([0, 0, 0]) {
        color("#d98c00") translate([0, 0, CR_Z_ROT0]) cr_rotor();                 // as printed
        color("#d98c00") translate([0, 0, CR_Z_TROT1 + EXPLODE*0.35]) rotate([180, 0, 0]) cr_rotor();  // flipped
        // one clamp hub per rotor, on the OUTBOARD face (away from the stator):
        // below the bottom disc and above the top disc, each bolted through the disc
        // bottom hub: boss (modelled below z=0) rides the 608 at z=0, body up to the disc
        color("#c0392b") translate([0, 0, CR_Z_HUB0]) cr_hub();
        color("#c0392b") translate([0, 0, CR_Z_TROT1 + EXPLODE*0.35]) cr_hub(false);
    }
    // gears and crank
    color("#8e44ad") translate([0, 0, CR_Z_GEAR + EXPLODE]) cr_gear_big();
    color("#8e44ad") translate([CR_CRANK_X, 0, CR_Z_GEAR + EXPLODE]) cr_gear_small();
    color("#7f8c8d") translate([CR_CRANK_X, 0, CR_Z_ARM + EXPLODE]) cr_arm();
    color("orange") translate([CR_CRANK_X + CR_ARM_R, 0, CR_Z_ARM + CR_ARM_T + EXPLODE]) cr_knob();
    // bought parts
    c_bearing([0, 0], -CR_BRG_T); c_bearing([CR_CRANK_X, 0], CR_Z_BOSS1 - CR_BRG_T + EXPLODE);
    c_shaft_rotor(); c_shaft_crank();
}

// lid sits under the tray; drawn exploded downwards for clarity
module cr_lid_asm() translate([0, 0, CR_Z_TRAY0 - CR_BOX_LID_T]);

function split(s, i=0, cur="") = i >= len(s) ? [cur] :
    s[i] == ":" ? concat([cur], split(s, i+1, "")) : split(s, i+1, str(cur, s[i]));

if (CHECK != "") {
    pr = split(CHECK);
    intersection() { part(pr[0]); part(pr[1]); }
// section: keep the y > 0 half so a cut through both axes shows the whole stack
} else if (SECTION) intersection() { cr_unit(); translate([-200, 0, CR_Z_BENCH - 20]) cube([400, 400, 400]); }
else cr_unit();

module part(n) {
    if (n == "base") cr_base_plate();
    if (n == "stator") cr_stator();
    if (n == "top") cr_top_plate();
    if (n == "rotor") translate([0, 0, CR_Z_ROT0]) cr_rotor();
    if (n == "rotor_top") translate([0, 0, CR_Z_TROT1]) rotate([180, 0, 0]) cr_rotor();
    if (n == "gears") { translate([0, 0, CR_Z_GEAR]) cr_gear_big(); translate([CR_CRANK_X, 0, CR_Z_GEAR]) cr_gear_small(); }
    if (n == "arm") translate([CR_CRANK_X, 0, CR_Z_ARM]) cr_arm();
    if (n == "tray") cr_tray();
}

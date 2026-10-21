// Print-oriented export wrapper for the hand crank generator (used by tools/export_crank.py).
// Each part is rotated into its print orientation here; the exporter then centres it on
// x/y and drops it onto z = 0.
//   openscad -D 'PART="base"' -o base.stl cad/export_crank.scad
ASSEMBLY = true;
include <crank_common.scad>
use <crank_base.scad>
use <crank_stator.scad>
use <crank_top.scad>
use <crank_rotor.scad>
use <crank_hub.scad>
use <crank_gears.scad>
use <crank_arm.scad>
use <crank_tray.scad>

PART = "base";

// base: plate down, posts up (as modelled; the plate is at z < 0, posts rise from 0)
if (PART == "base") cr_base_plate();
// stator: wire channel up (as modelled)
if (PART == "stator") cr_stator();
// top plate: boss up (as modelled)
if (PART == "top") cr_top_plate();
// rotor disc: magnet pockets up (as modelled)
if (PART == "rotor") cr_rotor();
// clamp hub: boss up (as modelled)
if (PART == "hub") cr_hub();
// gears: flat, profile vertical
if (PART == "gear_big") cr_gear_big();
if (PART == "gear_small") cr_gear_small();
// crank arm: flat, D-bore vertical
if (PART == "arm") cr_arm();
// knob: standing on its washer
if (PART == "knob") cr_knob();
// tray: opening up (as modelled, it hangs below the plate plane)
if (PART == "tray") cr_tray();
// lid: flat
if (PART == "lid") cr_lid();
// foot: flange down, nut trap up
if (PART == "foot") translate([0, 0, 0]) cr_foot();

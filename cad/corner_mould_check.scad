// Interference harness for cad/corner_mould.scad, driven by work/scripts/check.sh:
//   openscad -D 'CHECK="cap:case"' cad/corner_mould_check.scad
// A "HIT" whose bbox is flat in one axis is a tangent contact and expected; only a
// volumetric overlap is a real collision.
PART = "none";
ASSEMBLY = true;
include <common.scad>
CM_PART = "none";
include <corner_mould.scad>

module case_corner() intersection() {
    outer_body();
    translate([-25, -60, -2]) cube([90, 120, T + 4]);   // covers the whole tool footprint
}

if (CHECK == "cap:case")   intersection() { cm_cap();   case_corner(); }
if (CHECK == "cup:case")   intersection() { cm_cup();   case_corner(); }
if (CHECK == "cup:cap")    intersection() { cm_cup();   cm_cap(); }
if (CHECK == "plate:case") intersection() { cm_plate(); case_corner(); }
if (CHECK == "plate:cap")  intersection() { cm_plate(); cm_cap(); }
if (CHECK == "lid:case")   intersection() { cm_lid();   case_corner(); }
if (CHECK == "lid:cup")    intersection() { cm_lid();   cm_cup(); }

// Print-oriented export wrapper (placed on the bed by tools/export.py)
//   openscad -D 'PART="bottom"' -o bottom.stl export.scad
//   openscad -D 'R2=false' -D 'PART="bottom"' ...   (r1 legacy parts)
ASSEMBLY = true;
include <common.scad>
use <bottom.scad>
use <face.scad>
use <keyboard_support.scad>
use <pull_switch.scad>
use <power_button.scad>
use <charge_plug.scad>
PART = "bottom";
if (PART=="bottom")           bottom_part();                       // back plate down
if (PART=="face")             rotate([180,0,0]) face_part();       // face plate down
if (PART=="keyboard_support") kb_support();
if (PART=="charge_plug")      charge_plug();                       // flange on the bed
if (!R2) {
    if (PART=="pull_switch")  rotate([180,0,0]) pull_switch();     // top face (with ring tab) down
    if (PART=="power_button") rotate([90,0,0]) power_button();     // outer cap end down
}

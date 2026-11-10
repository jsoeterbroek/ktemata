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
use <corner_mould.scad>
use <r5_tray.scad>
use <r5_deck.scad>
use <r5_lid_plate.scad>
use <r5_lid_cover.scad>
PART = "bottom";
if (PART=="bottom")           bottom_part();                       // back plate down
if (PART=="face")             rotate([180,0,0]) face_part();       // face plate down
if (PART=="keyboard_support") kb_support();
if (PART=="charge_plug")      charge_plug();                       // flange on the bed
// r5 (internal cassette): the tray and the lid parts print as modelled. The deck is flipped so
// its TOP face is on the bed (rotate about x), as r5_deck.scad's header requires: every keyboard
// well wall and the OLED pocket then grow straight up, while the modelled orientation would hang
// the 151 x 59 recess and bridge the pcb pocket. stl/r5/ktemata_r5_cass.3mf already stores it flipped.
if (PART=="r5_tray")          r5_tray();
if (PART=="r5_deck")          rotate([180,0,0]) r5_deck();
if (PART=="r5_lid_plate")     r5_lid_plate();                      // plate flat, lid/tape side down
if (PART=="r5_lid_cover")     r5_lid_cover();                      // cover flat, lid/tape side down
if (PART=="r5_lid_cover_test_dimensions") r5_lid_cover_test_dimensions(); // 1 mm fit template
// corner overmould tool (one corner at a time); print the cap in TPU for a test fit.
// The cup and lid print as modelled (open face up); the plate flips flat.
if (PART=="corner_cap")       mirror([0,0,1]) corner_mould_part("cap");   // flip z only, keep handedness
if (PART=="corner_plate")     corner_mould_part("plate");
if (PART=="corner_cup")       corner_mould_part("cup");
if (PART=="corner_lid")       corner_mould_part("lid");
if (!R2) {
    if (PART=="pull_switch")  rotate([180,0,0]) pull_switch();     // top face (with ring tab) down
    if (PART=="power_button") rotate([90,0,0]) power_button();     // outer cap end down
}

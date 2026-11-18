// Print-oriented export wrapper (placed on the bed by tools/export.py)
//   openscad -D 'PART="r5_deck"' -o deck.stl export.scad
//
// R5: tray, deck, lid plate, lid cover and alternatives. R6: named keyboard/OLED lid prototype.
// R5 parts print as modelled except the deck, which flips; the R6 lid flips for the same reason.
ASSEMBLY = true;
include <common.scad>
use <r5_tray.scad>
use <r5_deck.scad>
use <r5_lid_plate.scad>
use <r5_lid_cover.scad>
use <r5_lid_cover_waveshare_7in.scad>
use <r6_lid_plate.scad>
use <r6_tray.scad>
use <r6_deck.scad>
PART = "r5_deck";
if (PART=="r5_tray")          r5_tray();                                 // floor down
// The deck is flipped so its TOP face is on the bed (rotate about x), as r5_deck.scad's header
// requires: every keyboard well wall and the OLED pocket then grow straight up, while the
// modelled orientation would hang the 151 x 59 recess and bridge the pcb pocket.
if (PART=="r5_deck")          rotate([180,0,0]) r5_deck();
if (PART=="r5_lid_plate")     r5_lid_plate();                            // lid/tape side down
if (PART=="r5_lid_cover")     r5_lid_cover();                            // lid/tape side down
if (PART=="r5_lid_cover_waveshare_7in") r5_lid_cover_waveshare_7in();    // the 7" alternative
if (PART=="r5_lid_cover_test_dimensions") r5_lid_cover_test_dimensions(); // 1 mm fit template
// R6's lid plate also prints visible-front down: keyboard ledges and rear pockets then need no support.
if (PART=="r6_lid_plate")         rotate([180,0,0]) r6_lid_plate();
// The R6 tray prints exactly as modelled: floor on the bed, walls, bosses and saddles upward.
if (PART=="r6_tray")              r6_tray();
// The R6 deck prints as modelled: underside on the bed, panel pocket, connector recesses and vents up.
if (PART=="r6_deck")              r6_deck();

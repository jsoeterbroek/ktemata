// Pi Flux r1 - Internal bottom power button (presses the power bank button)
// Insert from the inside before fitting the battery. Modelled in assembly position.
include <common.scad>

module power_button() {
    cw = BTN_W; ch = BTN_HH;                 // shaft through the wall
    gap_end = BAT_Y + BAT_H + 0.3;           // battery edge (+0.3 rest gap)
    sleeve_in = L - WALL - 2.5;              // inner end of the guide sleeve
    // cap + shaft: from 1 mm proud of the outside to the sleeve
    at(BTN_X - cw/2, L + 1, BTN_Z - ch/2) cube([cw, 1 + WALL + 2.5, ch]);
    // stop flange
    at(BTN_X - 4.5, sleeve_in, BTN_Z - 3.5) cube([9, 1.2, 7]);
    // nub towards the battery button
    at(BTN_X, sleeve_in - 1.2, BTN_Z) rotate([-90,0,0]) cylinder(d=3, h=sleeve_in - 1.2 - gap_end);
}
if (is_undef(ASSEMBLY)) power_button();

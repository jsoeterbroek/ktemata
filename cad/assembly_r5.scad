// Ktemata r5 - assembly / fit check with stand-in components
//
//   openscad -D R5=true cad/assembly_r5.scad                          # whole cassette + host
//   openscad -D R5=true -D 'CHECK="tray:deck"' cad/assembly_r5.scad    # one interference pair
//   openscad -D R5=true -D 'HOST="1170"' cad/assembly_r5.scad          # another host interior
//
// The host case itself is a transparent box showing its real interior (HOST_* in common.scad),
// so the fit against the published dimensions is visible, not assumed.
ASSEMBLY = true;
include <common.scad>
use <r5_tray.scad>
use <r5_deck.scad>
use <r5_lid_plate.scad>

EXPLODE = 0;
SECTION = false;
SHOW_HOST = is_undef(SHOW_HOST) ? true : SHOW_HOST;   // -D SHOW_HOST=false for the cassette alone
SECTION_Y = R5_L/2;

// ---- host hard case: interior envelope + lid, at their published depths ----
// drawn flipped (lid below the base) because the cassette's z=0 is where the base starts and
// the display hangs off the lid: closing means bringing them together.
module host_case() {
    color("#9aa4ad", 0.25) difference() {
        translate([-HOST_CLR, -HOST_CLR, -HOST_BOT]) cube([HOST_L, HOST_W, HOST_BOT + HOST_LID]);
        translate([0, 0, -HOST_BOT]) cube([HOST_L, HOST_W, HOST_BOT]);
        translate([0, 0, 0]) cube([HOST_L, HOST_W, HOST_LID]);
    }
    // lid cavity, lid wall down: drawn as the same envelope with its floor at z = 0
    color("#9aa4ad", 0.18) translate([0, 0, 0]) difference() {
        translate([-HOST_CLR, -HOST_CLR, 0]) cube([HOST_L, HOST_W, HOST_LID]);
        translate([HOST_L/2, HOST_W/2, HOST_LID/2])
            cube([HOST_L - 2*HOST_CLR, HOST_W - 2*HOST_CLR, HOST_LID], center=true);
    }
}

// ---- components (drawing coords via r5_at) ----
module c_pi() {
    r5_at(R5_PI_X0, R5_PI_Y0 + 56, R5_PI_BOT) linear_extrude(1.6) rrect(85, 56, 3);
    // right-edge ports: USB 3, USB 2, Ethernet, all on the +x side of the board
    // the USB/Ethernet bodies hang off the board's +x edge (x 75..85 of the board)
    for (p=PI_PORTS) r5_box(R5_PI_X0 + 75, R5_PI_Y0 + p[0], R5_PI_X0 + 85,
                            R5_PI_Y0 + p[0] + p[1], R5_PI_BOT - p[2], p[2]);
    // USB-C + 2x micro-HDMI on the -y (hinge) edge
    for (dx=[4, 14, 24]) r5_box(R5_PI_X0 + dx, R5_PI_Y0 - 1.5, R5_PI_X0 + dx + 9,
                                R5_PI_Y0 + 6, R5_PI_BOT - 3.2, 3.2);
    // the two 22-pin MIPI connectors, top side near the same edge
    r5_box(R5_PI_X0 + 1, R5_PI_Y0 + 9, R5_PI_X0 + 11, R5_PI_Y0 + 21, R5_PI_TOP, 1.2);
    // 40-pin header: two rows of 20 (50.8 mm) along the board's 56 mm axis, 3.5 mm in from the
    // GPIO edge, 5.1 mm wide in x. It sits directly over the Pi's own mounting holes.
    r5_box(R5_PI_X0 + 3.5, R5_PI_Y0 + 2.6, R5_PI_X0 + 8.6, R5_PI_Y0 + 53.4, R5_PI_TOP, 8.5);
    // SoC + cooler shadow

}
module c_ups() {
    r5_at(R5_UPS_X, R5_UPS_Y + UPS_H, R5_HAT_BOT) linear_extrude(UPS_T) rrect(UPS_W, UPS_H, 3);
    // pogo pins + standoffs between HAT and Pi (Waveshare's 4 x M2.5)
    r5_at(R5_UPS_X + 8, R5_UPS_Y + 32, R5_HAT_TOP) cube([20, 12, UPS_COMP]);
    r5_at(R5_UPS_X + 52, R5_UPS_Y + 56, R5_HAT_TOP) cube([22, 16, UPS_COMP - 1]);
    // 8.4 V jack + USB-A + switch, overhanging the +y end
    r5_at(R5_UPS_X + 34, R5_UPS_Y + UPS_H, R5_HAT_BOT - 8.4) cube([8, 12.5, 8.4]);
    r5_at(R5_UPS_X + 20, R5_UPS_Y + UPS_H, R5_HAT_BOT - 9.8) cube([18, 11.75, 9.8]);
}
module c_cells() {
    for (p=R5_CELL_POS) r5_at(p[0], p[1] - CELL_L/2, R5_CELL_Z0 + CELL_D/2)
        rotate([90, 0, 0]) cylinder(d=CELL_D, h=CELL_L);
}
module c_keyboard() r5_box(R5_KB_X0 + 0.3, R5_KB_Y0 + 0.3,
                           R5_KB_X0 + 151.3, R5_KB_Y0 + 59.3, R5_DECK_TOP, KB_BODY[2]);
module c_oled() r5_box(R5_OLED_X0 + 0.4, R5_OLED_Y0 + 0.4,
                       R5_OLED_X0 + R5_OLED_W - 0.4, R5_OLED_Y0 + R5_OLED_H - 0.4,
                       R5_DECK_Z + R5_OLED_LEDGE, R5_OLED_T);
module c_display() {
    // on the lid: the plate is taped to the lid ceiling, so its back sits R5_DISP_DEEP below
    // z = HOST_BOT + HOST_LID; the display hangs down from there, glass towards the base
    z = HOST_BOT + HOST_LID - R5_DISP_DEEP;
    r5_at(R5_DISP_X0, R5_DISP_Y0 + DISP_H, z + R5_LID_T + 8.5) linear_extrude(6.42) rrect(DISP_W, DISP_H, 5);
    r5_at(R5_DISP_X0 - 6, R5_DISP_Y0 + DISP_H + 6, z) linear_extrude(R5_LID_T)
        rrect(R5_LID_PLATE[0], R5_LID_PLATE[1], 5);
    // the display's own standoffs
    for (p=R5_DISP_HOLES) r5_at(R5_DISP_X0 + p[0], R5_DISP_Y0 + p[1], z + R5_LID_T)
        cylinder(d=4.5, h=8.5, $fn=6);
}
module c_floor() {
    r5_box(R5_FB_X + 2, R5_FB_Y + 2, R5_FB_X + 2 + FB_W, R5_FB_Y + 2 + FB_H, R5_FLOOR + 3.4, 7);
    r5_box(R5_RTC_X + 2, R5_RTC_Y + 2, R5_RTC_X + 2 + RTC_W, R5_RTC_Y + 2 + RTC_H, R5_FLOOR + 3.4, RTC_T);
    r5_box(R5_MPPT_X + 2, R5_MPPT_Y + 2, R5_MPPT_X + 2 + MPPT_MOD_W,
           R5_MPPT_Y + 2 + MPPT_MOD_H, R5_FLOOR + 3.4, 8);
}

module components() {
    color("green") c_pi(); color("blue") c_ups(); color("orange") c_cells();
    color("darkgreen") c_keyboard(); color("purple") c_oled();
    color("black") c_display(); color("teal") c_floor();
}

module all() {
    if (SHOW_HOST) host_case();
    color("#3a3a3a") r5_tray();
    color("#555") translate([0, 0, EXPLODE]) r5_deck();
    components();
}

function split(s, i=0, cur="") = i >= len(s) ? [cur] :
    s[i] == ":" ? concat([cur], split(s, i+1, "")) : split(s, i+1, str(cur, s[i]));
CHECK = "";
if (CHECK != "") { pr = split(CHECK); intersection() { part(pr[0]); part(pr[1]); } }
else if (SECTION) intersection() { all(); translate([-1, R5_L - SECTION_Y, -100]) cube([R5_W + 2, 1, 300]); }
else all();

module part(n) {
    if (n=="tray") r5_tray(); if (n=="deck") r5_deck(); if (n=="lid") r5_at(R5_DISP_X0 - 6, R5_DISP_Y0 + DISP_H + 6, HOST_BOT + HOST_LID - R5_DISP_DEEP)
        translate([0, -R5_LID_PLATE[1], 0]) r5_lid_plate();
    if (n=="pi") c_pi(); if (n=="ups") c_ups(); if (n=="cells") c_cells();
    if (n=="keyboard") c_keyboard(); if (n=="oled") c_oled(); if (n=="display") c_display();
    if (n=="floor") c_floor();
}

// Ktemata - assembly check with dummy components (not for printing)
ASSEMBLY = true;
include <common.scad>
use <bottom.scad>
use <face.scad>
use <keyboard_support.scad>
use <pull_switch.scad>
use <power_button.scad>

EXPLODE = 0;     // e.g. 30
SECTION = false; // cut along x = SECTION_X to look inside
SECTION_X = W/2;   // mid-width slice

module c_display() {
    at(DISP_X, DISP_Y + DISP_H, DISP_Z_BACK) linear_extrude(DISP_T) rrect(DISP_W, DISP_H, DISP_R);
    for (p=DISP_HOLES) at(p[0], p[1], DISP_POST_END) cylinder(d=4.5, h=DISP_POST, $fn=6);
}
module c_pi() {
    at(PI_X0, PI_Y0 + 56, PI_PCB_BOT) linear_extrude(1.6) rrect(85, 56, 3);
    // connector bodies near the port edge (they protrude outwards, not 21 mm inwards)
    for (p=PI_PORTS) at(PI_X0 + 85 - 10, PI_Y0 + p[0] + p[1]/2, PI_PCB_BOT - p[2]) cube([10, p[1], p[2]]);
    at(PI_USBC_X - 4.5, PI_Y0 + 7.5, PI_USBC_Z - 1.6) cube([9, 7.5, 3.2]);         // usb-c socket
    if (!R2) {
        at(PI_X0 + 25, PI_Y0 + 48, PI_PCB_BOT - 11) cube([42, 40, 11]);            // r1 cooler
        at(PI_X0 + 7, PI_Y0 + 56 - 0.5, PI_PCB_BOT - 8.5) cube([51, 5.2, 8.5]);    // r1 gpio header
    }
}
module c_battery() at(BAT_X, BAT_Y + BAT_H, FLOOR) linear_extrude(BAT_T) rrect(BAT_W, BAT_H, 6);
module c_keyboard() {
    // r4: the K06 is a 16.5 mm complete body (keys + touchpad), not a 1.2 mm PCB
    if (R4) at(KB_PCB_X, KB_PCB_Y + KB_PCB[1], KB_PCB_BACK) cube(KB_BODY);
    else    at(KB_PCB_X, KB_PCB_Y + KB_PCB[1], KB_PCB_BACK) cube([KB_PCB[0], KB_PCB[1], 1.2]);
    if (!R2) at(KB_PCB_X + 66, KB_PCB_Y + 50, KB_PCB_BACK - 5) cube([45, 32, 5]);   // r1 keyboard lipo
}
module c_uadapter() {
    at(PI_USBC_X - UADP[0]/2, 2 + UADP[1], PI_USBC_Z + UADP_MALE_FROM_TOP - UADP[2]) cube(UADP);
    at(PI_USBC_X - 4, PI_Y0 - 0.5, PI_USBC_Z - 1.25) cube([8, PI_Y0 - 0.5 - 2 - UADP[1], 2.5]);  // male plug
}

// ---- r2 components -------------------------------------------------
module c_ups() {
    // Waveshare UPS HAT (E) (r2/r3) or HAT (B) (r4), hanging under the Pi
    at(UPS_X, UPS_Y + UPS_H, UPS_PCB_BOT) linear_extrude(UPS_T) rrect(UPS_W, UPS_H, 3);
    // components/pogo pins between pcb and Pi
    at(UPS_X + 8, UPS_Y + 32, UPS_PCB_TOP) translate([0,-12,0]) cube([20, 12, UPS_COMP]);
    at(UPS_X + 52, UPS_Y + 56, UPS_PCB_TOP) translate([0,-16,0]) cube([22, 16, UPS_COMP-1]);
    if (R4) {
        // HAT (B): the USB-A output and the 8.4 V DC jack are on the board's long edge and
        // protrude past the 85 x 56 outline, i.e. beside the Pi rather than against it
        // (8.7 x 12.5 x 8 and 18 x 11.75 x 11 mm, measured on Waveshare's 3D drawing).
        // the jack/USB-A bodies overhang the board's +y end, i.e. past the Pi (clear of the cells)
        at(UPS_X + 34, UPS_Y + UPS_H, UPS_PCB_BOT - 8.4) translate([0,-12.5,0]) cube([8, 12.5, 8.4]);
        at(UPS_X + 20, UPS_Y + UPS_H, UPS_PCB_BOT - 9.8) translate([0,-11.75,0]) cube([18, 11.75, 9.8]);
    } else {
        // USB-C / USB-A / switch on the connector edge
        at(UPS_X + 20, UPS_Y + UPS_H, UPS_PCB_TOP) translate([0,-8,0]) cube([30, 8, 5]);
    }
}
module c_cells() {
    // r2: four 21700 cells in one row, axes along y. r4: two 18650 side by side, axes along x.
    if (R4) for (p=CELL_POS) at(p[0], p[1]-CELL_L/2, CELL_ZC) rotate([90,0,0]) cylinder(d=CELL_D, h=CELL_L);
    else    for (x=CELL_XS) at(x, CELL_Y0, CELL_ZC) rotate([90,0,0]) cylinder(d=CELL_D, h=CELL_L);
}
module c_oled() {
    // 1.3" 4-pin I2C OLED module behind the face window
    at(OLED_X0+0.2, OLED_Y1-0.2, OLED_Z0) cube([OLED_W-0.4, OLED_H-0.4, OLED_T]);
}
module c_firebeetle() {
    // FireBeetle 2 ESP32-UE (25.4 x 60) in the bottom shell
    at(FB_X, FB_Y+FB_H, FB_Z+2.2) cube([FB_W, FB_H, FB_T+5]);
}
module c_sensor() {
    // Pimoroni BME688 breakout (19 x 19 x 5)
    at(1.8, SENSOR_CY + 9.5, SENSOR_Z0+2) cube([19, 19, 5]);
}
module c_rtc() at(RTC_X, RTC_Y + RTC_H, RTC_Z0+2.2) cube([RTC_W, RTC_H, RTC_T]);
module c_mppt() at(MPPT_X+2, MPPT_Y+2+MPPT_MOD_H, MPPT_Z+2.3) cube([MPPT_MOD_W, MPPT_MOD_H, 8]);
module c_charge() {
    // Sealed panel connector in the top wall.
    // r2/r3: USB-C, a 9 x 3.5 rectangular body that fits the rectangular hole.
    // r4: 5.5 x 2.1 mm DC socket - ROUND, so the stand-in must be a cylinder. A box would
    // poke through the round wall hole at its corners and report a false collision.
    if (R4) translate([CHG_X, L - (WALL - 2) - 3, CHG_Z]) rotate([90, 0, 0])
                cylinder(d=CHG_W - 1.0, h=12);            // body through the wall + pocket
    else    at(CHG_X-4.5, 0, CHG_Z-1.5) translate([0,-10,0]) cube([9, 10, 3]);
}
module c_oledbtn() {
    at(OLED_BTN_X, 0, OLED_BTN_Z) rotate([90,0,0]) cylinder(d=OLED_BTN_D-0.4, h=11);
}

module components() {
    color("black") c_display(); color("green") c_pi(); color("darkgreen") c_keyboard();
    if (R2) {
        color("blue") c_ups(); color("orange") c_cells();
        color("purple") c_oled(); color("teal") c_sensor(); color("navy") c_firebeetle();
        color("brown") c_rtc(); color("olive") c_mppt();
        color("gray") c_charge(); color("red") c_oledbtn();
    } else {
        color("dimgray") c_battery(); color("orange") c_uadapter();
    }
}

module all() {
    color("#3a3a3a") bottom_part();
    color("#555", 0.6) translate([0,0,EXPLODE]) face_part();
    color("white") translate([0,0,EXPLODE/2]) kb_support();
    if (!R2) {
        color("white") pull_switch();
        color("white") power_button();
    }
    components();
}

function split(s, i=0, cur="") = i>=len(s) ? [cur] : s[i]==":" ? concat([cur], split(s, i+1, "")) : split(s, i+1, str(cur, s[i]));
if (CHECK != "") { pr = split(CHECK); intersection() { part(pr[0]); part(pr[1]); } }
else if (SECTION) intersection() { all(); translate([SECTION_X, -50, -50]) cube([300, 300, 300]); }
else all();

// interference check: openscad -D 'CHECK="bottom:pi"' assembly.scad
CHECK = "";
module part(n) {
    if (n=="bottom") bottom_part(); if (n=="face") face_part(); if (n=="kbs") kb_support();
    if (n=="pull" && !R2) pull_switch(); if (n=="button" && !R2) power_button();
    if (n=="display") c_display(); if (n=="pi") c_pi(); if (n=="keyboard") c_keyboard();
    if (n=="battery" && !R2) c_battery(); if (n=="uadp" && !R2) c_uadapter();
    if (n=="ups" && R2) c_ups(); if (n=="cells" && R2) c_cells();
    if (n=="oled" && R2) c_oled(); if (n=="firebeetle" && R2) c_firebeetle();
    if (n=="sensor" && R2) c_sensor();
    if (n=="rtc" && R2) c_rtc(); if (n=="mppt" && R2) c_mppt();
    if (n=="charge" && R2) c_charge(); if (n=="oledbtn" && R2) c_oledbtn();
}

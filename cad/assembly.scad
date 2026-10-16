// Pi Flux r1 - assembly check with dummy components (not for printing)
ASSEMBLY = true;
include <common.scad>
use <bottom.scad>
use <face.scad>
use <keyboard_support.scad>
use <pull_switch.scad>
use <power_button.scad>

EXPLODE = 0;     // e.g. 30
SECTION = false; // cut along x = SECTION_X to look inside
SECTION_X = 64;

module c_display() {
    at(DISP_X, DISP_Y + DISP_H, DISP_Z_BACK) linear_extrude(DISP_T) rrect(DISP_W, DISP_H, DISP_R);
    for (p=DISP_HOLES) at(p[0], p[1], DISP_POST_END) cylinder(d=4.5, h=DISP_POST, $fn=6);
}
module c_pi() {
    at(PI_X0, PI_Y0 + 56, PI_PCB_BOT) linear_extrude(1.6) rrect(85, 56, 3);
    for (p=PI_PORTS) at(PI_X0 + 85 - 21 + 2, PI_Y0 + p[0] + p[1]/2, PI_PCB_BOT - p[2]) cube([21, p[1], p[2]]);
    at(PI_X0 + 25, PI_Y0 + 48, PI_PCB_BOT - 11) cube([42, 40, 11]);              // cooler
    at(PI_USBC_X - 4.5, PI_Y0 + 7.5, PI_USBC_Z - 1.6) cube([9, 7.5, 3.2]);         // usb-c socket
    at(PI_X0 + 7, PI_Y0 + 56 - 0.5, PI_PCB_BOT - 8.5) cube([51, 5.2, 8.5]);        // gpio header
}
module c_battery() at(BAT_X, BAT_Y + BAT_H, FLOOR) linear_extrude(BAT_T) rrect(BAT_W, BAT_H, 6);
module c_keyboard() {
    at(KB_PCB_X, KB_PCB_Y + KB_PCB[1], KB_PCB_BACK) cube([KB_PCB[0], KB_PCB[1], 1.2]);
    at(KB_PCB_X + 66, KB_PCB_Y + 50, KB_PCB_BACK - 5) cube([45, 32, 5]);           // keyboard lipo
}
module c_uadapter() {
    at(PI_USBC_X - UADP[0]/2, 2 + UADP[1], PI_USBC_Z + UADP_MALE_FROM_TOP - UADP[2]) cube(UADP);
    at(PI_USBC_X - 4, PI_Y0 - 0.5, PI_USBC_Z - 1.25) cube([8, PI_Y0 - 0.5 - 2 - UADP[1], 2.5]);  // male plug
}
module components() {
    color("black") c_display(); color("green") c_pi(); color("dimgray") c_battery();
    color("darkgreen") c_keyboard(); color("orange") c_uadapter();
}

module all() {
    color("#3a3a3a") bottom_part();
    color("#555", 0.6) translate([0,0,EXPLODE]) face_part();
    color("white") translate([0,0,EXPLODE/2]) kb_support();
    color("white") pull_switch();
    color("white") power_button();
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
    if (n=="pull") pull_switch(); if (n=="button") power_button();
    if (n=="display") c_display(); if (n=="pi") c_pi(); if (n=="battery") c_battery();
    if (n=="keyboard") c_keyboard(); if (n=="uadp") c_uadapter();
}

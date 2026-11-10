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
use <r5_lid_cover.scad>

EXPLODE = 0;
SECTION = false;
SHOW_HOST = is_undef(SHOW_HOST) ? true : SHOW_HOST;   // -D SHOW_HOST=false for the cassette alone
// Which lid part to show: the flat plate (r5_lid_plate) or the full-face cover with the recessed
// 7" panel (r5_lid_cover, the shipped one). -D LID="plate" to check the simpler part in place.
LID = is_undef(LID) ? "cover" : LID;
SECTION_Y = R5_L/2;

// ---- host hard case: the mouth section, at the published depths ----
// The stand-in shows the LARGEST section - the measured mouth, HOST_TOP - because that is what
// both the cassette and the deck (243.3 x 186.8) have to fit; the real cavity tapers in below it
// (see host_cavity() and docs/R5.md).  Drawn as a schematic stack, base below and lid above,
// because the cassette's z = 0 is its floor and closing brings the lid down onto it.
module host_case() {
    mw = HOST_TOP[0]; ml = HOST_TOP[1];
    ox = (R5_W - mw) / 2; oy = (R5_L - ml) / 2;
    color("#9aa4ad", 0.25) difference() {
        translate([ox - HOST_CLR, oy - HOST_CLR, -HOST_BOT])
            cube([mw + 2*HOST_CLR, ml + 2*HOST_CLR, HOST_BOT + HOST_LID]);
        translate([ox, oy, -HOST_BOT]) cube([mw, ml, HOST_BOT]);
        translate([ox, oy, 0]) cube([mw, ml, HOST_LID]);
    }
    // lid cavity, lid wall down: the same envelope with its floor at z = 0
    color("#9aa4ad", 0.18) translate([ox, oy, 0]) difference() {
        translate([-HOST_CLR, -HOST_CLR, 0])
            cube([mw + 2*HOST_CLR, ml + 2*HOST_CLR, HOST_LID]);
        cube([mw, ml, HOST_LID + 1]);
    }
}

// ---- components (drawing coords via r5_at) ----
// Both boards are PORTRAIT (85 along y, 56 along x) and stand on the floor, side by side.
// Port mapping is the r5 one: USB/Ethernet on the +x edge, USB-C/HDMI/DSI on the hinge (-y) edge.
module c_pi() {
    // the Seeed PCIe-to-M.2 BASE, bolted under the Pi; the SSD sits on its underside
    r5_at(R5_PI_X, R5_PI_Y + R5_PI_L, R5_M2_BOT) linear_extrude(R5_M2_T) rrect(R5_PI_W, R5_PI_L, 3);
    r5_box(R5_PI_X + 18, R5_PI_Y + 20, R5_PI_X + 40, R5_PI_Y + 62, R5_M2_BOT - 2.4, 2.4);   // SSD
    // Pi pcb, up on the BASE's standoffs
    r5_at(R5_PI_X, R5_PI_Y + R5_PI_L, R5_PI_BOT) linear_extrude(1.6) rrect(R5_PI_W, R5_PI_L, 3);
    // right-edge ports: USB 3, USB 2, Ethernet, on the +x edge
    for (p=PI_PORTS) r5_box(R5_PI_X + R5_PI_W - 10, R5_PI_Y + p[0], R5_PI_X + R5_PI_W,
                            R5_PI_Y + p[0] + p[1], R5_PI_BOT, p[2]);
    // USB-C + 2x micro-HDMI on the hinge (-y) edge
    for (dx=[4, 14, 24]) r5_box(R5_PI_X + dx, R5_PI_Y - 3.2, R5_PI_X + dx + 9,
                                R5_PI_Y + 6, R5_PI_BOT, 3.2);
    // 40-pin header: 5.1 mm wide, 3.5 mm in from the GPIO edge (the -x edge), 50.8 long
    r5_box(R5_PI_X + 3.5, R5_PI_Y + 2.6, R5_PI_X + 8.6, R5_PI_Y + 53.4, R5_PI_TOP, R5_PI_HDR);
}
module c_ups() {
    r5_at(R5_UPS_X, R5_UPS_Y + R5_UPS_L, R5_HAT_BOT) linear_extrude(UPS_T) rrect(R5_UPS_W, R5_UPS_L, 3);
    // components on the pcb's top side, inside the 35 mm envelope
    r5_box(R5_UPS_X + 6, R5_UPS_Y + 56, R5_UPS_X + 46, R5_UPS_Y + 74, R5_HAT_TOP, 9);        // 5V reg / inductors
    // 8.4 V jack + USB-A + switch, overhanging the hinge end (-y). The jack's far face reaches
    // y = R5_UPS_EDGE (4), so the two boxes stop there and not at the pcb edge.
    r5_box(R5_UPS_X + 8, R5_UPS_EDGE, R5_UPS_X + 20, R5_UPS_Y, R5_HAT_BOT - 8.4, 8.4);
    r5_box(R5_UPS_X + 24, R5_UPS_EDGE, R5_UPS_X + 42, R5_UPS_Y, R5_HAT_BOT - 9.8, 9.8);
}
module c_cells() {
    for (p=R5_CELL_POS) r5_at(p[0], p[1] - CELL_L/2, R5_CELL_Z0 + CELL_D/2)
        rotate([90, 0, 0]) cylinder(d=CELL_D, h=CELL_L);
}
// The K06 body, sunk the full 11 mm so its key face is level with the deck's top face. Rounded to
// R5_KB_CORNER like the real outline, so the deck:keyboard sweep checks the cut's corners too.
// r5_at puts the shape's MAX drawing y at its argument (it grows towards +y in real coords), so
// the far edge of the pocket is what goes in, not the near one.
module c_keyboard() r5_at(R5_KB_X0 + R5_KB_CLR,
                          R5_KB_Y0 + R5_KB_POCKET[1] - R5_KB_CLR, R5_KB_WELL_BOT)
    linear_extrude(KB_BODY[2]) rrect(KB_BODY[0], KB_BODY[1], R5_KB_CORNER);
// the module: pcb seated on the pocket ceiling, glass in the window well. Both are drawn at
// their measured size so the interference sweep checks the pocket and window really clear them.
module c_oled() {
    r5_box(R5_OLED_X0 + R5_OLED_PCB_CLR, R5_OLED_Y0 + R5_OLED_PCB_CLR,
           R5_OLED_X0 + R5_OLED_PCB_CLR + R5_OLED_BOARD[0],
           R5_OLED_Y0 + R5_OLED_PCB_CLR + R5_OLED_BOARD[1],
           R5_OLED_SEAT - R5_OLED_BOARD[2], R5_OLED_BOARD[2]);
    r5_box(R5_OLED_X0 + R5_OLED_PCB_CLR + (R5_OLED_BOARD[0] - R5_OLED_GLASS[0])/2,
           R5_OLED_Y0 + R5_OLED_PCB_CLR + R5_OLED_GLASS_Y,
           R5_OLED_X0 + R5_OLED_PCB_CLR + (R5_OLED_BOARD[0] + R5_OLED_GLASS[0])/2,
           R5_OLED_Y0 + R5_OLED_PCB_CLR + R5_OLED_GLASS_Y + R5_OLED_GLASS[1],
           R5_OLED_SEAT, R5_OLED_GLASS[2]);
}
module c_display() {
    // The Touch Display 2: glass at R5_GLASS, the 6.42 mm body above it, then the four M2.5
    // standoffs rising to the lid part's seat. Nothing else protrudes, so there are no reliefs.
    r5_at(R5_DISP_X0, R5_DISP_Y0 + R5_PANEL[1], R5_GLASS)
        linear_extrude(R5_PANEL_BODY) rrect(R5_PANEL[0], R5_PANEL[1], R5_PANEL[2]);
    for (p=R5_DISP_HOLES)
        r5_at(R5_DISP_X0 + p[0], R5_DISP_Y0 + p[1], R5_GLASS + R5_PANEL_BODY)
            cylinder(d=R5_PANEL_STUD_D, h=R5_PANEL_STUD);
}

// Both lid parts are modelled with z = 0 on the host/tape face and grow towards the display.
// Flip them about x so that face lands on the lid ceiling; their PCB seats are R5_LID_T below it.
// No extra y translation: the flip alone maps their drawing-y frames into the cassette frame.
module c_lid_plate() {
    translate([R5_DISP_X0 - 6, R5_L - R5_DISP_Y0 + 6, HOST_BOT + HOST_LID])
        rotate([180, 0, 0]) r5_lid_plate();
}
module c_lid_cover() {
    translate([0, R5_L, HOST_BOT + HOST_LID]) rotate([180, 0, 0]) r5_lid_cover();
}

// The 16 mm IP67 power button on the deck: the thread through the bore and the nut under the
// plate. Both are needed for the sweep to mean anything - the nut alone is a tangent disc on the
// plate's underside (a zero-volume contact, which is what a seated nut is), while the thread spans
// the plate, so any overlap there is the bore being missing or misplaced. Its leads go to the
// Pi's J2 pads (external power button), which is why it sits over free floor.
module c_button() {
    r5_at(R5_BTN_X, R5_BTN_Y, R5_DECK_Z - R5_BTN_BODY_H)
        cylinder(d=R5_BTN_BODY, h=R5_BTN_BODY_H);                       // nut, under the plate
    r5_at(R5_BTN_X, R5_BTN_Y, R5_DECK_Z)
        cylinder(d=R5_BTN_D, h=R5_DECK_T);                              // thread, through the bore
}

// The 5.5 x 2.1 mm charge socket through the deck's right rail: barrel and nut below the plate,
// tags towards the Pi. The plug is not drawn - it is only fitted with the lid open.
module c_charger() {
    r5_at(R5_CHG_X, R5_CHG_Y, R5_DECK_Z - 14) cylinder(d=R5_CHG_D - 0.2, h=14);
    r5_at(R5_CHG_X, R5_CHG_Y, R5_DECK_Z - 2.1) cylinder(d=R5_CHG_NUT_D, h=2.0);
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
    color("#b0b6bc") c_button(); color("#b0b6bc") c_charger();
}

module all() {
    if (SHOW_HOST) host_case();
    if (LID == "cover") color("#6b8fb0") c_lid_cover();
    if (LID == "plate") color("#6b8fb0") c_lid_plate();
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
    if (n=="tray") r5_tray(); if (n=="deck") r5_deck();
    if (n=="lid") c_lid_plate();
    // The display and selected lid part are separate, so both cover:display and lid:display are
    // real fit checks: the panel must clear the recess and its Pi standoffs must enter the reliefs.
    if (n=="cover") c_lid_cover();
    if (n=="pi") c_pi(); if (n=="ups") c_ups(); if (n=="cells") c_cells();
    if (n=="keyboard") c_keyboard(); if (n=="oled") c_oled(); if (n=="display") c_display();
    if (n=="button") c_button();
    if (n=="charger") c_charger();
    if (n=="floor") c_floor();
}

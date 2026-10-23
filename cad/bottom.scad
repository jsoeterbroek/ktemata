// Ktemata - Bottom part (back shell)
// R2 default: UPS HAT (E) + 4x21700 tray, sealed charge port, sensor pocket, RTC.
// R1 option (-D R2=false): original INIU battery bay + pull switch + power button.
// Print back-plate down. All internal features are vertical or 45 deg; no supports.
include <common.scad>

module shell() {
    difference() {
        intersection() { outer_body(); translate([-10,-10,-1]) cube([W+20, L+20, H_BOT+1]); }
        translate([0,0,FLOOR]) linear_extrude(H_BOT) inner_outline();
    }
}

// ---- case screw boss: counterbored from the back, screw passes into the face part
module case_boss_solid(p) at(p[0], p[1]) cylinder(d=BOSS_D, h=H_BOT);
module case_boss_cut(p) at(p[0], p[1]) {
    translate([0,0,-1]) cylinder(d=M25_CLR, h=H_BOT+2);
    translate([0,0,-1]) cylinder(d=M25_HEAD, h=1 + (H_BOT-2));   // 2 mm seat at the top
}

// ---- display posts: M2.5x10 from the back into the display's own standoffs
module disp_post_solid(p) at(p[0], p[1]) {
    cylinder(d=6.5, h=DISP_POST_END-2);
    cylinder(d=5, h=DISP_POST_END);
}
module disp_post_cut(p) at(p[0], p[1]) {
    translate([0,0,-1]) cylinder(d=M25_CLR, h=DISP_POST_END+2);
    translate([0,0,-1]) cylinder(d=M25_HEAD, h=1 + DISP_POST_END - 6);  // ~6 mm through, ~4 mm into the standoff
}

// =====================================================================
// R1: battery bay, pull switch, port box and power button
// =====================================================================
// ---- battery bay guides
module battery_guides() {
    gh = 7; t = 1.6; c = 0.6;   // height, rib thickness, clearance
    x0 = BAT_X - c - t; x1 = BAT_X + BAT_W + c;
    y0 = BAT_Y - c - t;
    // side rails
    for (x=[x0, x1]) at(x, BAT_Y + 8) translate([0,-(BAT_H-16),FLOOR]) cube([t, BAT_H-16, gh]);
    // top rail (two segments, gap for the battery cable)
    at(BAT_X+10, y0) translate([0,-t,FLOOR]) cube([BAT_W*0.45, t, gh]);
    at(BAT_X+BAT_W*0.62, y0) translate([0,-t,FLOOR]) cube([BAT_W*0.30, t, gh]);
}

// ---- pull switch: carrier (pull_switch.scad) slides in +-y through a full-height top-wall slot
PS_CX  = PULL_SLOT_X0 + PULL_SLOT_W/2;
PS_LEN = 15;                             // guide rail length from the outer top edge
module pull_channel() {
    // side rails continuing the slot walls inwards
    for (x=[PULL_SLOT_X0 - 2, PULL_SLOT_X0 + PULL_SLOT_W]) at(x, 0) translate([0,-PS_LEN,0]) cube([2, PS_LEN, H_BOT - 0.3]);
}
module pull_cut() {
    // slot through the top wall, open to the split plane, plus a shallow floor groove
    at(PULL_SLOT_X0, -1, FLOOR - PULL_GROOVE) translate([0,-PS_LEN-1,0]) cube([PULL_SLOT_W, PS_LEN+1, H_BOT]);
}

// ---- top-right port box (two USB-C sized slots in the top wall)
PB_X = PULL_SLOT_X0 + PULL_SLOT_W + 3; PB_W = 28; PB_D = PI_Y0 - 2;   // stays clear of the Pi pcb
module port_box() {
    // 1 mm pad bridging into the top wall so box and wall fuse (flush faces gave non-manifold edges)
    at(PB_X, WALL + 0.5, FLOOR) cube([PB_W, 1, H_BOT-FLOOR-2.5]);
    at(PB_X, WALL) translate([0, -(PB_D-WALL), FLOOR]) difference() {
        cube([PB_W, PB_D-WALL, H_BOT-FLOOR-2.5]);
        translate([2, -1, -1]) cube([PB_W-4, PB_D-WALL-1, H_BOT-FLOOR-4.5]);
    }
}
module port_box_cut() {
    for (dx=[PB_W/2-7, PB_W/2+7]) at(PB_X+dx, 0, H_BOT-8) hull() {
        for (s=[-1,1]) translate([s*(9-3.4)/2, 0, 0]) rotate([90,0,0]) translate([0,0,-WALL-1]) cylinder(d=3.4, h=WALL+12);
    }
}

// ---- battery power button hole (bottom wall)
module btn_cut() at(BTN_X - (BTN_W+0.5)/2, L+1, BTN_Z - (BTN_HH+0.5)/2) cube([BTN_W+0.5, WALL+4.5, BTN_HH+0.5]);
module btn_guide() {
    // short sleeve around the plunger on the inside
    at(BTN_X - (BTN_W+3.7)/2, L-WALL, FLOOR) cube([BTN_W+3.7, 2.5, BTN_Z + (BTN_HH+0.5)/2 + 1.6 - FLOOR]);
}

// =====================================================================
// R2: 4x21700 tray
// =====================================================================
// Cells lie in one row across the width, axes along y, under the UPS board.
// The UPS HAT (E) itself hangs from the Pi; the printed tray only locates the cells.
// r4 (R4) has no printed tray: the UPS HAT (B) carries its own holders, so the cells are
// held by the board and only need clearance in the bottom shell.
CELL_CRADLE_TOP = CELL_Z0 + CELL_D*0.52;

module cell_cradle(x, yc) {
    // U-shaped saddle. The bore is 0.8 mm larger than the cell so it is not a press fit.
    at(x - (CELL_D+2.6)/2, yc - 2, FLOOR) translate([0,-4,0]) difference() {
        cube([CELL_D + 2.6, 4, CELL_CRADLE_TOP - FLOOR]);
        translate([(CELL_D+2.6)/2, 5, CELL_ZC - FLOOR]) rotate([90,0,0]) cylinder(d=CELL_D + 1.2, h=10);
        // zip-tie tunnels under the cell (2 per cradle)
        for (dx=[-CELL_D/4, CELL_D/4])
            translate([(CELL_D+2.6)/2 + dx - 1.5, -1, 1.2]) cube([3, 6, 1.6]);
    }
}

module cell_tray() {
    // saddles near both cell ends
    for (y=[CELL_Y0 + 3, CELL_Y1 - 3]) for (x=CELL_XS) cell_cradle(x, y);
    // end walls stop axial movement and protect the cell ends
    ew = CELL_COUNT*CELL_D + (CELL_COUNT-1)*CELL_GAP + 3;
    for (y=[CELL_Y0-3, CELL_Y1+1]) at(CELL_X0-1.5, y, FLOOR) translate([0,-2,0]) cube([ew, 2, CELL_Z1-FLOOR]);
    // wire slots in the end walls (cell terminals -> UPS board)
    for (x=CELL_XS) for (y=[CELL_Y0-3, CELL_Y1+1])
        at(x-2.5, y-0.2, CELL_ZC) translate([0,-2.4,0]) cube([5, 2.4, 5]);
}

// =====================================================================
// R2: cells / FireBeetle / MPPT / RTC / sensor / charge port / OLED button
// =====================================================================
// The UPS HAT (E) is attached to the Pi (component side) and sits above the cells;
// it needs no printed support. The printed tray only locates the cells.

module firebeetle_tray() difference() {
    // FireBeetle 2 ESP32-UE (25.4 x 60) in the bottom shell under the keyboard.
    // Low corner posts only; the 4-wire OLED cable and the USB cable leave over the ends.
    m = 2; t = 1.6;
    at(FB_X-m, FB_Y-m, FB_Z) translate([0,-(FB_H+2*m),0]) cube([FB_W+2*m, FB_H+2*m, 2]);
    for (p=[[FB_X-m, FB_Y-m], [FB_X+FB_W+m-t, FB_Y-m],
            [FB_X-m, FB_Y+FB_H+m-t], [FB_X+FB_W+m-t, FB_Y+FB_H+m-t]])
        at(p[0], p[1], FB_Z+2) translate([0,-t,0]) cube([t, t, 5]);
    // two zip-tie slots through the base
    for (y=[FB_Y+10, FB_Y+FB_H-12])
        at(FB_X+FB_W/2-1.5, y, FB_Z+1) translate([0,-3,0]) cube([3, 3, 2]);
}

module rtc_tray() {
    // DS3231 sits on a shallow floor tray under the keyboard (2 mm margin around the module)
    m = 2; t = 1.6;
    at(RTC_X-m, RTC_Y-m, RTC_Z0) translate([0,-(RTC_H+2*m),0]) cube([RTC_W+2*m, RTC_H+2*m, 2]);
    for (p=[[RTC_X-m, RTC_Y-m], [RTC_X+RTC_W+m-t, RTC_Y-m],
            [RTC_X-m, RTC_Y+RTC_H+m-t], [RTC_X+RTC_W+m-t, RTC_Y+RTC_H+m-t]])
        at(p[0], p[1], RTC_Z0) translate([0,-t,0]) cube([t, t, RTC_T+2]);
    // wire notch
    at(RTC_X+RTC_W-6, RTC_Y-m-1, RTC_Z0+1.4) translate([0,-1,0]) cube([6, 3, 4]);
}

module mppt_tray() {
    // small MPPT/charge module under the keyboard, clear of the cells and RTC
    at(MPPT_X, MPPT_Y, MPPT_Z) translate([0,-MPPT_H,0]) cube([MPPT_W, MPPT_H, 2]);
    t = 1.6;
    for (p=[[MPPT_X, MPPT_Y], [MPPT_X+MPPT_W-t, MPPT_Y], [MPPT_X, MPPT_Y+MPPT_H-t], [MPPT_X+MPPT_W-t, MPPT_Y+MPPT_H-t]])
        at(p[0], p[1], MPPT_Z) translate([0,-t,0]) cube([t, t, 8]);
    // cable slots towards the top wall and the UPS board
    at(MPPT_X+4, MPPT_Y-1, MPPT_Z+1) translate([0,-1.5,0]) cube([5, 2.5, 5]);
    at(MPPT_X+MPPT_W-9, MPPT_Y+MPPT_H-1, MPPT_Z+1) translate([0,-2,0]) cube([5, 2, 5]);
}

module sensor_chamber_solid() {
    // box grown inwards from the left wall; the cavity is cut by sensor_chamber_cut()
    at(0, SENSOR_Y0, SENSOR_Z0) translate([0,-(SENSOR_Y1-SENSOR_Y0),0]) cube([SENSOR_X1, SENSOR_Y1-SENSOR_Y0, SENSOR_Z1-SENSOR_Z0]);
    // small shelf for the breakout
    at(1.2, SENSOR_Y0+2, SENSOR_Z0+2) translate([0,-(SENSOR_Y1-SENSOR_Y0-4),0]) cube([SENSOR_X1-1.2, SENSOR_Y1-SENSOR_Y0-4, 1.2]);
}
module sensor_chamber_cut() {
    // open towards the interior for inserting the breakout and its cable
    at(1.2, SENSOR_Y0+2, SENSOR_Z0+2) translate([0,-(SENSOR_Y1-SENSOR_Y0-4),0])
        cube([SENSOR_X1-1.2+1, SENSOR_Y1-SENSOR_Y0-4, SENSOR_Z1-SENSOR_Z0-2]);  // open top = no bridge
    // membrane vent through the outer wall + 16 mm seat for a stick-on membrane
    at(-1, SENSOR_CY, SENSOR_CZ) rotate([0,90,0]) cylinder(d=SENSOR_MEM_D, h=WALL+2);
    at(-1.2, SENSOR_CY, SENSOR_CZ) rotate([0,90,0]) cylinder(d=SENSOR_MEM_D+4, h=1.2);
    // cable exit slot (foam/grommet it to keep Pi heat out)
    at(SENSOR_X1-1.2, SENSOR_CY-2, SENSOR_Z1-6) translate([0,-4,0]) cube([2.2, 4, 4]);
}

module charge_port_solid() {
    // boss around the panel connector, fused into the top wall
    h = CHG_H + 7;
    at(CHG_X-10, WALL, CHG_Z-h/2) translate([0,-8,0]) cube([20, 8, h]);
}
module charge_port_cut() {
    // r2: USB-C panel connector. r4: 5.5 x 2.1 mm DC barrel socket (round, so the panel
    // nut seats on a round hole).
    if (R4) {
        at(CHG_X, -1, CHG_Z) rotate([90,0,0]) cylinder(d=CHG_W, h=WALL+2);
        at(CHG_X, -1.2, CHG_Z) rotate([90,0,0]) cylinder(d=CHG_REC_W, h=1.2);   // O-ring seat
        // socket body pocket: a Ø9.5 barrel socket has a ~9 mm body, so 10 mm of height
        at(CHG_X-7, WALL, CHG_Z-5) translate([0,-13,0]) cube([14, 13, 10]);     // socket body
    } else {
        at(CHG_X-CHG_W/2, -1, CHG_Z-CHG_H/2) translate([0,-(WALL+2),0]) cube([CHG_W, WALL+2, CHG_H]);
        // rubber plug / O-ring seat on the outside
        at(CHG_X-CHG_REC_W/2, -1.2, CHG_Z-CHG_REC_H/2) translate([0,-1.2,0]) cube([CHG_REC_W, 1.2, CHG_REC_H]);
        // connector body pocket inside
        at(CHG_X-7, WALL, CHG_Z-4) translate([0,-9,0]) cube([14, 9, 8]);
    }
}

module oled_btn_solid() {
    at(OLED_BTN_X-10, WALL, OLED_BTN_Z-10) translate([0,-9,0]) cube([20, 9, 20]);
}
module oled_btn_cut() {
    // sealed 12 mm push button through the top wall
    at(OLED_BTN_X, -1, OLED_BTN_Z) rotate([90,0,0]) cylinder(d=OLED_BTN_D, h=WALL+2);
    // 16 mm O-ring recess
    at(OLED_BTN_X, -1.2, OLED_BTN_Z) rotate([90,0,0]) cylinder(d=16, h=1.2);
    // switch body / nut pocket inside
    at(OLED_BTN_X, WALL, OLED_BTN_Z) rotate([90,0,0]) cylinder(d=OLED_BTN_D+1, h=10);
}

module kbs_post(p) {
    // vertical support column for the keyboard support frame (frame is a separate part)
    at(p[0]-2, p[1]-2, FLOOR) translate([0,-4,0]) cube([4, 4, KBS_Z0-FLOOR-0.2]);
}

// ---- Pi 5 port windows in the right wall (r1 only; r2 uses internal USB)
module pi_port_cuts() {
    for (p = PI_PORTS) {
        yc = PI_Y0 + p[0]; w = p[1] + 1.2; h = p[2] + 1.2;
        at(W - WALL - 2, yc + w/2, max(FLOOR, PI_PCB_BOT - h))
            cube([WALL + 6, w, min(h, PI_PCB_BOT - FLOOR + 0.6)]);
    }
}

// ---- microSD extender slot (left wall, extender board lies on the floor)
module sd_cut() at(-1, 48, FLOOR) translate([0,-14,0]) cube([WALL+2, 14, 3.5]);

// ---- back vents behind the Pi cooler
// r2: the cell row ends at y=88, so the vents move towards the keyboard end
// (still under the cooler) instead of opening behind the cells.
module vent_cut() {
    if (R4)        for (i=[0:5]) at(70, 150 + i*2.8, -1) translate([0,-1.6,0]) linear_extrude(FLOOR+2) rrect(25, 1.6, 0.79);
    else if (R2)   for (i=[0:5]) at(67, 92 + i*2.8, -1) translate([0,-1.6,0]) linear_extrude(FLOOR+2) rrect(25, 1.6, 0.79);
    else           for (i=[0:5]) at(61, 57 + i*2.8, -1) translate([0,-1.6,0]) linear_extrude(FLOOR+2) rrect(25, 1.6, 0.79);
}

// ---- inside text
module floor_text() {
    at(W/2, pick(228, 196, 140), FLOOR - 0.5) linear_extrude(1)
        text(pick("KTEMATA  r4", "KTEMATA  r2", "KTEMATA"), size=R2 ? 6 : 7,
             halign="center", valign="center", font="Liberation Sans:style=Bold");
}

module bottom_part() {
    difference() {
        union() {
            shell();
            for (p=CASE_SCREWS) case_boss_solid(p);
            for (p=DISP_HOLES) disp_post_solid(p);
            if (R2) {
                if (!R4) cell_tray();
                rtc_tray();
                mppt_tray();
                firebeetle_tray();
                sensor_chamber_solid();
                charge_port_solid();
                oled_btn_solid();
                for (p=KBS_POSTS) kbs_post(p);
            } else {
                battery_guides();
                pull_channel();
                port_box();
                btn_guide();
            }
        }
        for (p=CASE_SCREWS) case_boss_cut(p);
        for (p=DISP_HOLES) disp_post_cut(p);
        if (R2) {
            sensor_chamber_cut();
            charge_port_cut();
            oled_btn_cut();
        } else {
            pull_cut();
            port_box_cut();
            pi_port_cuts();
            btn_cut();
        }
        sd_cut();
        vent_cut();
        floor_text();
        // keep everything below the split plane
        translate([-1,-1,H_BOT]) cube([W+2, L+2, 50]);
    }
}

if (is_undef(ASSEMBLY)) bottom_part();

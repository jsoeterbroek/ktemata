// Pi Flux r1 - Bottom part (back shell)
// Print back-plate down, no supports needed except the port windows' top bridges.
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

// ---- Pi 5 port windows in the right wall
module pi_port_cuts() {
    for (p = PI_PORTS) {
        yc = PI_Y0 + p[0]; w = p[1] + 1.2; h = p[2] + 1.2;
        at(W - WALL - 2, yc + w/2, max(FLOOR, PI_PCB_BOT - h))
            cube([WALL + 6, w, min(h, PI_PCB_BOT - FLOOR + 0.6)]);
    }
}

// ---- microSD extender slot (left wall, extender board lies on the floor)
module sd_cut() at(-1, 48, FLOOR) translate([0,-14,0]) cube([WALL+2, 14, 3.5]);

// ---- battery power button hole (bottom wall)
module btn_cut() at(BTN_X - (BTN_W+0.5)/2, L+1, BTN_Z - (BTN_HH+0.5)/2) cube([BTN_W+0.5, WALL+4.5, BTN_HH+0.5]);
module btn_guide() {
    // short sleeve around the plunger on the inside
    at(BTN_X - (BTN_W+3.7)/2, L-WALL, FLOOR) cube([BTN_W+3.7, 2.5, BTN_Z + (BTN_HH+0.5)/2 + 1.6 - FLOOR]);
}

// ---- back vents behind the Pi cooler
module vent_cut() {
    for (i=[0:5]) at(61, 57 + i*2.8, -1) translate([0,-1.6,0]) linear_extrude(FLOOR+2) rrect(25, 1.6, 0.79);
}

// ---- inside text
module floor_text() {
    at(W/2, 140, FLOOR - 0.5) linear_extrude(1)
        text("π·FLUKS/AI", size=7, halign="center", valign="center", font="Liberation Sans:style=Bold");
}

module bottom_part() {
    difference() {
        union() {
            shell();
            for (p=CASE_SCREWS) case_boss_solid(p);
            for (p=DISP_HOLES) disp_post_solid(p);
            battery_guides();
            pull_channel();
            port_box();
            btn_guide();
        }
        for (p=CASE_SCREWS) case_boss_cut(p);
        for (p=DISP_HOLES) disp_post_cut(p);
        pull_cut();
        port_box_cut();
        pi_port_cuts();
        sd_cut();
        btn_cut();
        vent_cut();
        floor_text();
        // keep everything below the split plane
        translate([-1,-1,H_BOT]) cube([W+2, L+2, 50]);
    }
}

if (is_undef(ASSEMBLY)) bottom_part();

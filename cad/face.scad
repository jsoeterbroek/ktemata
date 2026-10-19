// Pi Flux - Top part (front face)
// Modelled in assembly position; the STL export flips it so the face plate is on the bed.
include <common.scad>

SIDE_CUTOUT  = is_undef(SIDE_CUTOUT) ? !R2 : SIDE_CUTOUT;  // r1 only; r2 keyboard is wired internally
BRASS_INSERT = is_undef(BRASS_INSERT) ? false : BRASS_INSERT;

SCR_WIN = [DISP_X+1, DISP_Y+1, DISP_X+DISP_W-1, DISP_Y+DISP_H-1];  // 1 mm lip over the glass

module win2d(r4) {   // r4 = [x0,y0,x1,y1] in drawing coords
    translate([r4[0], L-r4[3]]) rrect(r4[2]-r4[0], r4[3]-r4[1], 2.5);
}

module face_shell() {
    difference() {
        intersection() { outer_body(); translate([-10,-10,H_BOT]) cube([W+20, L+20, H_FACE+1]); }
        translate([0,0,H_BOT-1]) linear_extrude(H_FACE - PLATE + 1) inner_outline();
    }
}

module face_boss(p) at(p[0], p[1], H_BOT) difference() {
    cylinder(d=BOSS_D, h=H_FACE - PLATE + 0.01);
    translate([0,0,-1]) cylinder(d=BRASS_INSERT ? 3.6 : M25_PIL, h=H_FACE - PLATE - 0.8);
}

// alignment lip that drops 2 mm into the bottom shell
module lip() {
    difference() {
        translate([0,0,H_BOT-2]) linear_extrude(2.01) difference() {
            offset(delta=-TOL) inner_outline();
            offset(delta=-TOL-1.2) inner_outline();
        }
        for (p=CASE_SCREWS) at(p[0], p[1], H_BOT-3) cylinder(d=BOSS_D+2, h=4);
        if (!R2) {
            // keep clear of the pull switch slot / port box / pi ports
            at(PULL_SLOT_X0-3, -1, H_BOT-3) translate([0,-12,0]) cube([PULL_SLOT_W+6, 12, 4]);
            at(W-15, PI_Y0, H_BOT-3) translate([0,-60,0]) cube([16, 60, 4]);
        }
    }
}

// display locating ribs: 4 corner L-brackets hugging the glass (glass sits against the plate)
module display_ribs() {
    rh = 4; t = 1.2; c = 0.3; k = 12;
    translate([0,0,T-PLATE-rh]) linear_extrude(rh + 0.01) intersection() {
        difference() {
            translate([DISP_X-c-t, L-DISP_Y-DISP_H-c-t]) square([DISP_W+2*(c+t), DISP_H+2*(c+t)]);
            translate([DISP_X-c, L-DISP_Y-DISP_H-c]) square([DISP_W+2*c, DISP_H+2*c]);
        }
        for (cx=[DISP_X-c-t, DISP_X+DISP_W+c+t-k]) for (cy=[L-DISP_Y-DISP_H-c-t, L-DISP_Y+c+t-k])
            translate([cx, cy]) square([k, k]);
    }
}

// keyboard PCB pocket ribs
module kb_ribs() {
    rh = T - PLATE - KB_PCB_FRONT + 1.2;   // reaches the back of the pcb edge
    t = 1.2; c = 0.4;
    x0 = KB_PCB_X - c - t; x1 = KB_PCB_X + KB_PCB[0] + c;
    y0 = KB_PCB_Y - c - t; y1 = KB_PCB_Y + KB_PCB[1] + c;
    z0 = T - PLATE - rh;
    if (R2) {
        // split the top rib around the status-OLED board (no long gap under the board)
        xa = x0 + 12; xb = x0 + KB_PCB[0] - 12;
        at(xa, y0 + t, z0) cube([max(0.01, OLED_X0 - 2 - xa), t, rh]);
        at(OLED_X1 + 2, y0 + t, z0) cube([max(0.01, xb - OLED_X1 - 2), t, rh]);
    } else {
        at(x0 + 12, y0 + t, z0) cube([KB_PCB[0] - 24, t, rh]);        // top
    }
    at(x0 + 12, y1 + t, z0) cube([KB_PCB[0] - 24, t, rh]);            // bottom
    at(x0, y0 + 14 + 30, z0) cube([t, 30, rh]);                       // left
}

// status OLED module pocket: the 1.3" I2C OLED module sits just behind the face
// plate, between the display and the keyboard PCB. Side walls + retaining tabs.
module oled_mount() {
    t = 1.5; ztop = T - PLATE;
    // side walls
    for (x=[OLED_X0-t, OLED_X1])
        at(x, OLED_Y0, OLED_Z0) translate([0,-OLED_H,0]) cube([t, OLED_H, ztop-OLED_Z0]);
    // no end walls: the module top is 1.6 mm below the display and its bottom
    // 1.6 mm above the keyboard window, so only side walls + tabs fit.
    // small tabs under the board (attached to the side walls, 4 mm long bridges)
    for (y=[OLED_Y0+2, OLED_Y1-6]) {
        // overlap 0.5 mm into the side walls so the tab does not just touch them
        at(OLED_X0-0.5, y, OLED_Z0-1.0) translate([0,-4,0]) cube([1.7, 4, 0.8]);
        at(OLED_X1-1.2, y, OLED_Z0-1.0) translate([0,-4,0]) cube([1.7, 4, 0.8]);
    }
}

// screen / key / OLED windows with a 45 deg bevel on the outside (prints face-down without supports)
BEVEL = 1.2;
module windows_cut() {
    wins = R2 ? [SCR_WIN, KB_WIN, OLED_WIN] : [SCR_WIN, KB_WIN];
    for (r = wins) {
        translate([0,0,T-PLATE-1]) linear_extrude(PLATE+2) win2d(r);
        hull() {
            translate([0,0,T-BEVEL]) linear_extrude(0.01) win2d(r);
            translate([0,0,T+0.01]) linear_extrude(0.01) offset(delta=BEVEL+0.01) win2d(r);
        }
    }
}

// faux screw heads over the case screws: recessed ring + hex socket, 0.6 mm deep
module screw_heads() {
    for (p = CASE_SCREWS) at(p[0], p[1], T-0.6) {
        difference() { cylinder(d=6, h=1); translate([0,0,-1]) cylinder(d=5, h=3); }
        cylinder(d=2.6, h=1, $fn=6);
    }
}

module logo() {
    at(W/2, R2 ? 5.0 : DISP_Y/2 + 0.3, T - 0.6) linear_extrude(1)
        text("π·FLUKS/AI", size=6, halign="center", valign="center", font="Liberation Sans:style=Bold Italic");
}

module motto() {
    if (R2) at(W/2, 197, T - 0.6) linear_extrude(1)
        text("scientia potentia est", size=4.2, halign="center", valign="center", font="Liberation Sans:style=Italic");
}

module face_part() {
    difference() {
        union() {
            face_shell();
            for (p=CASE_SCREWS) face_boss(p);
            lip();
            display_ribs();
            kb_ribs();
            if (R2) oled_mount();
        }
        windows_cut();
        screw_heads();
        // keyboard side cutout (r1 USB-C + power switch of the keyboard pcb)
        if (SIDE_CUTOUT) at(W - WALL - 1, 124, H_BOT - 3) translate([0,-22,0]) cube([WALL + 2 + RIB_H + 1, 22, KB_PCB_BACK - H_BOT + 3 + 2.5]);
        logo();
        motto();
    }
}

if (is_undef(ASSEMBLY)) face_part();

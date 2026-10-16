// Pi Flux r1 - Top part (front face)
// Modelled in assembly position; the STL export flips it so the face plate is on the bed.
include <common.scad>

SIDE_CUTOUT  = true;    // keyboard USB-C / power switch access on the right edge (false = GPIO-wired option)
BRASS_INSERT = false;   // larger holes for M2.5 heat-set inserts

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
        // keep clear of the pull switch slot / port box / pi ports
        at(PULL_SLOT_X0-3, -1, H_BOT-3) translate([0,-12,0]) cube([PULL_SLOT_W+6, 12, 4]);
        at(W-15, PI_Y0, H_BOT-3) translate([0,-60,0]) cube([16, 60, 4]);
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
    at(x0 + 12, y0 + t, z0) cube([KB_PCB[0] - 24, t, rh]);         // top
    at(x0 + 12, y1 + t, z0) cube([KB_PCB[0] - 24, t, rh]);         // bottom
    at(x0, y0 + 14 + 30, z0) cube([t, 30, rh]);                    // left
}

// screen / key windows with a 45 deg bevel on the outside (prints face-down without supports)
BEVEL = 1.2;
module windows_cut() {
    for (r = [SCR_WIN, KB_WIN]) {
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
    at(W/2, DISP_Y/2 + 0.3, T - 0.6) linear_extrude(1)
        text("π·FLUKS/AI", size=6, halign="center", valign="center", font="Liberation Sans:style=Bold Italic");
}

module face_part() {
    difference() {
        union() {
            face_shell();
            for (p=CASE_SCREWS) face_boss(p);
            lip();
            display_ribs();
            kb_ribs();
        }
        windows_cut();
        screw_heads();
        // keyboard side cutout (USB-C + power switch of the keyboard pcb)
        if (SIDE_CUTOUT) at(W - WALL - 1, 124, H_BOT - 3) translate([0,-22,0]) cube([WALL + 2 + RIB_H + 1, 22, KB_PCB_BACK - H_BOT + 3 + 2.5]);
        logo();
    }
}

if (is_undef(ASSEMBLY)) face_part();

// Ktemata r5 website showcase: open yellow Peli-style host with the complete cassette.
// render_showcase.py supplies STRATA_DECK / STRATA_COVER from paint.strata_marks().

ASSEMBLY = true;
include <common.scad>
use <r5_tray.scad>
use <r5_deck.scad>
use <r5_lid_cover.scad>
use <assembly_r5.scad>

$fn = 48;

// Showcase composition and host exterior (the fit-check host remains schematic).
CASE_W = 270;
CASE_D = 215;
CASE_X = (R5_W - CASE_W) / 2;
CASE_Y = (R5_L - CASE_D) / 2;
CASE_LID_WALL = 4;
CASE_SEAL_Z = HOST_BOT;
CASE_TOP_Z = HOST_BOT + HOST_LID + CASE_LID_WALL;
OPEN_ANGLE = 100;
FOAM_Z = R5_PAD;
PAINT_Z = 0.08;
YELLOW = "#f1c40f";
BASE = "#151b21";
GASKET = "#24282a";
SCREEN = "#071017";
SCREEN_TEXT = "#e8e4d9";
SCREEN_ACCENT = "#e2bd8d";

// json-compatible paint arrays: [x0, y0, x1, y1, CSS colour].
STRATA_DECK = is_undef(STRATA_DECK) ? [] : STRATA_DECK;
STRATA_COVER = is_undef(STRATA_COVER) ? [] : STRATA_COVER;

module prism(w, d, h, r) linear_extrude(h) rrect(w, d, r);
module span(x0, y0, x1, y1, z, h) translate([x0, y0, z]) cube([x1-x0, y1-y0, h]);
module at3(x, y, z) translate([x, y, z]) children();

module peli_base() {
    // Hollow base: cavity floor is the foam top, matching the cassette's 8 mm pad.
    difference() {
        at3(CASE_X, CASE_Y, 0) prism(CASE_W, CASE_D, HOST_BOT, 12);
        at3((R5_W-HOST_TOP[0])/2, (R5_L-HOST_TOP[1])/2, FOAM_Z)
            prism(HOST_TOP[0], HOST_TOP[1], HOST_BOT-FOAM_Z+1, 10);
    }
    // Moulded vertical ribs on all four outside walls.
    for (x=[CASE_X+30, CASE_X+62, CASE_W+CASE_X-67, CASE_W+CASE_X-35])
        for (y=[CASE_Y-1.5, CASE_Y+CASE_D-1.5])
            at3(x, y, 10) cube([5, 3, HOST_BOT-22]);
    for (y=[CASE_Y+32, CASE_Y+70, CASE_Y+108, CASE_Y+146])
        for (x=[CASE_X-1.5, CASE_X+CASE_W-1.5])
            at3(x, y, 10) cube([3, 5, HOST_BOT-22]);
    // Feet and the dark sealing bead at the mouth.
    for (x=[CASE_X+22, CASE_X+CASE_W-34])
        for (y=[CASE_Y+22, CASE_Y+CASE_D-34])
            at3(x, y, -2) prism(12, 12, 2, 3);
    color(GASKET) difference() {
        at3(CASE_X+3, CASE_Y+3, HOST_BOT-1.4) prism(CASE_W-6, CASE_D-6, 1.4, 10);
        at3((R5_W-HOST_TOP[0])/2-1, (R5_L-HOST_TOP[1])/2-1, HOST_BOT-2)
            prism(HOST_TOP[0]+2, HOST_TOP[1]+2, 3, 9);
    }
}

module peli_lid() {
    // Closed-pose lid, ceiling at HOST_BOT+HOST_LID and a 4 mm outer skin above it.
    difference() {
        at3(CASE_X, CASE_Y, CASE_SEAL_Z) prism(CASE_W, CASE_D, HOST_LID+CASE_LID_WALL, 12);
        at3((R5_W-HOST_TOP[0])/2, (R5_L-HOST_TOP[1])/2, CASE_SEAL_Z-1)
            prism(HOST_TOP[0], HOST_TOP[1], HOST_LID+1, 10);
    }
    // Exterior lid channels, visible on the closed orange case.
    for (x=[CASE_X+28, CASE_X+62, CASE_W+CASE_X-67, CASE_W+CASE_X-35])
        at3(x, CASE_Y+18, CASE_TOP_Z) cube([5, CASE_D-36, 2]);
}

module peli_hardware() {
    // Hinge barrels share the actual showcase pivot at y=0, z=HOST_BOT.
    for (x=[CASE_X+28, CASE_X+104, CASE_X+CASE_W-68]) {
        at3(x, -4, CASE_SEAL_Z) rotate([0, 90, 0]) cylinder(d=10, h=40);
        at3(x+5, -4, CASE_SEAL_Z) rotate([0, 90, 0]) cylinder(d=6, h=45);
    }
    // Two front latches and a carrying handle.
    for (x=[CASE_X+42, CASE_X+CASE_W-62]) {
        at3(x, CASE_Y+CASE_D-1, CASE_SEAL_Z-24) prism(20, 7, 27, 2);
        color(GASKET) at3(x+3, CASE_Y+CASE_D+5, CASE_SEAL_Z-20) cube([14, 3, 15]);
    }
    for (x=[R5_W/2-39, R5_W/2+34])
        at3(x, CASE_Y+CASE_D+1, 25) prism(5, 8, 17, 1.5);
    color(GASKET) at3(R5_W/2-36, CASE_Y+CASE_D+7, 27) prism(72, 6, 10, 3);
}

module open_lid() {
    translate([0, 0, CASE_SEAL_Z]) rotate([OPEN_ANGLE, 0, 0])
        translate([0, 0, -CASE_SEAL_Z]) children();
}

module deck_mark(m) {
    color(m[4]) r5_box(m[0], m[1], m[2], m[3], R5_DECK_TOP-0.02, PAINT_Z);
}

module painted_deck() {
    color(BASE) r5_deck();
    // Intersect each mark with the real part so paint never bridges a hole or the outer edge.
    for (m=STRATA_DECK) intersection() { r5_deck(); deck_mark(m); }
}

module cover_mark(m) {
    color(m[4]) at3(m[0], m[1], COVER_FRONT_Z-0.02)
        cube([m[2]-m[0], m[3]-m[1], PAINT_Z]);
}

module cover_paint_local() {
    for (m=STRATA_COVER) intersection() { r5_lid_cover(); cover_mark(m); }
}

module cover_text_local() {
    at3(COVER_W/2, COVER_L/2, 0) rotate([0, 0, 180])
        at3(-COVER_W/2, -COVER_L/2, 0) {
            color(SCREEN_TEXT) at3(COVER_W/2, COVER_L-17, COVER_FRONT_Z+0.07)
                linear_extrude(0.03) text("KTEMATA", size=5, halign="center", font="DejaVu Sans:style=Bold");
            color(SCREEN_ACCENT) at3(COVER_W/2, COVER_L-23, COVER_FRONT_Z+0.07)
                linear_extrude(0.03) text("A POSSESSION FOR ALL TIME", size=2.5, halign="center");
        }
}

module closed_painted_cover() {
    color(BASE) c_lid_cover();
    at3(0, R5_L, HOST_BOT+HOST_LID) rotate([180, 0, 0]) {
        cover_paint_local();
        cover_text_local();
    }
}

module deck_lettering() {
    color(SCREEN_TEXT) r5_at(R5_W/2, 82, R5_DECK_TOP+0.08) rotate([0, 0, 180])
        linear_extrude(0.03) text("KTEMATA", size=8, halign="center", font="DejaVu Sans:style=Bold");
    color(SCREEN_ACCENT) r5_at(R5_W/2, 89, R5_DECK_TOP+0.08) rotate([0, 0, 180])
        linear_extrude(0.03) text("A POSSESSION FOR ALL TIME", size=2.6, halign="center");
}

module keyboard_detail() {
    // K06-style five-row key field on the left and touchpad on the right.
    for (row=[0:4]) for (col=[0:11])
        color("#30363a") r5_box(45.0+col*8.2, 108.0+row*8.6,
                                 51.8+col*8.2, 114.2+row*8.6, R5_KB_TOP+0.03, 0.55);
    color("#111619") r5_box(150, 109, 188, 153, R5_KB_TOP+0.04, 0.12);
    color("#4d565c") r5_box(151, 110, 187, 152, R5_KB_TOP+0.16, 0.08);
    color("#1b2226") r5_box(151.8, 110.8, 186.2, 151.2, R5_KB_TOP+0.25, 0.12);
    color("#3e474d") r5_box(151, 154, 169, 158, R5_KB_TOP+0.05, 0.25);
    color("#3e474d") r5_box(170, 154, 188, 158, R5_KB_TOP+0.05, 0.25);
}

module oled_detail() {
    ox = R5_OLED_X0 + (R5_OLED_PCB[0]-R5_OLED_ACTIVE[0])/2;
    oy = R5_OLED_Y0 + R5_OLED_PCB_CLR + R5_OLED_GLASS_Y
         + (R5_OLED_GLASS[1]-R5_OLED_ACTIVE[1])/2;
    oz = R5_OLED_SEAT + R5_OLED_GLASS[2] + 0.04;
    color("#02090a") r5_box(ox, oy, ox+R5_OLED_ACTIVE[0], oy+R5_OLED_ACTIVE[1], oz, 0.06);
    color("#a9d6c4") r5_at(ox+3, oy+10.5, oz+0.07) rotate([0, 0, 180])
        linear_extrude(0.02) text("12:34", size=4.2, font="DejaVu Sans:style=Bold");
    color("#a9d6c4") r5_at(ox+26.5, oy+10.5, oz+0.07) rotate([0, 0, 180])
        linear_extrude(0.02) text("87%", size=3.4, halign="right");
    color("#6c9b8b") r5_at(ox+3, oy+4.0, oz+0.07) rotate([0, 0, 180])
        linear_extrude(0.02) text("7.9 V  ·  READY", size=2.2);
}

module cassette_base() {
    color("#303537") r5_tray();
    painted_deck();
    deck_lettering();
    color("#24734a") c_pi();
    color("#244b68") c_ups();
    color("#b76a2e") c_cells();
    color("#101214") c_keyboard();
    keyboard_detail();
    color("#11181d") c_oled();
    oled_detail();
    color("#24474a") c_floor();
    color("#c5c9cb") c_button();
    color("#bfc4c7") c_charger();
}

// Simulated offline-library UI on the active 154.88 x 86.72 mm display area.
module screen_local() {
    sx = PANEL_X + (R5_PANEL[0]-R5_PANEL_ACTIVE[0])/2;
    sy = PANEL_Y + 11.0;
    sw = R5_PANEL_ACTIVE[0];
    sh = R5_PANEL_ACTIVE[1];
    sz = COVER_FRONT_Z + 0.10;
    at3(sx+sw/2, sy+sh/2, 0) rotate([0, 0, 180]) at3(-sx-sw/2, -sy-sh/2, 0) {
    color(SCREEN) at3(sx, sy, sz) linear_extrude(0.05) rrect(sw, sh, 2);
    color("#20333e") at3(sx, sy+sh-16, sz+0.05) cube([sw, 16, 0.03]);
    color(SCREEN_ACCENT) at3(sx+8, sy+sh-11.5, sz+0.09)
        linear_extrude(0.02) text("KTEMATA", size=7.5, font="DejaVu Sans:style=Bold");
    color("#a9b2bb") at3(sx+54, sy+sh-10.5, sz+0.09)
        linear_extrude(0.02) text("OFFLINE LIBRARY", size=3.4);
    color("#42545f") at3(sx+7, sy+sh-20, sz+0.06) cube([sw-14, 0.45, 0.02]);
    rows = ["Wikipedia", "OpenStreetMap", "Project Gutenberg", "Text and field archives"];
    subs = ["Articles and reference", "Maps without a network", "Books and documents", "Local collections"];
    for (i=[0:3]) {
        yy = sy+sh-31-i*13.0;
        color(SCREEN_ACCENT) at3(sx+8, yy, sz+0.08) cylinder(d=2.4, h=0.03);
        color(SCREEN_TEXT) at3(sx+14, yy+1.2, sz+0.09)
            linear_extrude(0.02) text(rows[i], size=4.4, font="DejaVu Sans:style=Bold");
        color("#9fabb2") at3(sx+14, yy-3.4, sz+0.09)
            linear_extrude(0.02) text(subs[i], size=2.7);
    }
    color("#8a6234") at3(sx+7, sy+5, sz+0.07) cube([sw-14, 6, 0.03]);
    color(SCREEN_TEXT) at3(sx+sw/2, sy+7, sz+0.11)
        linear_extrude(0.02) text("AVAILABLE WITHOUT POWER OR NETWORK", size=2.6, halign="center");
    }
}

module closed_screen() {
    at3(0, R5_L, HOST_BOT+HOST_LID) rotate([180, 0, 0]) screen_local();
}

module foreground_case() {
    color(YELLOW) { peli_base(); peli_hardware(); }
    translate([0, 0, FOAM_Z]) cassette_base();
    open_lid() {
        color(YELLOW) peli_lid();
        closed_painted_cover();
        color("#050708") c_display();
        closed_screen();
    }
}

foreground_case();

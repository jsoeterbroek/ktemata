// Pi Flux - Internal keyboard support frame
// r1: sits on the power bank. r2: rests on four printed columns above the cells and
// backs up the wired keyboard PCB (two windows for components). Print flat, as modelled.
include <common.scad>

KBS_H  = KB_PCB_BACK - 0.2 - KBS_Z0; // stop 0.2 mm short of the keyboard pcb
KBS_WALL = 3;

module kb_support() {
    translate([0,0,KBS_Z0]) difference() {
        linear_extrude(KBS_H) translate([KBS[0], L-KBS[3]]) rrect(KBS[2]-KBS[0], KBS[3]-KBS[1], 2);
        // windows
        translate([0,0,-1]) linear_extrude(KBS_H+2) {
            translate([KBS[0]+KBS_WALL, L-KBS[3]+KBS_WALL]) rrect(KBS_DIV-1.5-KBS[0]-KBS_WALL, KBS[3]-KBS[1]-2*KBS_WALL, 1.5);
            translate([KBS_DIV+1.5, L-KBS[3]+KBS_WALL]) rrect(KBS[2]-KBS_WALL-KBS_DIV-1.5, KBS[3]-KBS[1]-2*KBS_WALL, 1.5);
        }
        // wire relief notches on the top edge (cable routing in r2)
        for (x=[KBS_DIV-10, KBS[2]-20]) at(x, KBS[1]-1, KBS_H-2) translate([0,-KBS_WALL-2,0]) cube([8, KBS_WALL+2, 3]);
        // lighten / flex slots in the long walls
        for (x=[KBS[0]+12 : 18 : KBS[2]-20]) for (y=[KBS[1]-1, KBS[3]-KBS_WALL-1])
            at(x, y+KBS_WALL+2, -1) cube([10, KBS_WALL+2, KBS_H-3]);
    }
}
if (is_undef(ASSEMBLY)) kb_support();

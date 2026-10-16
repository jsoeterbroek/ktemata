// Pi Flux r1 - Internal keyboard support frame
// Sits on top of the power bank and backs up the keyboard PCB (two windows for the
// keyboard's own LiPo / components). Print flat, as modelled.
include <common.scad>

KBS_Z0 = FLOOR + BAT_T + 0.5;        // underside (on the battery)
KBS_H  = KB_PCB_BACK - KBS_Z0;       // up to the back of the keyboard pcb
KBS    = [12, 97, 138, 166];         // x0,y0,x1,y1
KBS_WALL = 3;
KBS_DIV  = 68.5;                     // divider x (right window clears the keyboard LiPo)

module kb_support() {
    translate([0,0,KBS_Z0]) difference() {
        linear_extrude(KBS_H) translate([KBS[0], L-KBS[3]]) rrect(KBS[2]-KBS[0], KBS[3]-KBS[1], 2);
        // windows
        translate([0,0,-1]) linear_extrude(KBS_H+2) {
            translate([KBS[0]+KBS_WALL, L-KBS[3]+KBS_WALL]) rrect(KBS_DIV-1.5-KBS[0]-KBS_WALL, KBS[3]-KBS[1]-2*KBS_WALL, 1.5);
            translate([KBS_DIV+1.5, L-KBS[3]+KBS_WALL]) rrect(KBS[2]-KBS_WALL-KBS_DIV-1.5, KBS[3]-KBS[1]-2*KBS_WALL, 1.5);
        }
        // wire relief notches on top edge (battery wire of the keyboard, see guide p.8)
        for (x=[KBS_DIV-10, KBS[2]-20]) at(x, KBS[1]-1, KBS_H-2) translate([0,-KBS_WALL-2,0]) cube([8, KBS_WALL+2, 3]);
        // lighten / flex slots in the long walls
        for (x=[KBS[0]+12 : 18 : KBS[2]-20]) for (y=[KBS[1]-1, KBS[3]-KBS_WALL-1])
            at(x, y+KBS_WALL+2, -1) cube([10, KBS_WALL+2, KBS_H-3]);
    }
}
if (is_undef(ASSEMBLY)) kb_support();

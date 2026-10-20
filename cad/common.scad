// Pi Flux - shared parameters
// Coordinates: x = left->right as seen from the FRONT, y = top->bottom
// (top edge = charge-port / pull-switch side), z = 0 at the back surface, up towards the screen.
// Use at(x,y) to place things in these "drawing" coordinates.
//
// R2 selects the current target hardware (Pi 5 + DFR0550-V2 + UPS HAT (E) + 4x21700).
// r3 is a build variant of r2 with the same geometry: only the keyboard/radio changes
// (Phistone Mini Keyboard, 2.4 GHz dongle or Bluetooth). See docs/R3.md.
// The original r1 case (Waveshare display + INIU power bank) is still available:
//   openscad -D 'R2=false' ...
//   python3 cad/tools/export.py --r1

$fn = 40;

R2    = is_undef(R2)    ? true  : R2;
SEN66 = is_undef(SEN66) ? false : SEN66;   // true = larger SEN66 sensor pocket instead of BME688

// ---------------- overall ----------------
W        = 150;     // outer width
L        = R2 ? 205 : 183;     // outer height (r2 is 22 mm taller for the status OLED band)
CH       = 9;       // corner chamfer
WALL     = 3;       // side wall thickness
FLOOR    = 2;       // back plate thickness
H_FACE   = 10.5;    // face part height
PLATE    = 2;       // face plate thickness
TOL      = 0.25;
DISP_POST = 5;      // display's own standoffs (Pi and case posts)

// ---------------- r2 vertical stack ----------------
// The UPS HAT (E) hangs under the Pi; four 21700 cells lie in one row below it.
// This sets the case depth. All values are derived, so changing a component moves the shell.
CELL_D   = 21;      // 21700 diameter
CELL_L   = 70;      // 21700 length
CELL_GAP = 3.0;     // gap between cells in the tray
CELL_COUNT = 4;
CELL_Z0  = FLOOR + 1;
CELL_Z1  = CELL_Z0 + CELL_D;

UPS_W    = 88;      // Waveshare UPS HAT (E)
UPS_H    = 56;
UPS_T    = 1.6;     // pcb
UPS_COMP = 6.0;     // components/pogo pins between pcb and Pi
UPS_CELL_GAP = 0.9; // pcb underside -> cell top
UPS_PI_GAP   = 0.5; // components -> Pi pcb

UPS_PCB_BOT_R2   = CELL_Z1 + UPS_CELL_GAP;
UPS_PCB_TOP_R2   = UPS_PCB_BOT_R2 + UPS_T;
PI_PCB_BOT_R2    = UPS_PCB_TOP_R2 + UPS_COMP + UPS_PI_GAP;
PI_PCB_TOP_R2    = PI_PCB_BOT_R2 + 1.6;
DISP_POST_END_R2 = PI_PCB_TOP_R2;
DISP_Z_BACK_R2   = DISP_POST_END_R2 + DISP_POST; // display/Pi standoffs
DISP_T_R2        = 4.9;                       // DFR0550-V2
DISP_Z_FRONT_R2  = DISP_Z_BACK_R2 + DISP_T_R2;
T_R2             = DISP_Z_FRONT_R2 + PLATE;

T     = R2 ? T_R2 : 34.5;             // overall thickness
H_BOT = T - H_FACE;                   // bottom shell height (split plane)

// ---------------- screws ----------------
M25_CLR  = 2.8;     // clearance hole
M25_PIL  = 2.2;     // pilot hole for self tapping into plastic (use 3.6 for brass insert)
M25_HEAD = 5.2;     // counterbore for head
BOSS_D   = 7;
// 6 case screws: 4 corners + 2 on the screen/keyboard divider
// (side bosses at x=6 so they overlap the 3 mm wall; tangent bosses make non-manifold edges)
CASE_SCREWS = [[8.5,8.5],[W-8.5,8.5],[6,90],[W-6,90],[8.5,L-8.5],[W-8.5,L-8.5]];

// ---------------- display ----------------
// r1: Waveshare 5-DSI-TOUCH-A. r2: DFRobot DFR0550-V2 (120.7 x 75.8 x 4.9,
// outer holes 113 x 68, Pi holes 58 x 49).
DISP_W = R2 ? 120.7 : 129;
DISP_H = R2 ? 75.8  : 72.8;
DISP_T = R2 ? DISP_T_R2 : 7.8;
DISP_R = 4;
DISP_X = (W-DISP_W)/2;                // left edge of glass
DISP_Y = R2 ? 10 : 13;                // top edge of glass
DISP_Z_FRONT = T - PLATE;
DISP_Z_BACK  = DISP_Z_FRONT - DISP_T;
DISP_POST_END = DISP_Z_BACK - DISP_POST;   // where the display's own standoffs end

// case posts use the display's OUTER mounting pattern
DISP_HOLE_W  = R2 ? 113 : 117;
DISP_HOLE_H  = R2 ? 68  : 61;
DISP_HOLE_IX = R2 ? (DISP_W-DISP_HOLE_W)/2 : 6;
DISP_HOLE_IY = R2 ? (DISP_H-DISP_HOLE_H)/2 : 5.9;
DISP_HOLES = [for (dx=[DISP_HOLE_IX, DISP_HOLE_IX+DISP_HOLE_W])
              for (dy=[DISP_HOLE_IY, DISP_HOLE_IY+DISP_HOLE_H]) [DISP_X+dx, DISP_Y+dy]];

// ---------------- Raspberry Pi 5 (mounted on the display back) -----
// inner 58 x 49 pattern; ports point to the RIGHT wall, USB-C edge to the TOP.
// The Pi board is 85 x 56 with the hole pattern 3.5 mm from the GPIO edge and
// 23.5 mm from the port edge, hence the -3.5 offset.
PI_HOLE_X0 = R2 ? DISP_X + (DISP_W-58)/2 : DISP_X + 45.5;
PI_HOLE_Y0 = R2 ? DISP_Y + (DISP_H-49)/2 : DISP_Y + 11.9;
PI_HOLES_X = [PI_HOLE_X0, PI_HOLE_X0+58];
PI_HOLES_Y = [PI_HOLE_Y0, PI_HOLE_Y0+49];
PI_X0 = PI_HOLES_X[0]-3.5;          // non-port end of the board
PI_Y0 = PI_HOLES_Y[0]-3.5;          // USB-C / HDMI edge
PI_PCB_TOP = DISP_POST_END;         // pcb face against the posts
PI_PCB_BOT = PI_PCB_TOP - 1.6;      // component side faces the back plate
PI_USBC_X  = PI_X0 + 11.2;
PI_USBC_Z  = PI_PCB_BOT - 1.6;
// right-edge ports (centre measured from the USB-C edge, width, height)
PI_PORTS = [[10.2, 16.0, 13.6], [29.1, 13.4, 16.0], [47.0, 13.4, 16.0]];

// ---------------- r2: UPS HAT (E) and 4x21700 ----------------
// The UPS HAT (E) is left-aligned under the Pi: its Pi mounting holes are 26.5 mm
// from the left edge, so the 88 mm board overhangs 23 mm to the left and ends
// ~20 mm short of the Pi's port edge (no collision with the USB/Ethernet ports).
UPS_X = PI_HOLES_X[0] - 26.5;
UPS_Y = PI_HOLES_Y[0] - 3.5;
UPS_PCB_BOT = UPS_PCB_BOT_R2;
UPS_PCB_TOP = UPS_PCB_TOP_R2;
UPS_COMP_TOP = UPS_PCB_TOP + UPS_COMP;

// shift the row 5 mm left of centre so the rightmost cell clears the Pi port bodies
CELL_X0 = (W - (CELL_COUNT*CELL_D + (CELL_COUNT-1)*CELL_GAP))/2 - 5;
CELL_XS = [for (i=[0:CELL_COUNT-1]) CELL_X0 + CELL_D/2 + i*(CELL_D+CELL_GAP)];
CELL_Y0 = 18;                       // under the display, clear of keyboard
CELL_Y1 = CELL_Y0 + CELL_L;
CELL_ZC = CELL_Z0 + CELL_D/2;

// ---------------- r1 battery (INIU 10000 mAh) ----------------
BAT_W = 112; BAT_H = 70; BAT_T = 16;      // measure yours!
BAT_X = (W-BAT_W)/2;
BAT_Y = L - WALL - 5.5 - BAT_H;            // leaves room for the button plunger
BTN_X = 108;                                // battery button position along the bottom edge
BTN_Z = FLOOR + BAT_T/2;
BTN_W = 6; BTN_HH = 4;                      // button plunger cross-section

// ---------------- r1 pull switch (USB-C U adapter) ----------------
PULL_SLOT_X0 = 46.2; PULL_SLOT_W = 27.5;    // from the mat drawing (46.2 | 27.5 | 66.2)
PULL_GROOVE = 0.8;                          // floor groove the carrier rides in
UADP = [7.0, 12.5, 20.5];                   // body thickness(x), depth(y, excl. plug), height(z) - measure yours!
UADP_MALE_FROM_TOP = 5.25;                  // body top -> male plug centre
UADP_PLUG = 6.5;                            // male plug length
PULL_TRAVEL = 7;

// ---------------- keyboard ----------------
// r2: keep the existing 137 x 72 PCB footprint, wired USB (no Bluetooth, no side cutout).
KB_WIN = R2 ? [10, 123, 140, 190] : [10, 97, 140, 164];
KB_PCB = [137, 72];                         // keyboard PCB outline
KB_PCB_X = (W-KB_PCB[0])/2;
KB_PCB_Y = R2 ? 120.5 : 94.5;
KB_PCB_FRONT = T - 5;                       // z of the PCB front face
KB_PCB_BACK  = KB_PCB_FRONT - 1.2;

// ---------------- r2 status OLED (FireBeetle 2 ESP32-UE + 1.3" I2C OLED) ----------------
// The OLED is a separate 4-pin I2C module (1.3" 128x64, ~35 x 34 mm PCB,
// active area ~23.7 x 13.2 mm) mounted behind the face; the FireBeetle board
// (25.4 x 60 mm) sits in the bottom shell and connects with a short 4-wire cable.
OLED_W = 35; OLED_H = 34; OLED_T = 1.6;     // 1.3" OLED module PCB
OLED_CX = W/2;
OLED_CY = 104.4;                            // in the 37 mm band between display and keyboard
OLED_X0 = OLED_CX - OLED_W/2;
OLED_Y0 = OLED_CY - OLED_H/2;
OLED_X1 = OLED_X0 + OLED_W;
OLED_Y1 = OLED_Y0 + OLED_H;
OLED_Z0 = T - PLATE - 2.2;                  // just behind the face plate
OLED_Z1 = OLED_Z0 + OLED_T;
OLED_WIN = [OLED_CX-13, OLED_CY-7.5, OLED_CX+13, OLED_CY+7.5];  // 26 x 15 window

FB_W = 25.4; FB_H = 60; FB_T = 1.6;         // DFRobot FireBeetle 2 ESP32-UE (DFR1140)
FB_X = 30; FB_Y = 127.5; FB_Z = FLOOR;      // bottom shell, under the keyboard

// push button in the top wall (cycles the OLED screens; TinyTronics PBS-33B, 12 mm)
OLED_BTN_X = 35;
OLED_BTN_D = 12.2;                          // 12 mm PBS-33B panel button
OLED_BTN_Z = 14;

// ---------------- r2 vented sensor pocket (left wall) ----------------
// BME688 breakout 19 x 19 x 5; SEN66 option is 55.5 x 25.6 x 21.5.
SENSOR_Y0 = SEN66 ? 112 : 130;
SENSOR_Y1 = SEN66 ? 168 : 158;
SENSOR_X1 = SEN66 ? 30 : 22;
SENSOR_Z0 = FLOOR;
SENSOR_Z1 = SEN66 ? 24 : 24;
SENSOR_CY = (SENSOR_Y0 + SENSOR_Y1)/2;
SENSOR_CZ = (SENSOR_Z0 + SENSOR_Z1)/2;
SENSOR_MEM_D = 12;                          // membrane vent

// ---------------- r2 charge input, MPPT and RTC ----------------
// One sealed USB-C port, shared by solar and the hand-crank generator through
// an internal MPPT/charge module which feeds the UPS HAT USB-C input.
CHG_X = 108; CHG_W = 9.2; CHG_H = 3.5; CHG_Z = 14;
CHG_REC_W = 16; CHG_REC_H = 8;              // rubber plug seat

MPPT_W = 26; MPPT_H = 20;                   // printed tray (module is 22 x 16)
MPPT_MOD_W = 22; MPPT_MOD_H = 16;
MPPT_X = 100; MPPT_Y = 100; MPPT_Z = 6;

RTC_W = 38; RTC_H = 22; RTC_T = 14;         // DS3231 module
RTC_X = 100; RTC_Y = 145; RTC_Z0 = FLOOR;

// ---------------- keyboard support ----------------
KBS_Z0 = R2 ? 25.2 : FLOOR + BAT_T + 0.5;   // underside (on cell-tray supports in r2)
KBS = R2 ? [12, 123, 138, 192] : [12, 97, 138, 166];
KBS_WALL = 3;
KBS_DIV  = 68.5;                            // divider x (right window clears the keyboard LiPo)
KBS_POSTS = [[40,123], [110,123], [40,192], [110,192]];

// ---------------- helpers ----------------
module at(x, y, z=0) translate([x, L-y, z]) children();

// base chamfered rectangle (in real XY, origin bottom-left)
module chamfer_rect(w, l, c) {
    polygon([[c,0],[w-c,0],[w,c],[w,l-c],[w-c,l],[c,l],[0,l-c],[0,c]]);
}

// ---------------- rugged exterior ----------------
// The body edges carry a large 45 deg chamfer (front and back), so the full-height corner
// bumpers stand proud in every view. The grip sides carry vertical ribs. All of it is
// printable without supports: the chamfers are 45 deg overhangs, the ribs are vertical.
EDGE_CZ = 3;        // edge chamfer (front + back), measured from the rib tips
BUMP    = 3;        // corner bumper protrusion beyond the body
BUMP_LX = 26;       // bumper length along the top/bottom edges (from the corner)
BUMP_LY = 21;       // ... along the sides (r1: first Pi port window starts at y=23)
BUMP_CZ = 1.2;      // small chamfer on the bumpers
RIB_H = 1.2; RIB_W = 1.6; RIB_P = 4;   // grip ribs: height, width, pitch
// grip rib zones: [side (0 = left, 1 = right), y0, y1] in drawing coords
// r2 leaves a gap in the left ribs for the sensor pocket.
RIB_ZONES = R2 ? (SEN66 ? [[0, 54, 108], [0, 170, 176], [1, 82, 176]]
                            : [[0, 54, 126], [0, 161, 176], [1, 82, 176]])
               : [[0, 54, 160], [1, 82, 160]];

module body2d() offset(r=1) offset(delta=-1) chamfer_rect(W, L, CH);

module ribs2d() {
    for (z = RIB_ZONES) for (y = [z[1] : RIB_P : z[2] - RIB_W]) {
        translate([z[0] ? W : 0, L - y - RIB_W]) mirror([z[0] ? 0 : 1, 0])
            polygon([[-0.5, 0], [RIB_H - 0.4, 0], [RIB_H, 0.4], [RIB_H, RIB_W - 0.4], [RIB_H - 0.4, RIB_W], [-0.5, RIB_W]]);
    }
}

// one bumper per corner; 45 deg tapered ends where it meets the body
module bumper2d() {
    win = [[-20, -20], [BUMP_LX - 20, -20], [BUMP_LX + 1, 1], [1, BUMP_LY + 1], [-20, BUMP_LY - 20]];
    intersection() {
        offset(r=1) offset(delta=-1) offset(delta=BUMP) chamfer_rect(W, L, CH);
        for (mx = [0, 1]) for (my = [0, 1])
            translate([mx * W, my * L]) mirror([mx, 0]) mirror([0, my]) polygon(win);
    }
}

// convex chamfered slab around the chamfer_rect body, grown by d
module chamfer_slab(d, c, h=T) hull() {
    linear_extrude(0.01) offset(delta=d - c) chamfer_rect(W, L, CH);
    translate([0, 0, c]) linear_extrude(h - 2 * c) offset(delta=d) chamfer_rect(W, L, CH);
    translate([0, 0, h - 0.01]) linear_extrude(0.01) offset(delta=d - c) chamfer_rect(W, L, CH);
}

// complete closed outer body, z = 0 .. T (each part intersects its own z range)
module outer_body() {
    intersection() {
        linear_extrude(T) { body2d(); ribs2d(); }
        chamfer_slab(RIB_H, EDGE_CZ);
    }
    intersection() {
        linear_extrude(T) bumper2d();
        chamfer_slab(BUMP, BUMP_CZ);
    }
}
module inner_outline() offset(delta=-WALL) offset(r=1) offset(delta=-1) chamfer_rect(W, L, CH);

module rrect(w, h, r) offset(r=r) offset(delta=-r) square([w, h]);

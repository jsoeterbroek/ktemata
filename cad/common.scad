// Ktemata - shared parameters
// Coordinates: x = left->right as seen from the FRONT, y = top->bottom
// (top edge = charge-port / pull-switch side), z = 0 at the back surface, up towards the screen.
// Use at(x,y) to place things in these "drawing" coordinates.
//
// R4 selects the current target hardware: Raspberry Pi Touch Display 2 (5", landscape,
// 143.4 x 91.46), Waveshare UPS HAT (B) with 2x18650 in 2S, and the Rii K06 155 x 89
// keyboard with touchpad. See docs/R4.md.
// R2 (still available with -D R2=true -D R4=false) is the previous target:
// Pi 5 + DFRobot DFR0550-V2 + UPS HAT (E) + 4x21700 + Phistone keyboard (r2/r3).
// The original r1 case (Waveshare display + INIU power bank) is still available:
//   openscad -D 'R2=false' ...            (R4 follows R2 off)
//   python3 cad/tools/export.py --r1
//   python3 cad/tools/export.py --r2

$fn = 40;

R2    = is_undef(R2)    ? true  : R2;      // r2/r3 mechanics; false = r1
R4    = is_undef(R4)    ? R2    : R4;      // r4 retarget; automatically off in r1 mode
SEN66 = is_undef(SEN66) ? false : SEN66;   // true = larger SEN66 sensor pocket instead of BME688

// r4 -> a, r2/r3 -> b, r1 -> c
function pick(a, b, c) = R4 ? a : (R2 ? b : c);

// ---------------- overall ----------------
W        = pick(172, 150, 150);   // outer width (r4: 155 mm keyboard + window border)
L        = pick(237, 205, 183);   // outer height (r2 +22, r4 +54 mm over r1 for OLED band + K06)
CH       = 9;       // corner chamfer
WALL     = 3;       // side wall thickness
FLOOR    = 2;       // back plate thickness
// r4's display is 14.92 mm deep (6.42 panel + 8.5 standoffs), so the face part has to be
// tall enough to hold the whole screen below the split plane (r2: the display sits
// entirely in a 10.5 mm face).
PLATE    = 2;       // face plate thickness
TOL      = 0.25;
DISP_POST = pick(8.5, 5, 5);   // display's own standoffs (TD2 drawing: 8.5)

// ---------------- r2 vertical stack ----------------
// The UPS HAT (E) hangs under the Pi; four 21700 cells lie in one row below it.
// This sets the case depth. All values are derived, so changing a component moves the shell.
CELL_D   = pick(18.4, 21, 21);      // 18650 (r4) / 21700 (r2) diameter
CELL_L   = pick(65, 70, 70);        // cell length
CELL_GAP = 3.0;     // gap between cells in the tray
CELL_COUNT = pick(2, 4, 4);
CELL_Z0  = FLOOR + 1;
CELL_Z1  = CELL_Z0 + CELL_D;

// r4: the HAT (B) is the same 85 x 56 outline as the Pi, so it is mounted ROTATED (56 x 85).
// That makes it 29 mm narrower than the Pi along x, which keeps the Pi's USB/Ethernet port
// bodies (13.6-16 mm tall on the component side, at the +x edge) clear of its board, and it
// lets the +y end with the 8.4 V jack / USB-A / switch overhang past the Pi instead of
// colliding with it. Cells then run along y.
UPS_W    = pick(56, 88, 88);        // Waveshare UPS HAT (B) rotated / HAT (E)
UPS_H    = pick(85, 56, 56);
UPS_T    = 1.6;     // pcb
UPS_COMP = pick(6.0, 6.0, 6.0);     // components/pogo pins between pcb and Pi
UPS_CELL_GAP = 0.9; // pcb underside -> cell top (r2 tray)
UPS_PI_GAP   = 0.5; // components -> Pi pcb

// r4 uses the HAT (B) with its own soldered 18650 holders. In Waveshare's 3D drawing the PCB
// spans z 0..1.6, the cells sit on the +z side (z 2.56..20.96) and the holder runs to z 23.35,
// so the cell side extends 23.35 mm from the PCB bottom. The holder's other lip reaches 3.3 mm
// back past the PCB (towards the Pi) and stays inside the 6 mm pogo gap. Cells hang below the
// board; the pogo pins reach the Pi on top. 2S, 2x18650, NO printed tray. Measure yours.
HAT_B_BELOW_R4   = 23.35;
UPS_PCB_BOT_R2   = R4 ? CELL_Z0 + HAT_B_BELOW_R4 : CELL_Z1 + UPS_CELL_GAP;
UPS_PCB_TOP_R2   = UPS_PCB_BOT_R2 + UPS_T;
PI_PCB_BOT_R2    = UPS_PCB_TOP_R2 + UPS_COMP + UPS_PI_GAP;
PI_PCB_TOP_R2    = PI_PCB_BOT_R2 + 1.6;
DISP_T_R2        = pick(6.42, 4.9, 0);   // panel body behind the glass (TD2: 6.42 + 8.5 standoffs = 14.92)
DISP_Z_BACK_R2   = PI_PCB_TOP_R2 + DISP_POST;   // display bracket back = top of the case posts
DISP_Z_FRONT_R2  = DISP_Z_BACK_R2 + DISP_T_R2;
T_R2             = DISP_Z_FRONT_R2 + PLATE;
DISP_POST_END_R2 = PI_PCB_TOP_R2;   // case posts end at the Pi pcb; the display's own standoffs continue

T     = R2 ? T_R2 : 34.5;             // overall thickness
// r4 keeps the split plane clear of the Pi board (it must not be cut) and leaves the whole
// screen body in the face part; the display's standoffs span the split.
H_BOT  = R4 ? PI_PCB_TOP_R2 + 2.5 : T - 10.5;   // bottom shell height (split plane)
H_FACE = T - H_BOT;                             // face part height

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
// r4: Raspberry Pi Touch Display 2, 5" (143.4 x 91.46 x 14.92, outline R5). Outer hole
// pattern 72.96 x 92.87; its Pi pattern is 51 x 49 (drawing: 49 and 51 across, 58 between
// the top pair), i.e. the Pi's 58 x 49 pattern only lines up on the 49 mm axis.
DISP_W = pick(143.4, 120.7, 129);
DISP_H = pick(91.46, 75.8, 72.8);
DISP_T = R2 ? DISP_T_R2 : 7.8;
DISP_R = pick(5, 4, 4);
DISP_X = (W-DISP_W)/2;                        // left edge of glass
DISP_Y = pick(6, 10, 13);                     // top edge of glass
DISP_Z_FRONT = T - PLATE;
DISP_Z_BACK  = DISP_Z_FRONT - DISP_T;
DISP_POST_END = DISP_Z_BACK - DISP_POST;   // where the display's own standoffs end

// case posts use the display's OUTER standoff pattern.
// r4 (TD2, landscape): outer standoffs are 122.74 apart along the 143.4 mm axis and 72.96
// across the 91.46 mm axis (drawing insets 10.33 / 9.25). Its inner Pi pattern is 51 x 49,
// so only the 49 mm axis matches the Pi's 58 x 49 - see docs/R4.md.
DISP_HOLE_W  = pick(122.74, 113, 117);   // along x
DISP_HOLE_H  = pick(72.96, 68, 61);      // along y
DISP_HOLE_IX = pick((DISP_W-DISP_HOLE_W)/2, (DISP_W-113)/2, 6);
DISP_HOLE_IY = pick((DISP_H-DISP_HOLE_H)/2, (DISP_H-68)/2, 5.9);
DISP_HOLES = [for (dx=[DISP_HOLE_IX, DISP_HOLE_IX+DISP_HOLE_W])
              for (dy=[DISP_HOLE_IY, DISP_HOLE_IY+DISP_HOLE_H]) [DISP_X+dx, DISP_Y+dy]];

// ---------------- Raspberry Pi 5 (mounted on the display back) -----
// inner 58 x 49 pattern; ports point to the RIGHT wall, USB-C edge to the TOP.
// The Pi board is 85 x 56 with the hole pattern 3.5 mm from the GPIO edge and
// 23.5 mm from the port edge, hence the -3.5 offset.
// r4: the TD2's Pi pattern is 51 x 49, so the Pi keeps its 58 x 49 board holes on the case
// posts and the display is fixed through the 49 mm axis only (see docs/R4.md).
PI_HOLE_X0 = pick(DISP_X + (DISP_W-58)/2 + 3.5, DISP_X + (DISP_W-58)/2, DISP_X + 45.5);
PI_HOLE_Y0 = pick(DISP_Y + (DISP_H-49)/2, DISP_Y + (DISP_H-49)/2, DISP_Y + 11.9);
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
// r4: the UPS HAT (B) is the same 85 x 56 board size as the Pi with its holes 3.5 mm
// from the corner, so it sits directly under the Pi. Pogo pins up, 2S 18650 down.
UPS_X = pick(PI_HOLES_X[0] - 3.5, PI_HOLES_X[0] - 26.5, 0);
UPS_Y = pick(PI_HOLES_Y[0] - 3.5, PI_HOLES_Y[0] - 3.5, 0);   // r4: +y end overhangs the Pi
UPS_PCB_BOT = UPS_PCB_BOT_R2;
UPS_PCB_TOP = UPS_PCB_TOP_R2;
UPS_COMP_TOP = UPS_PCB_TOP + UPS_COMP;

// r2: one row of 4 cells across the width, axes along y, under the UPS board.
// r4: the HAT (B) holds 2 cells side by side, axes along the board's 85 mm axis,
// 19.3 mm apart across the 56 mm axis (measured on Waveshare's 3D drawing).
CELL_PITCH_R4 = 19.3;
UPS_CX = UPS_X + UPS_W/2;
UPS_CY = UPS_Y + UPS_H/2;
CELL_AXIS = R4 ? "y" : "y";                       // cell long axis (both run along y)
CELL_POS = R4
    ? [[UPS_CX + CELL_PITCH_R4/2, UPS_CY], [UPS_CX - CELL_PITCH_R4/2, UPS_CY]]  // 2 cells, axes along y
    : [for (i=[0:CELL_COUNT-1]) [(W - (CELL_COUNT*CELL_D + (CELL_COUNT-1)*CELL_GAP))/2 - 5
                                 + CELL_D/2 + i*(CELL_D+CELL_GAP), 18 + CELL_L/2]];
CELL_XS = [for (p=CELL_POS) p[0]];
CELL_YS = [for (p=CELL_POS) p[1]];
CELL_X0 = R4 ? min(CELL_XS) - CELL_D/2 : (W - (CELL_COUNT*CELL_D + (CELL_COUNT-1)*CELL_GAP))/2 - 5;
CELL_Y0 = min(CELL_YS) - CELL_D/2;                // r2 tray reference (r4 has no printed tray)
CELL_Y1 = max(CELL_YS) + CELL_D/2;
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
// r2/r3: 137 x 72 PCB pocket (Phistone 134 x 74 body or a wired PCB), wired or 2.4 GHz.
// r4: Rii K06 with touchpad, 151 x 59 x 11 (K06 manual, ver 1.2: "Productsize: 151*59*11mm",
// 98 g). The 155 x 89 x 16.5 figure in earlier notes is the Rii i4, a different keyboard.
// It is a complete body, not a PCB, so the pocket is 151 x 59 and the face window opens it.
KB_BODY = pick([151, 59, 11], [137, 72, 12.7], [137, 72, 12.7]);
// r4 window: the K06's key caps are flush to the shell edge on the sides and the bottom
// (~0.6-0.7 mm measured), so any rim there would stop those keys from being pressed. The
// window therefore follows the body outline on those three edges (x 10.5 / 161.5, y 192) and
// keeps a 2.5 mm lip on the top edge only, where the shell has a 3.6 mm bezel above the Esc
// row. The body drops in from inside the face part, is held laterally by the pocket walls,
// backed by the support frame and trapped from the front by that top lip. Keeping the window
// edges on the pocket outline (not inside it) leaves the whole plate ledge supported by the
// wall instead of cantilevered over the pocket.
KB_WIN  = pick([10.5, 135.5, 161.5, 192], [10, 123, 140, 190], [10, 97, 140, 164]);
KB_PCB  = pick([151, 59], [137, 72], [137, 72]);   // pocket outline
KB_PCB_X = (W-KB_PCB[0])/2;
KB_PCB_Y = pick(133, 120.5, 94.5);
// r4: the keys must sit just under the face plate; the 11 mm body then ends at 39.97, above
// the 38.55 split plane, so the whole body stays in the face part and the support frame
// inside the pocket backs it up (it no longer reaches past the split).
KB_PCB_FRONT = pick(T - PLATE, T - 5, T - 5);
KB_PCB_BACK  = KB_PCB_FRONT - (R4 ? KB_BODY[2] : 1.2);   // r2/r1: 1.2 mm PCB; r4: 11 mm body
KB_H = KB_BODY[2];                           // body thickness (r4: 11)

// ---------------- r2 status OLED (FireBeetle 2 ESP32-UE + 1.3" I2C OLED) ----------------
// The OLED is a separate 4-pin I2C module (1.3" 128x64, ~35 x 34 mm PCB,
// active area ~23.7 x 13.2 mm) mounted behind the face; the FireBeetle board
// (25.4 x 60 mm) sits in the bottom shell and connects with a short 4-wire cable.
OLED_W = 35; OLED_H = 34; OLED_T = 1.6;     // 1.3" OLED module PCB
OLED_CX = W/2;
// r4: display ends at DISP_Y+DISP_H (97.46); the K06 pocket starts at KB_PCB_Y (133), so the
// only free band is ~34.3 mm - the OLED module is 34 mm, i.e. it just fits, centred.
OLED_CY = pick((DISP_Y+DISP_H + KB_PCB_Y)/2, 104.4, 104.4);
OLED_X0 = OLED_CX - OLED_W/2;
OLED_Y0 = OLED_CY - OLED_H/2;
OLED_X1 = OLED_X0 + OLED_W;
OLED_Y1 = OLED_Y0 + OLED_H;
OLED_Z0 = T - PLATE - 2.2;                  // just behind the face plate
OLED_Z1 = OLED_Z0 + OLED_T;
OLED_WIN = [OLED_CX-13, OLED_CY-7.5, OLED_CX+13, OLED_CY+7.5];  // 26 x 15 window

FB_W = 25.4; FB_H = 60; FB_T = 1.6;         // DFRobot FireBeetle 2 ESP32-UE (DFR1140)
FB_X = pick(34, 30, 30);
// r4: floor under the keyboard, left of the RTC/MPPT (2 cells leave this end free).
FB_Y = pick(150, 127.5, 127.5);
FB_Z = FLOOR;

// push button in the top wall (cycles the OLED screens; TinyTronics PBS-33B, 12 mm)
OLED_BTN_X = pick(35, 35, 35);
OLED_BTN_D = 12.2;                          // 12 mm PBS-33B panel button
OLED_BTN_Z = 14;

// ---------------- r2 vented sensor pocket (left wall) ----------------
// BME688 breakout 19 x 19 x 5; SEN66 option is 55.5 x 25.6 x 21.5.
// r4 keeps it in the left wall beside the free keyboard end (the 2-cell build leaves room).
SENSOR_Y0 = pick(SEN66 ? 176 : 196, SEN66 ? 112 : 130, 130);
SENSOR_Y1 = pick(SEN66 ? 226 : 224, SEN66 ? 168 : 158, 158);
SENSOR_X1 = SEN66 ? 30 : 22;
SENSOR_Z0 = FLOOR;
SENSOR_Z1 = SEN66 ? 24 : 24;
SENSOR_CY = (SENSOR_Y0 + SENSOR_Y1)/2;
SENSOR_CZ = (SENSOR_Z0 + SENSOR_Z1)/2;
SENSOR_MEM_D = 12;                          // membrane vent

// ---------------- charge input, MPPT and RTC ----------------
// r2/r3: one sealed USB-C port, shared by solar and the hand-crank generator through an
// internal MPPT/charge module which feeds the UPS HAT (E) USB-C input.
// r4: the HAT (B) has no USB-C input - it charges from an 8.4 V / 2 A DC barrel jack. The
// sealed case port becomes a DC socket (5.5 x 2.1 mm), fed by the same internal
// MPPT/solar module (which must now output 8.4 V, not 5 V) or a 2S charger.
CHG_X = 108;
CHG_W = pick(9.5, 9.2, 9.2);                // barrel jack barrel diameter (5.5 mm) + tolerance
CHG_H = pick(9.5, 3.5, 3.5);
CHG_Z = 14;
CHG_REC_W = pick(14, 16, 16); CHG_REC_H = pick(14, 8, 8);   // rubber plug seat

MPPT_W = 26; MPPT_H = 20;                   // printed tray (module is 22 x 16)
MPPT_MOD_W = 22; MPPT_MOD_H = 16;
// r4: under the keyboard, right of the sensor chamber (x 0..22) and clear of the KBS posts.
MPPT_X = pick(70, 100, 100); MPPT_Y = pick(190, 100, 100); MPPT_Z = 6;

RTC_W = 38; RTC_H = 22; RTC_T = 14;         // DS3231 module
RTC_X = pick(70, 100, 100); RTC_Y = pick(150, 145, 145); RTC_Z0 = FLOOR;

// r4: the DS3231, MPPT module and FireBeetle sit on the free floor under the keyboard
// (2 cells instead of 4 leave the whole keyboard end free); the support frame stands on
// four columns between them.

// ---------------- keyboard support ----------------
// r2/r3: 4 columns onto the r2 cell tray, frame just under the PCB.
// r4: the K06 sits entirely in the face part, so the frame is a backstop below the body, from
// KBS_Z0 up to 0.2 mm behind it. The footprint stays the r4 one the bottom shell was printed
// with (the four columns and the frame rectangle are unchanged), so only the frame grows in
// height; the part of it beyond the 59 mm pocket is the free cavity under the logo band.
KBS_Z0 = pick(21.5, 25.2, FLOOR + BAT_T + 0.5);   // underside (r4: just above the cells)
KBS = pick([26, 131, 146, 224], [12, 123, 138, 192], [12, 97, 138, 166]);
KBS_WALL = 3;
KBS_DIV  = pick(88, 68.5, 68.5);                  // divider x
KBS_POSTS = pick([[32, 136], [140, 136], [32, 220], [140, 220]],
                 [[40, 123], [110, 123], [40, 192], [110, 192]],
                 [[40, 123], [110, 123], [40, 192], [110, 192]]);

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

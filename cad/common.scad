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

R5    = is_undef(R5)    ? false : R5;      // r5: internal cassette that drops into a host hard case
R2    = is_undef(R2)    ? true  : R2;      // r2/r3 mechanics; false = r1
R4    = is_undef(R4)    ? R2    : R4;      // r4 retarget; automatically off in r1 mode
SEN66 = is_undef(SEN66) ? false : SEN66;   // r2/r3 only: larger SEN66 pocket instead of the BME688

// r5 keeps the r4 electronics (TD2, UPS HAT (B), K06) and removes the air-quality sensor; it
// only replaces the printed exterior with a cassette + host hard case. See docs/R5.md.
assert(!R5 || (R4 && R2), "r5 needs the r4 mechanics: drop -D R4=false / -D R2=false");

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

// r5 parts are their own envelope (R5_W x R5_L), so they flip y about R5_L, not L.
module r5_at(x, y, z=0) translate([x, R5_L-y, z]) children();
// box given by its drawing-coord span (min-x, min-y, max-x, max-y) - a cube grows towards +y,
// which is drawing -y, so the real min-y corner is R5_L - y1.
module r5_box(x0, y0, x1, y1, z, h) translate([x0, R5_L - y1, z]) cube([x1 - x0, y1 - y0, h]);
// ---------------- r5: cassette + host hard case ----------------
// NOTE: r5 keeps the r4 hardware parameters above (Pi, HAT (B), TD2, K06, cells); it only
// replaces the printed exterior with a cassette, so most of the r4 geometry is reused.
// r5 prints no visible exterior: a floor tray (r5_tray), a deck that carries the keyboard and
// the status OLED (r5_deck), and a plate that mounts the display on the inside of the host lid
// (r5_lid_plate). Bumpers, ribs and chamfers belong to the host case, so only the host's
// INTERIOR sizes the printed parts. Lid/bottom depth are Peli's published figures
// (https://www.pelican.com/us/en/product/cases/<model>), not estimates:
//   1200   9.31 x 7.13 x 4.12 in, lid 1.19, bottom 2.93   (236.5 x 181.1 / 30.2 / 74.4 mm)
//   1400  11.81 x 8.87 x 5.18 in, lid 1.18, bottom 4.00   (300.0 x 225.3 / 30.0 / 101.6 mm)
// The R40/R60 Ruck cases cannot host this build: their whole interior is ~48 / 75 mm, so the
// lid is shallower than the 14.92 mm display plus plate and the base is shallower than the cell
// stack. See docs/R5.md. r5 has no air-quality sensor.
HOST = is_undef(HOST) ? "1200" : HOST;
function host_dims(m) =
    m == "1200" ? [236.5, 181.1, 30.2, 74.4] :
    m == "1400" ? [300.0, 225.3, 30.0, 101.6] :
    assert(false, str("unknown r5 host \"", m, "\": use 1200 or 1400 (see docs/R5.md)")) [0, 0, 0, 0];
HOST_I = host_dims(HOST);
HOST_L = HOST_I[0]; HOST_W = HOST_I[1]; HOST_LID = HOST_I[2]; HOST_BOT = HOST_I[3];
// The published interior is the cavity at the FLOOR; the moulded walls flare towards the seal.
// Measured across the open mouth of the received Peli 1200 (tape, 2026-11): 250 x 193 mm against
// the published 236.5 x 181.1. The mouth is 26 mm above the deck's underside (R5_PAD 8 + R5_DECK_Z
// 40.4), so a plate cut to 250 x 193 would jam on the flare long before it reached the tray rim -
// and even at the mouth it would be flush with the wall. The cavity is interpolated linearly
// between the two known sections (published floor, measured mouth); a host without a measurement
// falls back to the published interior. See R5_DECK_* below for what the deck is cut to.
HOST_TOP = is_undef(HOST_TOP) ? (HOST == "1200" ? [250, 193] : [HOST_L, HOST_W]) : HOST_TOP;
function host_cavity(z) = [HOST_L + (HOST_TOP[0] - HOST_L) * z / HOST_BOT,
                           HOST_W + (HOST_TOP[1] - HOST_W) * z / HOST_BOT];   // z from the floor
HOST_CLR = 1.5;                    // cassette -> host wall, per side
R5_W = HOST_L - 2*HOST_CLR;        // cassette width  (x, across the display)
R5_L = HOST_W - 2*HOST_CLR;        // cassette length (y, y = 0 at the hinge)
R5_R = 14;                         // printed corner radius
R5_WALL = 2.6;
R5_FLOOR = 2.4;
R5_DECK_T = 4.5;                   // was 3: +1.5 mm of plate, and it goes on the TOP face, so
                                   // the underside stays at R5_DECK_Z and the keyboard well, the
                                   // Pi keep-out and every pocket keep their own depths. A 3 mm
                                   // plate over a 151 x 59 mm opening is what felt wobbly.
R5_PAD = 8;                        // closed-cell foam under the tray

// ---- r5 board layout: both assemblies BOLT TO THE FLOOR, side by side ----
// r5 no longer stacks the Pi on the HAT (B) with pogo pins: power now runs from the HAT to the
// Pi on soldered wires, so the two boards are independent and each is screwed down to the tray
// floor on four posts (see board_post() in r5_tray.scad). Position and orientation come from
// reference/first_fit.jpg, measured through a homography fitted to the tray's own outline:
//   - UPS HAT (B), top middle: pcb up, its 2x 18650 cells and holders below it in the cradles,
//   - Pi 5, top right, with the Seeed PCIe-to-M.2 BASE underneath and the SSD on that.
// Both boards are PORTRAIT: 85 mm along y, 56 mm along x.
R5_UPS_W = 56;  R5_UPS_L = 85;      // UPS HAT (B) pcb (Waveshare: 56 x 85)
R5_UPS_X = 76;  R5_UPS_Y = 16;      // left / hinge-side edge  (photo: 76 / 12, nudged clear)
R5_PI_W  = 56;  R5_PI_L  = 85;      // Pi 5 pcb (85 x 56)
R5_PI_X  = 152; R5_PI_Y  = 16;      // left / hinge-side edge  (photo: 152 / 14, nudged clear)

// Pi-standard mounting holes: 49 mm across the 56 mm axis, 58 mm along the 85 mm axis, 3.5 mm in
// from three edges and 23.5 from the fourth (so both holes sit near the hinge end). The HAT (B)
// carries the same pattern - Waveshare's 3D drawing has its four 3 mm holes at exactly 58 x 49
// with the same insets - which is what lets one post design serve both boards.
R5_HOLE_LONG  = 58; R5_HOLE_SHORT = 49; R5_HOLE_IN = 3.5;
function board_holes(x0, y0) = [for (dx=[R5_HOLE_IN, R5_HOLE_IN + R5_HOLE_SHORT])
                                for (dy=[R5_HOLE_IN, R5_HOLE_IN + R5_HOLE_LONG]) [x0+dx, y0+dy]];
R5_UPS_HOLES = board_holes(R5_UPS_X, R5_UPS_Y);
R5_PI_HOLES  = board_holes(R5_PI_X,  R5_PI_Y);

// ---- heights, z = 0 at the cassette floor; the floor's top face is R5_FLOOR ----
// UPS: the cells lie in the cradles and Waveshare's holder carries the pcb 23.35 mm above its own
// bottom (their drawing). R5_UPS_LIFT raises the pcb - and the posts with it - if your holder
// measures more.
R5_CELL_Z0 = R5_FLOOR + 1;                              // cell bottom
CELL_ZC_R5 = R5_CELL_Z0 + CELL_D/2;                     // cell axis height
R5_UPS_LIFT = 0;
R5_HAT_BOT = R5_CELL_Z0 + HAT_B_BELOW_R4 + R5_UPS_LIFT; // HAT (B) pcb underside = UPS post top
R5_HAT_TOP = R5_HAT_BOT + UPS_T;

// The measured envelopes are ground truth (tape measure, cells / SSD fitted): 35 mm for the
// HAT (B) with its two 18650s, 30 mm for the Pi 5 + M.2 BASE + SSD. Both are heights above the
// floor's top face. The deck sits on the tray rim, so the rim clears the taller of the two.
R5_UPS_H_MAX = 35;                                      // HAT (B) + 2x 18650
R5_PI_H_MAX  = 30;                                      // Pi 5 + M.2 BASE + SSD
R5_STACK_AIR = 3;                                       // air over the taller assembly
R5_H_BOT   = R5_FLOOR + max(R5_UPS_H_MAX, R5_PI_H_MAX) + R5_STACK_AIR;   // 40.4, was 46.0

// Pi sandwich, built UP from the floor so the derived height can be checked against the measured
// envelope instead of being assumed. Order: floor -> air -> M.2 BASE pcb -> SSD (in the gap) ->
// Pi pcb -> 40-pin header.
//   R5_M2_CLR  air under the BASE for its solder side and the FPC connector,
//   R5_M2_GAP  the BASE-to-Pi standoff; the SSD lies in this gap, so it must clear 2.38 mm of
//              drive plus its connector. 11 mm is the Seeed stud pack's; shorten it and the
//              whole sandwich drops, which is the easiest way to buy vertical room.
// One M2.5 per hole runs from the top of the Pi pcb, through the Pi, the standoff and the BASE,
// and threads into the printed post (R5_M2_BOT is that post's top face). Kit the sandwich with
// the standoffs first, then screw it down through the BASE into the posts.
// The SSD sits on the BASE's UNDERSIDE (Seeed's board is back-mounted), so it hangs below the
// BASE and the four posts stand at the corners, clear of its 22 x 42 footprint. R5_M2_CLR is the
// air under the BASE that the drive and its connector need: 2.38 of drive + 1 of connector + 1.6
// of margin.
R5_M2_CLR = 5;                                          // air under the BASE (SSD + connector)
R5_M2_T   = 1.6;                                        // M.2 BASE pcb
R5_M2_GAP = 11;                                         // BASE -> Pi standoff (Seeed stud pack)
R5_PI_HDR = 8.5;                                        // 2x20 header above the Pi pcb
R5_M2_BOT = R5_FLOOR + R5_M2_CLR;                       // 7.4 = Pi post top face (the BASE seat)
R5_PI_BOT = R5_M2_BOT + R5_M2_T + R5_M2_GAP;            // 20.0 = Pi pcb underside
R5_PI_TOP = R5_PI_BOT + 1.6;
R5_PI_TOP_HDR = R5_PI_TOP + R5_PI_HDR;                  // 30.1, the tallest Pi-side point
// The measured envelope is a tape-measure figure, so allow a millimetre of slack on it. Anything
// more and the deck would sit on the header instead of on the tray rim.
assert(R5_PI_TOP_HDR - R5_FLOOR <= R5_PI_H_MAX + 1,
       str("Pi sandwich is ", R5_PI_TOP_HDR - R5_FLOOR, " mm above the floor, the measured ",
           "envelope is ", R5_PI_H_MAX, ": shorten R5_M2_GAP (standoffs) or R5_M2_CLR"));
R5_DECK_Z  = R5_H_BOT;
R5_DECK_TOP = R5_DECK_Z + R5_DECK_T;
// The plate is bigger than the cassette. The tray is sized to the published floor section
// (R5_W x R5_L) and fills it with 1.5 mm a side; the host's cavity widens with height, so the deck
// - which only has to pass down to the tray rim - can also widen, and that is what closes the
// visible gap round the top. It is cut to the cavity at the height it lands at (its underside, the
// narrowest section it has to pass), less a printing clearance. Everything cut into the plate
// (seven M3s, keyboard, OLED, fan, button) keeps its absolute position, so the screw pattern and
// every component relationship are unchanged; only the rim moves out.
R5_DECK_CLR = 1;                                        // plate -> host wall, per side
R5_DECK_H_Z = R5_PAD + R5_DECK_Z;                       // 48.4 above the host's floor
R5_DECK_W   = host_cavity(R5_DECK_H_Z)[0] - 2*R5_DECK_CLR;   // 243.3 for the measured 1200
R5_DECK_L   = host_cavity(R5_DECK_H_Z)[1] - 2*R5_DECK_CLR;   // 186.8
R5_DECK_X0  = (R5_W - R5_DECK_W)/2;                     // negative: overhangs the tray wall
R5_DECK_Y0  = (R5_L - R5_DECK_L)/2;
// The corner follows the cassette's own R5_R, grown by the plate's own overhang: that is what a
// uniform offset of the host's floor section gives, and the taper model below says the host's
// corner radius grows with its walls.  Anything rounder would cut inside the tray's rim at the
// corners; anything sharper would not clear the host.  Every deck screw stays in the straight run
// (the hinge pair is 26 mm from the tray wall, i.e. 31 from the plate's edge).
R5_DECK_R   = R5_R + min((R5_DECK_W - R5_W)/2, (R5_DECK_L - R5_L)/2);   // 18.37
assert(R5_DECK_W > R5_W && R5_DECK_L > R5_L,
       str("the deck (", R5_DECK_W, " x ", R5_DECK_L, ") does not reach past the cassette (",
           R5_W, " x ", R5_L, "): check HOST_TOP / host_cavity()"));
// The deck has no opening over the 40-pin header: it is a plain plate there. That is only safe
// because the header is well below it - nothing clamps the Pi any more, so the deck is a lid and
// not a clamp. This assert is what keeps the slot from ever being needed again; if the Pi
// sandwich grows, it fails the build instead of putting the plate on the header.
R5_HDR_CLEAR = 3;                                       // air the deck needs over the header
assert(R5_DECK_Z - R5_PI_TOP_HDR >= R5_HDR_CLEAR,
       str("deck underside ", R5_DECK_Z, " is only ", R5_DECK_Z - R5_PI_TOP_HDR,
           " mm above the 40-pin header (", R5_PI_TOP_HDR, "), needs ", R5_HDR_CLEAR,
           ": raise R5_STACK_AIR or shorten the Pi sandwich"));

// Cells: two 18650s side by side under the HAT's pcb, on Waveshare's own holders. Their axes run
// along y and are CELL_PITCH_R4 apart across the board's 56 mm width, centred on it. The holder
// stops 23.35 mm below the pcb, which is what R5_HAT_BOT encodes, so the cells hang in the
// cradles with their cans pointing down.
// The 8.4 V jack, the USB-A socket and the ON/OFF switch overhang the board's HINGE end by about
// 12 mm (Waveshare's drawing: parts past the pcb edge, 12.5 long; the photo agrees). That is why
// both boards sit at y = 16 rather than the photo's 12-14: it leaves 3.4 mm to the wall for the
// overhang and still ends the boards at y 101, clear of the keyboard well's 102.5.
R5_CELL_CY = R5_UPS_Y + R5_UPS_L/2;
R5_CELL_POS = [[R5_UPS_X + R5_UPS_W/2 + CELL_PITCH_R4/2, R5_CELL_CY],
               [R5_UPS_X + R5_UPS_W/2 - CELL_PITCH_R4/2, R5_CELL_CY]];
R5_UPS_EDGE = R5_UPS_Y - 12;                            // 4, the jack's far face

// keyboard: at the latch end, i.e. outside the display's shadow, so its height is free
// The K06 outline is not a plain rectangle: its corners are rounded. R5_KB_CORNER is measured off
// the outline drawing in the K06 manual (the same drawing that gives 151 x 59 - 746 px / 151 mm =
// 290 px / 59 mm, and a circle fitted to the corner arc over 26 px gives r 6.4 mm, rms 0.2 px).
R5_KB_CORNER = 6.4;
R5_KB_CLR = 0.3;                                        // printed clearance per side
R5_KB_POCKET = [KB_BODY[0] + 2*R5_KB_CLR,               // 151.6
                KB_BODY[1] + 2*R5_KB_CLR];              // 59.6
R5_KB_X0 = (R5_W - R5_KB_POCKET[0])/2;
R5_KB_Y0 = R5_L - 16 - R5_KB_POCKET[1];
R5_KB_WALL = 1.8;
// The keyboard is SUNK into the deck so its keys finish level with the deck's top face. The body
// is KB_BODY[2] = 11 mm and the plate is R5_DECK_T = 4.5, so the recess has to hang below the
// plate: R5_KB_SINK is how far the body's underside sits below R5_DECK_TOP (11 mm - the whole
// body), i.e. 6.5 mm below the plate's underside, into the (empty) tray cavity.
R5_KB_SINK = KB_BODY[2];                               // 11 mm below the deck's TOP face
R5_KB_WELL_BOT = R5_DECK_TOP - R5_KB_SINK;             // 33.9, the keyboard's resting plane
// The body rests on R5_KB_WELL_BOT. Nothing may occupy the space ABOVE that plane inside the
// pocket - the whole 11 mm column belongs to the keyboard - so the seat hangs below it: a ledge
// along each of the two long walls, R5_KB_SEAT wide, its underside chamfered 45 deg back to the
// wall so it prints. The K06's shell carries its rim on exactly those two edges, which is also
// where r4's support frame touched it.
// A ledge rather than the two full-height "carry ribs" this replaced: those stood inside the
// keyboard's own volume, and the plate cut sheared their tops off at the plate's underside - the
// body then landed 5.5 mm above its intended plane. A band spanning the pocket instead would be a
// 59.6 mm unsupported bridge at the top of the print.
R5_KB_SEAT = 2.5;                                      // ledge width under the body's edge
R5_KB_SEAT_X0 = R5_KB_X0 + R5_KB_CORNER;               // straight run only, clear of the corners
R5_KB_SEAT_X1 = R5_KB_X0 + R5_KB_POCKET[0] - R5_KB_CORNER;
R5_KB_TOP = R5_DECK_TOP;                               // keys finish level with the plate

// status OLED module on the deck (visible with the lid open). Measured module:
//   pcb 35.5 x 33.7 x 1.2, glass 34.5 x 23 x 1.45, lit 128 x 64 area 29.42 x 14.7 (2:1)
// The plate is 4.5 mm, i.e. thicker than the module, so the module lives INSIDE the deck: a
// pocket of the pcb's size in the underside (dropped in from below, flush with the underside)
// and a window in the top face over the glass. Sizing one opening to the pcb, as it was before,
// left the board's edge in view all round the panel.
// Both cuts carry 1 mm of extra fitting tolerance a side (they were 0.4 and 0.15): 0.15 mm round
// the glass is less than the glass slab's own tolerance, and the module has to drop in from
// below with the plate printed to a few tenths.
// What you see through the window is now the glass, its black border and - across the 0.65 mm
// where the window is wider than the pcb - the board's own black edge. The plate ring between the
// two cuts is still the bezel and the seat.
R5_OLED_BOARD  = [35.5, 33.7, 1.2];                     // pcb
R5_OLED_GLASS  = [34.5, 23.0, 1.45];                    // glass slab on the pcb
R5_OLED_ACTIVE = [29.42, 14.7];                        // lit area inside the glass border
// The glass is centred on the pcb in both axes: 34.5 against the pcb's 35.5 leaves 0.5 mm a side,
// and its 23 mm against the pcb's 33.7 leaves (33.7 - 23)/2 = 5.35 mm to each edge, which is the
// ~5 mm the window's border has to be. Relative to the BOARD, not the pocket: the pocket carries a
// clearance, so centring on it would put 1.4 mm more plate at one end than the other. (It sat at
// 1.0 mm from the hinge-side edge, i.e. 9.7 mm at the far edge, which put the window 4.75 mm too
// far towards the hinge. Measure yours and adjust.)
R5_OLED_PCB_CLR = 1.4;                                 // pocket clearance, per side (was 0.4)
R5_OLED_WIN_CLR = 1.15;                                // window clearance around the glass (was 0.15)
R5_OLED_MIN_SEAT = 0.3;                                // least plate the pcb rests on
R5_OLED_PCB = [R5_OLED_BOARD[0] + 2*R5_OLED_PCB_CLR,   // 38.3
               R5_OLED_BOARD[1] + 2*R5_OLED_PCB_CLR];  // 36.5
R5_OLED_GLASS_Y = (R5_OLED_BOARD[1] - R5_OLED_GLASS[1])/2; // 5.35, centred on the pcb
R5_OLED_WIN = [R5_OLED_GLASS[0] + 2*R5_OLED_WIN_CLR,   // 36.8
               R5_OLED_GLASS[1] + 2*R5_OLED_WIN_CLR];  // 25.3
// centred between the keyboard pocket and the hinge-side edge: the keyboard owns y > R5_KB_Y0,
// so the free band is the 100 mm strip between the Pi keep-out and the pocket
R5_OLED_X0 = (R5_W - R5_OLED_PCB[0])/2;
R5_OLED_Y0 = (R5_KB_Y0 - R5_OLED_PCB[1])/2 + 4;        // centred in the free band, nudged to the pocket
R5_OLED_WIN_X0 = R5_OLED_X0 + (R5_OLED_PCB[0] - R5_OLED_WIN[0])/2;
R5_OLED_WIN_Y0 = R5_OLED_Y0 + R5_OLED_PCB_CLR + R5_OLED_GLASS_Y - R5_OLED_WIN_CLR;
// the pcb's top face is the seat: the pocket stops there and the window starts there
R5_OLED_SEAT = R5_DECK_Z + R5_OLED_BOARD[2];
// How much plate the pcb actually lands on, per edge: the ring of plate at the seat plane runs
// from the window's edge to the pocket's wall, but the board's own edge stops a clearance short
// of that wall, so the clearance is dead width and subtracts. The 1 mm window tolerance spends the
// side seat outright: the window is 36.8 wide against a 35.5 pcb, so the sides carry nothing and
// the ends - (33.7 - 25.3)/2 = 4.2 mm each, the board's own ~5 mm glass border - are what hold the
// module up. It cannot fall through: the window is 25.3 across the board's 33.7 mm length.
R5_OLED_SEAT_X  = (R5_OLED_PCB[0] - R5_OLED_WIN[0])/2 - R5_OLED_PCB_CLR;   // -0.65: no side seat
R5_OLED_SEAT_Y0 = R5_OLED_WIN_Y0 - R5_OLED_Y0 - R5_OLED_PCB_CLR;
R5_OLED_SEAT_Y1 = R5_OLED_Y0 + R5_OLED_PCB[1] - (R5_OLED_WIN_Y0 + R5_OLED_WIN[1])
                  - R5_OLED_PCB_CLR;
assert(R5_OLED_SEAT_Y0 >= R5_OLED_MIN_SEAT && R5_OLED_SEAT_Y1 >= R5_OLED_MIN_SEAT,
       str("the OLED would rest on ", R5_OLED_SEAT_Y0, " / ", R5_OLED_SEAT_Y1,
           " mm of plate at the ends (sides ", R5_OLED_SEAT_X, "), the lit area needs ",
           "the ends to hold the module: cut R5_OLED_WIN_CLR"));
assert(R5_OLED_WIN[0] < R5_OLED_BOARD[0] || R5_OLED_WIN[1] < R5_OLED_BOARD[1],
       "the OLED window is larger than the pcb in both axes: the module would fall through");
assert(R5_OLED_WIN[0] >= R5_OLED_ACTIVE[0] && R5_OLED_WIN[1] >= R5_OLED_ACTIVE[1],
       "the OLED window is smaller than the lit area");
assert(R5_DECK_T - R5_OLED_BOARD[2] - R5_OLED_GLASS[2] >= 0.5,
       str("the deck (", R5_DECK_T, " mm) cannot sink the OLED: pcb ", R5_OLED_BOARD[2],
           " + glass ", R5_OLED_GLASS[2], " leaves less than 0.5 mm of plate over the glass"));

// FireBeetle 2, DS3231 and charger module on the free floor. With both boards on the floor and
// spanning y 12..99 there is no free floor between them any more, so the three modules go in the
// 62 mm strip at the hinge end, left of the boards: x 8..70, y 100..175, which is clear of the
// cell cradles (y 22..87) and of the UPS jack at x 132..144.
R5_FB_X = 8;  R5_FB_Y = 104;                            // 25.4 x 60 FireBeetle, upright
R5_FB_HOLE_Y0 = 44;                                     // access hole start along the module
R5_FB_HOLE_H  = 10;                                     // ... and its length (16 x 10 mm)
R5_RTC_X = 40; R5_RTC_Y = 104;                          // DS3231, turned 90 deg (22 along x)
R5_MPPT_X = 40; R5_MPPT_Y = 150;                        // 26 x 20 tray, below the RTC

// ---- r5 display: Touch Display 2, 7" ----
// r5 hangs the 7" TD2 in the host lid, not the 5" of r4. Raspberry Pi's 7" brief (RP-010429):
//   189.32 x 120.24 mm module, corners R8, glass = module outline
//   active area 154.6 (along 189.32) x 86.9, so a 17.4 / 16.7 mm glass border all round
//   standoffs 168.55 x 99.71, insets 10.385 / 10.265 (drawing: 10.265 +/-0.5 and 18.21+6.45)
//   8.5 mm standoffs + 6.42 mm body = 14.92 mm deep, exactly the 5" stack
//   backlight 2.4 W (the 5" is 1.4 W), same 720 x 1280, same J1 + FFC cabling
// The 189.32 mm axis MUST run along x: 189.32 alone is more than the 178.1 mm cassette length,
// so a portrait mount cannot fit any accepted host. The panel therefore sits landscape, as r4's
// does, with the 120.24 mm axis across the cassette.
R5_PANEL        = [189.32, 120.24, 8];                  // w (along x), h (along y), corner R
R5_PANEL_ACTIVE = [154.6, 86.9];                        // lit area, same axes
R5_PANEL_HOLES  = [168.55, 99.71];                      // standoff pattern, same axes
// The display's back (6.42 body + its own 8.5 standoffs) faces the lid, the glass faces the base.
R5_LID_T = 2;
R5_DISP_DEEP = R5_LID_T + DISP_POST + DISP_T_R2;        // 16.92 mm from the lid wall to the glass
// Centred in both axes. The lid has no hardware left to dodge: the 7" panel eats the latch band
// the 16 mm power button needed, so the button moved to the deck (see R5_BTN_* below).
R5_DISP_X0 = (R5_W - R5_PANEL[0])/2;                    // 22.09
R5_DISP_Y0 = (R5_L - R5_PANEL[1])/2;                    // 28.93
R5_LID_PLATE = [R5_PANEL[0] + 12, R5_PANEL[1] + 12];    // 201.32 x 132.24, 6 mm border
R5_DISP_HOLE_IX = (R5_PANEL[0] - R5_PANEL_HOLES[0])/2;  // 10.385
R5_DISP_HOLE_IY = (R5_PANEL[1] - R5_PANEL_HOLES[1])/2;  // 10.265
R5_DISP_HOLES = [for (dx=[R5_DISP_HOLE_IX, R5_DISP_HOLE_IX + R5_PANEL_HOLES[0]])
                 for (dy=[R5_DISP_HOLE_IY, R5_DISP_HOLE_IY + R5_PANEL_HOLES[1]]) [dx, dy]];
// The DSI/GPIO leads leave the panel's hinge-side long edge and have to turn down into the base,
// so the cover and the plate are notched there, through plate and bezel wall together. The notch
// is R5_CABLE_W wide, R5_CABLE_W/2 of it each side of R5_CABLE_X (measured from the panel's own
// left edge), so moving the connector is one number. Verify against your panel before printing:
// the 7" drawing puts the FFC at one end of that edge, and a notch at the wrong end leaves the
// ribbon with no way out.
R5_CABLE_W  = 46;                                        // covers the DSI + GPIO sockets
R5_CABLE_X  = R5_CABLE_W/2;                              // notch centre, from the panel's left edge
R5_CABLE_X0 = R5_CABLE_X - R5_CABLE_W/2;                 // its left edge, in panel coords

// deck screws: on the straight wall runs only (a boss in a 14 mm corner would break the
// outer radius). Each is a Ø9 column whose centre sits 2.5 mm inside the inner face, so it
// overlaps the wall by 2 mm and protrudes 7 mm into the cavity.
//
// The deck is held by M3, not M2.5. It comes off for every service - keyboard, OLED, fan,
// FireBeetle - and a heat-set insert is what survives that; a 2.2 mm self-tapping pilot in PETG
// does not. That in turn sets the boss: an M3 insert is ~4.6 mm across, so the boss goes from
// Ø7 (BOSS_D, still right for the board posts and the case) to Ø9, which leaves 2.4 mm of wall
// round the insert. The four board posts keep their Ø8 and M2.5 pilots - those screws go in once.
M3_CLR   = 3.4;                                        // clearance hole through the deck
M3_HEAD  = 6.2;                                        // countersink at the top face: Ø6.0 flat head + 0.2
M3_CSK_T = (M3_HEAD - M3_CLR)/2;                       // 1.4, i.e. 90 deg
M3_INS_D = 4.2;                                        // heat-set insert hole: 4.6 OD - 0.4 melt
M3_INS_H = 6.0;                                        // insert depth: 5.7 mm insert + margin
R5_BOSS_D = 9;                                         // deck boss (2.4 mm wall round the insert)
// The inset stays at 2.5, not R5_BOSS_D/2 - 1: at 3.5 the left-wall bosses would reach x 10.6
// and eat 0.6 mm into the FireBeetle's floor pad (module at x 10). At 2.5 the boss tops out at
// 9.6, which is the pad's inner face, so the module still has its full seat.
R5_INSET = 2.5;
// The hinge-end pair moved outboard, from x = R5_W/2 to x = 26 / R5_W-26: the centre one stood
// exactly where the HAT (B)'s USB-A and 8.4 V jack overhang the hinge end (x 84..118, y 4..16),
// and that overhang hangs below the pcb, i.e. at the boss's own height. Both new positions are in
// the solid hinge wall run, clear of the board posts and of the jack.
//
// The seventh boss is the middle of the BOTTOM (keyboard-end) wall, which carried none: that wall
// is 151.6 mm of unscrewed span between the corner bosses at x 26 / R5_W-26, and the deck's
// keyboard pocket sits right on it, so the plate there was free to lift. It is appended rather
// than inserted so R5_SCREWS[5] (the hinge-wall pair that bounds the Pi opening) keeps its index.
R5_SCREW_MID = [R5_W/2, R5_L - R5_WALL - R5_INSET];    // 116.75, 173.0
R5_SCREWS = concat([[R5_WALL + R5_INSET, 40], [R5_W - R5_WALL - R5_INSET, 40],
                    [R5_WALL + R5_INSET, R5_L - 40], [R5_W - R5_WALL - R5_INSET, R5_L - 40],
                    [26, R5_WALL + R5_INSET], [R5_W - 26, R5_WALL + R5_INSET]],
                   [R5_SCREW_MID]);
// The middle boss has to clear the keyboard well, which hangs below the deck from y 100.7 to
// 163.9 (pocket + its 1.8 mm wall ring); 4.5 mm of boss either side of 173 leaves 6.6 mm.
assert(R5_SCREW_MID[1] - R5_BOSS_D/2 >= R5_KB_Y0 + R5_KB_POCKET[1] + R5_KB_WALL + 1,
       str("the middle deck boss reaches y ", R5_SCREW_MID[1] - R5_BOSS_D/2,
           ", into the keyboard well (which ends at ",
           R5_KB_Y0 + R5_KB_POCKET[1] + R5_KB_WALL, ")"));
assert((R5_BOSS_D - M3_INS_D)/2 >= 2,
       str("an M3 insert hole of ", M3_INS_D, " in a ", R5_BOSS_D,
           " boss leaves less than 2 mm of wall"));
assert(R5_INSET >= 1, "the deck bosses must overlap the wall by at least 1 mm");

// ---- closed-case clearance ----
// The base and the lid meet at the seal plane (z = HOST_BOT), so the lid ceiling sits HOST_LID
// above it. The plate is taped to that ceiling and the display hangs down from it, which puts
// the glass (R5_DISP_DEEP below the ceiling) well clear of the deck.
R5_GLASS = HOST_BOT + HOST_LID - R5_DISP_DEEP;          // glass height above the host floor
// 4 mm beyond the assembly: the DSI/GPIO leads have to fold between plate and lid
assert(!R5 || HOST_LID >= R5_DISP_DEEP + 4,
       str("host ", HOST, ": lid ", HOST_LID, " mm, the display assembly + lead fold needs ",
           R5_DISP_DEEP + 4));
assert(!R5 || R5_W >= R5_KB_POCKET[0] + 2*R5_KB_WALL + 6,
       str("host ", HOST, ": ", R5_W, " mm wide, the keyboard pocket needs ",
           R5_KB_POCKET[0] + 2*R5_KB_WALL + 6));
assert(!R5 || R5_PAD + R5_KB_TOP + 2 <= R5_GLASS,
       str("host ", HOST, ": ", R5_GLASS, " mm under the display, the deck + keyboard needs ",
           R5_PAD + R5_KB_TOP + 2));
assert(!R5 || R5_PAD + R5_KB_TOP <= HOST_BOT - 2,
       str("host ", HOST, ": ", HOST_BOT, " mm base, the keyboard stack needs ", R5_PAD + R5_KB_TOP));
// The keyboard's whole thickness column must be free: the seat hangs BELOW R5_KB_WELL_BOT, never
// inside it, and the body drops the full KB_BODY[2] so its keys land on the deck's top face. The
// first version of the sunk recess put two full-height ribs in that column, the plate cut sheared
// them, and the body landed 5.5 mm high - so the geometry that made it possible is checked here.
assert(R5_KB_WELL_BOT < R5_DECK_Z,
       str("the keyboard seat (", R5_KB_WELL_BOT, ") is not below the plate's underside (",
           R5_DECK_Z, "): the body cannot sink into the deck"));
assert(R5_KB_WELL_BOT - R5_KB_SEAT > R5_FLOOR,
       str("the seat ledge reaches down to ", R5_KB_WELL_BOT - R5_KB_SEAT,
           ", at or through the tray floor (", R5_FLOOR, ")"));

// The 7" panel must fit the cassette plan and the cassette must still fit the host: the glass is
// 189.32 x 120.24 against a 233.5 x 178.1 cassette, so there is 22.09 / 28.93 a side, not much -
// check it rather than trust it, since R5_W/R5_L move with HOST. 20 mm of cassette either side is
// the floor: a 7 mm bezel, the 8 mm tape border round it and the 5 mm of wall the panel's own
// standoff screws need.
assert(!R5 || R5_W - R5_PANEL[0] >= 20 && R5_L - R5_PANEL[1] >= 20,
       str("host ", HOST, ": the 7\" panel (", R5_PANEL[0], " x ", R5_PANEL[1],
           ") leaves only ", (R5_W - R5_PANEL[0])/2, " / ", (R5_L - R5_PANEL[1])/2,
           " mm a side in the ", R5_W, " x ", R5_L, " cassette, needs 10"));
// The power button is 16 mm IP67: bore plus nut, plus the plate that has to survive round it.
assert(R5_BTN_X - R5_BTN_BODY/2 > R5_KB_X0 + R5_KB_POCKET[0] + R5_KB_WALL,
       str("the power button nut (", R5_BTN_BODY, " mm) reaches x ",
           R5_BTN_X - R5_BTN_BODY/2, ", into the keyboard skirt at ",
           R5_KB_X0 + R5_KB_POCKET[0] + R5_KB_WALL));
assert(R5_BTN_X + R5_BTN_BODY/2 < R5_W - R5_WALL,
       str("the power button nut reaches x ", R5_BTN_X + R5_BTN_BODY/2,
           ", past the tray's inner wall at ", R5_W - R5_WALL));
assert(R5_BTN_Y + R5_BTN_BODY/2 < R5_L - 2.5,
       str("the power button nut reaches y ", R5_BTN_Y + R5_BTN_BODY/2,
           ", off the deck's latch edge (", R5_L, ")"));


// ---------------- r5 lid cover (r5_lid_cover.scad) ----------------
// Params live here, not in r5_lid_cover.scad, because assembly_r5.scad `use`s that file: `use`
// imports modules only, never variables, so the assembly could not see them. The assertions that
// guard these values stay in r5_lid_cover.scad, next to the geometry they protect.
COVER_T     = 4;          // plate thickness: tape face, and the print bed
COVER_FRAME = 7;          // bezel wall thickness outside the glass
COVER_GAP   = 0.5;        // clearance around the panel module, inside the bezel
COVER_R     = 8;          // cover corner radius
COVER_PROUD = 1.5;        // bezel height above the glass plane, to protect the panel edge

COVER_W = HOST_L - 2*HOST_CLR;      // the same 1.5 mm clearance the cassette uses
COVER_L = HOST_W - 2*HOST_CLR;

// The TD2's own vertical stack: plate, its 8.5 mm standoffs, 6.42 mm of panel body, then glass.
COVER_GLASS_Z = COVER_T + DISP_POST + DISP_T_R2;
COVER_RIM_H   = DISP_POST + DISP_T_R2 + COVER_PROUD;    // bezel height above the plate

// The 7" panel, centred in both axes - the operator's call, and the lid has nothing left to
// dodge now that the power button is on the deck. Margins: 15.09 mm of plate outside the bezel
// in x, 21.93 in y; 22.09 / 28.93 from the panel module itself.
PANEL_X = (COVER_W - R5_PANEL[0]) / 2;
PANEL_Y = (COVER_L - R5_PANEL[1]) / 2;

// Power button: 16 mm IP67 panel button, moved from the lid to the deck's right rail. A centred
// 7" panel leaves 28.93 mm of latch band and the button needs 16.2 + 2*9 = 34.2 mm, so the two
// cannot share a 178.1 mm lid. On the deck it is reachable with the case open, and its two leads
// reach the Pi's J2 pads (external power button) under the plate.
// Placed at the latch end of the right rail, on free floor: the boards and cells all end at
// y 101, and the rail's own deck screws are at (207.5, 5.1), (228.4, 40) and (228.4, 138.1).
// 9.5 mm of half-nut keeps it 11.4 mm inside the right edge and 18.1 mm off the latch edge,
// clear of the keyboard skirt (ends x 194.35) by 9.2 mm. R5_BTN_BODY is the nut.
R5_BTN_D       = 16.2;   // 16 mm IP67 panel button, 0.2 clearance
R5_BTN_BODY    = 19;     // nut/body diameter - what has to clear the rail and the screw heads
R5_BTN_BODY_H  = 8;      // nut + thread length below the plate (16 mm button: ~7 mm thread)
R5_BTN_X    = (R5_KB_X0 + R5_KB_POCKET[0] + R5_W)/2;    // 213.0, the rail's centre
R5_BTN_Y    = R5_L - 18;                                // 160.1, past the boards

// ---------------- r5 deck cooling (r5_deck.scad) ----------------
// The deck is the plate between the Pi stack and the keyboard. The old cooling was a bank of
// five 2.4 mm slots at the right-hand end, and they were in the wrong place twice over: their
// y span (101-108.4) crossed the keyboard pocket's hinge wall (100.7-102.5), so they cut into
// the pocket instead of venting anything, and being a slot bank they moved little air.
//
// They are replaced by round fan openings in the free top corners, away from the keyboard and
// from the deck screws:
//   top-left  centre (44, 38)     38 mm hole for a 40 mm fan
//   top-right centre (189.5, 38)  the same, with DECK_FANS=2
// The corners are clear: the nearest deck screw is 40 mm away and the keyboard starts at
// y = 102.5, so a 40 mm fan has 25 mm of plate between it and the pocket.
//
// NOTE ON AIRFLOW: a sealed host has no path through its wall, so these openings move air
// between the deck and the Pi, not out of the case. They are a path for a fan, not a cooling
// solution on their own - see docs/R5.md, "Heat".
DECK_FANS = is_undef(DECK_FANS) ? 1 : DECK_FANS;        // 2 = both corners (1 = top-left only)
DECK_FAN_D = 38;                                        // 40 mm fan opening (2 mm clear of the blades)
DECK_FAN_HOLE_SP = 32;                                  // 40 mm fan's own mounting holes
DECK_FAN_SCREW_D = 3.4;                                 // M3 clearance
DECK_FAN_CTRL = [[44, 38], [R5_W - 44, 38]];            // top-left, then top-right
DECK_GRILL_BARS = 7;                                    // bars across the opening
DECK_GRILL_BAR = 1.4;                                   // bar width
DECK_GRILL_RIB = 1.0;                                   // bars sit flush, this deep in the plate

// ---- r5 deck: hinge-edge opening (Pi connectors) ----
// The cut over the Pi's hinge edge is the one opening the cassette cannot do without: USB-C, the
// two micro-HDMI sockets and the 22-pin MIPI/DSI all sit on that edge (Pi pcb y 16, connectors
// overhang to y 12.8), the display FFC leaves through it and the M.2 FPC drops to the BASE.
// It stays on the Pi side (x 152-208) and not centred - a centred opening lands over the UPS
// HAT (B) and its 8.4 V jack, USB-A and switch (x 84-118) instead, which would seal every Pi
// cable under plate.
//
// Both ends are bounded by real hardware, which the previous 150..210 span ignored:
//   - right: deck screw 5 at (207.5, 5.1) with a Ø6.2 countersink, so the cut must stop short of
//            x 204.4 or that boss has no head seat,
//   - right: with DECK_FANS=2 the right fan reaches down to y 19, so the cut must stay shallower
//            than that or the two merge into one ragged outline. With DECK_FANS=1 (the default)
//            there is no fan there and the depth only has to clear the Pi's connectors (16 mm).
//   - left:  x 150 clears the Pi's own edge by 2 mm and nothing else is there.
R5_OPEN_X0 = R5_PI_X - 2;                              // 150
R5_OPEN_X1 = R5_SCREWS[5][0] - M3_HEAD/2 - 1;          // 203.4: 1 mm clear of the head
// depth: 1 mm below the right fan if it is fitted, otherwise the connector envelope (16 mm).
// Derived from the fan centre and DECK_FANS so it tracks the switch instead of describing it.
R5_FAN_R_Y = DECK_FAN_CTRL[1][1] - DECK_FAN_D/2;       // 19: lowest point of the right opening
R5_OPEN_D  = DECK_FANS > 1 ? min(R5_FAN_R_Y - 1, DECK_FAN_CTRL[1][1]) : R5_PI_Y;   // 18 or 16
// The invariant is not "as wide as the Pi" - the opening only has to uncover the connectors that
// sit on the hinge edge (USB-C at x 156, the two micro-HDMI at 166 and 176, each 9 mm wide, so
// they end at 185) and to be deep enough that the plugs and the FFC/FPC fold behind it.
R5_PI_HINGE_CONN = [R5_PI_X + 4, R5_PI_X + 33];        // 156..185, all three sockets
assert(R5_OPEN_X0 <= R5_PI_HINGE_CONN[0] && R5_OPEN_X1 >= R5_PI_HINGE_CONN[1],
       str("the hinge opening ", R5_OPEN_X0, "..", R5_OPEN_X1, " no longer covers the Pi's ",
           "hinge-edge connectors ", R5_PI_HINGE_CONN[0], "..", R5_PI_HINGE_CONN[1],
           ": deck screw 5 or the right fan has moved into it"));
assert(R5_OPEN_D >= R5_PI_Y,
       str("the hinge opening is ", R5_OPEN_D, " mm deep, the Pi's connectors need ", R5_PI_Y));
assert(R5_SCREWS[5][0] - M3_HEAD/2 >= R5_OPEN_X1,
       "the hinge opening runs into deck screw 5's countersink");

// ---- charge socket: 5.5 x 2.1 DC jack through the deck's right rail ----
// The host stays sealed: the 8.4 V charge lead ends in a panel socket in the deck's top face
// instead of a hole through the Peli wall. The socket is the r4 part (CHG_W's 9.5 mm barrel), so
// its plug goes in from above and charging is done with the lid open; with the plug out only
// the bezel stands proud, well inside the 4.6 mm between the deck and the display glass.
//
// The barrel drops through the hole into the channel between the Pi's port edge (x 208) and the
// tray wall (x 230.9), which is empty floor: the nut and the tags land there. The position
// clears the Pi's USB/Ethernet plugs, which project ~19 mm out of the pcb at y 26.2..76.4, and
// the right-rail screws at (207.5, 40) / (228.4, 40) / (228.4, 138.1); it sits between the hinge
// opening and the keyboard pocket. Turn the tags towards the Pi: 5 mm of lug past a 14 mm nut
// still clears the wall, 5 mm the other way does not.
// The socket's plug cannot be fitted with the lid shut - by design; see docs/R5.md.
R5_CHG_X = 216;                        // right rail centre, on free floor
R5_CHG_Y = 90;                         // between the Pi's ports and the keyboard pocket
R5_CHG_D = 9.5;                        // barrel hole, the same socket as r4's CHG_W
R5_CHG_NUT_D = 14;                     // nut/bezel envelope, the clearance that matters
assert(R5_CHG_X - R5_CHG_NUT_D/2 >= R5_PI_X + R5_PI_W,
       str("the charge socket (", R5_CHG_X, ") overlaps the Pi pcb edge (", R5_PI_X + R5_PI_W, ")"));
assert(R5_CHG_Y - R5_CHG_NUT_D/2
       >= R5_PI_Y + max([for (p=PI_PORTS) p[0] + p[1]]) + 2,
       str("the charge socket reaches y ", R5_CHG_Y - R5_CHG_NUT_D/2,
           ", into the Pi's USB/Ethernet plugs (they end at ",
           R5_PI_Y + max([for (p=PI_PORTS) p[0] + p[1]]), ")"));
assert(R5_CHG_X + R5_CHG_NUT_D/2 + 5 <= R5_W - R5_WALL,
       str("the charge socket's tags reach the tray wall: ",
           R5_CHG_X + R5_CHG_NUT_D/2 + 5, " vs ", R5_W - R5_WALL));
assert(R5_CHG_Y + R5_CHG_NUT_D/2 <= R5_KB_Y0,
       "the charge socket runs into the keyboard pocket");
assert(R5_CHG_Y - R5_CHG_NUT_D/2 > R5_OPEN_D,
       "the charge socket runs into the hinge opening");
assert(min([for (p=R5_SCREWS) sqrt((p[0]-R5_CHG_X)^2 + (p[1]-R5_CHG_Y)^2)]) 
       >= M3_HEAD/2 + R5_CHG_NUT_D/2 + 1,
       "the charge socket runs into a deck screw countersink");
assert(min([for (c=DECK_FAN_CTRL) sqrt((c[0]-R5_CHG_X)^2 + (c[1]-R5_CHG_Y)^2)])
       >= DECK_FAN_D/2 + R5_CHG_NUT_D/2 + 1,
       "the charge socket runs into a fan opening");
assert(sqrt((R5_BTN_X-R5_CHG_X)^2 + (R5_BTN_Y-R5_CHG_Y)^2)
       >= R5_BTN_BODY/2 + R5_CHG_NUT_D/2 + 2,
       "the charge socket runs into the power button nut");

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

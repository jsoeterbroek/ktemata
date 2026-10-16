// Pi Flux r1 - reverse-engineered shared parameters
// Coordinates: x = left->right as seen from the FRONT, y = top->bottom
// (top edge = pull-switch side), z = 0 at the back surface, up towards the screen.
// Use at(x,y) to place things in these "drawing" coordinates.

$fn = 40;

// ---------------- overall ----------------
W        = 150;     // outer width
L        = 183;     // outer height
CH       = 9;       // corner chamfer
WALL     = 3;       // side wall thickness
FLOOR    = 2;       // back plate thickness
H_BOT    = 24;      // bottom shell height (split plane)
H_FACE   = 10.5;    // face part height
T        = H_BOT + H_FACE; // total thickness
PLATE    = 2;       // face plate thickness
TOL      = 0.25;

// ---------------- screws ----------------
M25_CLR  = 2.8;     // clearance hole
M25_PIL  = 2.2;     // pilot hole for self tapping into plastic (use 3.6 for brass insert)
M25_HEAD = 5.2;     // counterbore for head
BOSS_D   = 7;
// 6 case screws: 4 corners + 2 on the screen/keyboard divider
// (side bosses at x=6 so they overlap the 3 mm wall; tangent bosses make non-manifold edges)
CASE_SCREWS = [[8.5,8.5],[W-8.5,8.5],[6,90],[W-6,90],[8.5,L-8.5],[W-8.5,L-8.5]];

// ---------------- display (Waveshare 5-DSI-TOUCH-A) ----------------
DISP_W = 129; DISP_H = 72.8; DISP_T = 7.8; DISP_R = 4; DISP_POST = 5;
DISP_X = (W-DISP_W)/2;  // left edge of glass
DISP_Y = 13;            // top edge of glass
DISP_Z_FRONT = T - PLATE;
DISP_Z_BACK  = DISP_Z_FRONT - DISP_T;
DISP_POST_END = DISP_Z_BACK - DISP_POST;   // where the display's own standoffs end
// outer 117 x 61 M2.5 pattern (6 / 5.9 mm from glass edges)
DISP_HOLES = [for (dx=[6, 6+117]) for (dy=[5.9, 5.9+61]) [DISP_X+dx, DISP_Y+dy]];

// ---------------- Raspberry Pi 5 (mounted on the display back) -----
// inner 58 x 49 pattern; ports point to the RIGHT wall, USB-C edge to the TOP
PI_HOLES_X = [DISP_X+45.5, DISP_X+45.5+58];
PI_HOLES_Y = [DISP_Y+11.9, DISP_Y+11.9+49];
PI_X0 = PI_HOLES_X[0]-3.5;          // non-port end of the board
PI_Y0 = PI_HOLES_Y[0]-3.5;          // USB-C / HDMI edge
PI_PCB_TOP = DISP_POST_END;         // pcb face against the posts
PI_PCB_BOT = PI_PCB_TOP - 1.6;      // component side faces the back plate
PI_USBC_X  = PI_X0 + 11.2;
PI_USBC_Z  = PI_PCB_BOT - 1.6;
// right-edge ports (centre measured from the USB-C edge, width, height)
PI_PORTS = [[10.2, 16.0, 13.6], [29.1, 13.4, 16.0], [47.0, 13.4, 16.0]];

// ---------------- battery (INIU 10000 mAh) ----------------
BAT_W = 112; BAT_H = 70; BAT_T = 16;      // measure yours!
BAT_X = (W-BAT_W)/2;
BAT_Y = L - WALL - 5.5 - BAT_H;            // leaves room for the button plunger
BTN_X = 108;                                // battery button position along the bottom edge
BTN_Z = FLOOR + BAT_T/2;
BTN_W = 6; BTN_HH = 4;                      // button plunger cross-section

// ---------------- pull switch (USB-C U adapter) ----------------
PULL_SLOT_X0 = 46.2; PULL_SLOT_W = 27.5;    // from the mat drawing (46.2 | 27.5 | 66.2)
PULL_GROOVE = 0.8;                          // floor groove the carrier rides in
// USB-C U (180 deg) adapter, standing upright: male plug on top (into the Pi),
// female socket below (battery cable, runs under the Pi / through the cooler fins)
UADP = [7.0, 12.5, 20.5];                   // body thickness(x), depth(y, excl. plug), height(z) - measure yours!
UADP_MALE_FROM_TOP = 5.25;                  // body top -> male plug centre
UADP_PLUG = 6.5;                            // male plug length
PULL_TRAVEL = 7;

// ---------------- keyboard ----------------
KB_WIN = [10, 97, 140, 164];                // x0,y0,x1,y1 of key window in face plate
KB_PCB = [137, 72];                         // keyboard PCB outline
KB_PCB_X = (W-KB_PCB[0])/2; KB_PCB_Y = 94.5;
KB_PCB_FRONT = T - 5;                       // z of the PCB front face
KB_PCB_BACK  = KB_PCB_FRONT - 1.2;

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
BUMP_LY = 21;       // ... along the sides (the first Pi port window starts at y=23)
BUMP_CZ = 1.2;      // small chamfer on the bumpers
RIB_H = 1.2; RIB_W = 1.6; RIB_P = 4;   // grip ribs: height, width, pitch
// grip rib zones: [side (0 = left, 1 = right), y0, y1] in drawing coords
RIB_ZONES = [[0, 54, 160], [1, 82, 160]];

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

// Ktemata - silicone corner overmould tool
//
// Casts one soft-rubber corner cap onto the case (one corner at a time) by pouring
// addition-cure silicone into the gap between the printed case and this tool.
//
// The cap is a CM_T thick rubber shell over the corner bumper, from CM_Z0 to CM_Z1. The
// tool is three pieces, all of which slide off along +z after curing:
//
//   cm_plate()  bottom seal, clamped against the case below the cap
//   cm_cup()    the cavity: its inner surface IS the cap's outer surface
//   cm_lid()    top seal, with a fill port and an air vent
//
// Why z and not a diagonal split: the corner cross-section is only prismatic along z. A
// two-piece tool split on the corner's 45 deg bisector would have to drag each half through
// the wall it wraps.
//
// The cap's ends are plain vertical faces. That is deliberate: the whole shell is prismatic
// in z, so it lifts off the case and out of the cup without a taper, and a vertical end wall
// in the tool needs no slide.
//
// Casting notes, silicone choice and finishing: docs/CORNER_MOULD.md.

include <common.scad>

// ---------------- parameters (mm) ----------------
CM_T     = 2.0;    // rubber wall thickness
// Case clearance, shared by the rubber's inner face and every tool bore. One value keeps
// the cavity exactly equal to the cap: the rubber slides on, and the tool seals on the same
// surface (the 0.15 mm line is the flash line you trim off).
CM_FIT   = 0.15;
CM_Z0    = 5.0;    // cap bottom; above the 3 mm edge chamfer (EDGE_CZ)
CM_Z1    = 35.0;   // cap top; below the 38.55 mm split plane (H_BOT)
// Cap reach along the top/bottom wall. Exactly BUMP_LX: the OLED button's Ø16 recess starts
// at x 27 on the top wall, so anything past 26 would run under it.
CM_LX    = 26.0;
// Cap reach along the side wall (bumper is BUMP_LY = 21). The left wall carries the BME688
// chamber (drawing y 196..224 = real y 13..41) and its vent seat, so both left corners use
// `-D CM_LY=12`; the two right corners take 23.
CM_LY    = 23.0;
CM_WALL  = 12.0;   // tool material beyond the rubber on the outside
CM_PLATE = 5.0;    // bottom plate thickness
CM_LID   = 5.0;    // top lid thickness
CM_ROUND = 5.0;    // outer corner radius of the tool
CM_PORT  = 3.2;    // fill port diameter
CM_VENT  = 2.0;    // air vent diameter
CM_PIN_D = 5.0;    // alignment pin diameter
CM_PIN_H = 5.0;    // pin height above the plate
CM_CSINK = 2.2;    // M3 countersink depth in the cup

// corner selection: the tool is modelled at the real (0,0) corner; mirror it onto the others
CM_MX = false;  // true = mirror about x = W/2
CM_MY = false;  // true = mirror about y = L/2

// Hardware sits in the block's outboard margin (CM_WALL = 12), never inside the L of rubber.
CM_SCREWS = [[-7, -7], [CM_LX + 6, -7]];  // M3 x 40 (5 + 30 + 5), lid -> cup -> plate
CM_PINS   = [[-7, CM_LY + 6], [CM_LX + 6, -5]];  // alignment pins, clear of the cavity

// ---------------- 2D building blocks, local to the (0,0) corner ----------------
// The real exterior (body + bumper + ribs), clipped near the corner so the offsets below
// stay cheap: the rib polygons and the far side of the case are trimmed first.
module cm_case2d() {
    intersection() {
        union() { body2d(); bumper2d(); ribs2d(); }
        translate([-60, -60]) square([120, 120]);
    }
}

// the cap's footprint: the corner up to its ends (CM_LX / CM_LY). The tool block continues
// CM_WALL further out, which is what forms the mould's end walls.
module cm_clip2d() {
    translate([-CM_WALL - 2, -CM_WALL - 2])
        square([CM_LX + CM_WALL + 2, CM_LY + CM_WALL + 2]);
}

// footprint of the whole tool: the corner rectangle, grown CM_WALL outside the case
module cm_block2d() {
    translate([-CM_WALL, -CM_WALL]) offset(r=CM_ROUND) offset(delta=-CM_ROUND)
        square([CM_LX + CM_WALL + 14, CM_LY + CM_WALL + 14]);
}

// the rubber: a CM_T shell over the case, offset by CM_FIT so it slides on, clipped to the
// corner. The clip must not reach past the tool block or the rubber would poke through it.
module cm_cap2d() {
    intersection() {
        difference() {
            offset(delta = CM_FIT + CM_T) cm_case2d();
            offset(delta = CM_FIT) cm_case2d();
        }
        cm_clip2d();
    }
}

// ---------------- the rubber part ----------------
// Printed in TPU it is also the test fit for the case, before committing silicone.
module cm_cap() translate([0, 0, CM_Z0]) linear_extrude(CM_Z1 - CM_Z0) cm_cap2d();

// same shell, split at the split plane: for checking against the bottom shell alone
module cm_cap_bottom() intersection() {
    cm_cap();
    translate([-60, -60, -1]) cube([160, 160, H_BOT + 1]);
}

// ---------------- tool halves ----------------
// R - case(clearance) - cavity. The material left between the cavity and the block edge is
// the mould wall; beyond the cap's ends that same band forms the closing end wall.
module cm_tool2d() {
    difference() {
        cm_block2d();
        offset(delta = CM_FIT) cm_case2d();
        cm_cap2d();
    }
}

module cm_plate() {
    z0 = CM_Z0 - CM_PLATE;                           // sits directly under the cap
    difference() {
        translate([0, 0, z0]) linear_extrude(CM_PLATE) difference() {
            cm_block2d();
            offset(delta = CM_FIT) cm_case2d();      // seals on the case
            cm_cap2d();                              // never intrude on the rubber
        }
        for (p = CM_SCREWS) translate([p[0], p[1], z0 - 0.1]) cylinder(d = 2.6, h = CM_PLATE + 0.2);
    }
    // pins rise from the plate's top face into the cup's blind holes
    for (p = CM_PINS) translate([p[0], p[1], CM_Z0]) cylinder(d = CM_PIN_D, h = CM_PIN_H, $fn = 32);
}

module cm_cup() {
    z0 = CM_Z0;
    h  = CM_Z1 - CM_Z0;
    difference() {
        translate([0, 0, z0]) linear_extrude(h) cm_tool2d();
        for (p = CM_SCREWS) {
            translate([p[0], p[1], z0 - 0.1]) cylinder(d = 3.4, h = h + 0.2);
            translate([p[0], p[1], z0 + h - CM_CSINK]) cylinder(d = 6.2, h = CM_CSINK + 0.1, $fn = 32);
        }
        for (p = CM_PINS) translate([p[0], p[1], z0 - 0.1]) cylinder(d = CM_PIN_D + 0.3, h = CM_PIN_H + 0.4, $fn = 32);
    }
}

module cm_lid() {
    z0 = CM_Z1;
    // fill port sits over the top-wall end of the cavity, vent over the side-wall end
    fill = [CM_LX - 8, -CM_T / 2];
    vent = [-CM_T / 2, CM_LY - 8];
    difference() {
        translate([0, 0, z0]) linear_extrude(CM_LID) difference() {
            cm_block2d();
            offset(delta = CM_FIT) cm_case2d();      // seals on the case
            cm_cap2d();                              // never intrude on the rubber
        }
        for (p = CM_SCREWS) translate([p[0], p[1], z0 - 0.1]) cylinder(d = 3.4, h = CM_LID + 0.2);
        // fill: port plus a shallow pour basin
        translate([fill[0], fill[1], z0 - 0.1]) cylinder(d = CM_PORT, h = CM_LID + 0.2, $fn = 32);
        translate([fill[0], fill[1], z0 + CM_LID - 2]) cylinder(d = 10, h = 2.1, $fn = 32);
        // vent
        translate([vent[0], vent[1], z0 - 0.1]) cylinder(d = CM_VENT, h = CM_LID + 0.2, $fn = 32);
    }
}

// ---------------- corner placement ----------------
module cm_place() {
    translate([CM_MX ? W : 0, CM_MY ? L : 0, 0]) mirror([CM_MX ? 1 : 0, CM_MY ? 1 : 0, 0]) children();
}

// ---------------- render ----------------
// One dispatcher, used by export.scad as well as by the preview below.
module corner_mould_part(p) {
    if (p == "cap")   cm_place() cm_cap();
    if (p == "plate") cm_place() cm_plate();
    if (p == "cup")   cm_place() cm_cup();
    if (p == "lid")   cm_place() cm_lid();
    if (p == "tool") {                       // as assembled, for a fit check
        cm_place() {
            cm_plate();
            cm_cup();
            cm_lid();                        // each piece already sits at its own z
        }
    }
}

CM_PART = "cap";        // cap | plate | cup | lid | tool   (export.scad overrides this)
if (is_undef(PART)) corner_mould_part(CM_PART);

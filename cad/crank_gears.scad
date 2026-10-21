// Pi Flux - hand crank generator: gears
// Big gear (66T) clamps to the rotor shaft, small gear (22T) to the crank shaft; 1.5 mm
// module, 20 deg pressure angle, 3:1 step-up. Both print flat with the D-bore vertical:
// the involute profile is vertical, so no supports.
include <crank_common.scad>

module cr_gear_big() cr_gear(CR_T_BIG, clamp=true, holes=6, hole_d=9, hole_r=30);
// half-tooth phase so the 22T pinion meshes with the 66T gear at the modelled spacing
module cr_gear_small() rotate([0, 0, 180/CR_T_SM]) cr_gear(CR_T_SM, clamp=true);

if (is_undef(ASSEMBLY)) cr_gear_big();

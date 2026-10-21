# Pi Fluks r3 — hand crank generator

The backup charger, modelled in `cad/crank_*.scad` and exported to `stl/crank/`. It is a **separate
unit**: it does not fit in the case, a shaft through the wall would break the seal, and the reaction
torque of cranking would need a second hand on the case. Its output feeds the same sealed USB-C charge
port as the solar panel (see `WIRING.md`).

![Crank assembly, exploded](../renders/crank_assembly.png)

*Exploded view: base plate and posts, stator with its 8 coil windows, the two rotor discs, top plate,
66T/22T gear pair, crank arm and knob.*

![Stack section](../renders/crank_stack_sec.png)

*Half-section through both axes: the two magnet rotors either side of the stator, the 608 bearings and
the clamp hubs, and the electronics tray under the base plate.*

## How it works

An **axial-flux alternator** with a 3:1 spur-gear step-up:

- two **rotors** (the same printed disc, one flipped) each carry 8 N52 disc magnets on a 42 mm pitch
  radius, with alternating polarity around the circle;
- a **stator** between them has 8 coil windows; the magnets sweep past, so each coil sees a reversing
  field;
- the coils are wired **2 in series / 4 in parallel**, rectified by a bridge, buffered by capacitors and
  fed to a 5 V USB module in the tray;
- the crank drives the rotor through a 66T : 22T pair, so a comfortable 60 rpm at the handle gives
  180 rpm at the rotor.

Everything is printed in PLA/PETG except the shafting, bearings and fasteners. All parts print flat with
no supports.

## Printed parts

| Part | Qty | Notes |
|---|---|---|
| `crank_base` | 1 | Base plate, four M3 insert posts, 608 pocket for the rotor shaft |
| `crank_stator` | 1 | 8 coil windows, 4 mounting lugs (M3 through), wire channel on top |
| `crank_top` | 1 | Top plate, 608 pocket in the crank boss, rotor guide bore |
| `crank_rotor` | 2 | 8 magnet pockets, 4 screws to the hub; use one as printed and one flipped |
| `crank_hub` | 2 | Clamp hub with a pinch slit: one under the bottom rotor, one above the top rotor |
| `crank_gear_big` | 1 | 66T, 1.5 mm module, clamp hub on the rotor shaft |
| `crank_gear_small` | 1 | 22T, clamp hub on the crank shaft |
| `crank_arm` | 1 | Arm plus M6 knob bolt and nut trap |
| `crank_knob` | 1 | Printable knob (an M6 star knob also works) |
| `crank_tray` | 1 | Electronics tray under the plate, gland for the output cable |
| `crank_lid` | 1 | Screw-on lid with a vent slot |
| `crank_foot` | 4 | Screw-on feet with M3 nut traps; set the 20 mm bench clearance |
| `crank_spacer` | 4 | Spacer tube Ø14 × 12.4 mm between a stator lug and the top plate |

## Bought parts

| Item | Qty | Size / spec |
|---|---|---|
| N52 disc magnets | 16 | Ø15 × 3 mm |
| 608-2RS bearings | 2 | 8 × 22 × 7 mm |
| Silver-steel shaft | 2 | Ø8 mm, one ground flat; rotor 55 mm, crank 32 mm |
| M3 socket screws | 4 × 30 | Stack screws: top plate → spacer tube → stator lug → base post insert |
| M3 × 16 | 8 | Rotor discs to clamp hubs (7 mm disc + 4.3 mm hub body = 11.3 mm, so 16 mm is the shortest screw that still engages) |
| M3 × 8 + nuts | 8 | Tray lid and feet |
| M6 × 40 bolt + nut | 1 | Knob through the crank arm |
| M3 heat-set inserts | 8 | 4 in the base posts, 4 in the plate underside for the tray |
| Enamelled copper wire | ≈ 40 m | 0.3–0.4 mm, 300–350 turns per coil |
| Bridge rectifier | 1 | e.g. KBPC2504 or a 4× 1N5408 bridge |
| Capacitors | 2–3 | 1000 µF 25 V (buffer) |
| 5 V USB buck module | 1 | MP1584 / LM2596 set to 5.1 V, 1 A |
| USB-A pigtail | 1 | To the case charge port or a USB-C adapter |
| Spacer tubes | 4 | Printed (`crank_spacer`), or aluminium cut to `CR_TPOST_H` = 11.9 mm of clear height |

## Assembly

Read the whole sequence first: the two rotors and their clamp hubs are built as sub-assemblies
**before** the stator goes in, because the M3 hub screws are inserted from the magnet face and that
face ends up 0.6 mm from the stator.

### A. Rotor sub-assemblies (×2, mirror images)

1. **Magnets.** Press the 16 N52 discs into the rotor pockets, alternating polarity around the circle.
   Find the poles with a stack test (two magnets attract on one side, repel on the other) and keep all
   the north faces on the same side of each disc. Glue them flush; the pockets are 3.3 mm deep for a
   3 mm magnet.
2. **Hub to disc.** Lay a rotor with its **magnet face up**. Drop a clamp hub into the recess so its
   body sits against the disc, and fit 4 × M3×16 through the counterbored holes in the magnet face into
   the hub's self-tapping holes. Snug them: the counterbore is 6.2 mm, so the heads end up flush with
   the magnet face. This is the only chance to fit these screws.
3. **Shaft.** Slide the hub onto the rotor shaft (flat to flat) and tighten the pinch screw through the
   hub's side slit.
4. **Repeat** for the second rotor, but with its **magnet face down** (mirror image). The two discs are
   identical parts; the second one is simply flipped.

### B. Frame and alternator

5. **Base bearing.** Press a 608 into the base plate's top pocket, flush with the plate top.
6. **Bottom rotor.** Slide the shaft through the bearing from above. The hub's 10 mm boss sits on the
   bearing inner race, so the disc turns 5.8 mm above the plate.
7. **Posts.** Heat-set four M3 inserts into the base-plate posts. Lower the **stator** onto them, coil
   windows up, with the wire exit notch at the −x side. Do not screw it down yet.
8. **Coils.** Wind 8 coils of ≈300–350 turns of 0.3–0.4 mm enamelled wire and lay them into the
   windows. Join them 2 in series × 4 in parallel (see *Electrical notes*), then run the two output
   leads through the channel on the stator's top face and out of the −x hole.
9. **Top rotor.** Lower the second rotor onto the shaft, magnet face **down**, so its magnets face the
   stator. Align it with the bottom rotor (its magnets sit opposite the lower ones) and tighten its hub
   pinch screw.
10. **Top plate.** Fit the four **spacer tubes** on the stator lugs, then the top plate, and run the
    four M3×30 screws down through the plate, the spacers, the stator lugs and into the base-post
    inserts. Do not fully tighten yet.
11. **Crank bearing.** Press the second 608 into the crank boss, flush with the boss top, and slide the
    crank shaft down through it.

### C. Drive and electronics

12. **Gears.** Clamp the **66T** gear to the rotor shaft above the top plate and the **22T** gear to the
    crank shaft, both with their pinch screws. The centres are 66.4 mm apart, giving ≈0.4 mm backlash:
    turn the crank by hand and check for a smooth mesh with no binding before going further.
13. **Arm and knob.** Bolt the arm to the crank shaft and tighten its pinch screw. Push the M6 bolt
    through the knob, then through the arm's end, and fit the M6 nut in the trap under the arm; tighten
    from above.
14. **Electronics.** Solder the coils to the bridge rectifier and the capacitor bank, then to the 5 V
    module's input, and the module's output to the USB pigtail. Fix the boards in the tray, run the
    pigtail out through the −x gland, and screw the tray and its lid under the base plate. Fit the four
    feet.
15. **Test.** Spin the crank slowly: the rotor should run free with a light cogging from the magnets,
    and the multimeter should show ≥5 V DC at the module output. Load it with a phone and confirm the
    output holds 5 V. Check that no screw head or magnet touches the stator (the gap is 0.6 mm per
    side).

## Electrical notes

- **Wiring:** 8 coils at ≈0.35 mm wire, 300–350 turns each. Two in series per branch, four branches in
  parallel: about 10–15 V AC at 150–200 rpm, which the rectifier and capacitor bank turn into a stiff
  DC rail for the 5 V module.
- **Output:** the 5 V module feeds a USB-A pigtail; use a USB-A→USB-C cable into the case's sealed charge
  port. Do **not** connect the raw alternator to the case: the UPS needs a regulated 5 V input.
- **Power:** expect 5–10 W at the battery after losses for 10–20 W of arm effort, i.e. about 1 minute of
  cranking per minute of Pi runtime, and 7–14 h to refill the 4S pack. Cranking a phone charge is the
  realistic use.
- **Direction and polarity:** the bridge rectifier makes the output polarity independent of crank
  direction, so the handle can be turned either way.
- **Safety:** the alternator can produce well over 20 V open circuit if spun fast; the 5 V module's input
  rating is the limit. Fit the capacitor bank before the module and never short the output.

## Printing notes

- No supports anywhere: every part prints flat or standing on a flat face.
- The rotor discs are identical; print two and flip one.
- The gears print flat. Use 4 walls and 40 % infill for the 66T gear; the teeth are 1.5 mm module.
- PETG for the gears and arm is worth it; PLA is fine for the frame.
- The stator needs the coil windows clean: print at 0.2 mm layers and check the windows before winding.

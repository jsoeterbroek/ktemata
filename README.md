# Pi Fluks r1 – reverse-engineered printable parts

Rebuilt from the photos in `Pi_Flux_r1_-_Build_Guide.pdf`. The guide has no CAD
drawings, so this is a **functional re-creation**, not a copy of the original files.
Everything is parametric OpenSCAD. Measure your own parts, edit `cad/common.scad`,
then re-export.

## Project Nomad
based on project nomad

## Files

| STL (`stl/`) | Source (`cad/`) | Print orientation |
|---|---|---|
| `pi_fluks_bottom.stl` – back shell | `bottom.scad` | back plate down, supports for the port window bridges only |
| `pi_fluks_face.stl` – front face | `face.scad` | face plate down |
| `pi_fluks_keyboard_support.stl` | `keyboard_support.scad` | flat |
| `pi_fluks_pull_switch.stl` – USB-C U-adapter pull switch | `pull_switch.scad` | top face (ring tab) down |
| `pi_fluks_power_button.stl` – battery button plunger | `power_button.scad` | cap end down |

`cad/assembly.scad` shows everything with stand-in components (`-D EXPLODE=40`).
`-D 'CHECK="bottom:pi"'` intersects one part with another, which is handy for clearance checks.
To re-export the STLs: `python3 cad/tools/export.py`. To refresh the images in `renders/` afterwards: `python3 cad/tools/render.py`

## Rugged exterior

The corner bumpers stand 3 mm proud. The body edges have a 3 mm 45° chamfer on the front and back, and the
left and right grip zones carry vertical ribs. The face has bevelled windows and faux screw heads over the
case screws. Everything prints without supports. To tune it, edit `BUMP*`, `EDGE_CZ`, `RIB_*` and `RIB_ZONES`
in `common.scad`. Imprinted text: "π·FLUKS/AI" on the face and inside the back.

The optional back attachment is **not** modelled. The guide shows too little of it.

## Where the dimensions come from

* **Scale**: from the Waveshare 5-DSI-TOUCH-A datasheet drawing (129 × 72.8 × 7.8 mm,
  M2.5 holes 117 × 61 outer and 58 × 49 inner). The display is visible in the overview photo (p.3).
  → body ≈ **150 × 183 mm** (**156 × 189 mm** over the corner bumpers), thickness **34.5 mm** (bottom 24 + face 10.5).
* Pull-switch slot position (46.2 / 27.5 / 66.2 mm) is taken from the drawing printed on the mat.
* The Pi 5 hangs on the display's inner holes. Its ports face the **right** wall (guide: "prime the
  right USB port"), and its USB-C sits under the pull switch.
* 6 case screws (M2.5×10, from the back, into pilot holes in the face): 4 corners and 2 on the
  screen/keyboard divider. 4 optional M2.5×10 screws go into the display standoffs.

## Check these before printing (estimates)

| Parameter | Value | Why |
|---|---|---|
| `BAT_W/H/T` | 112 × 70 × 16 | INIU size estimated from the photo |
| `BTN_X`, `BTN_Z` | 108, 10 | battery button position |
| `UADP*` | 7 × 12.5 × 20.5, male 5.25 from top | your U adapter. It stands upright: male into the Pi, female below (cable runs under the Pi; the guide notes some coolers need fin trimming) |
| `KB_PCB*`, `KB_WIN` | 137 × 72 PCB | keyboard PCB size and key window |
| `W`, `L`, `H_BOT`, `H_FACE` | 150, 183, 24, 10.5 | from photo scaling, ±3 mm |
| `M25_PIL` | 2.2 | set `BRASS_INSERT=true` in `face.scad` for heat-set inserts |

Set `SIDE_CUTOUT=false` in `face.scad` for the version with no side cutout (keyboard wired to the GPIO).

## project briefing
- ruggedized, strong case, rubber corners
- boots into kiwix
- local offline maps, wikipedia, prepper, medical
- no networking (no wifi, no lan)
- no bluetooth
- power by battery bank, solar charger
- zimablade 7700
- screen tough protected
- no keyboard
- bom from pi flux project 
- rubber seals for openings (not cooling)
- no sound





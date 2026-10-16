# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Parametric OpenSCAD re-creation of the 3D-printed case for the "Pi Flux r1" handheld (Pi 5 + 5" Waveshare DSI display + mini keyboard + INIU power bank). It is reverse-engineered from the photos in `Pi_Flux_r1_-_Build_Guide.pdf` (text in `build_guide.txt`, page images in `work/pages/`). No original CAD exists. Many dimensions are estimates; see the "Check these before printing" table in `README.md`. The device has a rugged/military styling (corner bumpers, chamfered edges, grip ribs). Imprinted branding is "π·FLUKS/AI".

Not a git repo. Back up before large changes (a prior version is in `work/backup_v1/`). Tooling: OpenSCAD 2021.01 (CGAL, slow on many booleans), Python 3.

## Commands

```bash
python3 cad/tools/export.py              # export all parts to stl/ (binary, centred, on z=0), prints size + open-edge count
python3 cad/tools/export.py face bottom  # export only some parts (names: bottom face keyboard_support pull_switch power_button)
bash work/scripts/check.sh               # interference check of every part vs. every component/part (slow, minutes)
openscad -D 'CHECK="bottom:pi"' -o /tmp/x.stl cad/assembly.scad   # single interference pair
openscad -o out.png --render --imgsize=1400,1100 --camera=75,90,17,60,0,35,430 cad/assembly.scad  # render preview
```

`open edges: 0` from export.py means the mesh is manifold. Any other value is a regression. In check.sh, a "HIT" whose bbox is flat in one axis (or that throws an empty-bbox traceback) is a zero-volume contact and is expected. Only volumetric bboxes are real collisions.

## Architecture

- `cad/common.scad` is included by every part. It holds all shared parameters and helpers:
  - **Coordinate convention:** x = left→right seen from the front, y = top→bottom ("drawing" coords, top edge = pull-switch side), z = 0 at the back surface rising toward the screen. Use `at(x, y, z)` to place things in drawing coords (it flips y to `L-y`). Raw `translate` uses real coords.
  - Component positions (display, Pi 5 hung on the display's inner holes, battery, USB-C U-adapter, keyboard PCB) are derived from each other, so changing one parameter moves dependents.
  - `outer_body()` is the full closed exterior z=0..T: chamfered body + grip ribs (`RIB_ZONES`) + corner bumpers (`BUMP*`). `bottom.scad` and `face.scad` each intersect it with their own z range (split at `H_BOT`), then subtract `inner_outline()`. Exterior styling changes belong here, not in the parts.
- Each part file (`bottom.scad`, `face.scad`, `keyboard_support.scad`, `pull_switch.scad`, `power_button.scad`) models its part **in assembly position** and only renders itself when `ASSEMBLY` is undefined. Pattern: `difference() { union() { solids } cuts }`.
- `assembly.scad` combines all parts with stand-in components (`EXPLODE`, `SECTION`, `CHECK` variables). It defines `part(name)` used for interference checks.
- `export.scad` rotates parts into print orientation (face and pull switch flipped). `tools/export.py` drives it and normalises placement.

## Design constraints

- Everything must print without supports in the orientation set in `export.scad`. The bottom prints back-plate down and the face prints face-plate down. So nothing may protrude beyond those bed faces. Overhangs must be ≤45° (hence the 45° edge chamfers and window bevels).
- Cuts through the side walls (Pi port windows, keyboard side cutout, SD slot) must extend past the rib/bumper protrusion. Bumpers and rib zones are sized to stay clear of these openings (e.g. `BUMP_LY` < first Pi port at y≈23).
- Screws are M2.5×10 from the back into pilot holes in the face (`BRASS_INSERT` option for heat-set inserts).

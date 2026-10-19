# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Parametric OpenSCAD re-creation of the 3D-printed case for the "Pi Flux" handheld. The r1 geometry (Pi 5 + 5" Waveshare DSI display + mini keyboard + INIU power bank) is reverse-engineered from the photos in `Pi_Flux_r1_-_Build_Guide.pdf` (text in `build_guide.txt`, page images in `work/pages/`); no original CAD exists. r2 retargets the same exterior to the DFR0550-V2 display, UPS HAT (E) + 4× 21700 and FireBeetle status OLED, and is the default. Many dimensions are estimates; see the "r2 CAD implementation" section in `README.md`. The device has a rugged/military styling (corner bumpers, chamfered edges, grip ribs). Imprinted branding is "π·FLUKS/AI".

**Target hardware is r2 and is modelled by default.** The CAD has an `R2` switch in `cad/common.scad` (default `true`); `-D R2=false` restores the original r1 geometry. The chosen r2 parts are in `README.md` ("Target hardware"): Pi 5 (4 GB), DFRobot DFR0550-V2 5" DSI LCD, Waveshare UPS HAT (E) with 4× 21700 cells, recharged by solar (main) and a separate hand crank generator (backup, not built into the case) through one MPPT input and one sealed USB-C port, a **wired USB** keyboard (no Bluetooth), Pimoroni trackball, BME688 (optionally SEN66), 1 TB NVMe, and the Pi 5 RTC with an ML-2020 cell. The ZimaBlade, the Pi 4 (no real power saving) and e-paper displays were considered and rejected; don't reintroduce them. No Wi-Fi, LAN, Bluetooth or sound. Nice to have: a DFRobot FireBeetle 2 ESP32-UE (N16R2, DFR1140) with a small 1.3" 4-pin I2C OLED (SH1106/SSD1306) (custom PlatformIO firmware in `firmware/`, all radios off) with at least 4 screens (time = default, battery, environment, storage %), a button to cycle them and auto-switching to the relevant screen when a threshold is passed; spec in `README.md` ("Status OLED"). Meshtastic/LoRa was considered and dropped; no hardware radio switch. When recommending or linking parts, prefer tinytronics.nl and bol.com; never Amazon. When modelling r2 parts, keep the existing r1 geometry working (add parameters or options rather than deleting) unless told otherwise.

**Status OLED firmware (`firmware/`).** The board is the DFR1140 FireBeetle 2 ESP32-UE: **ESP32-WROOM-32UE-N16R2, not an ESP32-S3** (16 MB flash, 2 MB PSRAM, CH340). It needs the project-local board JSON in `firmware/boards/` (`dio_qspi`, `BOARD_HAS_PSRAM`, 16 MB partitions). Verified: 1.3" 4-pin SH1106 OLED at `0x3C`; SDA GPIO21 / SCL GPIO22 (header pins `21/SDA`, `22/SCL`). Button GPIO4 to GND (TinyTronics PBS-33B 12 mm panel button; add a rubber boot for sealing), BME688 `0x76/0x77`, DS3231 `0x68`, Waveshare UPS HAT (E) `0x2D`. The display and 16 MB/2 MB PSRAM are confirmed working; the sensors, button and Pi-side serial sender are still to be brought up. Idle blanking is currently disabled with `-DSCREEN_OFF_MS=0UL` because the button is not fitted; the blank-screen report was the OLED display-off command, not ESP32 sleep. Details and serial protocol: `firmware/README.md`.

Git repo. Commit or back up before large changes (an older version is also in `work/backup_v1/`). Tooling: OpenSCAD 2021.01 (CGAL, slow on many booleans), Python 3.

## Tools

For development phase use:

- for ESP32/OLED component, use the project venv: `source .venv/bin/activate` then `pio ...` (or `.venv/bin/pio`). The venv has PlatformIO and `intelhex`.
-

## Commands

```bash
python3 cad/tools/export.py              # export all r2 parts to stl/ (binary, centred, on z=0), prints size + open-edge count
python3 cad/tools/export.py --r1         # export the original r1 set instead (pull_switch, power_button)
python3 cad/tools/export.py face bottom  # export only some parts (names: bottom face keyboard_support charge_plug)
python3 cad/tools/render.py              # regenerate renders/*.png (after export; pi_fluks_* views use the STLs); args filter by name, e.g. asm_iso
bash work/scripts/check.sh               # r2 interference check (slow, minutes); R1=1 for the r1 set
openscad -D 'CHECK="bottom:pi"' -o /tmp/x.stl cad/assembly.scad   # single interference pair
openscad -o out.png --render --imgsize=1400,1100 --camera=75,90,17,60,0,35,430 cad/assembly.scad  # render preview
```

`bad edges: 0` from export.py means the mesh is manifold (no open edges, no edges shared by >2 faces, which slicers flag as non-manifold). Touching-but-not-overlapping solids (tangent bosses, flush faces) are the usual cause: overlap them by ≥0.5 mm. Any other value is a regression. In check.sh, a "HIT" whose bbox is flat in one axis (or that throws an empty-bbox traceback) is a zero-volume contact and is expected. Only volumetric bboxes are real collisions.

## Architecture

- `cad/common.scad` is included by every part. It holds all shared parameters and helpers:
  - **R2 switch:** `R2 = is_undef(R2) ? true : R2`. All component positions, the display holes, cell/UPS stack, keyboard, OLED, sensor pocket and case depth are conditional on it. r1 remains selectable with `-D R2=false`.
  - **Coordinate convention:** x = left→right seen from the front, y = top→bottom ("drawing" coords, top edge = charge-port / pull-switch side), z = 0 at the back surface rising toward the screen. Use `at(x, y, z)` to place things in drawing coords (it flips y to `L-y`). Raw `translate` uses real coords. Note that a cube placed with `at(x,y,z)` extends toward *smaller* drawing y; use `translate([0,-h,0])` for a positive drawing-y span.
  - Component positions are derived from each other. In r2 the stack is: display (DFR0550-V2) → Pi 5 → UPS HAT (E) → one row of 4× 21700. `CELL_*`, `UPS_*`, `DISP_*` and `DISP_POST` determine `T` and `H_BOT`; changing one moves the shell.
  - `outer_body()` is the full closed exterior z=0..T: chamfered body + grip ribs (`RIB_ZONES`) + corner bumpers (`BUMP*`). `bottom.scad` and `face.scad` each intersect it with their own z range (split at `H_BOT`), then subtract `inner_outline()`. Exterior styling changes belong here, not in the parts.
- Each part file (`bottom.scad`, `face.scad`, `keyboard_support.scad`, `charge_plug.scad`, and the r1-only `pull_switch.scad`/`power_button.scad`) models its part **in assembly position** (the plug is modelled print-ready) and only renders itself when `ASSEMBLY` is undefined. Pattern: `difference() { union() { solids } cuts }`.
- `assembly.scad` combines all parts with stand-in components (`EXPLODE`, `SECTION`, `CHECK` variables). It defines `part(name)` used for interference checks; r1 components return empty when `R2` is true and vice versa.
- `export.scad` rotates parts into print orientation (face flipped, pull switch flipped). `tools/export.py` drives it and normalises placement; it skips the r1-only parts unless `--r1` is given.

## Design constraints

- Everything must print without supports in the orientation set in `export.scad`. The bottom prints back-plate down and the face prints face-plate down. So nothing may protrude beyond those bed faces. Overhangs must be ≤45° (hence the 45° edge chamfers and window bevels).
- Cuts through the side walls (Pi port windows, keyboard side cutout, SD slot) must extend past the rib/bumper protrusion. Bumpers and rib zones are sized to stay clear of these openings (e.g. `BUMP_LY` < first Pi port at y≈23).
- Screws are M2.5×10 from the back into pilot holes in the face (`BRASS_INSERT` option for heat-set inserts).
- r2 is 150 × 205 × 46.5 mm. The UPS HAT (E) sits on the Pi's component side (left-aligned, clear of the USB/Ethernet ports) and the 21700 cells sit in a single row below it (custom printed cradles, no stock 2×2 holder), which keeps the depth practical. r2 has no active cooler or 40-pin header; the 6.5 mm gap is for the UPS pogo pins. The status OLED band adds 22 mm to the length. The face holds a separate 1.3" 4-pin I2C OLED module (`OLED_*`); the FireBeetle 2 ESP32-UE board (`FB_*`) sits in a low tray in the bottom shell and connects with a short 4-wire cable. Check `README.md` ("r2 CAD implementation") for the assumptions to verify before printing.

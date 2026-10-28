# AGENTS.md

This file provides guidance when working with code in this repository.

## Important
Be direct, ultra-concise, and straight to the point. Skip all pleasantries, introductory remarks, meta-commentary, and unnecessary explanations. Answer using bullet points where applicable.

## What this is

Parametric OpenSCAD re-creation of the 3D-printed case for the **Ktemata** handheld (formerly "Pi Flux"/"Pi Fluks"): a rugged offline library device — Wikipedia, maps, Gutenberg — that keeps its content when power and networking are gone. The name is Greek κτήματα, "possessions"; the README opens with Thucydides' κτῆμα ἐς ἀεί, "a possession for all time". The r1 geometry (Pi 5 + 5" Waveshare DSI display + mini keyboard + INIU power bank) is reverse-engineered from the photos in `Pi_Flux_r1_-_Build_Guide.pdf` (text in `build_guide.txt`, page images in `work/pages/`); no original CAD exists. r2 retargets the same exterior to the DFR0550-V2 display, UPS HAT (E) + 4× 21700 and FireBeetle status OLED. **r4 is the current default**: the ordered hardware is Raspberry Pi Touch Display 2 (5", 143.4 × 91.46, native portrait), Waveshare UPS HAT (B) with 2× 18650 in 2S, and the Rii K06 keyboard (155 × 89 × 16.5, touchpad), giving a 172 × 237 × 53 mm case. Many dimensions are estimates; see the "r4 CAD implementation" section in `README.md` and `docs/R4.md`. The device has a rugged/military styling (corner bumpers, chamfered edges, grip ribs). Imprinted branding is "π·FLUKS/AI".

**r5 (new) removes the printed exterior entirely.** `-D R5=true` (or `export.py --r5`) builds an internal cassette — `r5_tray`, `r5_deck`, `r5_lid_plate` — that drops into a bought waterproof hard case, with the display mounted on the inside of the lid. r5 keeps r4's electronics but **drops the air-quality sensor**. Only `HOST = "1200"` (Peli 1200, default) and `"1400"` are accepted; the **Peli R40/R60 are rejected by `assert()`** because their lid cannot take the 16.92 mm display assembly and their base cannot take the 67.95 mm cassette. See `docs/R5.md` before touching r5 numbers. `bash work/scripts/check_r5.sh` is its interference set.

**Target hardware is r4 and is modelled by default; r2/r3 and r1 remain selectable.** The CAD has two switches in `cad/common.scad`: `R4` (default `true`, the ordered hardware) and `R2` (default `true`; `-D R2=false` restores the original r1 geometry). `-D R4=false` gives the r2/r3 build, and `export.py` takes `--r4` (default) / `--r2` / `--r1`. Note the r4 consequences of the order: the UPS HAT (B) is **2S 18650** with an **8.4 V DC** charge input (no PD), its gauge is an **INA219 at 0x42** (not 0x2D), the Touch Display 2's inner Pi holes are **51 × 49** so the Pi hangs on the case posts, and the ordered **Active Cooler does not fit** any variant. **r3 uses the same STLs as r2** and changes only the keyboard/radio configuration: the r1 Phistone Mini Keyboard over its 2.4 GHz dongle or Pi Bluetooth (see `docs/R3.md`). The chosen r2 parts are in `README.md` ("Target hardware"): Pi 5 (4 GB), DFRobot DFR0550-V2 5" DSI LCD, Waveshare UPS HAT (E) with 4× 21700 cells, recharged by solar (main) and a separate hand crank generator (backup, not built into the case) through one MPPT input and one sealed USB-C port, a **wired USB** keyboard for r2 (no Bluetooth; r3 uses the Phistone 2.4 GHz/Bluetooth keyboard), Pimoroni trackball for r2 (r3 omits it; the Phistone air mouse/touchscreen replaces it), BME688 (optionally SEN66), 1 TB NVMe, and the Pi 5 RTC with an ML-2020 cell. The ZimaBlade, the Pi 4 (no real power saving) and e-paper displays were considered and rejected; don't reintroduce them. No Wi-Fi, LAN, Bluetooth or sound by default. A Bluetooth or 2.4 GHz keyboard is an allowed input exception when reusing the r1 Phistone Mini Keyboard; the Pi's Wi-Fi/LAN stay off and the FireBeetle radios stay off. Nice to have: a DFRobot FireBeetle 2 ESP32-UE (N16R2, DFR1140) with a small 1.3" 4-pin I2C OLED (SH1106/SSD1306) (custom PlatformIO firmware in `firmware/`, all radios off) with at least 4 screens (time = default, battery, environment, storage %), a button to cycle them and auto-switching to the relevant screen when a threshold is passed; spec in `README.md` ("Status OLED"). Meshtastic/LoRa was considered and dropped; no hardware radio switch. When recommending or linking parts, prefer tinytronics.nl and bol.com; never Amazon. When modelling r2 parts, keep the existing r1 geometry working (add parameters or options rather than deleting) unless told otherwise.

**r5 has no air-quality sensor.** The r5 cassette leaves the left wall and the sensor chamber out; the BME688/SEN66 pocket only exists in r2/r3/r4 (r4 prints it too, so an r4 bottom shell still has it). Do not reintroduce `SENSOR_*` geometry into r5.

**Status OLED firmware (`firmware/`).** The board is the DFR1140 FireBeetle 2 ESP32-UE: **ESP32-WROOM-32UE-N16R2, not an ESP32-S3** (16 MB flash, 2 MB PSRAM, CH340). It needs the project-local board JSON in `firmware/boards/` (`dio_qspi`, `BOARD_HAS_PSRAM`, 16 MB partitions). Verified: 1.3" 4-pin SH1106 OLED at `0x3C`; SDA GPIO21 / SCL GPIO22 (header pins `21/SDA`, `22/SCL`). Button GPIO4 to GND (TinyTronics PBS-33B 12 mm panel button; add a rubber boot for sealing), BME688 `0x76/0x77` (r4 only — r5 has no sensor), DS3231 `0x68`, Waveshare UPS HAT (B) INA219 `0x42` (the older HAT (E) was `0x2D`). The display and 16 MB/2 MB PSRAM are confirmed working; the sensors, button and Pi-side serial sender are still to be brought up. Idle blanking is currently disabled with `-DSCREEN_OFF_MS=0UL` because the button is not fitted; the blank-screen report was the OLED display-off command, not ESP32 sleep. Details and serial protocol: `firmware/README.md`. The Pi sends a **UTC** epoch; the DS3231 stores UTC; the OLED applies `TIMEZONE` (default `CET-1CEST,M3.5.0,M10.5.0/3`, Europe/Amsterdam with DST) only when rendering.

Git repo. Commit or back up before large changes (an older version is also in `work/backup_v1/`). Tooling: OpenSCAD 2021.01 (CGAL, slow on many booleans), Python 3.

## Tools

For development phase use:

- for ESP32/OLED component, use the project venv: `source .venv/bin/activate` then `pio ...` (or `.venv/bin/pio`). The venv has PlatformIO and `intelhex`.
- r5 needs no firmware change for the missing sensor: `initBme688()` logs `BME688 not found` and the environment screen/alert simply never becomes valid (`env.valid` stays false). The environment page then shows the absence; do not add a stub.
-

## Commands

```bash
python3 cad/tools/export.py              # export all r4 parts to stl/ (binary, centred, on z=0), prints size + open-edge count
python3 cad/tools/export.py --r2         # export the previous r2/r3 set instead (DFR0550 + HAT (E) + Phistone)
python3 cad/tools/export.py --r1         # export the original r1 set instead (pull_switch, power_button)
python3 cad/tools/export.py --r5         # export the r5 cassette (r5_tray, r5_deck, r5_lid_plate)
python3 cad/tools/export.py face bottom  # export only some parts (names: bottom face keyboard_support charge_plug)
python3 cad/tools/render.py              # regenerate renders/*.png (after export; ktemata_* views use the STLs); args filter by name, e.g. asm_iso
bash work/scripts/check.sh               # r4 interference check (slow, minutes); R4=0 for r2/r3, R1=1 for r1
bash work/scripts/check_r5.sh            # r5 cassette interference check (HOST=1400 for the bigger host)
openscad -D 'CHECK="bottom:pi"' -o /tmp/x.stl cad/assembly.scad   # single interference pair
openscad -D R4=false -o /tmp/r2.stl cad/assembly.scad              # r2/r3 assembly (R2=false for r1)
openscad -o out.png --render --imgsize=1400,1100 --camera=75,90,17,60,0,35,430 cad/assembly.scad  # render preview
```

`bad edges: 0` from export.py means the mesh is manifold (no open edges, no edges shared by >2 faces, which slicers flag as non-manifold). Touching-but-not-overlapping solids (tangent bosses, flush faces) are the usual cause: overlap them by ≥0.5 mm. Any other value is a regression. In check.sh (r4 by default, `R4=0` for r2/r3, `R1=1` for r1), a "HIT" whose bbox is flat in one axis (or that throws an empty-bbox traceback) is a zero-volume contact and is expected. Only volumetric bboxes are real collisions.

## Architecture

- `cad/common.scad` is included by every part. It holds all shared parameters and helpers:
  - **Switches:** `R4 = is_undef(R4) ? R2 : R4` (r4 retarget, on by default) and `R2 = is_undef(R2) ? true : R2` (r2/r3 mechanics; false = r1). Every variant-dependent value is written as `pick(r4, r2r3, r1)`. The display, display holes, HAT/cell stack, keyboard body/pocket, OLED band, sensor pocket, charge port, floor layout and case depth are all conditional.
  - **Coordinate convention:** x = left→right seen from the front, y = top→bottom ("drawing" coords, top edge = charge-port / pull-switch side), z = 0 at the back surface rising toward the screen. Use `at(x, y, z)` to place things in drawing coords (it flips y to `L-y`). Raw `translate` uses real coords. Note that a cube placed with `at(x,y,z)` extends toward *smaller* drawing y; use `translate([0,-h,0])` for a positive drawing-y span.
  - Component positions are derived from each other. In r2 the stack is: display (DFR0550-V2) → Pi 5 → UPS HAT (E) → one row of 4× 21700. `CELL_*`, `UPS_*`, `DISP_*` and `DISP_POST` determine `T` and `H_BOT`; changing one moves the shell.
  - `outer_body()` is the full closed exterior z=0..T: chamfered body + grip ribs (`RIB_ZONES`) + corner bumpers (`BUMP*`). `bottom.scad` and `face.scad` each intersect it with their own z range (split at `H_BOT`), then subtract `inner_outline()`. Exterior styling changes belong here, not in the parts.
- Each part file (`bottom.scad`, `face.scad`, `keyboard_support.scad`, `charge_plug.scad`, and the r1-only `pull_switch.scad`/`power_button.scad`) models its part **in assembly position** (the plug is modelled print-ready) and only renders itself when `ASSEMBLY` is undefined. Pattern: `difference() { union() { solids } cuts }`.
- `assembly.scad` combines all parts with stand-in components (`EXPLODE`, `SECTION`, `CHECK` variables). It defines `part(name)` used for interference checks; r1 components return empty when `R2` is true and vice versa.
- **Hand crank generator** lives in its own project, [handcrank](https://github.com/jsoeterbroek/handcrank).
  It is a separate unit (not in the case, no shared code); do not add crank parts back to this repo.
- `export.scad` rotates parts into print orientation (face flipped, pull switch flipped). `tools/export.py` drives it and normalises placement; it skips the r1-only parts unless `--r1` is given.

## Design constraints

- Everything must print without supports in the orientation set in `export.scad`. The bottom prints back-plate down and the face prints face-plate down. So nothing may protrude beyond those bed faces. Overhangs must be ≤45° (hence the 45° edge chamfers and window bevels).
- Cuts through the side walls (Pi port windows, keyboard side cutout, SD slot) must extend past the rib/bumper protrusion. Bumpers and rib zones are sized to stay clear of these openings (e.g. `BUMP_LY` < first Pi port at y≈23).
- Screws are M2.5×10 from the back into pilot holes in the face (`BRASS_INSERT` option for heat-set inserts).
- r4 is 172 × 237 × 53 mm: width from the display plus walls and window border (the 151 × 59 × 11 mm K06 fits inside it), length from the portrait Touch Display 2 plus the 35.5 mm OLED band and the 59 mm K06, depth from the HAT (B) holder/cell side (23.35 mm; the board is mounted rotated 90° to clear the Pi's ports). The split plane moved to 38.55 mm (just above the Pi pcb) because the display is 14.92 mm deep; the display's own 8.5 mm standoffs span it and `face_part()` is clipped at `H_BOT`. The K06 pocket is entirely in the face part (body back at 39.97, above the plane). The K06 is **151 × 59 × 11** per its manual; the 155 × 89 × 16.5 on Rii's product page is the **i4**.
- r2 is 150 × 205 × 46.5 mm. The UPS HAT (E) sits on the Pi's component side (left-aligned, clear of the USB/Ethernet ports) and the 21700 cells sit in a single row below it (custom printed cradles, no stock 2×2 holder), which keeps the depth practical. r2 has no active cooler or 40-pin header; the 6.5 mm gap is for the UPS pogo pins. The status OLED band adds 22 mm to the length. The face holds a separate 1.3" 4-pin I2C OLED module (`OLED_*`); the FireBeetle 2 ESP32-UE board (`FB_*`) sits in a low tray in the bottom shell and connects with a short 4-wire cable. Check `README.md` ("r3 CAD implementation") for the assumptions to verify before printing.

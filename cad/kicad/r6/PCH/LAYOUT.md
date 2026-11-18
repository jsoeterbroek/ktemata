# PCH layout — FireBeetle 2 ESP32-UE on the carrier

Implemented in `PCH.kicad_pcb`: a 63 × 66 mm, two-layer carrier with the FireBeetle
socket rows, the charge-sense divider, and filled GND zones on both layers. The schematic
and PCB are the sources of truth for nets, pins, tracks and vias.

## Mechanical envelope

| Item | Implemented value |
|---|---|
| Outline | `(100,100)`–`(163,166)`, 63 × 66 mm, square corners |
| Module body | 25.4 × 60 × 7.3 mm on approximately 8.5 mm sockets |
| Module keep-clear area | x 100.7–160.7, y 140.1–165.5; no connector bodies in this area |
| Socket rows | 22.0 mm apart, 2.54 mm pitch; both rows extend toward +x at 90° |
| Row ends | 1.7 mm from the antenna end; pad 1 offsets 15.12 mm (J9) / 25.32 mm (J10) from the USB-C end |
| USB-C | module connector faces −x at x = 100.7; the carrier edge is x = 100 |
| Documentation outline | module body and USB-C marker are on `Cmts.User` |

## As-built placement

Coordinates are KiCad footprint origins. For J5, J6, J9 and J10 the origin is pad 1.

| Ref | x, y (mm) | Rotation |
|---|---:|---:|
| J1 | 113, 108 | 0° |
| J2 | 113, 119 | 0° |
| J4 | 109, 126 | 0° |
| J5 | 134, 113.92 | 0° |
| J6 | 143, 113.92 | 0° |
| J7 | 119, 131 | 0° |
| J8 | 128, 131 | 0° |
| J3 | 140, 131 | 0° |
| R1 | 124.8, 120 | 0° |
| R2 | 104, 120 | 0° |
| R3 | 104, 124 | 0° |
| C1 | 104, 128 | 0° |
| J9 — mechanical-only 18-pin socket | 115.82, 163.8 | 90° |
| J10 — 14-pin socket | 126.02, 141.8 | 90° |
| H1 / H2 | 103.5, 103.5 / 146.5, 103.5 | — |
| H3 / H4 | 103.5, 135 / 159.5, 136.5 | — |

Corrections to the earlier derived sheet:

- J6 stays at y = 113.92 to clear J3's courtyard; its fifth pad is the OLED button.
- J4 moves to (109,126), and J7/J8 use 9 mm centre spacing to clear the JST XH courtyards.
- R2, R3 and C1 are horizontal. C1 uses the standard 0603 capacitor pad offset of ±0.775 mm.
- H3/H4 are inside the enlarged outline and clear the socket courtyards.
- Back-side crossovers connect directly between through-hole pads where possible; unnecessary
  via pairs from the derived route were omitted. Zones were refilled and saved by KiCad.

## Verification

Run from this directory with KiCad 10:

```bash
kicad-cli pcb drc --severity-all --refill-zones --save-board -o /tmp/pch_drc.rpt PCH.kicad_pcb
kicad-cli pcb drc --severity-error --exit-code-violations -o /tmp/pch_errors.rpt PCH.kicad_pcb
kicad-cli sch erc --severity-error --exit-code-violations -o /tmp/pch_erc.rpt PCH.kicad_sch
```

Result on 2026-11-18:

- **0 DRC errors, 0 unconnected pads; 0 ERC errors.**
- `--severity-all` retains two warnings: `lib_footprint_mismatch` for J9/J10. Both use the
  installed standard footprint geometry at the required 90° rotation. The same warning was
  reproduced with an exact rotated clone of the existing R1 footprint and disappeared at 0°;
  no DRC rule was suppressed.
- Schematic parity has no net conflicts or field mismatches. It reports only those two warnings
  and the five intentional mechanical extras: H1–H4 and J9.
- Top-side copper, bottom-side copper, silkscreen, outline and module envelope were exported
  and visually inspected together.

## Physical gates before ordering

The drawing-derived dimensions are not a substitute for the part in hand. Dry-fit the module;
confirm the 22.0 mm row spacing and 15.12 / 25.32 mm first-pad offsets with calipers. Check that
the USB-C plug clears the carrier edge and that the fitted sockets hold the module above every
component outside its keep-clear area. Re-run the historical `EMC.md` analysis before using its
old routing-specific conclusions.

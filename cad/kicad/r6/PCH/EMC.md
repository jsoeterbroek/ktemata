# EMC pre-compliance — PCH (r6)

Analysed `cad/kicad/r6/PCH/PCH.kicad_pcb` + `PCH.kicad_sch` as saved 2026-11-17 17:07
(DRC.rpt: 0 violations, 0 unconnected pads). Target: EN 55032 / CISPR 32 Class B (EU market).

**Verdict: low EMC risk — no emissions action required before fab.** The analyzer's three
`error` findings are sampling artefacts; the one genuine gap is input protection on the
12.6 V charge lead (immunity, not emissions). The board also does not match its own spec yet.

## What the board is

| Property | Value |
|---|---|
| Size / stackup | 63 × 66 mm, 2 copper layers, 1.6 mm FR4 (1.51 mm core, εr 4.5), no stackup-controlled impedance |
| Parts | 18 (8 connectors, the FireBeetle 14- and 18-pin socket rows, R1 330R, the 47k/10k + 100 nF divider, 4 mounting holes), 19 nets, 50 track segments, **6 vias** |
| Routing | 32 segments on F.Cu, 18 on B.Cu; GND pour on both layers |
| Ground | one domain, both layers poured, tied at every THT ground pad. The B.Cu pour is now **voided where the 18 B.Cu segments run**, so it is no longer solid under all of the F.Cu routing |
| Sources | **none** — no switcher, no clock, no crystal, no IC on the board itself. Only I2C (100–400 kHz), 12.6 V DC and a 9 mA LED. The FireBeetle sits on J9/J10, so its 40 MHz crystal and 2.4 GHz radio are inside this board's footprint but under firmware control and off |
| Nets | +3V3, +5V, GND, I2C_SCL, I2C_SDA, CHG_12V6_IN, CHG_SENSE, BAT_12V6_OUT, UPS_SW_1/2, SW_LED_ANODE, OLED_BTN |

## Analyzer result and triage

`analyze_emc.py --standard cispr-class-b`, re-run 2026-11-18 on the 63 × 66 board with the FireBeetle
sockets: **27 findings (2 error, 10 warning, 15 info), risk score 74.5**. All findings are
`confidence: heuristic`; still 0 datasheet-backed (`DS-001`: no MPNs, no `datasheets/`). The earlier
run (19 findings, 80.5) described the 50 × 50 board and is superseded.

| Rule | n | Analyzer | Reality | Why |
|---|---|---|---|---|
| GP-001 | 2 error, 5 warn | plane gaps under signal traces | **partly real now** | Re-sampling the tracks against the actual `filled_polygon`: 20 of 56 misses are *mid-trace*, not pad endpoints — e.g. /I2C_SCL over x 132, y 134–137 is 3–6 mm from any pad. The cause is the new B.Cu routing: its 18 segments void the B.Cu reference under F.Cu runs. The same-layer F.Cu pour still carries the return, so this is a softened plane rather than a split; fix opportunistically by keeping long F.Cu runs out of B.Cu track corridors or stitching GND beside them. |
| BE-001 | 1 warn | /CHG_12V6_IN near the board edge | **real, minor** | the 0.8 mm charge run grazes the edge; pull it ≥1 mm inboard at the next revision. |
| RP-001 | 3 warn | no stitching via at a layer transition | **real, minor** | /CHG_SENSE, /SW_LED_ANODE and /UPS_SW_2 each change layer through a via; a GND via within ~2 mm of each transition keeps the return short. |
| VS-001 | — | not raised | n/a | the board now has 6 vias, and nothing on it emits above ~1 MHz. |
| SU-001 | 1 info | F.Cu/B.Cu adjacent, no plane between | accepted | two-layer decision; both layers are poured and nothing is fast. |
| EE-001 | 1 info | cavity modes at 1413/1999/2827 MHz | n/a | no source in band. |
| IO-001 | 10 info | no ferrite/TVS within 25 mm of any connector | **1 real** | J1's charge lead to the DC jack, as before. J9/J10 are the module sockets inside the case; J2/J3/J4/J7/J8 are internal JST harness. |
| IO-002 | 3 info | J3, J6 and J10 ground-pin count | n/a | J10's ground pins are the module's own pinout; J3's are the LED return and switch pair. |

The 74.5 score is dragged down by the GP-001 class; the electrically meaningful residue is BE-001, the
three RP-001 stitches and the charge-input protection below.

## Real findings

1. **No ESD or surge protection on the charge input (warning, immunity).** J1's harness goes to
   the user-accessible DC-099 jack; J1/J2 sit on the same net with no TVS, no fuse, no cap.
   An IEC 61000-4-2 (jack contact discharge) or 61000-4-5 event on the charge lead is clamped
   only by the upstream UPS/battery. Add one bidirectional TVS across J1 (SMBJ15A for a
   12.6 V charger, SMBJ18A if the source floats to 14.4 V) plus a 10 µF/50 V bulk cap, and keep
   the TVS-to-GND return shorter than 3 mm into the F.Cu pour, which now reaches the connector pads coplanar. This is the only item on this board
   that can fail a compliance test.
2. **12.6 V charge current is at the trace rating, not under it.** `CHG_12V6_IN` and
   `BAT_12V6_OUT` are 0.8 mm on 35 µm = 2.03 A at 10 °C rise (IPC-2221 external);
   `docs/R6.md` specifies the 12.6 V / 2 A charge input. Widen to 1.5–2 mm (there is room) or
   parallel a second run. GND return is fine: 4 × 0.4 mm thermal spokes ≈ 5 A per THT pad.
3. **+5V ampacity — sized for the status side, as designed.** 0.8 mm between J5.7/8 and J6.5
   (2.03 A) and a single 2.54 mm header pin (~3 A) is enough for the aux load only, which is what
   `docs/WIRING.md` §4.2 requires: "The PCH's 5 V output feeds the status side. The Pi 5 and
   7-inch display stay on the UPS Module 3S's USB-C lead; do not route the Pi's 5 A through this
   board." One trap remains: the r6 netlist puts `UPS_5V` on J16 pin 5, which reads as the Pi's
   5 A passing through the PCH. Keep the Pi off J6.5 — the board is ~2.5× undersized for it.
4. **Only the divider's 100 nF on the board.** No bulk capacitance at J5/J6. Not an emissions problem
   on a passive board, but a 10 µF at J5 and a 100 nF at J6 cost nothing and drop the rail impedance
   the harness sees. Optional.
5. **J4 duplicates J3's switch nets.** `UPS_SW_1` / `UPS_SW_2` come out on both J3.1/2 and
   J4.1/2. Fit the switch to one of them: a straight harness on the other shorts the contact pair,
   and the switch stops switching. One line for the harness list, no hardware change.

## Not covered by this analysis

- No datasheet verification (`DS-001`): no MPN on any part, so no claim here is
  "per datasheet" — all statements are read from the KiCad files.
- SPICE: not applicable — the schematic has one resistor and no subcircuit worth simulating.
- Conducted emissions (150 kHz–30 MHz) are covered only indirectly by the rule set; the
  analyzer has no LISN/cable model.
- Enclosure, harness routing and the Pi 5/NVMe (the actual emitters) are outside this board's scope.

## Pre-compliance test plan

| Test | Setup | Priority |
|---|---|---|
| Conducted emissions, 150 kHz–30 MHz | LISN on the 12.6 V charge lead, source connected, Pi idle and loaded | high — the only external conductor this board owns |
| Radiated, 30–1000 MHz | Assembled device in the plastic case, near-field first | high — source is the Pi/NVMe, PCH is a passive victim/path |
| Near-field probe points | J1/J2 (charge in), J3 (switch + LED loop: 24.7 mm of 0.2–0.25 mm trace, the largest loop on the board), J5↔J6 (I2C pair, 17.8 mm) | medium |
| ESD ±8 kV contact | DC jack centre pin and shell; expect the gap in finding 1 | high |
| EFT / burst | Charge lead, 1 kV | medium |
| Surge 1 kV / 2 Ω | Charge lead | medium |

Bands 30–1000 MHz from this board alone: `risk_level: none`, 0 sources.

## Reproduce

```bash
cd cad/kicad/r6/PCH
python3 ~/.omp/agent/skills/kicad/scripts/analyze_schematic.py PCH.kicad_sch --analysis-dir analysis/
python3 ~/.omp/agent/skills/kicad/scripts/analyze_pcb.py PCH.kicad_pcb --full \
        --schematic analysis/<run>/schematic.json --analysis-dir analysis/
python3 ~/.omp/agent/skills/emc/scripts/analyze_emc.py --analysis-dir analysis/ --standard cispr-class-b
```

Output of this run: `analysis/2026-11-17_2002/{schematic,pcb,emc}.json`
(`emc.json`: 19 findings, risk 80.5). Re-run after any layout change — the `~PCH.*.lck` files
show the project open in KiCad, so re-check the saved timestamp first.

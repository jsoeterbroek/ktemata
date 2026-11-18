# EMC pre-compliance — PCH (r6)

Analysed `cad/kicad/r6/PCH/PCH.kicad_pcb` + `PCH.kicad_sch` as saved 2026-11-17 17:07
(DRC.rpt: 0 violations, 0 unconnected pads). Target: EN 55032 / CISPR 32 Class B (EU market).

**Verdict: low EMC risk — no emissions action required before fab.** The analyzer's three
`error` findings are sampling artefacts; the one genuine gap is input protection on the
12.6 V charge lead (immunity, not emissions). The board also does not match its own spec yet.

## What the board is

| Property | Value |
|---|---|
| Size / stackup | 50 × 50 mm, 2 copper layers, 1.6 mm FR4 (1.51 mm core, εr 4.5), no stackup-controlled impedance |
| Parts | 9 (8 connectors + R1 330R), 10 nets, 28 track segments, **0 vias** |
| Routing | all 28 segments on F.Cu; GND pour on **both** layers — B.Cu 2211.0 mm² (**88 %**), F.Cu 1930.3 mm² (**77 %**, lower only because the tracks and pads void it) |
| Ground | one domain, both layers poured, no splits; every GND pad is a THT barrel, so the pours are tied together at all nine ground pins on the seven connectors that have one |
| Sources | **none** — no switcher, no clock, no crystal, no IC. Only I2C (100–400 kHz), 12.6 V DC and a 9 mA LED |
| Nets | +3V3, +5V, GND, I2C_SCL, I2C_SDA, CHG_12V6_IN (J1↔J2), BAT_12V6_OUT (J7↔J8), UPS_SW_1/2 (J3.1–2 ↔ J4.1–2), SW_LED_ANODE |

## Analyzer result and triage

`analyze_emc.py --standard cispr-class-b`: 19 findings (3 error, 5 warning, 11 info),
risk score **80.5**; 18 of 19 are `confidence: heuristic`, 0 datasheet-backed
(`DS-001`: no MPNs, no `datasheets/`).

| Rule | n | Analyzer | Reality | Why |
|---|---|---|---|---|
| GP-001 | 3 error, 4 warn | plane gaps, 50–94 % coverage | **false positive** | Every miss is a trace *endpoint* sitting inside a pad's clearance + 0.5 mm thermal void (0.85–1.0 mm from the pad centre). Re-sampling all 80 points against the actual `filled_polygon` gives 100 % coverage away from pads. The pour spans x 96.3–153.3, y 97–152 and is clipped to the 100–150 outline: there is no split, slot or island chain anywhere on the board. |
| VS-001 | 1 warn | "0 vias, 150 MHz, stitch ≤48 mm" | **N/A** | 150 MHz is the tool's 50 MHz default ×3; nothing on the board emits above ~1 MHz. With one plane layer and nothing to stitch to, vias would add no return path. |
| SU-001 | 1 info | F.Cu/B.Cu adjacent, no plane between | **accepted** | True but moot: all routing is on F.Cu, with the same-layer F.Cu pour beside it and the 88 % B.Cu pour underneath, and nothing is fast. Correct 2-layer decision — keep it. |
| EE-001 | 1 info | cavity modes at 1413/1999/2827 MHz | **N/A** | Board cavities only matter with a source in band; there is none. |
| IO-001 | 8 info | no ferrite/TVS within 25 mm of any connector | **1 of 8 real** | J5/J6 carry 100–400 kHz I2C over a ~140 mm internal harness, J2/J3/J4/J7/J8 are internal JST harness inside a plastic case: no filtering needed. J1 is the charge lead to the DC jack — see below. |
| IO-002 | 1 info | J3 has 1 GND pin for 3 signals | **N/A** | J3's "signals" are the 9 mA LED return and one switch contact pair. |

Adjusted score with GP-001 and VS-001 removed: **98.5** (worst remaining penalty is VS-001).

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
4. **No decoupling on the board at all.** Zero capacitors. Not an emissions problem on a passive
   board, but a 10 µF + 100 nF at J5 and J6 costs nothing and drops the rail impedance the harness
   sees. Optional.
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

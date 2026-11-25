# EMC pre-compliance — PCH (r6)

Analysed `cad/kicad/r6/PCH/PCH.kicad_pcb` + `PCH.kicad_sch` as saved 2026-11-25
(DRC: 0 violations, 0 unconnected pads). Target: EN 55032 / CISPR 32 Class B (EU market).

**Verdict: no emissions action required before fab.** The board is a passive 12.6 V / 5 V
pass-through. Every analyzer finding is heuristic and either describes a DC rail or a connector
whose cable is internal to the product.

## What the board is

| Property | Value |
|---|---|
| Size / stackup | 63 × 66 mm, 2 copper layers, 1.6 mm FR4 (1.51 mm core, εr 4.5), no controlled impedance |
| Parts | 7 footprints: J5 (UPS 2×4 header), J7 (12.6 V in), J8 (aux 12.6 V out), 4 mounting holes |
| Routing | 4 track segments, 0 vias; GND pour on both layers |
| Nets | `+5V`, `GND`, `BAT_12V6_OUT`; J5 pads 1–4 are no-connect |
| Sources | **none** — no switcher, clock, crystal or IC on the board. Only DC and a 12.6 V harness |
| External I/O | none. J5 is the UPS header, J7/J8 are internal JST-XH harness connectors |

The charge lead and the UPS button plug directly into the UPS Module 3S, not into this board. The
R6 status controller, display, button and sense tap are not fitted, so the board has no I2C, no
3.3 V rail and no ADC divider.

## Analyzer result and triage

`analyze_emc.py --standard cispr-class-b`, run 2026-11-25 on the 63 × 66 board: **7 findings
(1 error, 1 warning, 5 info), risk score 92.5**. All findings are `confidence: heuristic`; 0
datasheet-backed (no MPNs).

| Rule | n | Analyzer | Reality | Why |
|---|---|---|---|---|
| GP-001 | 1 error | `BAT_12V6_OUT` has 78 % reference-plane coverage over 16 mm | **not real for this net** | The net is a DC 12.6 V branch. The same-layer F.Cu pour and the THT connector pads carry the return; a 22 % sampling gap on a DC trace is not a loop antenna |
| VS-001 | 1 warn | 0 stitching vias; 150 MHz λ/20 spacing | n/a | Defaults assume a 150 MHz source; this board has none. The F.Cu and B.Cu pours are tied through every THT pad |
| IO-001 | 3 info | no ferrite/TVS within 25 mm of J5, J7, J8 | accepted | J5 is the UPS module header; J7/J8 are internal harness connectors inside the same enclosure. Protection and filtering belong to the UPS |
| SU-001 | 1 info | F.Cu/B.Cu adjacent, no plane between | accepted | two-layer decision; both layers poured, nothing fast |
| EE-001 | 1 info | cavity modes at 1071/1122/1551/2141/2243 MHz | n/a | no source in band |

The 92.5 score is dominated by the GP-001 heuristic; the electrically meaningful residue is the
12.6 V track width below.

## Real findings

1. **12.6 V track is at the 2 A rating.** `BAT_12V6_OUT` between J7 and J8 is 0.8 mm on 35 µm =
   2.03 A at 10 °C rise (IPC-2221 external). The R6 12.6 V branch is specified at 2 A, and J8 is
   unused in the current build, so this is adequate. Widen to 1.5 mm if J8 is ever loaded at the
   full branch current.
2. **No bulk capacitance on the board.** Not an emissions problem on a passive board; the UPS
   output and the Pi/display harness own the rail impedance. Optional: 10 µF/16 V at J7.
3. **J5's +5V pair is unused.** Pins 7/8 are commoned by a 2.54 mm segment. Nothing consumes the
   5 V on this board; it is carried only to keep the header pinout identical to the UPS.

## Not covered by this analysis

- No datasheet verification (`DS-001`): no MPN on any part; every statement is read from the KiCad
  files.
- SPICE: not applicable — the board has no subcircuit.
- Conducted emissions (150 kHz–30 MHz) are covered only indirectly by the rule set; there is no
  LISN or cable model.
- Enclosure, harness routing and the Pi 5/NVMe (the actual emitters) are outside this board's scope.

## Pre-compliance test plan

| Test | Setup | Priority |
|---|---|---|
| Radiated, 30–1000 MHz | assembled device, flat open; PCH 12.6 V harness in place | high — the PCH is a passive path, the Pi/NVMe are the sources |
| Conducted emissions, 150 kHz–30 MHz | LISN on the supplied adapter's AC lead | high — the UPS charges through it |
| ESD ±8 kV contact | external DC jack and USB ports; not on the PCH | high |
| EFT / burst | charge lead at the UPS entry, 1 kV | medium |
| Near-field probe points | PCH J7/J8 12.6 V harness, J5 UPS header | low |

Bands 30–1000 MHz from this board alone: `risk_level: none`, 0 sources.

## Reproduce

```bash
cd cad/kicad/r6/PCH
kicad-cli pcb drc --severity-all --refill-zones -o /tmp/pch_drc.rpt PCH.kicad_pcb
python3 ~/.omp/agent/skills/kicad/scripts/analyze_schematic.py PCH.kicad_sch --analysis-dir analysis/
python3 ~/.omp/agent/skills/kicad/scripts/analyze_pcb.py PCH.kicad_pcb --full \
        --schematic analysis/<run>/schematic.json --analysis-dir analysis/
python3 ~/.omp/agent/skills/emc/scripts/analyze_emc.py --analysis-dir analysis/ --standard cispr-class-b
```

Output of this run: `analysis/2026-11-25_0709-2/{schematic,pcb,emc}.json`
(`emc.json`: 7 findings, risk 92.5). Re-run after any layout change.

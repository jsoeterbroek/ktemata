# EMC pre-compliance — r6 (system)

**There is no r6 PCB to analyse.** `ktemata.kicad_pcb` is an empty 79-byte stub (0 footprints,
0 tracks, no outline); the r6 project is a 4-sheet interface hierarchy (`ktemata`, `power`, `pi`,
`mcu`) with 16 connector-shaped module symbols and 25 nets. The only laid-out board in this folder
is the PCH sub-project — its EMC review is [`PCH/EMC.md`](PCH/EMC.md) and is not repeated here.

So this document is a **system-level EMC assessment and a board-layout requirement set**, not a
layout check. It states what the tools could and could not do, ranks the r6 interfaces that will
drive emissions, and gives the test plan for the assembled device.

## What the tools produced, and why it is not a result

`analyze_emc.py --analysis-dir analysis/ --standard cispr-class-b` on the r6 project returns
**2 findings, risk score 98.5** — and neither means anything:

| Rule | Severity | Text | Reality |
|---|---|---|---|
| GP-001 | info | "Return path not checked: no ground or power plane fill" | Correct: the board file has no zones. |
| VS-001 | warning | "0 vias across 2500 mm² (no vias detected) … 150 MHz" | Neither figure exists. `2500 mm²` is the analyser's default area and `150 MHz` is its 50 MHz default ×3; the stub has no outline and no area. |

Schematic side: `DS-001` (no MPNs, no `datasheets/`) and `SS-001` (0/16 MPN coverage) are the only
error-severity items, plus `RS-001` ×2 for rails that a block diagram cannot source. The score of
98.5 must **not** be read as a good design — an empty board has nothing to score.

## What actually emits in r6

Ranked from the published hardware in `docs/R6.md` / `docs/BOM.md`, all `[INFERENCE]` from the
datasheet-level numbers there unless marked:

| # | Path | Rate | Harmonics in the 30–1000 MHz band | Ranking |
|---|---|---|---|---|
| 1 | Pi 5 → 7" DSI LCD (C), FFC inside the cassette | 1024×600 RGB888 @ 60 Hz = 884.7 Mbit/s payload; ≈221 MHz lane clock over 2 lanes | 221 / 442 / 663 / 884 MHz (≈110 MHz spacing if 4 lanes) | **highest** — the longest unshielded ribbon in the product |
| 2 | Pi 5 → NVMe Base Duo, PCIe Gen 2 ×1 through the ASM1182e | 5 GT/s serial; 100 MHz refclk | refclk harmonics every 100 MHz, 100→1000 MHz | high |
| 3 | Pi 5 USB (K06 dongle) | USB 2.0 HS 480 Mbit/s | 240 MHz + harmonics | medium |
| 4 | Active Cooler fan | PWM ~25 kHz + brush commutation | broadband floor, 30–300 MHz | medium-low |
| 5 | OLED/button harness across the hinge (I2C, 5 conductors) | 100–400 kHz, ≈100 ns edges ≈3.5 MHz BW | below the 30 MHz test floor | low |
| 6 | 12.6 V / 2 A charge lead (adapter, solar or crank) | DC | only the source's ripple/switch noise | low from the device side |
| 7 | INA219 / DS3231 / OLED I2C, PCH rails | ≤400 kHz | none | none |

Two things that are **not** emitters in this design: the FireBeetle's radios are off (`AGENTS.md`),
and the K06's 2.4 GHz link is an intentional radiator in a separately CE/RED-marked dongle — it
does not fall under CISPR 32, but it does set a coexistence constraint (below).

The enclosure contributes no mitigation: the Peli 1200 is plastic and R6's operating posture is
flat-open. All filtering and return-path work has to happen on the harnesses and boards.

## Layout requirements for the r6 boards (apply when drawn)

Nothing here is optional for the two boards that carry the high-rate links; the passive PCH-class
parts can stay 2-layer as built.

1. **Stackup.** Any board carrying DSI or PCIe is 4-layer (F.Cu / GND / PWR / B.Cu) with an
   uninterrupted GND plane under every differential pair. A 2-layer board is fine for the 12.6 V /
   5 V / 3V3 / I2C distribution class (PCH already proves it: 88 % B.Cu fill, all routing on F.Cu).
2. **Differential pairs.** DSI 100 Ω, PCIe 85–90 Ω, both referenced to the same plane from end to
   end, no layer changes, no stubs at the FFC connector, skew inside the protocol limit (DSI
   intra-pair <25 ps, PCIe <5 ps). Ground pins on the FFC connector stitched to the plane
   immediately beside the pair.
3. **FFC/FPC tails.** Plane under the connector tail, no signal crossing a plane split, keep the
   DSI lead inside the cassette (R6's architecture already does this — do not route it across the
   hinge).
4. **Connector filtering.** Every internal harness connector gets one GND pin per signal pair or
   better; do not repeat PCH's J3 pattern (1 GND for 3 signals) on a new board. External-facing
   conductors (charge input) get TVS + bulk cap at the connector, per `PCH/EMC.md` finding 1.
5. **Charge input conditioning.** The supplied 12.6 V/2 A adapter is its own product under the EMC
   directive; a solar or crank source is not, and its ripple is unbounded. Put a common-mode choke
   plus the TVS on the charge entry, and keep the chassis/earth return short.
6. **Rails.** Size traces to the stated current (the Pi rail is rated 5 A and this build peaks
   ≈2.8 A per `BOM.md`; 1 mm of 35 µm copper is 2.4 A at 10 °C rise). Decouple at each connector,
   not only at the source.
7. **Fan.** Treat the Active Cooler lead as a noise source: twisted pair, 100 nF across the fan
   terminals for a 2-wire fan, return to the Pi's ground plane, not to a harness.
8. **Hinge harness.** I2C pair with an adjacent GND wire, 33–100 Ω series resistors at the
   FireBeetle end, no long stubs, and a keyed connector as `R6.md` already requires.
9. **Coexistence.** Keep the K06's 2.4 GHz dongle out of the near field of the DSI FFC — a ribbon
   carrying 221 MHz edges next to a 2.4 GHz receiver is a desense risk, not an emissions one.

## Product-level test plan

Test the assembled, flat-open device; the boards are not separable for compliance purposes.

| Test | Setup | Priority |
|---|---|---|
| Radiated, 30–1000 MHz | 3 m, CISPR 32 Class B; display on, NVMe under load, fan on, keyboard dongle plugged | **high** — DSI and PCIe are the sources |
| Radiated, 1–6 GHz | 3 m; PCIe Gen 2 and the 2.4 GHz dongle | medium |
| Conducted, 150 kHz–30 MHz | LISN on the supplied adapter's AC lead, device charging and running | high — adapter is the only mains port |
| Conducted, 150 kHz–30 MHz | LISN/replacement-source on the 12.6 V charge lead with a solar or crank source connected | medium — unbounded source ripple |
| ESD, EN 61000-4-2 ±8 kV contact / ±15 kV air | DC jack, keys, USB port, case seams | high (no TVS exists anywhere today) |
| EFT, EN 61000-4-4 1 kV | charge lead | medium |
| Surge, EN 61000-4-5 1 kV / 2 Ω | charge lead | medium |
| Radiated immunity, EN 61000-3/4, 80 MHz–6 GHz | display link and I2C must not drop; watch for DSI flicker and I2C lockups | **high** — plastic case, no shielding |

Pre-scan probe points before the lab: DSI FFC tail, the PCIe FPC at both ends, the fan lead, the
12.6 V harness at the DC jack, and the hinge harness.

## Gaps and limits

- No layout exists, so no rule in the 44-rule set can be evaluated; the two findings above are
  defaults, not results.
- No MPNs and no `datasheets/`, so nothing here is datasheet-verified (`DS-001`); part numbers come
  from `docs/BOM.md` prose only.
- SPICE is not applicable: the r6 sheets contain no subcircuit, only module symbols.
- The DSI lane count and the panel's lane rate are inferred from the 884.7 Mbit/s payload; confirm
  against the Waveshare wiki before sizing the pair impedance requirement.
- Module-level compliance (Pi 5, UPS Module 3S, DSI panel, NVMe base, adapter) is the
  manufacturer's; integrating them still makes the assembled product the subject of EN 55032/55035.

## Reproduce

```bash
cd cad/kicad/r6
python3 ~/.omp/agent/skills/kicad/scripts/analyze_schematic.py ktemata.kicad_sch --analysis-dir analysis/
python3 ~/.omp/agent/skills/kicad/scripts/analyze_pcb.py ktemata.kicad_pcb --full \
        --schematic analysis/<run>/schematic.json --analysis-dir analysis/
python3 ~/.omp/agent/skills/emc/scripts/analyze_emc.py --analysis-dir analysis/ --standard cispr-class-b
```

This run: `analysis/2026-11-17_2005/{schematic,pcb,emc}.json` (16 blocks, 25 nets, 0 footprints,
2 vacuous findings, risk 98.5). Re-run unchanged until `ktemata.kicad_pcb` has real geometry.

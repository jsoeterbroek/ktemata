# PCH wiring verification report

**Date:** 2026-11-25
**Status:** verified — ERC and DRC clean

## Design summary

The R6 PCH is a power/charge carrier only. The separate status subsystem was removed: no status
controller, no display, no display button, no status clock, no charge-sense tap. The board keeps:

- **J5** — Waveshare UPS Module 3S 2×4 header
- **J7** — UPS 12.6 V branch in
- **J8** — 12.6 V auxiliary output (unused in the current build)
- four M2.5 mounting holes

## Verified net topology

| Net | Pins | Status |
|---|---|---|
| `+5V` | J5.7, J5.8 | OK — UPS 5 V pair, no consumer on this board |
| `BAT_12V6_OUT` | J7.1, J8.1 | OK — 12.6 V feed-through |
| `GND` | J5.5, J5.6, J7.2, J8.2 | OK — both-layer pour |
| no-connect | J5.1, J5.2, J5.3, J5.4 | OK — UPS I²C pair and both 3V3 pins marked NC |

No other net exists. `PCH.net` exported from the schematic lists exactly these three nets and the
four unconnected pads.

## Removed with the status subsystem

J1 (charge-sense tap), J6 (lid harness), J9/J10 (controller socket rows), J11 (display header),
R2/R3/C1 (charge-sense divider and filter), and all status-only nets (charge input/sense, 3.3 V,
I²C and the display button). Their footprints, tracks and vias were deleted from the PCB, J5 pads
1–4 are now no-connect, and the two GND pours were refilled.

## Checks run

```bash
kicad-cli sch erc --severity-all -o /tmp/pch_erc.rpt PCH.kicad_sch
# 0 errors, 6 warnings — all lib_symbol_mismatch (project symbols are embedded)

kicad-cli pcb drc --severity-all --refill-zones -o DRC.rpt PCH.kicad_pcb
# 0 violations, 0 unconnected pads, 0 footprint errors
```

The board is a power-only carrier with 7 footprints, 4 track segments, 0 vias and two GND pours.
It is ready for fabrication from `gerbers/`.

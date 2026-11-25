## Power / charge carrier board (PCH)

The PCH is the r6's 12.6 V power pass-through: a single-sheet, 63 × 66 mm two-layer board with no
conversion, protection or controller. It carries the Waveshare UPS Module 3S 2×4 header, the UPS
12.6 V branch in and the 12.6 V auxiliary output. The R6 status controller, its display and its
button are not part of this board or project.

Nets and pins are in [`PCH.kicad_sch`](PCH.kicad_sch); assembly practice is in
[`docs/WIRING.md`](../../../../docs/WIRING.md) §3.

| Connector | Pads | Nets | Job |
|---|---|---|---|
| J5 `UPS3S_HDR_2X4` | 8 | 5/6 `GND`, 7/8 `+5V`; 1–4 no-connect | UPS Module 3S 2×4 header. The UPS I²C pair and both 3V3 pins are deliberately open: nothing on the R6 PCH consumes them |
| J7 `UPS_12V6_IN` | 2 | 1 `BAT_12V6_OUT`, 2 `GND` | UPS 12.6 V branch in |
| J8 `AUX_12V6_OUT` | 2 | 1 `BAT_12V6_OUT`, 2 `GND` | same net as J7 — feed-through 12.6 V aux outlet (unused in the current build) |

The only components on the board are those three connectors and four M2.5 mounting holes. There is
no active part, no clock and no I/O beyond the two power connectors and the UPS header.

The supplied DC5521 charge lead and self-lock button plug directly into the UPS; neither is routed
through the PCH. No charge current passes through the board.

## Deliberately not on this board

- **No fuse.** The UPS Module 3S protects the in-module pack; a pack built outside it carries its
  own fuse in the pack's positive lead (`docs/WIRING.md` §2).
- **No charge-sense divider.** The sense tap and its 47k/10k/100 nF filter were removed together
  with the status controller; nothing on R6 measures the charge input.
- **No controller, display, button or status clock.** The R6 status subsystem was removed from the
  hardware.
- **No Pi or display power.** The Pi 5 and the 7-inch panel stay on the UPS's own USB-C lead
  (`docs/WIRING.md` §2).

## Checks and build files

```bash
kicad-cli sch erc --severity-all -o /tmp/pch_erc.rpt PCH.kicad_sch   # 0 errors
kicad-cli pcb drc --severity-all -o DRC.rpt PCH.kicad_pcb            # 0 violations, 0 unconnected
```

The exported netlist is [`PCH.net`](PCH.net); the parts list is [`PCH.csv`](PCH.csv); fabrication
data is in [`gerbers/`](gerbers/). ERC reports only `lib_symbol_mismatch` warnings because the
project symbols are embedded in the schematic.

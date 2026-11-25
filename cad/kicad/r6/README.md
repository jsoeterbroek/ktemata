# KiCad 10.0

## CLI
Use the cli to edit, create kicad files, kicad-cli location:
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli

## Design rules check
Check design rules after each edit, eg.:
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli pcb drc PCH/PCH.kicad_pcb

# R6 system project

`ktemata.kicad_pro` is a three-sheet A4/A3 wiring project:

| Sheet | File | Contents |
|---|---|---|
| `/` | `ktemata.kicad_sch` | index and reading notes |
| `/Power` | `power.kicad_sch` | 12.6 V input, UPS Module 3S, PCH block (J16), switch and 3S pack |
| `/Pi 5 and its peripherals` | `pi.kicad_sch` | Pi 5, Waveshare 7-inch DSI display, NVMe Base Duo, keyboard, RTC cell |

Nets leave a sheet as global labels; `ktemata_r6_connections.csv` is generated from the exported
netlist:

```bash
kicad-cli sch export netlist --format kicadxml -o /tmp/ktemata_r6.xml ktemata.kicad_sch
python3 ../../../work/scripts/kicad_netlist_csv.py /tmp/ktemata_r6.xml \
  -o ktemata_r6_connections.csv
```

There is no MCU/status sheet. The R6 status subsystem (controller, display, display button and
status clock) was removed from the hardware, and with it the `3V3`, `CHG_SENSE`, I²C and
display-button nets. The Pi 5 sheet keeps the display, storage, keyboard and RTC cell.

# Power / charge carrier board (PCH)

[`PCH/`](PCH/) is a separate single-sheet project and a 63 × 66 mm two-layer board. It is a
power-only carrier with three connectors:

| Connector | Nets | Job |
|---|---|---|
| J5 `UPS3S_HDR_2X4` | `GND` (5/6), `+5V` (7/8); 1–4 NC | Waveshare UPS Module 3S header |
| J7 `UPS_12V6_IN` | `BAT_12V6_OUT`, `GND` | UPS 12.6 V branch in |
| J8 `AUX_12V6_OUT` | `BAT_12V6_OUT`, `GND` | 12.6 V auxiliary output |

There is no conversion, protection, controller, display or charge-sense divider on the board.
Parts are in [`PCH/PCH.csv`](PCH/PCH.csv); fabrication data is in [`PCH/gerbers/`](PCH/gerbers/).
The board checks clean: ERC 0 errors (embedded-symbol warnings only) and DRC 0 violations,
0 unconnected pads. Details and the EMC review are in [`PCH/README.md`](PCH/README.md) and
[`PCH/EMC.md`](PCH/EMC.md); the system-level EMC assessment is [`EMC.md`](EMC.md).

`PCH.net` is the exported netlist and `PCH.kicad_pcb` the board.

# KiCad 10.0

## CLI
Use the cli to edit, create kicad files, kicad-cli location:
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli

## Design rules check
Check design rules after each edit, eg.:
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli pcb drc PCH/PCH.kicad_pcb

# Power Distribution & Communication Hub (PCH) carrier board

The PCH is the r6's 12.6 V / aux-rail / I2C carrier: a single-sheet, 63 × 66 mm two-layer
board with no conversion or protection. It carries the FireBeetle 2 ESP32-UE socket rows and the
charge-sense divider; the module itself is removable. Nets and pins are in
[`PCH.kicad_sch`](PCH/PCH.kicad_sch); assembly practice is [`../../docs/WIRING.md`](../../docs/WIRING.md) §4.

| Connector | Pads | Nets | Job |
|---|---|---|---|
| J1 `CHG_SENSE_IN` | 2 | `CHG_12V6_IN`, `GND` | high-impedance sense tap on the supplied DC5521 input; no charge current passes through the PCH |
| J5 `UPS3S_HDR_2X4` | 8 | `I2C_SCL`, `I2C_SDA`, `+3V3` ×2, `GND` ×2, `+5V` ×2 | UPS Module 3S interface |
| J6 `LID_I2C_BTN` | 5 | See schematic | lid I²C, power and OLED-button harness |
| J9 / J10 `FB18_ESP32-UE` / `FB14_ESP32-UE` | 18 + 14 | See schematic | FireBeetle 2 ESP32-UE sockets; J9 carries the tested OLED connections |
| J11 `OLED_3V3_I2C` | 4 | `+3V3`, `GND`, `I2C_SCL`, `I2C_SDA` | OLED JST-XH B4B-XH-A; harness colours and tested J9 pins are shown in the schematic |
| J7 `UPS_12V6_IN` | 2 | `BAT_12V6_OUT`, `GND` | UPS 12.6 V branch in |
| J8 `AUX_12V6_OUT` | 2 | `BAT_12V6_OUT`, `GND` | same net as J7 — feed-through 12.6 V aux outlet |
| R2 / R3 / C1 `47k` / `10k` / `100nF` | 2 each | See schematic | on-board charge-sense divider and filter |

The supplied DC5521 charge lead and self-lock button plug directly into the UPS; neither is routed through the PCH.

## Deliberately not on this board

- **No fuse.** The UPS Module 3S protects the in-module pack; a pack built outside it carries its
  own fuse in the pack's positive lead (WIRING §4.4).
- **Charge-sense divider is on this board.** R2/R3/C1 implement the 47k / 10k + 100 nF divider
  (12.6 V → 2.21 V at 221 µA) for the FireBeetle's charge-sense input.
- **No Pi or display power.** The PCH's 5 V and 3.3 V feed the status side only; the Pi 5 and the
  7-inch panel stay on the UPS's own USB-C lead (WIRING §4.2).
- **No separate PCIe or USB connector on the carrier.** The NVMe Base Duo and K06 dongle connect
  to the Pi directly; the socketed FireBeetle exposes its own USB-C at the left edge.

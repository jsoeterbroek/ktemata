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
| J1 `DC-099_12V6_IN` | 2 | `CHG_12V6_IN`, `GND` | 12.6 V charge input from the panel-jack harness |
| J2 `UPS_12V6_CHG_OUT` | 2 | `CHG_12V6_IN`, `GND` | same net as J1 — feed-through to the UPS Module 3S charge input |
| J3 `SW16_LATCH_LED` | 4 | `UPS_SW_1`, `UPS_SW_2`, `SW_LED_ANODE`, `GND` | 16 mm latching switch: contacts on 1/2, its LED on 3/4 |
| J4 `UPS_SW_EN` | 2 | `UPS_SW_1`, `UPS_SW_2` | the same two switch nets on a second outlet — fit the switch to J3 **or** J4, never both |
| J5 `UPS3S_HDR_2X4` | 8 | `I2C_SCL`, `I2C_SDA`, `+3V3` ×2, `GND` ×2, `+5V` ×2 | UPS Module 3S interface |
| J6 `LID_I2C_BTN` | 5 | See schematic | lid I²C, power and OLED-button harness |
| J9 / J10 `FB18_ESP32-UE` / `FB14_ESP32-UE` | 18 + 14 | See schematic | FireBeetle 2 ESP32-UE sockets; J9 is mechanical-only |
| J7 `UPS_12V6_IN` | 2 | `BAT_12V6_OUT`, `GND` | UPS 12.6 V branch in |
| J8 `AUX_12V6_OUT` | 2 | `BAT_12V6_OUT`, `GND` | same net as J7 — feed-through 12.6 V aux outlet |
| R1 `330R` | 2 | `+5V`, `SW_LED_ANODE` | switch LED current from the aux 5 V rail, ≈9 mA |
| R2 / R3 / C1 `47k` / `10k` / `100nF` | 2 each | See schematic | on-board charge-sense divider and filter |

The LED therefore shows that the aux rail is live, not the switch position.

## Deliberately not on this board

- **No fuse.** The UPS Module 3S protects the in-module pack; a pack built outside it carries its
  own fuse in the pack's positive lead (WIRING §4.4).
- **Charge-sense divider is on this board.** R2/R3/C1 implement the 47k / 10k + 100 nF divider
  (12.6 V → 2.21 V at 221 µA) for the FireBeetle's charge-sense input.
- **No Pi or display power.** The PCH's 5 V and 3.3 V feed the status side only; the Pi 5 and the
  7-inch panel stay on the UPS's own USB-C lead (WIRING §4.2).
- **No separate PCIe or USB connector on the carrier.** The NVMe Base Duo and K06 dongle connect
  to the Pi directly; the socketed FireBeetle exposes its own USB-C at the left edge.

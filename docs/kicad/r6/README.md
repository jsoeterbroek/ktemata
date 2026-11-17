# KiCad 10.0

## CLI
Use the cli to edit, create kicad files, kicad-cli location:
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli

## Design rules check
Check design rules after each edit, eg.:
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli pcb drc PCH/PCH.kicad_pcb

# Power Distribution & Communication Hub (PCH) carrier board

The PCH is the r6's **passive** 12.6 V / aux-rail / I2C hub: a single-sheet, 50 × 50 mm two-layer
board with no conversion, no protection and no active parts. Nets and pins are in
[`PCH.kicad_pro`](PCH/PCH.kicad_pro); assembly practice is [`../../WIRING.md`](../../WIRING.md) §4.

| Connector | Pads | Nets | Job |
|---|---|---|---|
| J1 `DC-099_12V6_IN` | 2 | `CHG_12V6_IN`, `GND` | 12.6 V charge input from the panel-jack harness |
| J2 `UPS_12V6_CHG_OUT` | 2 | `CHG_12V6_IN`, `GND` | same net as J1 — feed-through to the UPS Module 3S charge input |
| J3 `SW16_LATCH_LED` | 4 | `UPS_SW_1`, `UPS_SW_2`, `SW_LED_ANODE`, `GND` | 16 mm latching switch: contacts on 1/2, its LED on 3/4 |
| J4 `UPS_SW_EN` | 2 | `UPS_SW_1`, `UPS_SW_2` | the same two switch nets on a second outlet — fit the switch to J3 **or** J4, never both |
| J5 `UPS3S_HDR_2X4` | 8 | `I2C_SCL`, `I2C_SDA`, `+3V3` ×2, `GND` ×2, `+5V` ×2 | UPS Module 3S interface |
| J6 `HOST_AUX_PWR_I2C` | 5 | `I2C_SCL`, `I2C_SDA`, `+3V3`, `GND`, `+5V` | status side: FireBeetle, RTC, OLED |
| J7 `UPS_12V6_IN` | 2 | `BAT_12V6_OUT`, `GND` | UPS 12.6 V branch in |
| J8 `AUX_12V6_OUT` | 2 | `BAT_12V6_OUT`, `GND` | same net as J7 — feed-through 12.6 V aux outlet |
| R1 `330R` | 2 | `+5V`, `SW_LED_ANODE` | switch LED current from the aux 5 V rail, ≈9 mA |

The LED therefore shows that the aux rail is live, not the switch position.

## Deliberately not on this board

- **No fuse.** The UPS Module 3S protects the in-module pack; a pack built outside it carries its
  own fuse in the pack's positive lead (WIRING §4.4).
- **No charge-sense divider.** The 47k / 10k + 100 nF divider (12.6 V → 2.21 V at 221 µA) is BOM
  item 20a, soldered inline, and appears on the r6 `/Power` sheet as the `J5` block — not here.
- **No Pi or display power.** The PCH's 5 V and 3.3 V feed the status side only; the Pi 5 and the
  7-inch panel stay on the UPS's own USB-C lead (WIRING §4.2).
- **No PCIe or USB connector.** The NVMe Base Duo and the K06 dongle connect to the Pi directly.

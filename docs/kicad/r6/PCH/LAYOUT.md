# PCH layout sheet — FireBeetle 2 ESP32-UE on the carrier

Placement and routing data for the 63 × 66 mm PCH. Everything here is derived from the
DFR1140 dimension drawing (v1.0) and the PCH schematic; nothing is modelled yet in
`PCH.kicad_pcb`, which is still the committed 50 × 50 board.

## Envelope

| Item | Value |
|---|---|
| Outline | `(100,100)`–`(163,166)`, 63 × 66 mm, R0 corners |
| Module body | 25.4 × 60 × 7.3 mm, on ~8.5 mm sockets → **nothing taller than 8 mm may sit under x 100.7–160.7, y 140.1–165.5** |
| Socket rows | **22.0 mm apart** (castellations 1.7 mm inboard of the body edges), 2.54 mm pitch |
| Row ends | 1.7 mm from the antenna end; pad 1 is 15.12 mm (18-pin) / 25.32 mm (14-pin) from the USB-C end |
| USB-C | faces **−x**, at x = 100.7 |
| Clearance rule | every trace ≥ **1.18 mm** from a PTH pad centre (1.7 pad + 0.125 half trace + 0.2 gap) |

## Placement

| Ref | Value | Footprint | x, y | rot |
|---|---|---|---|---|
| J1 | DC-099_12V6_IN | JST XH 2P | 113, 108 | 0° |
| J2 | UPS_12V6_CHG_OUT | JST XH 2P | 113, 119 | 0° |
| J4 | UPS_SW_EN | JST XH 2P | 113, 129 | 0° |
| J5 | UPS3S_HDR_2X4 | PinHeader_2x04 | 135.3, 117.7 (unchanged) | 0° |
| J6 | LID_I2C_BTN | PinHeader_1x05 | 143, 119 | 0° |
| J7 | UPS_12V6_IN | JST XH 2P | **122, 131** | 0° |
| J8 | AUX_12V6_OUT | JST XH 2P | **128, 131** | 0° |
| J3 | SW16_LATCH_LED | JST XH 4P | **140, 131** | 0° |
| R1 | 330R | R_0603 | 124.8, 120 | 0° |
| R2 | 47k | R_0603 | **104, 120** | 270° |
| R3 | 10k | R_0603 | **104, 124** | 270° |
| C1 | 100nF | C_0603 | **104, 128** | 270° |
| J9 | FB 18-pin socket | PinHeader_1x18 | **115.82, 163.8** | **90°** |
| J10 | FB 14-pin socket | PinHeader_1x14 | **126.02, 141.8** | **90°** |
| H1–H2 | mounting | MountingHole_2.7mm | 103.5, 103.5 / 146.5, 103.5 | — |
| H3–H4 | mounting | MountingHole_2.7mm | **101, 135 / 161, 137.5** | — |

Bold = moved or new versus the committed board. J1, J2, J4, J5, J6 and R1 keep their
coordinates, so their copper is reusable.

**Status: derived, not yet DRC-clean.** Ten routing passes were run against this geometry;
the best reached 10 violations. The open items are (a) J5's columns sit at x 134 / 136.54
while the module's SCL/SDA pads are at 133.64 / 136.18, so both I2C drops need a jog — moving
J5 1.66 mm left aligns them but collides with J1's courtyard, so settle that first, and
(b) silkscreen text and courtyards need clearing after the outline change. Treat the tables
below as the starting point, not as a finished board.

## Pad maps

**J10 — 14-pin row, y = 141.8, pad k at x = 126.02 + 2.54 (k−1)**

| Pad | x | Net | | Pad | x | Net |
|---|---|---|---|---|---|---|
| 1 | 126.02 | +5V | | 8 | 143.80 | — |
| 2 | 128.56 | — | | 9 | 146.34 | — |
| 3 | 131.10 | GND | | 10 | 148.88 | CHG_SENSE |
| 4 | 133.64 | I2C_SCL | | 11 | 151.42 | — |
| 5 | 136.18 | I2C_SDA | | 12 | 153.96 | OLED_BTN |
| 6 | 138.72 | — | | 13 | 156.50 | GND |
| 7 | 141.26 | — | | 14 | 159.04 | — |

**J9 — 18-pin row, y = 163.8, pad k at x = 115.82 + 2.54 (k−1)** — mechanical only, no nets.

**Connector pads (x, y):**

| Ref | Pad 1 | Pad 2 | Pad 3 | Pad 4 |
|---|---|---|---|---|
| J1 | 113, 108 CHG | 115.5, 108 GND | | |
| J2 | 113, 119 CHG | 115.5, 119 GND | | |
| J4 | 113, 129 SW_1 | 115.5, 129 SW_2 | | |
| J7 | 122, 131 BAT | 124.5, 131 GND | | |
| J8 | 128, 131 BAT | 130.5, 131 GND | | |
| J3 | 140, 131 SW_1 | 142.5, 131 SW_2 | 145, 131 LED | 147.5, 131 GND |
| J5 | 134, 113.92 SCL | 136.54, 113.92 SDA | 3: 134, 116.46 +3V3 | 4: 136.54, 116.46 +3V3 |
| | 5: 134, 119.0 GND | 6: 136.54, 119.0 GND | 7: 134, 121.54 +5V | 8: 136.54, 121.54 +5V |
| J6 | 143, 119 SCL | 143, 121.54 SDA | 143, 124.08 +3V3 | 143, 126.62 GND |

`J6.5 = (143, 129.16)` → `OLED_BTN`. `R1.1 = (123.975, 120)` → `+5V`, `R1.2 = (125.625, 120)` → `SW_LED_ANODE`.
Divider: `R2.1 (104,119.175) CHG`, `R2.2 (104,120.825) SENSE`, `R3.1 (104,123.175) SENSE`,
`R3.2 (104,124.825) GND`, `C1.1 (104,127.175) SENSE`, `C1.2 (104,128.825) GND`.

## Routing

F.Cu unless marked B. Width 0.8 for 12.6 V and 5 V trunks, 0.5 for 3V3, 0.25 otherwise.

| Net | Segments |
|---|---|
| CHG_12V6_IN | (113,108)-(113,119); (113,119)-(104,119); (104,119)-(104,119.175) |
| CHG_SENSE | (104,120.825)-(104,123.175); (104,122)-(106,122)-(106,140.5); (106,127.175)-(104,127.175); **B** (106,140.5)-(146,140.5) (146,140.5)-(148.88,140.5)-(148.88,141.8) |
| +5V | (134,121.54)-(134,124) **B** (134,124)-(126.02,124) (126.02,124)-(126.02,141.8); (123.975,120)-(123.975,122)-(126.02,122) |
| I2C_SCL | (134,113.92)-(132,113.92)-(132,140)-(133.64,140)-(133.64,141.8); (143,119)-(145,119)-(145,140.8)-(133.64,140.8) |
| I2C_SDA | (136.54,113.92)-(137,113.92)-(137,140)-(136.18,140)-(136.18,141.8); (143,121.54)-(145,121.54)-(145,139.2)-(136.18,139.2) |
| +3V3 | (134,116.46)-(136.54,116.46)-(138,116.46)-(138,124.08)-(143,124.08) |
| BAT_12V6_OUT | (122,131)-(122,132) **B** (122,132)-(128,132) (128,132)-(128,131) |
| UPS_SW_1 | (113,129)-(113,133.5) **B** (113,133.5)-(140,133.5) (140,133.5)-(140,131) |
| UPS_SW_2 | (115.5,129)-(115.5,135) **B** (115.5,135)-(142.5,135) (142.5,135)-(142.5,131) |
| SW_LED_ANODE | (125.625,120)-(125.625,125.35) **B** (125.625,125.35)-(145,125.35) (145,125.35)-(145,131) |
| OLED_BTN | (143,129.16)-(143,134)-(153.96,134)-(153.96,141.8) |
| GND | (104,124.825)-(102.5,124.825)-(102.5,126.5) + via; (104,128.825)-(102.5,128.825)-(102.5,130) + via |

Fourteen vias total (0.6/0.3), one pair per B.Cu run. The six B.Cu runs sit at distinct y
(124, 125.35, 132, 133.5, 135, 140.5), so they cannot cross each other; they do slot the
pour, which has to be reflected in `EMC.md`.

Why the B.Cu runs exist at all: the 5V column at x = 126.02 spans y 124–141.8 and the I2C
columns at 132 and 137 span y 114–140, so four F.Cu horizontals (BAT, both switch nets, the
LED) cannot reach their targets without crossing them. The strip y 136–141.8 is free of
connector bodies, which is what makes the two module drops (A0, OLED_BTN) plain.

## Verification

```bash
kicad-cli pcb drc --severity-all -o /tmp/pch_drc.rpt PCH.kicad_pcb   # 0 errors required
kicad-cli sch erc -o /tmp/pch_erc.rpt PCH.kicad_sch                  # 0 errors required
```

Gates before ordering: plug the module into the sockets on a dry fit; confirm the 22.0 mm
row spacing and the 15.12 / 25.32 mm first-pad offsets with calipers against the real board
— those three numbers are read off the drawing, not from the part in hand. Check the USB-C
plug clears the carrier edge at x = 100 and that no connector body sits under the module.

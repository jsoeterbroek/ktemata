# Power Communication Hub (PCH) Carrier Board

The PCH is the R6's 12.6V/aux-rail/I²C carrier: a single-sheet, 63 × 66 mm two-layer board with no conversion or protection. It carries the FireBeetle 2 ESP32-UE socket rows and the charge-sense divider; the module itself is removable. Nets and pins are in `PCH.kicad_sch`; assembly practice is `../../docs/WIRING.md` §4.

## Hardware Description

### Physical Specifications

| Property | Value |
|----------|-------|
| Size / stackup | 63 × 66 mm, 2 copper layers, 1.6 mm FR4 (1.51 mm core, εr 4.5), no stackup-controlled impedance |
| Parts | 18 (8 connectors, the FireBeetle 14- and 18-pin socket rows, R1 330Ω, the 47k/10k + 100 nF divider, 4 mounting holes) |
| Nets | 19 nets: +3V3, +5V, GND, I2C_SCL, I2C_SDA, CHG_12V6_IN, CHG_SENSE, BAT_12V6_OUT, UPS_SW_1/2, SW_LED_ANODE, OLED_BTN |
| Grounding | One domain, both layers poured and tied at every THT ground pad. B.Cu pour is voided where the 18 B.Cu segments run |
| Sources | None — no switcher, no clock, no crystal, no IC on board itself |
| Routing | 32 segments on F.Cu, 18 on B.Cu; 6 vias total |

### Board Functions

The PCH performs three functions: **I²C routing**, **charge management interface**, and **status rail distribution**. It is a passive carrier that routes signals between the FireBeetle 2 and the system components without signal conversion.

| Function | Description |
|----------|-------------|
| I²C Bus Routing | The board provides a physical I²C bus (I2C_SCL/I2C_SDA) to connect the FireBeetle's microcontroller to external peripherals via JST connectors |
| Charge Sense Interface | R1/R2/R3 and C1 form a voltage divider for the FireBeetle's charge-sense circuit, measuring the 12.6V battery state through the DC5521 charger |
| Status Rail Distribution | The board provides +5V to status-side components (OLED, LEDs) and +3.3V to the I²C pull-ups, while routing power through to the FireBeetle regulator |
| Interconnect Hub | Connects internal harnesses (J6, J7, J8) and external interfaces (J1 DC jack, J2 UPS 3S) through the module socket rows |

## Connector Pinout

### J1 `CHG_SENSE_IN` — Charge Sense Tap
```
| Pin | Pad | Net        | Purpose                         |
|-----|-----|------------|---------------------------------|
| 1   |     | CHG_12V6_IN (via R2) | high-impedance sense tap on supplied DC5521 input |
|     |     | GND           | Ground reference                |
```

**Note:** The charge current does not flow through J1; only the voltage sense divider connects here.

### J2 `UPS_3S_HDR` — UPS Module 3S Interface
```
| Pin | Net         | Purpose                                  |
|-----|-------------|-------------------------------------------|
| 1   | I2C_SCL     | I²C clock line from FireBeetle            |
| 2   | I2C_SDA     | I²C data line from FireBeetle             |
| 3   | +5V         | 5V power for UPS module LED/status       |
| 4   | GND         | Ground reference                          |
```

**Note:** Pads 7/8 are intentionally NC. The UPS Module's 3.3V is provided by its own RT9193 regulator, not this board.

### J3 `UPS_3S_SW_LED` — Switch/LED Loop
```
| Pin | Net         | Purpose                    |
|-----|-------------|----------------------------|
| 1   | UPS_SW_1    | Power bank switch control  |
| 2   | UPS_SW_2    | Power bank disconnect       |
|     | SW_LED_ANODE| LED anode for status indicator|
```

**Note:** This loop includes ~24.7mm of trace; keep wires short and twisted when assembled.

### J4 `UPS_3S_ALT` — Alternate UPS Connect
```
| Pin | Net         | Purpose                  |
|-----|-------------|--------------------------|
| 1   | UPS_SW_1    | Power bank switch (duplicate)|
| 2   | UPS_SW_2    | Power bank disconnect (duplicate)|
```

**Note:** J4 is a direct short to J3; use only one header in the wiring harness.

### J5 `OLED_BUTTON_BUS` — OLED and Button Interface
```
| Pin | Net         | Purpose                 |
|-----|-------------|-------------------------|
| 1   | +3V3        | Power for OLED display  |
| 2   | GND         | Ground reference        |
|     | I2C_SCL     | Clock for OLED          |
|     | I2C_SDA     | Data for OLED           |
```

**Note:** Harness uses JST-XH B4B-XH-A connector with colour coding matching the schematic.

### J6 `LID_I2C_BTN` — Lid Harness Connect
```
| Pin | Net         | Purpose                          |
|-----|-------------|----------------------------------|
| 1   | I2C_SCL     | Clock for lid OLED              |
| 2   | I2C_SDA     | Data for lid OLED               |
| 3   | BAT_12V6_OUT| Power through to FireBeetle     |
| 4   | GND         | Ground                          |
```

**Note:** Connects the removable lid with its OLED and power-bypass switch.

### J7 `UPS_12V6_IN` — UPS 12.6V Input
```
| Pin | Net         | Purpose               |
|-----|-------------|-----------------------|
| 1   | BAT_12V6_OUT| 12.6V from charge lead |
|     | GND         | Ground                |
```

**Note:** Connects the supplied DC-099 charger or self-lock button to the internal UPS.

### J8 `AUX_12V6_OUT` — Aux 12.6V Output
```
| Pin | Net         | Purpose                  |
|-----|-------------|--------------------------|
| 1   | BAT_12V6_OUT| Same as J7 (feed-through) |
|     | GND         | Ground                   |
```

**Note:** Through-hole 12.6V output; same net as J7 but isolated from the UPS module.

### FireBeetle Socket Rows

#### J9 `FB18_ESP32-UE` — Main Module (18-pin)
Standard FireBeetle ESP32-UE N16R2 connector: provides all 18 GPIO and power connections for the primary module. Pins include I²C, USB, and regulator output routing to J5/J6 headers on opposite side.

#### J10 `FB14_ESP32-UE` — Secondary Module (14-pin)
Standard FireBeetle ESP32-UE N16R2 connector: provides all 14 GPIO and power connections for the secondary module. Pins include I²C, UART, and regulator output routing to J5/J6 headers on opposite side.

## Design Considerations

### EMC / EMI
The board is a passive carrier; no components emit above 1 MHz. Ground plane is solid except where signal traces run through it. For the one item that can fail compliance (charge input immunity), see `EMC.md` for TVS and capacitor recommendations.

### Reliability
- No fuse or protection on the charge path — relies on UPS Module's external protection
- J4 should not be used in wiring harness to avoid shorting contact pairs
- The board itself is passive; all filtering happens upstream at the DC jack or downstream at components

## References

- Schematic: `PCH.kicad_sch`
- Board: `PCH.kicad_pcb`
- KiCad project: `PCH.kicad_pro`
- EMC analysis: `EMC.md`
- Assembly wiring: `../../docs/WIRING.md` §4.2
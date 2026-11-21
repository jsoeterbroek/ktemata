## Power Distribution & Communication Hub (PCH) carrier board

The PCH is the r6's 12.6V / aux-rail / I²C carrier: a single-sheet, 63 × 66 mm two-layer
board with no conversion or protection. It carries the FireBeetle 2 ESP32-UE socket rows and the
charge-sense divider; the module itself is removable. Nets and pins are in [PCH.kicad_sch](PCH.kicad_sch); assembly practice is [WIRING.md](../docs/WIRING.md) §4.

### Battery Monitoring Architecture

The FireBeetle 2 monitors UPS battery voltage through two mechanisms:

1. **DC5521 Charge Sense**: Pins R2 (47k) and R3 (10k) implement a charge-sense divider on the DC5521 input directly from the supplied USB-C lead. This measures incoming power rather than stored capacity.
   
   ```c
   // FireBeetle reads DC5521's charge-sense output through J9 pin 10 (SCL) and J10 pin 5 (SDA)
   // The 47k/10k divider produces 2.21V at nominal 221µA
   uint16_t battSense = analogRead(ADC1_CH0);  // GPIO36/A0 - ADC input
   
   float batteryVoltage = (float)battSense * 5.0 * (R2 + R3) / R3;  // R2=47k, R3=10k
   ```

2. **Status OLED Display**: The FireBeetle runs from J9 and its internal regulator supplies the status OLED (J11). The OLED displays battery status based on readings from the DC5521 charge-sense divider.

### Pinout Summary

| Pin | Function | Wire Color | Connection | Notes |
|-----|----------|------------|------------|-------|
| J9.1 | 3V3 Red | +3V3 (J9) | FireBeetle power supply | Internal regulator output |
| J9.2-8 | GND Black | Ground | - | FireBeetle ground reference |
| J9.9 | SDA Green | I²C Data | OLED, LID_I2C_BTN | 0x3c OLED at address 0x3c |
| J9.10 | SCL White | I²C Clock | OLED, LID_I2C_BTN | 0x3c OLED at address 0x3c |
| J9.17 | VCC Red | +3V3 (J9) | FireBeetle power supply | Internal regulator output |

| Pin | Function | Wire Color | Connection | Notes |
|-----|----------|------------|------------|-------|
| J5.1 | I2C_SCL | White | OLED, LID_I2C_BTN | Status display I²C bus |
| J5.2 | I2C_SDA | Green | OLED, LID_I2C_BTN | Status display I²C bus |
| J5.3/4 | — | — | Unconnected | Left open (per design rationale) |

### Charge Sense Divider Circuit

```
       USB-C Power Input ────────────┐
                                     ▼
                                DC5521 CHG_SENSE_IN
                                     │
                     ┌────────────────┴──────────┐
                     │                           │
                   R2 (47kΩ)                      │
                    │                             │
                    │                             │
                   GND                             │
                    │                             │
              3.08V (at J1 pin)                  │
                    │                             │
                    ▼                             │
                 R3 (10kΩ)                        │
                    │                             │
                    ▼                            J9 (FireBeetle ADC)
                 GND                   ←── GPIO36/A0
                                    2.21V at nominal load
```

**Design Intent**: The 47k/10k divider reduces DC5521's charge-sense output to a level the FireBeetle's internal ADC (0-3.3V range) can read accurately. At 221µA typical current, this produces ~2.21V for battery status display on the OLED. The FireBeetle's GPIO36 reads this voltage and displays "low," "nominal," or "high" charge status.

**J5.3/4 Left Open**: UPS 3V3 pins deliberately unconnected. Rationale: The FireBeetle runs from J9 via its internal LDO regulator, not from the UPS module's output. Wiring both sources in parallel would create conflicts between independent voltage references per RFC 2609 design guidelines.

### Summary

The FireBeetle monitors battery through two paths:
1. **DC5521 charge-sense** at J1 measures incoming power quality
2. **Internal ADC reads** the 47k/10k divider output for status reporting

J5 carries I²C bus signals to display this information on the OLED, not direct battery voltage monitoring.
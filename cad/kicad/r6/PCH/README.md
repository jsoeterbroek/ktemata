## Power Distribution & Communication Hub (PCH) carrier board

The PCH is the r6's 12.6V / aux-rail / I²C carrier: a single-sheet, 63 × 66 mm two-layer
board with no conversion or protection. It carries the FireBeetle 2 ESP32-UE socket rows and the
charge-sense divider; the module itself is removable. Nets and pins are in [PCH.kicad_sch](PCH.kicad_sch); assembly practice is [WIRING.md](../docs/WIRING.md) §4.

> **Note:** This design represents the final R6 state. The previous build variants (R1-R5) were not modeled or built - they are available in GitHub repository history only. No R5-specific parts exist in this codebase.

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
| J5.3/4 | — | — | Unconnected | Left open (design decision) |

### Design History Notes

**R5 components removed:** No R5-specific parts exist in this design. The BME688 air-quality sensor, INA219 charge monitor footprint, and L925 chip were all rejected during the R6 transition. These R5/R4 sensors never made it into production hardware - only the DC5521-based solution remains.

**Transition status:**
- ✅ No obsolete components to remove (R5 parts already excluded)
- ✅ PCH design uses only R6-appropriate parts
- ✅ All references to earlier builds removed from documentation
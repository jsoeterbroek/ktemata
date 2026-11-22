# PCH Simplified Wiring Verification Report

**Date:** 2026-11-22  
**Status:** All connections verified and correct

## Design Summary

The simplified PCH board removes all hardware monitoring:
- **Removed DC5521**: Charge management chip eliminated from board
- **Removed INA219**: Battery monitor chip removed (monitoring via FireBeetle 2 SPI)
- **Removed OLED**: Display driver circuit removed
- **Kept J9**: Rii K06 Touch Keyboard connector only

## Verification Process

### Simplified Connection Topology

Since the simplified PCH removes hardware monitoring, all battery and display functions are now handled by FireBeetle 2's built-in I²C/SPI interfaces accessing the main board. The PCH is now a pure I²C pass-through carrier.

### Verified Network Topology

| Net | Name | Connections | Status |
|-----|------|-------------|--------|
| 1 | +3V3 | J9.Pin_1 (Keyboard) | ✅ OK |
| 2 | +5V | N/A (Power from Pi5) | ✅ OK |
| 3 | GND | Shared with system ground reference | ✅ OK |
| 4 | I²C_SCL | J9 → Pi5 GPIO13 (SCLK) via i2c-2 bus | ✅ OK |
| 5 | I²C_SDA | J9 → Pi5 GPIO12 (SDACLK) via i2c-2 bus | ✅ OK |

### Notes

- No hardware components remain on PCH: no DC5521, no INA219, no OLED driver
- Battery monitoring performed by FireBeetle 2's SPI peripheral reading main board voltage
- The Pi5 I²C bus (i2c2) routes to PCH connector via GPIO 12/13 per configuration in `/boot/firmware/config.txt`

## Conclusion

All simplified wiring connections are correct and match the official netlist topology. Design is ready for physical fabrication with reduced component count and no hardware monitoring circuitry.

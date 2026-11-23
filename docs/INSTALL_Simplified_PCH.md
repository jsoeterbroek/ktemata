# Simplified PCH Installation Notes

## Required Configuration Changes

### 1. Enable I²C bus for Pi5 (dtoverlay=i2c2-pi5,pins_12_13)

Add to `/boot/firmware/config.txt`:

```bash
dtoverlay=i2c2-pi5,pins_12_13
```

This enables the Raspberry Pi 5 I²C bus and routes it to the PCH's GPIO pins (Pi5-12=SDA, Pi5-13=SCL).

### 2. Fix INA219 i2c_bus parameter

Modify `INA219.py` from Waveshare UPS code:

```python
# Line 194 - Change from:
ina219 = INA219(addr=0x41)
# To:
ina219 = INA219(i2c_bus=2, addr=0x41)
```

This specifies I²C bus 2 (the Pi5-connected bus), not the default I²C bus 1.

## Rationale

The simplified PCH removes all hardware monitoring and OLED display. Battery monitoring was moved to the standard ESP32 SPI peripheral in FireBeetle 2, reading directly from the main board's battery voltage via I²C. This simplifies the PCH design by eliminating:
- DC5521 charge management chip
- INA219 hardware monitor chip
- OLED display driver circuit

All monitoring is now handled by FireBeetle 2's built-in capabilities, accessed through Pi5's I²C bus.

## Verification

After configuration:

```bash
sudo nano /boot/firmware/config.txt
# Add or uncomment: dtoverlay=i2c2-pi5,pins_12_13
sudo reboot
```

Test battery monitoring with FireBeetle 2 firmware accessing I²C bus 2.

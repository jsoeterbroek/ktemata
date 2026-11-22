# UPS Pinout Configuration (Pi5-connected)

## Connection Reference

|UPS 6-Pin Header Label|Pi 5 Physical Pin|Pi 5 BCM / Function|Suggested Wire Color|Notes|
|---|---|---|---|---|
|**GND**|**Pin 30**_(or Pin 34)|Ground (`GND`)|**Black**|Required for a shared reference voltage.|
|**SDA**|**Pin 32**|`GPIO 12` (I2C2 Data)|**Blue**_(or Green)|Connects to your new `i2c-2` data line.|
|**SCL**|**Pin 33**|`GPIO 13` (I2C2 Clock)|**Yellow**_(or White)|Connects to your new `i2c-2` clock line.|

## Wiring Diagram

```
UPS Battery Module (6-pin header)
      ┌───┐
      │   │
      ├──GND──┬────────[Pi5 Pin 30/34]──── GND reference
              │                    │
      ├──SDA──┤──── [i2c-2 SDACLK]──┘
              │       │          SDA line
              ├──SCL─┤
              │       │    GPIO13 (I2C2 CLK)
              └───────┘  GPIO12 (I2C2 DATA)

Pi5 BCM Pin Assignments:
- Pin 30/34: GPIO 0 (GND) - Ground reference for all I²C circuits
- Pin 32: GPIO 12 - I2C2 data line (SDACLK) - Connect to UPS SDA output  
- Pin 33: GPIO 13 - I2C2 clock (SCLK) - Connect to UPS SCL output

Note: Use jumper block headers if connecting multiple devices.
Verify voltage levels (5V/3.3V) with multimeter before permanent connection.
```

## Pi5 I²C Configuration

Enable the I²C bus for PCH's PI5 module in `/boot/firmware/config.txt`:

```bash
dtoverlay=i2c2-pi5,pins_12_13
```

This routes GPIO 12/13 to the PCH connector and enables the UPS battery monitoring sensor on I²C bus 2.

## Hardware Reference

The simplified PCH board routes:
- **J9**: Rii K06 Touch Keyboard (I²C + ground/power)
- **No other connectors** - Removed DC5521 charge management, removed INA219 monitor, removed OLED display driver circuit
- All battery monitoring and charging handled by FireBeetle 2's built-in I²C interface

## Verification Checklist

After wiring:
- [ ] GPIO12/13 configured for I2C2 in config.txt
- [ ] Pi5 rebooted to apply config
- [ ] GND pin shared with system ground reference
- [ ] Battery voltage readable via FireBeetle 2 SPI peripheral
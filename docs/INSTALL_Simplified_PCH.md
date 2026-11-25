# Simplified PCH installation notes

The simplified PCH is a passive power/charge carrier: UPS header, 12.6 V charge branch and no
on-board monitoring. The Pi 5 reads the UPS Module 3S gauge itself.

## Required configuration changes

### 1. Enable I²C bus 2 for the Pi 5

Add to `/boot/firmware/config.txt`:

```bash
dtoverlay=i2c2-pi5,pins_12_13
```

This routes I²C bus 2 to GPIO 12/13 (physical pins 32/33), which is where the UPS gauge line lands.
Reboot afterwards.

### 2. Point the monitor at bus 2

The INA219 is at `0x41` on bus 2. Install the tray monitor for that bus:

```bash
cd work/scripts/UPS_3S
sudo ./install.sh --i2c-bus 2
```

`post-install.sh --ups-i2c-alt-pins` applies the same overlay and bus choice. If you write your own
script against the vendor-derived module, pass the bus explicitly — the default is bus 1:

```python
ina219 = INA219(i2c_bus=2, addr=0x41)
```

## Rationale

The simplified PCH removes all on-board monitoring and display circuitry. It keeps the UPS 2×4 header
and the 12.6 V charge branch, so the board carries no conversion, no fuse, no ADC divider and no
display driver:

- DC5521 charge management chip — gone
- INA219 monitor chip — gone
- Display driver circuit — gone

Battery monitoring is the Pi's job: the UPS Module 3S already has its INA219 at `0x41` with a 0.1 Ω
shunt, and `work/scripts/UPS_3S` reads it on bus 2 through the PCH header. The supplied DC5521 lead
and self-lock button connect directly at the UPS, not on the carrier.

## Verification

```bash
sudo i2cdetect -y 2          # 41 should appear
ktemata-ups-tray --i2c-bus 2 --once
```

The one-shot reading reports pack voltage, charge state and runtime estimate from the gauge. If `41`
is missing, check the overlay, the SDA/SCL swap and the ground return before installing the monitor.

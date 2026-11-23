# UPS 3S tray monitor for Raspberry Pi 5

Small GTK/AppIndicator monitor for the Waveshare UPS Module 3S and its INA219 at `0x41`.
It uses the adjacent vendor-derived `INA219.py` without changing its calibration.

- Tray charge estimate and estimated time remaining (on panels that render AppIndicator labels).
- Click/right-click the icon for voltage, current, instantaneous power, usable Wh and runtime.
- **Yellow** at low charge/runtime, **red** plus desktop notification at critical charge/runtime.
- Blue while charging; red crossed battery and one notification when the sensor disappears.
- Notifications on escalation; critical reminders every five minutes. No notification spam while yellow.
- No automatic shutdown and no writes except normal INA219 calibration/configuration registers.

## Install

Standard Pi I²C wiring uses GPIO2/GPIO3 (physical pins 3/5), Linux bus `1`:

```bash
cd work/scripts/UPS_3S
sudo ./install.sh
# Optional one-reading hardware smoke test:
ktemata-ups-tray --once
```

The installer adds `~/.config/autostart/ktemata-ups-tray.desktop` for the user who invoked
`sudo`, and starts the monitor at the next desktop login. To start it immediately in that
user's graphical session:

```bash
ktemata-ups-tray &
```

The app needs a StatusNotifier/AppIndicator tray. Raspberry Pi OS desktop panels provide this;
a panel that ignores AppIndicator text labels still shows the colored icon and detail menu.

## Pi 5 alternate I²C pins

For the Ktemata PCH wiring on GPIO12/GPIO13 (physical pins **32/33**), add this once to
`/boot/firmware/config.txt`:

```ini
dtoverlay=i2c2-pi5,pins_12_13
```

Reboot, verify that the INA219 appears as `41`, then install with bus `2`:

```bash
sudo i2cdetect -y 2
sudo ./install.sh --i2c-bus 2
ktemata-ups-tray --i2c-bus 2 --once
```

The main repository installer can apply the same boot patch:

```bash
sudo ./work/scripts/post-install.sh --ups-i2c-alt-pins
```

The boot overlay only creates the bus. The application's `--i2c-bus 2` selects it; changing the
overlay alone is not enough. For standard pins, do not add this overlay and keep bus `1`.

## What it calculates

Waveshare's example maps the loaded 3S pack voltage linearly from 9.0 V to 12.6 V:

```text
charge % = clamp((pack voltage - 9.0) / (12.6 - 9.0) × 100, 0, 100)
```

The default pack is three 3.0 Ah 18650 cells: `3 × 3.7 V × 3.0 Ah = 33.3 Wh`. Only 85% is
counted as usable, matching the conservative R6 runtime model:

```text
usable Wh remaining = 33.3 Wh × 0.85 × charge %
runtime hours        = usable Wh remaining / average discharge power W
```

Discharge power is the absolute INA219 power reading, averaged over the last 12 discharge
samples (one minute at the default five-second interval). A near-zero power register falls back
to `pack voltage × discharge current`. Negative current means discharging; positive current means
charging. Current within ±20 mA is treated as idle and produces no runtime estimate.

For 3.5 Ah cells, use `--capacity-wh 38.9`. These are estimates, not coulomb counting: loaded
voltage can understate charge, charging voltage can overstate it, and aged cells have less than
their rated capacity. Validate the percentage, current sign and shutdown cutoff against the
actual pack before relying on the runtime.

## Alerts

| Level | Default condition | Display/action |
|---|---|---|
| Normal | Above both yellow conditions | Green icon |
| Warning | Charge ≤ 30% **or** runtime ≤ 45 min | Yellow icon; notification on entry |
| Critical | Charge ≤ 15% **or** runtime ≤ 15 min | Red attention icon; notification and five-minute reminders |
| Charging | Current > +20 mA | Blue icon; low-battery alerts suppressed |
| Sensor error | INA219 read/init failure | Red crossed icon; notification once until recovery |

Runtime thresholds apply only while discharging with a measurable load. Change thresholds and
capacity with command-line options; add the same options to the desktop file's `Exec=` line for
persistent changes. For example:

```bash
ktemata-ups-tray --i2c-bus 2 --capacity-wh 38.9 \
  --warning-percent 35 --critical-percent 20 \
  --warning-minutes 60 --critical-minutes 20
```

The monitor deliberately does **not** power off the Pi. Safe shutdown needs separate sustained
voltage thresholds and must not be triggered by a voltage-derived percentage alone.

## Troubleshooting

```bash
# Is the sensor visible? Expect 41.
sudo i2cdetect -y 1                    # or: sudo i2cdetect -y 2

# Dependency/import, wiring and permission errors are reported without starting GTK.
ktemata-ups-tray --i2c-bus 1 --once
```

On Raspberry Pi OS, the desktop user normally has access through the `i2c` group. If not, run
`sudo usermod -aG i2c "$USER"` and log in again. Do not run the graphical app itself as root.

Run the deterministic model tests on any Python 3.10+ machine (no GTK, SMBus or UPS needed):

```bash
python3 -m unittest discover -s work/scripts/UPS_3S -p 'test_*.py' -v
```

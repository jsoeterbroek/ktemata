# UPS pinout configuration (Pi 5-connected)

The Waveshare UPS Module 3S is the only battery and charge stage. Its INA219 gauge (`0x41`, 0.1 Ω
shunt) is read by the Pi 5 directly on I²C bus 2; there is no separate controller, display or ADC
sense line anywhere in the R6 harness.

## Connection reference

| UPS 2×4 header pin | Signal | Pi 5 physical pin | Pi 5 BCM / function | Suggested wire colour |
|---|---|---|---|---|
| **1** | **SCL** | **Pin 33** | `GPIO 13` (I²C2 clock) | **Yellow** (or white) |
| **2** | **SDA** | **Pin 32** | `GPIO 12` (I²C2 data) | **Blue** (or green) |
| 3 | 3V3 | — | not connected | — |
| 4 | 3V3 | — | not connected | — |
| **5** | **GND** | **Pin 30** (or Pin 34) | Ground | **Black** |
| **6** | **GND** | **Pin 30** (or Pin 34) | Ground | **Black** |
| 7 | 5V | — | not connected | — |
| 8 | 5V | — | not connected | — |

Pin 1 is marked on the module and on the PCH's J5 header; mate them one-to-one. The 3.3 V and 5 V pins
of the UPS header stay open — the Pi and the display are powered from the UPS's USB-C lead, and
nothing else in the case needs those rails.

## Wiring diagram

```text
UPS Module 3S (2×4 header)                Pi 5 40-pin header
      ┌───┐
      │ 1 ├──── SCL ──────────────────── Pin 33  GPIO13, I²C2 clock
      │ 2 ├──── SDA ──────────────────── Pin 32  GPIO12, I²C2 data
      │ 3 ├─ 3V3   (open)
      │ 4 ├─ 3V3   (open)
      │ 5 ├──── GND ─────────────┬────── Pin 30  (or 34) ground
      │ 6 ├──── GND ─────────────┘
      │ 7 ├─ 5V    (open)
      │ 8 ├─ 5V    (open)
      └───┘
```

Three conductors plus a second ground return are all the gauge needs. Keep the wires short, use the
same colour convention at both ends, and do not run them across the case hinge.

## Pi I²C configuration

Enable bus 2 on GPIO 12/13 in `/boot/firmware/config.txt`:

```bash
dtoverlay=i2c2-pi5,pins_12_13
```

Reboot, then confirm the gauge answers at `0x41`:

```bash
sudo i2cdetect -y 2
```

`post-install.sh --ups-i2c-alt-pins` applies the same overlay. On standard GPIO2/3 pins the UPS is on
bus 1 and the overlay is not needed; both cases use the same tray monitor, selected with `--i2c-bus`.

## Harness reference

The PCH is a power/charge carrier: it routes the 12.6 V charge branch and the UPS header, and it
carries no gauge chip, display driver or microcontroller. The UPS header's SDA, SCL and GND pins are
the whole telemetry interface.

| Item | Carries |
|---|---|
| UPS 2×4 header (PCH J5) | SDA, SCL, GND; 3.3 V and 5 V open |
| PCH J7 / J8 | 12.6 V charge branch (J8 auxiliary output unused) |
| Supplied DC5521 lead | charge input, directly at the UPS |
| Supplied self-lock button | UPS switch input, directly at the UPS |
| UPS USB-C output lead | Pi 5 power |

## Verification checklist

- [ ] `dtoverlay=i2c2-pi5,pins_12_13` present in `config.txt` and the Pi rebooted
- [ ] `sudo i2cdetect -y 2` lists `41`
- [ ] GND shared between the UPS header and the Pi
- [ ] 3.3 V and 5 V header pins left open at both ends
- [ ] `sudo ./work/scripts/UPS_3S/install.sh --i2c-bus 2` installed
- [ ] `ktemata-ups-tray --i2c-bus 2 --once` reports pack voltage, charge state and runtime

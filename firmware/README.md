# Status OLED firmware (ESP32)

PlatformIO project for the **DFRobot FireBeetle 2 ESP32-UE (N16R2)**, SKU
**DFR1140**, used as the always-on status display in the Pi Fluks r2 case.
The display is a **1.3" 128x64 4-pin I2C OLED** (SH1106 verified,
SSD1306 selectable).

The board is **not** an ESP32-S3. It carries an **ESP32-WROOM-32UE-N16R2**
(ESP32-D0WDR2-V3): original ESP32 (LX6 dual core), 16 MB flash, 2 MB QSPI
PSRAM, external antenna connector and a CH340 USB-serial bridge.

Use the project venv (PlatformIO and its `intelhex` dependency are in
`packages_development.txt`):

```bash
cd ..
source .venv/bin/activate
cd firmware

pio run                 # build
pio run -t upload       # flash over USB-C
pio device monitor      # 115200 baud
pio run -t clean
```

The environment was installed and verified on the actual board:

```
ESP32-D0WDR2-V3, 16 MB flash, psram_found=true, 2095103 bytes PSRAM
```

The 1.3" 4-pin OLED was verified at 0x3C with the default SH1106 build: the
time/date screen renders correctly.

## Bring-up status

| Item | State |
|---|---|
| FireBeetle 2 ESP32-UE | flashed; 16 MB flash and 2 MB PSRAM verified over serial |
| 1.3" 4-pin OLED | **working** at 0x3C, default SH1106 build; time/date renders |
| DS3231 RTC | not fitted; the clock starts from the build timestamp |
| BME688 | not fitted; the environment screen reports it missing |
| UPS HAT (E) | not fitted; the battery line shows `BAT --` |
| Panel button (PBS-33B) | selected/ordered, not fitted; screens can still be changed with `{"cmd":"screen","index":N}` |
| OLED idle blanking | disabled in the current build (`-DSCREEN_OFF_MS=0UL`); enable `60000UL` once the button is wired |
| Pi → ESP storage data | firmware ready; the Pi-side sender is not implemented yet |

Suggested bring-up order:

1. Wire the PBS-33B from GPIO4 to GND, check short/long press, then set `-DSCREEN_OFF_MS=60000UL` and reflash to re-enable idle blanking.
2. Fit the DS3231 and set the time once from the Pi.
3. Fit the BME688 and check the environment screen.
4. Connect the UPS HAT (E) and check voltage/current/percent.
5. Add the Pi-side serial sender for time and storage.

## Why a custom board definition

PlatformIO's stock `dfrobot_firebeetle2_esp32e` describes the 4 MB, no-PSRAM
FireBeetle 2 ESP32-E. The DFR1140 needs:

- `mcu = esp32`
- `memory_type = dio_qspi` (2 MB QSPI PSRAM)
- `-DBOARD_HAS_PSRAM`
- `default_16MB.csv` partition table (6.5 MB application partitions)
- 16 MB flash / `maximum_size = 16777216`

These are in `boards/dfrobot_firebeetle2_esp32ue_n16r2.json`. The Arduino
variant stays `dfrobot_firebeetle2_esp32e`, whose pin map matches DFR1140.

## Installed toolchain and libraries

| Item | Version |
|---|---|
| PlatformIO Core | 6.2.0 |
| Platform | espressif32 7.1.3 |
| Arduino-ESP32 | 4.20017.260907 (2.0.17 API) |
| Adafruit SSD1306 | 2.5.17 |
| Adafruit SH110X | 2.1.15 |
| Adafruit GFX Library | 1.12.6 |
| Bosch BME68x Sensor library | 1.3.40408 |
| Adafruit RTClib | 2.1.4 |
| ArduinoJson | 7.4.3 |

On Arch, PlatformIO's bundled esptool needs the `intelhex` Python module. It
was installed once with:

```bash
python3 -m pip install --user --break-system-packages intelhex
# or: sudo pacman -S python-intelhex
```

## Wiring

All devices are on the default I2C bus, 3.3 V logic, 100 kHz.

| Device | Address | FireBeetle pin | Notes |
|---|---|---|---|
| 1.3" 128x64 4-pin I2C OLED | 0x3C (0x3D fallback) | SDA GPIO21, SCL GPIO22, 3V3, GND | SH1106 default, SSD1306 optional |
| BME688 | 0x76 or 0x77 | same bus, 3V3, GND | Bosch BME68x library |
| DS3231 RTC | 0x68 | same bus, 3V3, GND | CR2032 backup |
| Waveshare UPS HAT (E) | 0x2D | same bus, GND common | Fuel gauge; logic is 3.3 V |
| Panel push button (PBS-33B) | - | GPIO4 (D12 / A6 / T0) to GND | `INPUT_PULLUP`; short = next screen, long = ack |
| UPS 5 V output | - | VCC / USB 5 V, GND | Powers the ESP32 |

The I2C pins are silkscreened **`22/SCL`** and **`21/SDA`**. With the USB-C
connector at the top they are the 4th and 5th pins on the right-hand header
(VCC, 3V3, GND, 22/SCL, 21/SDA). The left-hand header also exposes the same
two pins below MISO, so either pair can be used.

The onboard user button is GPIO27 and the onboard LED is GPIO2; neither is
used. The external button is on GPIO4 so it does not conflict with the
onboard button. The GDI connector is SPI and is not used by this I2C OLED.

**Button choice:** the selected part is the **TinyTronics PBS-33B**, a 12 mm
panel-mount momentary, normally-open pushbutton. It fits the modelled
`OLED_BTN_D = 12.2` hole. Wire its two terminals to GPIO4 and GND; the firmware
uses `INPUT_PULLUP`, so no external resistor is needed.

The PBS-33B is not IP-rated. Add a rubber boot for the sealed build, or use a
sealed 16 mm IP67 metal button, which requires enlarging `OLED_BTN_D` and the
top-wall hole in the CAD. A 12 × 12 mm PCB tactile switch also works
electrically, but needs a printed bracket/plunger behind the case and does not
seal the opening.

The fitted module uses the **SH1106** controller, verified working. The 128x64
panel sits at a 2-column offset in the SH1106 controller RAM. The build flag
defaults to that:

```ini
build_flags = -DOLED_CONTROLLER_SH1106=1
```

If you swap to an **SSD1306** module (or the 0.96" one), set the flag to
`0`. Both variants compile and share the same Adafruit_GFX drawing code; only
the controller init and the display-on/off command differ. The I2C address is
0x3C on almost all modules, with 0x3D as a fallback.

`-DOLED_ROTATION=0` is the normal orientation; use `2` if the module is
mounted upside down in the case.

The module is the **4-pin version**: VCC, GND, SCL, SDA only. Wire VCC to
3V3, not 5V, so the I2C levels match the ESP32. There are no CS/DC/RES pins to
configure, and the module's onboard pull-ups are sufficient.

The UPS HAT (E) is an I2C slave at 0x2D; the ESP32 is the only master on
this bus. Do not also connect the same sensors to the Pi.

**Physical fit:** the CAD models the 1.3" module (about 35 × 34 mm PCB, active
area about 23.7 × 13.2 mm) behind a 26 × 15 mm window, and the FireBeetle
2 ESP32-UE (25.4 × 60 mm) on a tray in the bottom shell. The OLED is a separate
4-pin I2C module on a short cable, not soldered to the FireBeetle.

## What the firmware does

- Four screens, in this order: **time** (default), **battery**,
  **environment**, **storage**.
- Short button press cycles screens and wakes the OLED. A long press
  acknowledges the active alert.
- Back to the time screen after 30 s without a press. Alert screens stay until
  the condition clears or the alert is acknowledged (battery > environment >
  storage priority, with hysteresis).
- The code supports OLED off after 60 s idle; a press or a new alert wakes it.
  The current bring-up build sets `-DSCREEN_OFF_MS=0UL` so the panel stays on
  until the PBS-33B button is fitted. Change it to `60000UL` to enable blanking.
- BME688 forced-mode measurement every 5 s, pressure history for the 3 h
  trend, UPS registers polled every 5 s.
- Telemetry JSON every 10 s over USB serial; commands from the Pi are
  newline-delimited JSON as well.
- Wi-Fi and Bluetooth are never initialised.

Thresholds live in `include/config.h` and match the README table.

### Serial protocol

Pi → ESP32 (one JSON object per line):

```json
{"cmd":"time","epoch":1780000000}
{"cmd":"storage","used_pct":42.5,"free_gb":580.2}
{"cmd":"ack"}
{"cmd":"screen","index":1}
{"cmd":"status"}
```

`epoch` should be the Pi's local time (the firmware has no timezone logic).
`screen` index: 0 time, 1 battery, 2 environment, 3 storage.

Without a DS3231 the clock is lost on reset. Set it over USB (stop the serial
monitor first):

```bash
printf '{"cmd":"time","epoch":%s}\n' "$(date +%s)" > /dev/ttyUSB0
```

ESP32 → Pi every 10 s (and after `status`):

```json
{"type":"telemetry","ms":123456,"time":1780000000,
 "battery":{"present":true,"percent":78,"mv":13200,"ma":-420,
            "charging":false,"fast":false,"vbus":false,
            "vbus_mv":0,"remaining_mah":3900,
            "discharge_min":210,"charge_min":0},
 "environment":{"present":true,"temperature_c":24.3,"humidity_pct":45.1,
                "pressure_hpa":1013.2,"gas_kohm":123.4,"gas_index":145},
 "storage":{"present":true,"used_pct":42.5,"free_gb":580.2,"age_s":12},
 "alerts":[0,0,0]}
```

`alerts` is `[battery, environment, storage]` with 0 = ok, 1 = warning,
2 = critical. Values that are not available are serialized as `null`.

## Known limitations / next steps

- **Air quality** is a placeholder derived from gas resistance
  (`500 - 125*log10(R/1k)`), not Bosch BSEC. Integrate BSEC2 for a real IAQ
  value and use its accuracy/calibration state before trusting the alert.
- **SEN66** (CO2/PM) is not implemented. Add it on the same bus at 0x6B and
  extend `EnvReading` plus the environment screen.
- **Light sleep** is not implemented. The idle blanking only sends the
  SH1106/SSD1306 display-off command; the ESP32, I2C bus and telemetry keep
  running. The board has a low-power solder jumper and supports deep sleep.
  USB CDC/CH340 serial and the button wake path need care, so this is a
  deliberate next step, not an oversight.
- No pixel-shift/burn-in mitigation yet. The time screen is mostly static;
  add a small x/y offset on the time text if burn-in shows up.
- Storage data is whatever the Pi sends. With the Pi off, the last value and
  its age are shown; data older than 10 minutes is treated as stale for
  alerts.
- The UPS battery-current sign follows the Waveshare register manual:
  positive = charging, negative = discharging.

## Troubleshooting

```bash
pio device list
pio run -t upload --upload-port /dev/ttyUSB0
```

The CH340 has no unique serial number, so if several CH340 devices are
attached, specify the port explicitly. `/dev/ttyUSB0` was already writable
through the installed PlatformIO udev rules; if not:

```bash
sudo usermod -aG uucp "$USER"   # log out/in afterwards
```

Boot log is newline-delimited JSON too. With the OLED fitted:

```json
{"type":"log","msg":"mcu","model":"ESP32-D0WDR2-V3","cores":2,"flash":16777216,"psram_found":true,"psram":2095103}
{"type":"log","msg":"I2C scan"}
{"type":"log","msg":"I2C device","addr":60,"hex":"0x3C"}
{"type":"log","msg":"OLED ready","addr":60,"hex":"0x3C"}
{"type":"log","msg":"BME688 not found"}
```

`BME688 not found` is expected until that sensor is wired; the UPS is retried
once every 30 s. If the scan says `no I2C devices`, check VCC/GND/SDA/SCL and
that SDA is on GPIO21 and SCL on GPIO22.

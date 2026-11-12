# Status OLED firmware (ESP32)

PlatformIO project for the **DFRobot FireBeetle 2 ESP32-UE (N16R2)**, SKU
**DFR1140**, used as the always-on status display in the Ktemata r2 case.
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
time/date screen renders correctly. The clock uses the `TIMEZONE` setting
(default `Europe/Amsterdam`, including DST) and the Pi sends UTC.

## Bring-up status

| Item | State |
|---|---|
| FireBeetle 2 ESP32-UE | flashed; 16 MB flash and 2 MB PSRAM verified over serial |
| 1.3" 4-pin OLED | **working** at 0x3C, default SH1106 build; time/date renders in `TIMEZONE` |
| DS3231 RTC | not fitted; the clock starts from the build timestamp |
| UPS HAT (B) | **working** at 0x42 on the FireBeetle bus; a full 2S pack reads ~8.4 V, ~40 mA and 100 % (≥99 % snaps to 100) |
| Panel button (PBS-33B) | selected/ordered, not fitted; the screens auto-cycle — time 60 s, others 30 s (`-DAUTO_CYCLE_MS=30000UL`) — and can still be changed with `{"cmd":"screen","index":N}` |
| OLED idle blanking | disabled in the current build (`-DSCREEN_OFF_MS=0UL`); enable `60000UL` once the button is wired |
| Pi → ESP time and storage | **sender written**: `work/scripts/status-oled.py`, installed and enabled as `ktemata-status-oled.service` by `work/scripts/post-install.sh`; see "Pi-side sender" below |

Suggested bring-up order:

1. Plug the FireBeetle into a Pi USB-A port and run `work/scripts/post-install.sh` (or copy the sender and its unit); the OLED clock and storage screen then update on their own.
2. Wire the PBS-33B from GPIO4 to GND, check short/long press, then set `-DSCREEN_OFF_MS=60000UL` and reflash to re-enable idle blanking.
3. Fit the DS3231 and set the time once from the Pi; the service then keeps it corrected hourly.

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
| DS3231 RTC | 0x68 | same bus, 3V3, GND | CR2032 backup |
| Waveshare UPS HAT (B) | **0x42** | same bus, GND common | INA219 gauge (pack V/I/W); logic is 3.3 V. The old HAT (E) used 0x2D. |
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

The UPS HAT (B) is an INA219 I2C slave at 0x42; the ESP32 is the only master on
this bus. Do not also connect the same sensors to the Pi.

**Physical fit:** the CAD models the 1.3" module (about 35 × 34 mm PCB, active
area about 23.7 × 13.2 mm) behind a 26 × 15 mm window, and the FireBeetle
2 ESP32-UE (25.4 × 60 mm) on a tray in the bottom shell. The OLED is a separate
4-pin I2C module on a short cable, not soldered to the FireBeetle.

## What the firmware does

- Four screens, in this order: **time** (default), **power**, **storage**,
  **wifi**. The time screen draws a 9×9 clock icon beside the date and an 11×7
  battery icon whose fill follows the pack percentage; a 6×7 plug appears
  beside it when external power is attached, and `CHG` is appended while
  current flows into the pack.
- The **power** screen (header `POWER`) packs its rows from the top: percent and
  pack voltage, current and power, then the charge input when a source is
  connected (`IN 8.2 V steady`, `IN 6.1 V varying`, or no adjective until the
  one-minute window fills) — otherwise, on battery, `OB` and the load — and
  always the state line `discharging`, `charging` or `battery full`, then the
  runtime or the time to full. Input present while the pack still discharges
  reads `disch. weak in`: a source that cannot carry the load. `OL` is not
  printed: the state line already says the pack is on external power, and the
  load is unmeasurable on mains.
- The **wifi** screen mirrors the Pi's radio, which the board does not have:
  `off`, `station mode` or `access point` and the interface's IPv4 address.
  Until the Pi has sent a report it shows `no wifi data yet`.
- Short button press cycles screens and wakes the OLED. A long press
  acknowledges the active alert.
- **No button fitted yet:** the current build sets `AUTO_CYCLE_MS=30000UL`, so
  the time screen stays 60 s and power/storage/wifi 30 s. An active alert still
  takes over; waking (button, serial `screen` command, alert) restarts the
  current screen's dwell. Set `AUTO_CYCLE_MS=0UL` once the PBS-33B is wired.
- With the button in use (`AUTO_CYCLE_MS=0`), back to the time screen after 30 s
  without a press. Alert screens stay until the condition clears or the alert
  is acknowledged (battery > storage priority, with hysteresis).
- The code supports OLED off after 60 s idle; a press or a new alert wakes it.
  The current bring-up build sets `-DSCREEN_OFF_MS=0UL` so the panel stays on
  until the PBS-33B button is fitted. Change it to `60000UL` to enable blanking.
- UPS registers polled every 5 s. Mains presence is derived from the
  pack current: < −10 mA means the pack is discharging (battery only),
  anything else means the charger is attached. A full pack on charge reads
  near zero because the charger supplies the load, so the current sign is a
  better "mains present" test than the charge percentage.
- Telemetry JSON every 10 s over USB serial; commands from the Pi are
  newline-delimited JSON as well. The Arduino core logger is compiled out
  (`-DCORE_DEBUG_LEVEL=0`) and the ESP-IDF logger is set to `ESP_LOG_NONE`,
  because their free text — the `Wire.cpp` I2C errors when the UPS is absent —
  would corrupt the stream. Missing devices still appear as the JSON `not
  found` logs below.
- Wi-Fi and Bluetooth are never initialised.

Thresholds live in `include/config.h` and match the README table.

### Fonts

The UI uses **Roboto** as Adafruit_GFX bitmap fonts in `include/fonts/`:

| File | Use | Metrics |
|---|---|---|
| `Roboto5pt7b.h` | headers, labels, all body text | 7 px ascent, 10 px line pitch, tabular digits (6 px) |
| `Roboto18pt7b.h` | the clock on the time screen | 24 px digit ascent, `12:34` is 84 px wide |

They are generated from the Roboto variable font in
[google/fonts](https://github.com/google/fonts/tree/main/ofl/roboto) (SIL OFL 1.1,
`include/fonts/OFL.txt`) with Adafruit's `fontconvert`, which renders at 141 dpi:

```bash
fontconvert "Roboto[wdth,wght].ttf" 5  > include/fonts/Roboto5pt7b.h
fontconvert "Roboto[wdth,wght].ttf" 18 > include/fonts/Roboto18pt7b.h
```

A custom GFX font puts the cursor on the **baseline**, not the top-left; `bodyCursor()`,
`bodyCentered()` and `clockCentered()` in `src/main.cpp` take the top of the line and add the
ascent (7 px body, 24 px clock). Sizes are chosen so the existing 10 px row pitch still fits five
lines in 64 px; do not raise the body size without re-checking the layout.

### Serial protocol

Pi → ESP32 (one JSON object per line):

```json
{"cmd":"time","epoch":1780000000}
{"cmd":"storage","used_pct":42.5,"free_gb":580.2}
{"cmd":"wifi","state":"client","ip":"192.168.1.10"}
{"cmd":"wifi","state":"ap","ip":"10.10.10.1"}
{"cmd":"ack"}
{"cmd":"screen","index":1}
{"cmd":"status"}
```

`epoch` is a **UTC** Unix timestamp (`date +%s`). The DS3231 stores UTC; the OLED converts to
`TIMEZONE` only when rendering, so the Pi's local timezone does not matter and DST is handled by the
POSIX TZ rule. Default `TIMEZONE` is `CET-1CEST,M3.5.0,M10.5.0/3` (Europe/Amsterdam); change it in
`include/config.h` for another zone.
`screen` index: 0 time, 1 power, 2 storage, 3 wifi.
The board has no radio, so `wifi` carries the Pi's own state: `off`, `client`
(Wi-Fi up and associated) or `ap` (serving the library hotspot), plus the
`wlan0` IPv4 address. Any other state is rejected with an `error` line and the
last state is kept; the IP is truncated to 15 characters and cleared on `off`.

ESP32 → Pi every 10 s (and after `status`):

```json
{"type":"telemetry","ms":123456,"time":1780000000,
 "battery":{"present":true,"percent":78,"mv":7660,"ma":-420,
            "charging":false,"mains":false,"ol":false,"ob":true,"lb":false,
            "status":"OB","load_pct":11,"fast":false,"vbus":false,
            "vbus_mv":7660,"remaining_mah":2500,
            "runtime_s":21000,"charge_min":0,
            "source":"battery","input_mv":0,"input_stable":false},
 "input":{"present":false,"rail_mv":0,"stable":false,"samples":12},
 "storage":{"present":true,"used_pct":42.5,"free_gb":580.2,"age_s":12},
 "wifi":{"present":true,"state":"ap","age_s":4},
 "alerts":[0,0]}
```

`alerts` is `[battery, storage]` with 0 = ok, 1 = warning,
2 = critical. Values that are not available are serialized as `null`.
`wifi.state` is the last value the Pi sent (`off`, `client` or `ap`), with
`age_s` since that report; before the first one it is `null`.

`status` uses NUT's flags: `OL` = on utility power, `OB` = on battery, with
`LB` appended below 10 %. The OLED's `POWER` screen prints `OB`/`LB` only: on
mains its `charging` / `battery full` line carries the same information, so the
`OL` flag is left out. `load_pct` is the load relative to the HAT's 5 V /
5 A (25 W) output, assuming 88 % buck efficiency. The INA219 sits on the **pack**
branch, so the load is only measurable while the pack supplies it; on mains the
charger feeds the regulator and `load_pct` is `null` (the OLED omits the load).

`source` and the `input` block come from the charge-input sense line (one ADC
channel on a 30k/10k divider from the HAT's DC input, `PIN_CHG_SENSE`):
`input.rail_mv` is the rail in millivolts, `input.stable` says its spread over
the last 12 samples (60 s) is within 4 %, and `source` is `battery` (no rail and
the gauge confirms the pack is supplying), `external`, `external-weak` (rail
present but the pack still discharging) or `unknown` (no rail and no gauge, so
nothing can be claimed). One voltage
cannot tell mains from solar from crank, so nothing in the JSON claims to: it
reports the rail and whether it is steady. `battery.input_mv` and
`battery.input_stable` duplicate the two most-used fields for the Pi's log.
The boot banner prints `{"type":"log","msg":"charge sense","pin_mv":…,
"rail_mv":…}` once, which is how a wrong pin or a missing resistor is caught.

`runtime_s` is NUT's `battery.runtime`: seconds left at the measured discharge
current, from the voltage-derived remaining capacity (3200 mAh constant) divided
by that current. It is `null` on mains, or when the current is below 20 mA; the
power screen then omits the runtime row (or shows `to full` while charging). The
estimate follows the load and the (voltage-based) percentage, so it moves; it is
not a fuel-gauge measurement.

Without a DS3231 the clock is lost on reset. The Pi-side sender
(`work/scripts/status-oled.py`) covers that: it pushes UTC at start and hourly (and again when
the board announces a boot), so a reset is followed by a re-sync within seconds. Opening the
port can reset the board, so it waits two seconds before the first line; a send that the board
does not confirm with `{"type":"log","msg":"time synced"}` is repeated every 5 s (six times, then
hourly). It also sends the storage figures at start and every 60 s, the Wi-Fi state at start and
every 15 s, reads the telemetry back, and logs alert and Wi-Fi changes.
`work/scripts/post-install.sh` installs it to `/usr/local/lib/ktemata/status-oled.py` and
enables `ktemata-status-oled.service`; `--no-oled` skips it and `--oled-port` pins the device.

### Pi-side sender

```bash
python3 work/scripts/status-oled.py                 # autodetect, sync every hour
python3 work/scripts/status-oled.py --once -v      # one sync, echo what the board says
python3 work/scripts/status-oled.py --storage /srv/kiwix/zim --port /dev/ttyUSB0
```

The port is driven with `termios`, so no `pyserial` is needed. It prefers the CH340's stable
`/dev/serial/by-id` name, then `ttyUSB*`, then `ttyACM*`; when the board is unplugged it keeps
retrying instead of exiting. The unit therefore needs no device dependency. `used_pct` and
`free_gb` use `df` semantics (`f_bavail`), so the number matches what the Pi reports. Lines that
are not JSON (the boot ROM's log) are ignored unless `-v` is given.

The Wi-Fi state for the OLED comes from the Pi, never from the board: `nmcli` reports `wlan0`
as connected and the active profile's `802-11-wireless.mode` decides `ap` (the `--hotspot`
profile) versus `client`; without NetworkManager an active `hostapd` means `ap` and
`iw dev wlan0 link` means `client`; anything else — radio off, `--no-radio`, no association —
is `off`. All of it is read-only, so the service needs no extra privileges. The state is
re-sent every 15 s because a board reset loses it, and a change is logged.

It takes an **exclusive lock** on the port. Stop `ktemata-status-oled.service` before running it
by hand: two readers on one tty split the incoming bytes, so one process can miss the board's
`time synced` acknowledgement and report "never confirmed" while the other sees it.

The manual one-liner still works for a one-off (stop the service or the serial monitor first):

```bash
printf '{"cmd":"time","epoch":%s}\n' "$(date +%s)" > /dev/ttyUSB0
```

## Known limitations / next steps

- **Light sleep** is not implemented. The idle blanking only sends the
  SH1106/SSD1306 display-off command; the ESP32, I2C bus and telemetry keep
  running. The board has a low-power solder jumper and supports deep sleep.
  USB CDC/CH340 serial and the button wake path need care, so this is a
  deliberate next step, not an oversight.
- No pixel-shift/burn-in mitigation yet. The time screen is mostly static;
  add a small x/y offset on the time text if burn-in shows up.
- Storage data is whatever the Pi sends. With the Pi off, the last value is
  shown; data older than 10 minutes is treated as stale and the screen says
  `stale: Pi not sending`.
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
{"type":"log","msg":"reset","reason":9,"name":"brownout"}
{"type":"log","msg":"mcu","model":"ESP32-D0WDR2-V3","cores":2,"flash":16777216,"psram_found":true,"psram":2095103}
{"type":"log","msg":"I2C scan"}
{"type":"log","msg":"I2C device","addr":60,"hex":"0x3C"}
{"type":"log","msg":"OLED ready","addr":60,"hex":"0x3C"}
{"type":"log","msg":"UPS HAT (B) found"}
```

The UPS is retried once every 30 s. If the scan says `no I2C devices`, check
VCC/GND/SDA/SCL and that SDA is on GPIO21 and SCL on GPIO22.

`reset` is the second line after every power-up: `power-on` / `external pin` (the CH340's EN pulse
when the port opens), `brownout` (the 5 V from the HAT sagged — check the pack and the USB-A lead),
`panic` / `task watchdog` / `interrupt watchdog` (a firmware fault), `software` (an explicit restart;
none in this firmware). The Pi's sender prints it to journald as `board reset: <name> (reason N)`
without needing `-v`, so a board that reboots on its own leaves a trace.

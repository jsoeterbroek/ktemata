# Pi Fluks – reverse-engineered printable parts (r1 + r2 + r3)

The r1 geometry was rebuilt from the photos in `Pi_Flux_r1_-_Build_Guide.pdf`. The guide has no CAD
drawings, so this is a **functional re-creation**, not a copy of the original files. The r3 build is the
current target and is modelled by default: it uses the r2 mechanics unchanged, with the Phistone Mini
Keyboard (2.4 GHz dongle or Bluetooth) instead of the wired USB keyboard. Everything is parametric OpenSCAD,
and r3 shares the r2 STLs — no CAD change. Measure your own parts, edit `cad/common.scad`, then re-export.

## Project Nomad
Based on project nomad

### See: https://youtu.be/o4Bd-bleNDU?is=Fc3EMUCg8lrdhqlE

## Files

### Build variants

| Build | Mechanics | Keyboard / radios |
|---|---|---|
| **r1** | Original reverse-engineered Waveshare 5" DSI + INIU power bank case; r1-only pull switch and battery button | Original r1 keyboard; no r2 electronics |
| **r2** | Pi 5 + DFR0550-V2 + UPS HAT (E) + 4× 21700; same geometry and STLs as r3 | Wired USB keyboard; optional Pimoroni trackball; Wi-Fi/Bluetooth off |
| **r3** | **Same mechanical build and STLs as r2; current target, the default CAD geometry** | **Phistone Mini Keyboard** (2.4 GHz USB dongle or Bluetooth 5.0); **no Pimoroni trackball**; Wi-Fi off; Pi Bluetooth optional, FireBeetle radios off |

The default CAD is the **r3 / r2 build** (Pi 5 + DFR0550-V2 + UPS HAT (E) + 4× 21700). r3 is the current
target and reuses the r2 mechanics, so there is no `R3` switch: the `R2` switch selects this geometry
(`true`, the default) or the original r1 case (`-D R2=false`). The r1 parts are still in the repository and
export with `export.py --r1`. **r3 uses the same STLs as r2**; only the keyboard/radio configuration
changes. See [`docs/R3.md`](docs/R3.md).

| STL (`stl/`) | Source (`cad/`) | Print orientation | r2 / r3 |
|---|---|---|---|
| `pi_fluks_bottom.stl` – back shell | `bottom.scad` | back plate down, no supports | yes |
| `pi_fluks_face.stl` – front face | `face.scad` | face plate down | yes |
| `pi_fluks_keyboard_support.stl` | `keyboard_support.scad` | flat | yes |
| `pi_fluks_charge_plug.stl` – sealed USB-C plug | `charge_plug.scad` | flange down (TPU) | yes |
| `pi_fluks_pull_switch.stl` – USB-C U-adapter pull switch | `pull_switch.scad` | top face (ring tab) down | r1 only |
| `pi_fluks_power_button.stl` – battery button plunger | `power_button.scad` | cap end down | r1 only |

`cad/assembly.scad` shows everything with stand-in components (`-D EXPLODE=40`).
`-D 'CHECK="bottom:pi"'` intersects one part with another, which is handy for clearance checks.
To re-export the STLs: `python3 cad/tools/export.py` (use `--r1` for the original r1 set).
To refresh the images in `renders/` afterwards: `python3 cad/tools/render.py` (add `--r1` to include the r1-only views).
`R1=1 bash work/scripts/check.sh` runs the old interference set; the default is the r3/r2 set.

## Shopping list / BOM

See [`BOM.md`](BOM.md) for the r3 shopping list (Kiwi Electronics primary, with Tinytronics / Robotshop /
Bol alternates). It excludes the FireBeetle 2 ESP32-UE, the 1.3" OLED and the already-owned r3 Phistone
keyboard, and flags the current display / UPS / NVMe / button fit caveats. The r2 wired-keyboard variant
uses the same list with the keyboard alternatives in its section C.

## Hardware alternatives

Thinking of using a Waveshare PocketTerm35 as a parts donor for the screen/keyboard/MCU? See
[`docs/POCKETTERM35-FEASIBILITY.md`](docs/POCKETTERM35-FEASIBILITY.md). Short version: not a good donor for
the 5" r2 design, but the RP2040 USB keyboard is the one part worth prototyping separately.

## Wiring

See [`docs/WIRING.md`](docs/WIRING.md) for the power and data/I²C block diagrams, pin-level tables and wiring
rules. It also links the editable KiCad 10 schematic (`docs/pi_flux_r3_wiring.kicad_sch`, PDF/SVG/PNG) and
the netlist-style [`docs/pi_flux_r3_connections.csv`](docs/pi_flux_r3_connections.csv).

## Python environment

```bash
uv venv --python 3.13 .venv
uv pip install -r packages_development.txt   # or packages.txt for runtime only
source .venv/bin/activate
```

`packages.txt` holds the runtime dependencies (Pillow, for `work/scripts/crop.py`); `packages_development.txt`
adds PlatformIO, its `intelhex` runtime dependency and ruff. The export/render helpers are stdlib-only and just shell out to `openscad`.

## Status OLED firmware

`firmware/` is a PlatformIO project for the DFRobot FireBeetle 2 ESP32-UE
(N16R2, DFR1140). It drives the 1.3" 4-pin I2C OLED (SH1106/SSD1306), reads the
BME688, DS3231 and Waveshare UPS HAT (E) over I2C, and sends telemetry to the
Pi over USB serial. See `firmware/README.md` for the pinout, serial protocol
and current limitations.

```bash
source .venv/bin/activate
cd firmware
pio run                 # build
pio run -t upload       # flash over USB-C
pio device monitor      # 115200 baud
```

**Bring-up status:** the FireBeetle and 1.3" 4-pin SH1106 OLED are **working**
at `0x3C`; the display shows time/date and `BAT --` until the UPS HAT is
connected. I2C is SDA **GPIO21** / SCL **GPIO22** — the pins marked `21/SDA`
and `22/SCL`. Still to wire: button GPIO4, DS3231 `0x68`, BME688
`0x76/0x77`, UPS HAT (E) `0x2D`, and the PBS-33B button GPIO4→GND. The Pi-side serial sender for time/storage is
not written yet. Idle blanking is currently disabled (`-DSCREEN_OFF_MS=0UL`)
because the button is not fitted; the earlier blank screen was the OLED
display-off command, not an ESP32 sleep. Set it to `60000UL` when the button
works.

Without a DS3231 the clock resets on power loss; set it with (serial monitor
stopped):

```bash
printf '{"cmd":"time","epoch":%s}\n' "$(date +%s)" > /dev/ttyUSB0
```

The example sends a **UTC** epoch (`date +%s`); the FireBeetle converts it to
`TIMEZONE` (default Europe/Amsterdam, with DST) only for the OLED. Change
`TIMEZONE` in `firmware/include/config.h` for another region.

## Rugged exterior

The corner bumpers stand 3 mm proud. The body edges have a 3 mm 45° chamfer on the front and back, and the
left and right grip zones carry vertical ribs. The face has bevelled windows and faux screw heads over the
case screws. Everything prints without supports. To tune it, edit `BUMP*`, `EDGE_CZ`, `RIB_*` and `RIB_ZONES`
in `common.scad`. Imprinted text: "π·FLUKS/AI" (top) and "scientia potentia est" (bottom). The bottom also
carries "r2" next to the logo; r3 reuses that STL unchanged, so the imprint is still r2.

r3 (and r2) is 150 × 205 × 46.5 mm: 22 mm taller than r1 to fit the status-OLED band and 12 mm deeper for
the 21700 cells. The left ribs leave a gap for the sensor pocket; the sealed charge port and the 12 mm
PBS-33B OLED button (add a rubber boot for sealing) are in the top wall. The r1 pull-switch slot, side cutout
and battery button are not used in r2/r3.


## project briefing
- ruggedized, strong case, rubber corners
- boots into ubuntu kiwix - project nomad, no AI
- local offline maps, wikipedia, prepper, medical
- no networking (no wifi, no lan, no bluetooth)
- power by battery (UPS board); recharge by solar (main) + separate hand crank generator (backup); optional solar cells on backside
- Raspberry PI 5 4 GB
- 5" sunlight-readable LCD (DSI)
- wired USB keyboard (no Bluetooth)
- BME688 (successor of BME680) Breakout - Air Quality, Temperature, Pressure, Humidity Sensor
- nice to have: extra small OLED screen (FireBeetle 2 ESP32-UE) for the environment readings and warnings, and battery status (important); cycles through at least 4 screens: time (default), battery power, environment data, storage %; auto-switches to the relevant screen when a threshold is passed
- 1Tb SSD storage (NVMe 2230/2242 preferred, SATA possible)
- rubber seals for openings (not cooling)
- no sound
- clock important (correct date and time RTC)
- preferred hardware shops: [tinytronics.nl](https://www.tinytronics.nl), [bol.com](https://www.bol.com) (no Amazon)

## Target hardware (r3/r2, Pi 5 route)


| Function | Choice | Notes |
|---|---|---|
| Board | Raspberry Pi 5, 4 GB | Pi 4 was considered for lower power and rejected: idle draw is about the same (Pi 4 ≈ 2.9 W, Pi 5 ≈ 2.7–3.0 W), and the Pi 4 lacks PCIe (NVMe) and the built-in RTC. RAM size barely affects power. 4 GB covers the expected 2–4 GB use (desktop, NOMAD without AI under 1 GB, Chromium with Wikipedia + maps); keep browser tabs modest. 16 GB only pays off for local AI, which is out of scope. Project NOMAD is officially x86-64 only for now. ARM64 support is being built by the maintainers (no date). Until then, run Kiwix (Wikipedia, medical, prepper) and ProtoMaps directly, or use a community ARM build. |
| Display | **DFRobot DFR0550-V2** 5" IPS DSI, 800×480, optically bonded, 550 cd/m², anti-glare, capacitive touch | 120.7 × 75.8 × 4.9 mm, frame holes 113 × 68, Pi holes 58 × 49 (same Pi pattern as now). About 2.3 W. Brighter and less reflective outdoors than the r1 Waveshare 5" DSI (about 1.2 W, glossy, no brightness rating). Fallback: keep the Waveshare. |
| Power | **Waveshare UPS HAT (E)**: 4× 21700, 5 V 6 A out, USB-C PD 3.0 in (5–20 V, up to 40 W), I2C fuel gauge | Charges and powers the Pi at the same time, so plugging in solar or a charger does not reboot it. Most power banks drop their output for a moment when a charger is connected, which resets the Pi. 88 × 56 mm board, but the 21700 cells (Ø21 × 70 mm) set the case depth. Alternatives: SunFounder PiPower 5 (5–15 V PD in, 5 V 5 A), Geekworm X1200 (2× 18650) / X1202 (4× 18650; not compatible with the X1002 bottom NVMe board). |
| Solar | Foldable 20–30 W panel with a regulated **USB-C PD** output, into the UPS USB-C port | The UPS boards don't document raw solar input. Don't connect a bare panel; use one with a PD/regulator output or a small solar charge controller in between. |
| Hand crank (backup, nice to have) | **Separate** crank generator with rectifier + buffer capacitor, feeding the **same MPPT charge input** as solar, into the one sealed USB-C charge port | Emergency top-up for night and clouds, not a main source. Rough estimate: 10–20 W of arm effort gives about 5–10 W into the battery after losses, so 1 minute of cranking ≈ 1 minute of use, and a full charge (about 70 Wh) would take about 7–14 h. Sellers' "20 W" ratings are peaks. Kept outside the case: there's no room next to the 21700 cells, you can't hold the device steady against the crank torque, a shaft would break the seal, and it would add weight all the time. Build options: the 3D-printed axial-flux design in `reference/yt/Building a Generator [tb3iN4m9Bik].txt` (N52 magnets, 8 coils × 350 turns, gearbox, full-bridge rectifier), or a commercial USB-C crank generator. The MPPT/input-voltage regulation matters: without it the input collapses whenever cranking slows (in the video the phone kept showing "USB disconnected"). Later option: a clip-on module on the (not yet modelled) back attachment. A pedal generator gives several times more power. |
| Solar on case back (nice to have) | Thin ETFE panel (about 5–6 V) through a small solar power manager (MPPT) | The r1 back is 150 × 183 mm; the r2 back is 150 × 205 mm, so expect at most about 5–6 W peak and 2–3 W in practice. That only stretches idle time; it can't power the device while in use. Solar power banks with built-in cells charge just as slowly. |
| Keyboard | **r2:** wired USB, RP2040/Pico-based keyboard running KMK/QMK (USB HID). **r3:** **Phistone Mini Keyboard** from the r1 build (2.4 GHz + Bluetooth 5.0, 134 × 74 × 12.7 mm, USB-C, 100 h, RGB/air mouse) | Best fit: a custom PCB on the existing `KB_PCB` footprint (137 × 72), the open-source Solder Party **BBQ20KBD** (BlackBerry Q20 keys + trackpad, USB HID; sold out since Jan 2026), or the Phistone r1 keyboard. The Phistone body (134 × 74 mm) is close to the 137 × 72 `KB_PCB` footprint, and its keys sit behind the same 130 × 67 r2/r3 face window as on the r1 face, which was built around it; use its 2.4 GHz dongle in the spare Pi USB-A port, or pair it over Bluetooth (enable BT). Its layout is cramped and the Ctrl/punctuation positions are non-standard — test before committing. mini PiQWERTY (Pico, 107 × 65 mm) has no Ctrl/Alt, so it's poor for a Linux terminal. With the r3 Phistone keyboard the side cutout can stay off; set its 2.4G/BT switch before closing and charge it before assembly, or add a small sealed access. |
| Environment sensor | **Pimoroni BME688** (temp, RH, pressure, VOC/gas index; I2C) | No CO2 or particulates. For those, use Sensirion **SEN66** (PM1–10, CO2, VOC, NOx, T, RH; 55.5 × 25.6 × 21.5 mm, about 90 mA, I2C 0x6B; Adafruit SEN6x breakout). Mount it in a vented pocket on the outer wall with a membrane vent, away from Pi heat, or temperature/RH read high. The SEN66 needs real airflow (inlet + outlet). |
| Storage | 1 TB NVMe 2230/2242 on an M.2 board | Small and fast. A 1 TB 2.5" SATA SSD also works through the Waveshare PCIe-to-SATA HAT+, but needs a noticeably thicker case. M.2 **SATA** drives don't work on Pi 5 NVMe boards. Check stacking against the UPS board. |
| Clock | Pi 5 built-in RTC + **Panasonic ML-2020** rechargeable cell on the J5 battery connector | Needed with no networking (no NTP). Enable trickle charging: `dtparam=rtc_bbat_vchg=3000000` in `/boot/firmware/config.txt`. |
| Status OLED | **DFRobot FireBeetle 2 ESP32-UE (N16R2, DFR1140) with a 1.3" 4-pin I2C OLED (SH1106/SSD1306)** (ESP32-WROOM-32UE-N16R2, 16 MB flash, 2 MB PSRAM, 25.4 × 60 mm; the external antenna is not needed) running the custom PlatformIO firmware in `firmware/` | Shows **battery status** (charge %, voltage, charging/discharging, input present, estimated time left) and the environment readings, with warnings (low battery, high temperature, poor air) on screen. Works with the Pi off, so the battery level can be checked without booting. The ESP32 is the I2C master for the sensors (BME688, optional SEN66) and for the UPS HAT (E) battery monitor (I2C 0x2D, reachable by cable; Waveshare documents voltage, current, power, capacity % and USB-C input state; check the register manual). Powered from the UPS 5 V. It sends all readings to the Pi over internal USB (serial), so the Pi doesn't need its own I2C link to them. Its Wi-Fi/Bluetooth stay off in the firmware. |
| Status button | **TinyTronics PBS-33B** 12 mm panel-mount momentary NO pushbutton ([black](https://www.tinytronics.nl/en/switches/manual-switches/push-buttons-and-switches/black-push-button-12mm-reset-pbs-33b)) | Fits the modelled 12.2 mm `OLED_BTN_D` hole. One terminal to GPIO4, the other to GND (`INPUT_PULLUP`). Not IP-rated; add a rubber boot for the sealed build, or use a 16 mm IP67 metal button and enlarge the top-wall hole. Short press = next screen, long press = acknowledge. |
| Radios off | **r2 default:** `dtoverlay=disable-wifi` and `dtoverlay=disable-bt`; Wi-Fi/Bluetooth off in the FireBeetle firmware. **r3:** either use the Phistone 2.4 GHz dongle in the spare Pi USB-A, or enable the Pi's Bluetooth only (leave Wi-Fi off); FireBeetle radios stay off. | r2 matches "no networking, no Bluetooth". r3 treats the keyboard radio as an explicit input-device exception. No hardware radio switch needed. |

Check I2C address collisions before wiring: BME688 0x76/0x77, SEN66 0x6B, plus the UPS fuel gauge. The Pimoroni trackball (0x0A) is an **r2-only optional** part; **r3 drops it** because the Phistone keyboard's air mouse and the touchscreen provide pointer input. With the FireBeetle option the sensors and UPS battery monitor (0x2D) move to its I2C bus (its OLED is at 0x3C, SDA GPIO21, SCL GPIO22). Don't connect them to both the Pi and the FireBeetle; two I2C masters on one bus cause trouble.

### Considered and rejected (r2/r3)

- **MH-Real-Time Clock Modules - 2 (DS1302) for the OLED clock:** rejected. It is a 3-wire DS1302 (CE/SCLK/I/O), not I2C, so it needs three GPIOs and a separate driver (RTClib does not support it). It also has no TCXO and drifts far more than the DS3231. The DS3231 stays on the ESP32 I2C bus at 0x68; the Pi 5's own RTC + ML-2020 remains the Pi's clock. Keep a DS1302 only as a bench spare.
- **Adafruit MAX17048 QT for battery monitoring:** rejected. The UPS HAT (E) uses four 21700 cells **in series (4S)**, while the MAX17048 is a 1S gauge (2.5–4.5 V). It cannot measure the 12.0–16.8 V pack, and tapping one cell gives only that cell's voltage/SoC, not the pack's. The HAT's BQ4050-based gauge at 0x2D already reports pack voltage/current/power, charge %, remaining mAh, per-cell voltages and USB-C input state to the ESP32 while the Pi is off. A second gauge would only duplicate less accurate data and create conflicting battery alerts. The MAX17048 is useful only for a separate 1S cell (for example an ESP32 backup LiPo), which this build does not have.

### Status OLED: screens and alerts

At least four screens, cycled with a button. The **time** screen is the default.

| # | Screen | Content | Source |
|---|---|---|---|
| 1 | **Time** (default) | HH:MM, date, weekday; small battery % and alert icons | ESP32 clock, set from the Pi over USB when it runs; the Pi sends UTC and the firmware applies `TIMEZONE` (default **Europe/Amsterdam**, including DST); a **DS3231 RTC** (I2C 0x68) on the FireBeetle keeps UTC after a full power loss with the Pi off |
| 2 | **Battery power** | charge %, voltage, current (charging/discharging), input present (solar/crank), estimated time left | UPS HAT (E) battery monitor (0x2D) |
| 3 | **Environment** | temperature, humidity, pressure + 3 h trend (falling fast = weather warning), VOC/air-quality index; CO2 and PM2.5 if the SEN66 is fitted | BME688 / SEN66 |
| 4 | **Storage** | % used and free GB of the 1 TB SSD | Pi over USB; with the Pi off, shows the last value and its age |

**Navigation:** one 12 mm panel button on the case (TinyTronics PBS-33B; add a rubber boot for sealing), wired to ESP32 GPIO4. Short press: next screen. After about 30 s without a press, back to the time screen. Long press: acknowledge an alert.

**Auto-switch on thresholds:** when a value passes a threshold, the OLED jumps to that screen and marks the value (inverted/blinking). It stays there until the condition clears or the alert is acknowledged, then returns to the time screen. An acknowledged alert comes back only if it gets worse (warning → critical). With several alerts at once, priority is battery > environment > storage. Thresholds use hysteresis so a value hovering at the limit doesn't flap. Thresholds are stored in the ESP32 (NVS) and can be changed from the Pi over USB.

Starting thresholds (tune them in use):

| Value | Warning | Critical |
|---|---|---|
| Battery charge | ≤ 20 % | ≤ 10 % (the Pi also does a safe shutdown) |
| Ambient temperature | > 35 °C or < 0 °C | > 45 °C |
| Humidity | > 85 % RH | |
| Pressure | falls > 3 hPa in 3 h | falls > 6 hPa in 3 h |
| Air quality (BME688 IAQ/VOC index) | > 200 | > 300 |
| CO2 (SEN66) | > 1500 ppm | > 2500 ppm |
| PM2.5 (SEN66) | > 35 µg/m³ | > 75 µg/m³ |
| Storage used | ≥ 90 % | ≥ 97 % |

**Power and OLED care:** the ESP32 runs all the time from the UPS. Awake with the screen on, it draws roughly 0.3–0.5 W, which is about 10 % of the battery per day. So it sleeps between readings (light sleep, sensor reads about once a minute) and turns the OLED off after about 1 min idle; a button press or an alert wakes it. Small pixel shifts on the time screen reduce OLED burn-in.

### r3 CAD implementation (r2 mechanics)

r3 reuses the r2 mechanics, so `cad/` holds one geometry set: the default parts are the shared r2/r3 build
and the same `stl/` files serve both. There is no `R3` switch; the r1 geometry is kept behind `R2=false`
(`export.py --r1`). Only the keyboard/radio configuration changes, as described in [`docs/R3.md`](docs/R3.md).

**Vertical stack and case depth (identical for r2 and r3).** The UPS HAT (E) sits on the Pi's component
side (towards the back), and the four 21700 cells lie in one row below it, axes along y. This keeps the
depth at 46.5 mm for r2 and r3 instead of using the stock 2×2 cell holder (which would make the case about
73 mm deep). All z positions are derived from `CELL_*`, `UPS_*`, `DISP_*` and `DISP_POST` in `common.scad`,
so changing a component moves the shell.

- **Display:** `DISP_*` and `DISP_HOLES` now use the DFR0550-V2 (120.7 × 75.8 × 4.9 mm, outer holes 113 × 68,
  Pi holes 58 × 49). The Pi pattern is assumed centred on the display; check the inner-hole offsets on your
  unit before printing (the V3 drawing shows a slightly different pattern). The outer case posts still use
  the display's own 5 mm standoffs.
- **Battery/UPS:** `CELL_*` place four 21700 cells (Ø21 × 70) in printed U-cradles with zip-tie tunnels and
  end stops. The row is shifted 5 mm left of centre so the rightmost cell clears the Pi's USB/Ethernet port
  bodies. The Waveshare UPS HAT (E) is mounted on the Pi's component side (left-aligned, so its 88 mm board
  overhangs 23 mm to the left and ends short of the port edge); remove its 46 mm standoffs and acrylic base
  and wire the cells to V1–V4. The r1 battery bay, power-button plunger and USB-C U-adapter pull switch are
  not used in r2/r3. The r2/r3 stack has no room for the r1 active cooler or a fitted 40-pin header: the
  6.5 mm gap between the Pi and the UPS board is for the pogo pins/components. Use a thin thermal pad only if
  it fits, and expect the Pi 5 to throttle under sustained load.
- **Keyboard (the only r2 → r3 difference):** the 137 × 72 `KB_*` PCB footprint is kept, moved down to make
  the OLED band. r3 uses the r1 **Phistone Mini Keyboard** (134 × 74 × 12.7 mm, 2.4 GHz + Bluetooth, USB-C,
  100 h). Its keys sit behind the 130 × 67 face window — the same window size as on the r1 face — and its
  134 × 74 body sits in the 137 × 72 `KB_*` PCB pocket (1.5 mm narrower per side in x, 1 mm wider per side in
  y) and rests on the 126 × 69 `KBS` frame, as it did on the r1 face. No geometry changes; check the case
  edges, the 2.4G/BT switch and the USB-C port before closing. It is linked by its 2.4 GHz dongle in the
  spare Pi USB-A or over the Pi's Bluetooth, so there is no keyboard cable; r3 also drops the optional r2
  Pimoroni trackball (the air mouse and touchscreen replace it). Set the switch and charge it before final
  assembly, or add a small sealed side access, because the face has no side cutout (`SIDE_CUTOUT=false` by
  default). Its Ctrl/punctuation layout is non-standard; try it before relying on it for terminal work. An
  r2 wired USB keyboard or a custom Pico/BBQ20KBD PCB on the same footprint drops into the same support
  unchanged. The support's cable-relief notches and under-board windows are simply unused with a wireless
  keyboard. The keyboard support frame rests on four printed columns above the cells; it no longer sits on a
  power bank.
- **Status OLED:** a 1.3" 128×64 4-pin I2C OLED module (≈35 × 34 mm PCB, active area ≈23.7 × 13.2 mm)
  sits just behind a 26 × 15 window in the band between the display and the keyboard (`OLED_*`). The
  FireBeetle 2 ESP32-UE (25.4 × 60 mm) sits in a low tray in the bottom shell under the keyboard
  (`FB_*`) and connects to the OLED with a short 4-wire I2C cable; its USB cable goes to the Pi. A
  12 mm PBS-33B panel button in the top wall cycles the screens; add a rubber boot for sealing. The OLED
  window is centred on the module; move
  `OLED_CY`/`OLED_WIN` if your 1.3" module has the panel offset on its PCB.
- **Sensor pocket:** a vented chamber in the left wall with a Ø12 membrane-vent seat, vented to the outside
  and open to the interior for the cable. `-D SEN66=true` enlarges it for the Sensirion SEN66. Keep the
  BME688 away from Pi heat as described in the hardware table.
- **Charge input:** one sealed USB-C panel port in the top wall (16 × 8 × 1.2 mm rubber-plug recess) feeds a
  small internal MPPT/charge module (`MPPT_*`), which then feeds the UPS HAT USB-C input. Solar and the hand
  crank share this port. Print `charge_plug.stl` in TPU.
- **RTC:** a shallow DS3231 tray is under the keyboard (`RTC_*`). It is deliberately open at the top for
  double-sided tape or a zip tie; no retaining bridge is printed.
- **Pi ports:** the display is narrower than the r1 unit, so the Pi's right-edge ports are no longer at the
  case wall. r2/r3 have no Pi port windows. In r3 the Phistone needs no internal USB cable (2.4 GHz dongle or
  Bluetooth); only the FireBeetle USB link and the OLED's 4-wire I2C cable run inside. An r2 wired keyboard
  connects with an internal USB cable to a Pi port. The charge port is the only sealed external connector.

**Check before printing (r3).** Measure your own DFR0550-V2 inner-hole offset, UPS HAT (E) stack height,
21700 length, the 1.3" OLED module outline, the PBS-33B button body/nut clearance and the Phistone Mini
Keyboard outline (134 × 74 mm) against the 130 × 67 mm face window and the 126 × 69 mm support; these are the
parameters most likely to need a tweak. Also confirm whether your Pi 5 has a 40-pin header fitted: the
r2/r3 stack assumes it is removed (or low-profile) so the UPS HAT can sit on the component side. There is no
active cooler in the r2/r3 stack. The r2/r3 assembly is dimensioned for a 1.6 mm UPS PCB, 6 mm of
pogo-pin/component space, a 5 mm display/Pi standoff and 4.9 mm display thickness. A ±1 mm error moves the
outer depth by the same amount. The case is intentionally deeper and taller than r1; if you keep the stock
2×2 UPS holder instead, set `CELL_*`/`UPS_*` for that stack (and expect a much thicker case).

# Pi Fluks r1 – reverse-engineered printable parts

Rebuilt from the photos in `Pi_Flux_r1_-_Build_Guide.pdf`. The guide has no CAD
drawings, so this is a **functional re-creation**, not a copy of the original files.
Everything is parametric OpenSCAD. Measure your own parts, edit `cad/common.scad`,
then re-export.

## Project Nomad
Based on project nomad

### See: https://youtu.be/o4Bd-bleNDU?is=Fc3EMUCg8lrdhqlE

## Files

| STL (`stl/`) | Source (`cad/`) | Print orientation |
|---|---|---|
| `pi_fluks_bottom.stl` – back shell | `bottom.scad` | back plate down, supports for the port window bridges only |
| `pi_fluks_face.stl` – front face | `face.scad` | face plate down |
| `pi_fluks_keyboard_support.stl` | `keyboard_support.scad` | flat |
| `pi_fluks_pull_switch.stl` – USB-C U-adapter pull switch | `pull_switch.scad` | top face (ring tab) down |
| `pi_fluks_power_button.stl` – battery button plunger | `power_button.scad` | cap end down |

`cad/assembly.scad` shows everything with stand-in components (`-D EXPLODE=40`).
`-D 'CHECK="bottom:pi"'` intersects one part with another, which is handy for clearance checks.
To re-export the STLs: `python3 cad/tools/export.py`. To refresh the images in `renders/` afterwards: `python3 cad/tools/render.py`

## Rugged exterior

The corner bumpers stand 3 mm proud. The body edges have a 3 mm 45° chamfer on the front and back, and the
left and right grip zones carry vertical ribs. The face has bevelled windows and faux screw heads over the
case screws. Everything prints without supports. To tune it, edit `BUMP*`, `EDGE_CZ`, `RIB_*` and `RIB_ZONES`
in `common.scad`. Imprinted text: TBD (on the face and inside the back).


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
- nice to have: extra small OLED screen (ESP32 LilyGO) for the environment readings and warnings, and battery status (important); cycles through at least 4 screens: time (default), battery power, environment data, storage %; auto-switches to the relevant screen when a threshold is passed
- 1Tb SSD storage (NVMe 2230/2242 preferred, SATA possible)
- rubber seals for openings (not cooling)
- no sound
- clock important (correct date and time RTC)
- preferred hardware shops: [tinytronics.nl](https://www.tinytronics.nl), [bol.com](https://www.bol.com) (no Amazon)

## Target hardware (r2, Pi 5 route)


| Function | Choice | Notes |
|---|---|---|
| Board | Raspberry Pi 5, 4 GB | Pi 4 was considered for lower power and rejected: idle draw is about the same (Pi 4 ≈ 2.9 W, Pi 5 ≈ 2.7–3.0 W), and the Pi 4 lacks PCIe (NVMe) and the built-in RTC. RAM size barely affects power. 4 GB covers the expected 2–4 GB use (desktop, NOMAD without AI under 1 GB, Chromium with Wikipedia + maps); keep browser tabs modest. 16 GB only pays off for local AI, which is out of scope. Project NOMAD is officially x86-64 only for now. ARM64 support is being built by the maintainers (no date). Until then, run Kiwix (Wikipedia, medical, prepper) and ProtoMaps directly, or use a community ARM build. |
| Display | **DFRobot DFR0550-V2** 5" IPS DSI, 800×480, optically bonded, 550 cd/m², anti-glare, capacitive touch | 120.7 × 75.8 × 4.9 mm, frame holes 113 × 68, Pi holes 58 × 49 (same Pi pattern as now). About 2.3 W. Brighter and less reflective outdoors than the r1 Waveshare 5" DSI (about 1.2 W, glossy, no brightness rating). Fallback: keep the Waveshare. |
| Power | **Waveshare UPS HAT (E)**: 4× 21700, 5 V 6 A out, USB-C PD 3.0 in (5–20 V, up to 40 W), I2C fuel gauge | Charges and powers the Pi at the same time, so plugging in solar or a charger does not reboot it. Most power banks drop their output for a moment when a charger is connected, which resets the Pi. 88 × 56 mm board, but the 21700 cells (Ø21 × 70 mm) set the case depth. Alternatives: SunFounder PiPower 5 (5–15 V PD in, 5 V 5 A), Geekworm X1200 (2× 18650) / X1202 (4× 18650; not compatible with the X1002 bottom NVMe board). |
| Solar | Foldable 20–30 W panel with a regulated **USB-C PD** output, into the UPS USB-C port | The UPS boards don't document raw solar input. Don't connect a bare panel; use one with a PD/regulator output or a small solar charge controller in between. |
| Hand crank (backup, nice to have) | **Separate** crank generator with rectifier + buffer capacitor, feeding the **same MPPT charge input** as solar, into the one sealed USB-C charge port | Emergency top-up for night and clouds, not a main source. Rough estimate: 10–20 W of arm effort gives about 5–10 W into the battery after losses, so 1 minute of cranking ≈ 1 minute of use, and a full charge (about 70 Wh) would take about 7–14 h. Sellers' "20 W" ratings are peaks. Kept outside the case: there's no room next to the 21700 cells, you can't hold the device steady against the crank torque, a shaft would break the seal, and it would add weight all the time. Build options: the 3D-printed axial-flux design in `reference/yt/Building a Generator [tb3iN4m9Bik].txt` (N52 magnets, 8 coils × 350 turns, gearbox, full-bridge rectifier), or a commercial USB-C crank generator. The MPPT/input-voltage regulation matters: without it the input collapses whenever cranking slows (in the video the phone kept showing "USB disconnected"). Later option: a clip-on module on the (not yet modelled) back attachment. A pedal generator gives several times more power. |
| Solar on case back (nice to have) | Thin ETFE panel (about 5–6 V) through a small solar power manager (MPPT) | The back is about 150 × 183 mm, so expect at most about 5 W peak and 2–3 W in practice. That only stretches idle time; it can't power the device while in use. Solar power banks with built-in cells charge just as slowly. |
| Keyboard | **Wired USB**, no Bluetooth: RP2040/Pico-based keyboard running KMK/QMK (USB HID) | Best fit: a custom PCB on the existing `KB_PCB` footprint (137 × 72), or the open-source Solder Party **BBQ20KBD** (BlackBerry Q20 keys + trackpad, USB HID; sold out since Jan 2026). mini PiQWERTY (Pico, 107 × 65 mm) has no Ctrl/Alt, so it's poor for a Linux terminal. Use a short internal USB cable to a Pi USB port; the side cutout is then no longer needed (`SIDE_CUTOUT=false`). |
| Environment sensor | **Pimoroni BME688** (temp, RH, pressure, VOC/gas index; I2C) | No CO2 or particulates. For those, use Sensirion **SEN66** (PM1–10, CO2, VOC, NOx, T, RH; 55.5 × 25.6 × 21.5 mm, about 90 mA, I2C 0x6B; Adafruit SEN6x breakout). Mount it in a vented pocket on the outer wall with a membrane vent, away from Pi heat, or temperature/RH read high. The SEN66 needs real airflow (inlet + outlet). |
| Storage | 1 TB NVMe 2230/2242 on an M.2 board | Small and fast. A 1 TB 2.5" SATA SSD also works through the Waveshare PCIe-to-SATA HAT+, but needs a noticeably thicker case. M.2 **SATA** drives don't work on Pi 5 NVMe boards. Check stacking against the UPS board. |
| Clock | Pi 5 built-in RTC + **Panasonic ML-2020** rechargeable cell on the J5 battery connector | Needed with no networking (no NTP). Enable trickle charging: `dtparam=rtc_bbat_vchg=3000000` in `/boot/firmware/config.txt`. |
| Status OLED | **LilyGO ESP32-S3 board with a 0.96" SSD1306 OLED** (for example the T3-S3, about 56 × 36 mm; the LoRa radio is not used) running custom firmware (Arduino/ESP-IDF, or ESPHome) | Shows **battery status** (charge %, voltage, charging/discharging, input present, estimated time left) and the environment readings, with warnings (low battery, high temperature, poor air) on screen. Works with the Pi off, so the battery level can be checked without booting. The LilyGO is the I2C master for the sensors (BME688, optional SEN66) and for the UPS HAT (E) battery monitor (I2C 0x2D, reachable by cable; Waveshare documents voltage, current, power, capacity % and USB-C input state; check the register manual). Powered from the UPS 5 V. It sends all readings to the Pi over internal USB (serial), so the Pi doesn't need its own I2C link to them. Its Wi-Fi/Bluetooth stay off in the firmware. |
| Radios off | `dtoverlay=disable-wifi` and `dtoverlay=disable-bt` in `config.txt`; Wi-Fi/Bluetooth/LoRa off in the LilyGO firmware | Matches "no networking, no Bluetooth". No hardware radio switch needed. |

Check I2C address collisions before wiring: BME688 0x76/0x77, trackball 0x0A, SEN66 0x6B, plus the UPS fuel gauge. With the LilyGO option the sensors and the UPS battery monitor (0x2D) move to the LilyGO's I2C bus (its OLED is at 0x3C). Don't connect them to both the Pi and the LilyGO; two I2C masters on one bus cause trouble.

### Status OLED: screens and alerts

At least four screens, cycled with a button. The **time** screen is the default.

| # | Screen | Content | Source |
|---|---|---|---|
| 1 | **Time** (default) | HH:MM, date, weekday; small battery % and alert icons | ESP32 clock, set from the Pi over USB when it runs; a **DS3231 RTC** (I2C 0x68) on the LilyGO keeps the time after a full power loss with the Pi off |
| 2 | **Battery power** | charge %, voltage, current (charging/discharging), input present (solar/crank), estimated time left | UPS HAT (E) battery monitor (0x2D) |
| 3 | **Environment** | temperature, humidity, pressure + 3 h trend (falling fast = weather warning), VOC/air-quality index; CO2 and PM2.5 if the SEN66 is fitted | BME688 / SEN66 |
| 4 | **Storage** | % used and free GB of the 1 TB SSD | Pi over USB; with the Pi off, shows the last value and its age |

**Navigation:** one sealed push button on the case, wired to an ESP32 GPIO. Short press: next screen. After about 30 s without a press, back to the time screen. Long press: acknowledge an alert.

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

### CAD changes this implies (not done yet)
- Display pocket and holes for the DFR0550-V2 (`DISP_*`, `DISP_HOLES`). The Pi pattern stays 58 × 49, but the frame is 3 mm taller and 3 mm thinner than the r1 display.
- Battery bay for the UPS board + 4× 21700 instead of the INIU bank (`BAT_*`, `BTN_*`). The battery push-button plunger and the USB-C U-adapter pull switch may no longer be needed.
- Keyboard PCB mount for the wired keyboard (`KB_*`) and an internal USB cable route; drop the side cutout.
- Vented sensor pocket in the side wall; trackball window in the face; a sealed USB-C charge port (rubber plug), shared by solar and the hand crank through an internal MPPT charge module (find room for it).
- Optional LilyGO status OLED: small window in the face (for example beside the keyboard), a sealed push button for cycling screens, a DS3231 RTC module, board mount, internal USB cable to the Pi, I2C wiring to the sensor pocket and the UPS board. No antenna.


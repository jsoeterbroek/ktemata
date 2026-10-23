# Ktemata r4 — shopping list / BOM

Scope: the **r4** build in `README.md` ("Target hardware"): Pi 5 + **Raspberry Pi Touch Display 2 (5")** +
**Waveshare UPS HAT (B)** with 2× 18650 (2S) + **Rii K06** keyboard. This list is reconciled against the
**order placed on 22 Oct 2026** (`.shopping.md`): the Kiwi and Bol lines below are what was actually ordered,
and the **gaps** section lists what that order still needs before the case can be assembled and used.

r2/r3 (DFR0550-V2 + UPS HAT (E) + 4× 21700 + Phistone) remain selectable in the CAD
(`export.py --r2`, `-D R4=false`); the r2 part list is kept at the end for reference.

Prices: Kiwi lines are the order's own prices (incl. VAT, excl. shipping). Bol lines were ordered without a
printed price, so the estimates are marked `≈`. Preferred shops: **Kiwi Electronics**, **Tinytronics**,
**Robotshop EU**, **Bol.com**. No Amazon links.

Wiring: [`docs/WIRING.md`](docs/WIRING.md). r4 design notes: [`docs/R4.md`](docs/R4.md).

---

## Read this first — what changed from r2/r3

1. **Display.** The order uses the **official Raspberry Pi Touch Display 2 – 5"** (143.4 × 91.46 mm, native
   portrait), not the DFR0550-V2. That display is **143.4 mm wide in landscape**, so the r4 case grows to
   172 × 237 mm, the panel runs landscape, and the case gets 14.92 mm of display depth (6.42 mm panel + 8.5 mm
   standoffs) — the face part is 14.4 mm tall and the split plane moved up to the Pi pcb. It powers from the
   GPIO header (3-pin J1 cable, included) and is auto-detected by Pi OS; no driver work.
   *One consequence:* the TD2's **inner** Pi hole pattern is 51 × 49 mm (the Pi is 58 × 49), so the Pi is held
   by the case posts and the display by its own **outer** standoffs (122.74 × 72.96 mm). Check
   `docs/R4.md` before printing.
2. **UPS.** The order uses the **Waveshare UPS HAT (B)** (WS-20568), not the HAT (E). This is a different
   power architecture, not a drop-in swap:
   - **2× 18650 in 2S** (7.4 V nominal, ≈23 Wh) instead of 4× 21700 (≈70 Wh). Expect **≈2–2.5 h** of Pi 5
     use rather than ≈6–7 h.
   - **Charge input is 8.4 V / 2 A on a DC barrel jack**, not USB-C PD. The r4 case therefore has a
     **5.5 × 2.1 mm sealed DC socket**, and the internal solar/crank module must output **8.4 V**. A PD
     panel cannot feed this HAT directly.
   - The gauge is an **INA219 at 0x42** (not the BQ4050 at 0x2D), so the firmware driver was replaced
     (`firmware/src/ups_hat_b.cpp`). It reports pack voltage/current/power; **no per-cell data and no
     capacity percentage** — the percentage is derived from the 2S pack voltage.
   - The board carries its **own 18650 holders**, so there is no printed cell tray and no 21700 cells in this
     build.
3. **Keyboard.** The order uses the **Rii K06** (155 × 89 × 16.5 mm, touchpad, 2.4 GHz + Bluetooth), not the
   Phistone. It is 18 mm wider and 3.8 mm thicker, which is why the r4 case is 172 mm wide and the keyboard
   pocket crosses the split plane. Its touchpad replaces the r2 Pimoroni trackball.
4. **Active Cooler — does not fit.** The ordered Raspberry Pi Active Cooler (KW-3228) is 63.5 × 42.5 ×
   13.7 mm and clips onto the Pi's **component side**, which is exactly where the UPS board and its pogo pins
   sit (6 mm gap). It cannot be fitted in r4 (nor in r2/r3). Keep it as a bench spare, or return it.
5. **No coin cell, no NVMe, no RTC cell.** The DS3231 board ships **without** a CR1220; the Pi 5's ML-2020
   RTC cell and the M.2 BASE + 1 TB SSD are not in the order either. See "Gaps" below.

---

## A. Ordered — Kiwi Electronics (22 Oct 2026)

| # | Item | Code | Qty | Price | Total | Role in r4 |
|---|---|---|---|---|---|---|
| 1 | Raspberry Pi Touch Display 2 – 5 inch | KW-3549 | 1 | € 44.15 | € 44.15 | Main display. Includes the 22→15 pin FFC, the GPIO J1 power cable and 8× M2.5 screws. |
| 2 | Raspberry Pi Display Cable – Standard-Mini – 300 mm | KW-3235 | 1 | € 2.29 | € 2.29 | Spare/longer Pi 5 FFC. The display already includes one; 300 mm is long for a 237 mm case — coil it in the face cavity, don't fold it sharply. |
| 3 | Adafruit DS3231 Precision RTC Breakout | ADA-3013 | 1 | € 19.35 | € 19.35 | FireBeetle clock (0x68), keeps time with the Pi off. **CR1220 not included.** |
| 4 | BME688 4-in-1 Air Quality Breakout | PIM-575 | 1 | € 25.40 | € 25.40 | Environment screen; vented side pocket (`SENSOR_*`). |
| 5 | Raspberry Pi Active Cooler | KW-3228 | 1 | € 5.43 | € 5.43 | **Not usable** — see note 4. Bench spare. |
| 6 | UPS HAT voor RPi – 5V 5A output (Waveshare UPS HAT (B), WS-20568) | WS-20568 | 1 | € 27.82 | € 27.82 | r4 power board, 2S 18650, 8.4 V charge input, INA219 0x42. **Cells not included.** |
| | **Kiwi total** | | | | **€ 124.44** | |

## B. Ordered — Bol.com

| Item | Qty | ≈ Price | Role / note |
|---|---|---|---|
| Raspberry Pi 5 – 4 GB | 1 | ≈ € 121 | Same board as r2. **No 40-pin header must be fitted** (the UPS HAT sits on the component side). |
| Raspberry Pi 5 27 W USB-C power supply – black | 1 | ≈ € 12 | Bench power for the Pi on its own. **It cannot charge the HAT (B)** — that needs an 8.4 V barrel supply (see gaps). |
| SanDisk Extreme microSDHC 32 GB (A1/V30/U3, with adapter) | 1 | ≈ € 13 | Boot card. Too small for the ZIM library; that stays on the external disk. |
| Rii K06 mini keyboard (2.4 GHz + Bluetooth, backlit, touchpad) | 1 | ≈ € 40 | r4 keyboard. Set its 2.4G/BT switch and charge it **before** closing the case. |

Ordered subtotal: **≈ € 310**.

## C. Gaps — needed before the build is usable

These are not in the 22 Oct order. Ordered by how hard they block assembly.

| # | Item | Qty | Where | ≈ Price | Why it blocks |
|---|---|---|---|---|---|
| 1 | **2× 18650 Li-ion cells**, flat-top, unprotected, matched (e.g. Samsung 30Q / 35E) | 2 | [Tinytronics](https://www.tinytronics.nl/en/search?search=18650%203000mAh) · [Bol](https://www.bol.com/nl/nl/s/?searchtext=18650%20flat%20top%203000mAh) | ≈ € 5 each | The HAT (B) ships without cells. 2S pack; use a matched pair from one batch. |
| 2 | **8.4 V / 2 A DC power supply** with 5.5 × 2.1 mm plug | 1 | [Tinytronics](https://www.tinytronics.nl/en/search?search=8.4V%202A%20adapter) · [Bol](https://www.bol.com/nl/nl/s/?searchtext=8.4V%202A%20voeding%205.5mm) | ≈ € 12 | The only way to charge the pack and to bench-test the UPS. The ordered 27 W USB-C PSU cannot do it. |
| 3 | **Sealed DC panel socket / pigtail**, 5.5 × 2.1 mm, panel-mount with gasket | 1 | [Tinytronics](https://www.tinytronics.nl/en/search?search=DC%20paneel%20connector) · [Bol](https://www.bol.com/nl/nl/s/?searchtext=DC%20paneelconnector%205.5%202.1%20waterdicht) | ≈ € 6 | Replaces the r2 USB-C panel port; the CAD hole is now **Ø9.5 mm round** (`CHG_W`). |
| 4 | **CR1220 coin cell** | 1 | [Kiwi 750](https://www.kiwi-electronics.com/en/cr1220-battery-750) | ≈ € 2.77 | DS3231 backup; without it the OLED clock resets on power loss. |
| 5 | **2S solar/charger module with 8.4 V output** (MPPT or CC/CV) | 1 | [Tinytronics](https://www.tinytronics.nl/en/search?search=MPPT%202S%20lader) · [Robotshop](https://eu.robotshop.com/nl/search?q=2S%20MPPT%20charger) | ≈ € 20–35 | Solar/crank path. **Must be 8.4 V out**, not USB-C PD. The r2 choice (bq25185, 5 V out) no longer applies. |
| 6 | **Pi 5 RTC cell – Panasonic ML-2020 with JST plug** | 1 | [Kiwi 11586](https://www.kiwi-electronics.com/en/rtc-battery-for-raspberry-pi-5-11586) | € 5.43 | Without it the Pi's clock resets on every power-off (no NTP in this build). |
| 7 | **Storage:** Seeed PCIe-to-M.2 BASE + 1 TB M.2 2230 NVMe **or** a USB-C NVMe enclosure | 1 + 1 | [Kiwi 20204](https://www.kiwi-electronics.com/en/pcie-to-m-2-base-for-raspberry-pi-5-20204) · [Tinytronics 1 TB 2230](https://www.tinytronics.nl/en/search?search=1TB%20NVMe%202230) | € 6.40 + ≈ € 95 | 32 GB SD is not enough for ZIM. Check the BASE height against the 8.5 mm display standoff / 6 mm UPS gap. |
| 8 | **M2.5 screw set** (the case needs 6× M2.5×10) | 1 | [Kiwi 10252](https://www.kiwi-electronics.com/en/m2-5-screw-and-stand-off-set-black-nylon-380-pieces-10252) | ≈ € 12 | Display/Pi screws are included; the case screws are not. |
| 9 | **STEMMA QT / Qwiic 4-pin cables, 200 mm** | 3 | [Kiwi 10389](https://www.kiwi-electronics.com/en/stemma-qt-qwiic-jst-sh-4-pin-cable-200mm-long-10389) | ≈ € 1.44 ea | BME688, DS3231, OLED. |
| 10 | **STEMMA QT → male header cable, 150 mm** | 1 | [Kiwi 10386](https://www.kiwi-electronics.com/en/stemma-qt-qwiic-jst-sh-4-pin-to-premium-male-headers-cable-150mm-long-10386) | ≈ € 1.15 | FireBeetle header → Qw/ST bus. |
| 11 | **Dupont jumpers, female–female, 20 cm** | 1 set | [Tinytronics](https://www.tinytronics.nl/en/search?search=dupont%20kabels) | ≈ € 5 | UPS INA219 I²C (0x42) + 5 V to the FireBeetle. |
| 12 | **USB-A → USB-C data cable, 20–30 cm** | 1 | [Tinytronics](https://www.tinytronics.nl/en/search?search=USB-A%20USB-C%20kabel%2030cm) | ≈ € 5 | FireBeetle ↔ Pi serial. Use a **data-only** cable (VBUS disconnected) — the FireBeetle is powered from the UPS. |
| 13 | **USB-A → 2-pin 5 V lead (JST-XH/dupont)** | 1 | [Tinytronics](https://www.tinytronics.nl/en/search?search=USB-A%20JST%20kabel) | ≈ € 5 | UPS USB-A 5 V → FireBeetle 5 V/GND (keeps the OLED alive with the Pi off). |
| 14 | **Status button – PBS-33B 12 mm momentary NO** + 12 mm rubber boot | 1 + 1 | [Tinytronics PBS-33B](https://www.tinytronics.nl/en/switches/manual-switches/push-buttons-and-switches/black-push-button-12mm-reset-pbs-33b) | ≈ € 1.50 + € 3 | Fits `OLED_BTN_D` (12.2 mm); the boot seals it. |
| 15 | **Ø12 mm ePTFE membrane vent** | 1 | [Tinytronics](https://www.tinytronics.nl/en/search?search=membraan%20ventiel) | ≈ € 5 | Over the sensor pocket's Ø12 seat. |
| 16 | **Filament:** ≈ 400 g PETG/PLA + TPU for the charge plug | — | local | ≈ € 15 + € 20 | r4 parts are larger than r2: budget ≈ 500 g. |
| 17 | **Silicone O-ring / gasket assortment** | 1 | [Tinytronics](https://www.tinytronics.nl/en/search?search=O-ring%20assortiment) | ≈ € 10 | Case seam, DC socket, button. |
| 18 | **Fuse + holder** (2S pack lead, 3–5 A) | 1 | [Tinytronics](https://www.tinytronics.nl/en/search?search=zekeringhouder) | ≈ € 4 | The HAT (B) has protection, but fuse the pack lead anyway when you wire the cells. |

Gaps subtotal: **≈ € 250–280** (dominated by the SSD). With the ordered parts the build is **≈ € 560–590**
excluding the solar panel and the crank.

## D. Optional / later

| Item | ≈ Price | Note |
|---|---|---|
| Foldable 20–30 W solar panel | € 50–80 | Must reach **8.4 V** through the module in C5; a PD-only panel is useless here. |
| Hand crank generator (commercial, or the printed one in the separate [handcrank](https://github.com/jsoeterbroek/handcrank) project) | € 30–70 | Feeds the same charger input. A 23 Wh pack needs roughly 3–5 h of cranking for a full charge. Not part of this repo. |
| 5 W ETFE panel for the case back | € 42.34 | [Kiwi 10923](https://www.kiwi-electronics.com/en/5-watt-6-volt-solar-panel-etfe-10923); the r4 back is 172 × 237 mm. |
| Sensirion SEN66 + Adafruit SEN6x breakout | € 60–80 | Build with `-D SEN66=true`. |
| M2.5 heat-set inserts | ≈ € 13 | `BRASS_INSERT=true`. |
| Thin thermal pad | ≈ € 5 | No active cooler; only if it fits the 6 mm UPS gap. |

## E. Already owned (not in the total)

| Item | Notes |
|---|---|
| DFRobot FireBeetle 2 ESP32-UE (DFR1140) | 25.4 × 60 mm, ESP32-WROOM-32UE-N16R2. |
| 1.3" 128 × 64 4-pin I²C OLED | SH1106 default / SSD1306 option; 35 × 34 mm module. |

## F. r2/r3 reference list (not ordered)

Kept for the older build (`export.py --r2`, `-D R4=false`): DFRobot **DFR0550-V2** display + Standard–Mini
cable, **Waveshare UPS HAT (E)** + 4× 21700 (in printed cradles, wired to V1–V4), **Phistone Mini Keyboard**,
optional Pimoroni trackball, Pi 5 + ML-2020, Seeed M.2 BASE + 2230 SSD, BME688, DS3231 + CR1220, FireBeetle +
OLED, PBS-33B button, sealed **USB-C** panel port + MPPT module (5 V out), membrane vent, M2.5 set. See the
git history of this file (`git log -p -- BOM.md`) for the full r3 table with links.

> **Safety.** The HAT (B) is a **2S** pack: 7.4 V nominal, 8.4 V full, and it can deliver 5 A at 5 V out.
> Use two matched, unprotected flat-top cells from the same batch, check polarity against the PCB markings
> (the HAT has reverse-connection warning LEDs **and will be damaged by a reversed cell**), fuse the pack
> lead, and never assemble or rewire the pack with the board powered.

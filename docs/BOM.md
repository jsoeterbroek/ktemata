# Ktemata — BOM

Parts for the current build. **r5** (default) is the same electronics and display inside a bought Peli case;
**r4** (`-D R5=false`) is the printed exterior. r2/r3 are selectable in the CAD (`export.py --r2`) and their
parts are listed at the end.

Prices are indicative, in euro, for scale only.

Wiring: [`WIRING.md`](WIRING.md). r4 design notes: [`R4.md`](R4.md). r5 design notes: [`R5.md`](R5.md).

---

## A. Parts

| # | Part | Qty | Spec / role | ≈ Price |
|---|---|---|---|---|
| 1 | Raspberry Pi 5, 4 GB | 1 | 58 × 49 mm. **No 40-pin header** — the UPS HAT sits on the component side. | € 121 |
| 2 | Waveshare **7inch DSI LCD (C)**, 1024 × 600 | 1 | **192.96 × 110.76 mm**, active **154.88 × 86.72**, front glass to PCB back **10.50 mm**, 4× **M3** rear inserts (126.25 × 65.49 span), 5 V / 0.5 A. Includes DSI-Cable-12cm, two FPC leads, a 6 cm 4-pin 5 V/I²C lead and a screws pack. r5 hangs it landscape in the lid, glass flush; r4 keeps the 5" Touch Display 2 (143.4 × 91.46), selectable with `-D R5=false`. | € 62 |
| 3 | 4-pin 5 V / I²C lead, 30 cm | 1 | The display's included lead is only 6 cm; the display's 4-pin header is at the corner opposite the hinge, so a longer lead is needed to reach the Pi. Header is `GND SDA SCL 5V`; the Pi end is soldered to the 40-pin pads (5 V, GND, GPIO2/3) because the build has no 40-pin header. | € 3 |
| 4 | Waveshare UPS HAT (B) | 1 | 2S 18650, 5 V / 5 A out, **8.4 V / 2 A barrel input**, INA219 at 0x42. Cells not included; its 8.4 V / 2 A supply is. In future Waveshare UPS module 3S when available.| € 27.82 |
| 5 | 18650 Li-ion cells, flat-top, unprotected, matched pair | 2 | Same batch, ≤ 67 mm long, 3.0–3.5 Ah. | € 5 ea |
| 6 | DC panel socket, 5.5 × 2.1 mm | 1 | Panel-mount; the CAD hole is **Ø9.5 mm** (`CHG_W` in r4's printed wall, `R5_CHG_D` in r5's deck). r5 needs **no hole in the bought host**. | € 6 |
| 7 | Rii K06 keyboard | 1 | 151 × 59 × 11 mm, touchpad, 2.4 GHz + Bluetooth. Fits the 172 mm width and the 11 mm pocket. | € 40 |
| 8 | Seeed PCIe-to-M.2 BASE (103110063) | 1 | NVMe carrier, 2230–2280. Back-mounted under the Pi; **no bay in the CAD yet** — see note 7. | € 6.40 |
| 9 | WD SN740 512 GB, M.2 2242 | 1 | 2.38 mm single-sided, 4.7 W max, 300 TBW. Mount at the **42 mm** hole; the bundled 2280 bracket is unused. | € 40–60 |
| 10 | microSDHC 32 GB (A1/V30) | 1 | Boot card. Too small for the library; that stays on the NVMe. | € 13 |
| 11 | Raspberry Pi 5 27 W USB-C supply | 1 | Bench power for the Pi alone. It **cannot charge the HAT (B)**. | € 12 |
| 12 | Panasonic ML-2020, JST plug | 1 | Pi 5 clock backup on J5. Enable with `dtparam=rtc_bbat_vchg=3000000`. | € 5.43 |
| 13 | Adafruit DS3231 RTC breakout | 1 | FireBeetle clock at 0x68, keeps time with the Pi off. **CR1220 not included.** | € 19.35 |
| 14 | CR1220 coin cell | 1 | DS3231 backup; without it the OLED clock resets on power loss. | € 2.77 |
| 15 | DFRobot FireBeetle 2 ESP32-UE (DFR1140) | 1 | ESP32-WROOM-32UE-N16R2, 16 MB flash, 2 MB PSRAM, 25.4 × 60 mm, all radios off. | € 10 |
| 16 | 1.3" 128 × 64 I²C OLED, 4-pin | 1 | SH1106 default / SSD1306 option, 35 × 34 mm module. | € 5 |
| 17 | PBS-33B 12 mm momentary NO button + 12 mm rubber boot | 1 + 1 | Fits `OLED_BTN_D` (12.2 mm); the boot seals it. | € 1.50 + € 3 |
| 18 | STEMMA QT / Qwiic JST-SH 4-pin cable, 200 mm | 2 | I²C chain: DS3231, OLED (FireBeetle side uses the header cable below). | € 1.44 ea |
| 19 | STEMMA QT / Qwiic → male headers, 150 mm | 1 | FireBeetle header → Qw/ST bus. | € 1.15 |
| 20 | Dupont jumpers, female–female, 20 cm | 1 set | UPS INA219 I²C (0x42) + 5 V to the FireBeetle. | € 5 |
| 21 | USB-A → USB-C data cable, 20–30 cm | 1 | FireBeetle ↔ Pi serial. **Data-only** (VBUS disconnected) — the FireBeetle is powered from the UPS. | € 5 |
| 22 | USB-A → 2-pin 5 V lead (JST-XH / dupont) | 1 | UPS USB-A 5 V → FireBeetle 5 V/GND; keeps the OLED alive with the Pi off. | € 5 |
| 23 | M3 × 10 **countersunk** screws | 7 | DIN 7991 / ISO 10642, for the r5 deck's countersunk seats (a button head no longer fits). The display's M3 screws come in its screws pack; the cover uses four of them through the lid-side plate. | € 12 (set) |
| 23a | 16 mm IP67 metal panel button (momentary NO) | 1 | r5 power button, on the deck's right rail (`R5_BTN_D`). Two leads to the Pi 5's **J2** pads. A centred 7" panel leaves no latch band for it on the lid. | € 8 |
| 24 | Fuse + holder, 3–5 A | 1 | On the 2S pack lead. | € 4 |
| 25 | Silicone O-ring / gasket assortment | 1 | Case seam, DC socket, button. | € 10 |
| 26 | Filament, PETG/PLA + TPU | ≈ 500 g | The r4 shells or the r5 cassette; the TPU is only for the charge plug. | € 15 + € 20 |
| 27 | Peli 1200 hard case (r5 only; a 1400 is also accepted) | 1 | 236.5 × 181.1 × 30.2 mm base + 74.4 mm lid interior. See [`R5.md`](R5.md). | € 100–145 |

Parts ≈ **€ 460**; the r5 build with the Peli adds ≈ € 100–145, so ≈ **€ 560–605** complete.

## B. Nice to have

| Item | Qty | Note | ≈ Price |
|---|---|---|---|
| 2S solar/charger module with 8.4 V output (MPPT or CC/CV) | 1 | Solar/crank path. **Must be 8.4 V out**, not USB-C PD. | € 20–35 |
| Foldable 20–30 W solar panel | 1 | Must reach 8.4 V through the module above; a PD-only panel is useless here. | € 50–80 |
| 5 W ETFE panel for the case back | 1 | Fits the 172 × 237 mm r4 back. | € 42.34 |
| Hand crank generator | 1 | Feeds the same charge input. A 2S pack needs roughly 3–5 h of cranking for a full charge. Separate [handcrank](https://github.com/jsoeterbroek/handcrank) project, not part of this repo. | € 30–70 |
| M2.5 heat-set inserts | — | Only with `BRASS_INSERT=true` (r4 face). | € 13 |
| M3 heat-set inserts (4.6 mm OD × 5.7 mm) | 7 | r5 deck bosses, `M3_INS_*` in `common.scad`. The r4 case does not use them. | € 8 |
| Thin thermal pad | 1 | No active cooler; only if it fits the 6 mm UPS gap. | € 5 |

---

## Notes

1. **Display.** The r5 7" is the **Waveshare 7inch DSI LCD (C)**: 192.96 × 110.76 mm, 1024 × 600,
   active 154.88 × 86.72 (top 11.00, bottom 13.04, sides 19.04), 10.50 mm front glass to PCB back, four
   **M3** rear inserts at a 126.25 × 65.49 span (not symmetric), and unused 58 × 49 M2.5 Pi standoffs
   that protrude 3.5 mm behind the PCB. The lid cover screws through its 4 mm plate into the M3 inserts
   and the bezel top is at the glass plane, so the screen is **flush**. It runs landscape in the host lid
   and is thinner than the old TD2, so the lid clearance improves. Pi 5 DSI1 + I2C1 (`i2c1` overlay
   parameter); the touch is a Goodix at 0x14. 5 V / 0.5 A, 2.5 W.
   The **5" Touch Display 2** (143.4 × 91.46, standoffs 122.74 × 72.96, 1.4 W) is the r4 target; the r4
   case is 172 × 237 mm and the panel runs landscape in the face, auto-detected by Pi OS.
   *One consequence (r4 only):* the 5" TD2's **inner** Pi hole pattern is 51 × 49 mm (the Pi is 58 × 49),
   so the Pi is held by the case posts and the display by its own **outer** standoffs (122.74 × 72.96 mm).
   Check [`R4.md`](R4.md) before printing that variant.
2. **UPS.** The UPS HAT (B) is a different power architecture from the HAT (E), not a drop-in swap:
   - **2× 18650 in 2S** (7.4 V nominal, ≈ 23 Wh) instead of 4× 21700 (≈ 70 Wh). Expect **≈ 2–2.5 h** of Pi 5
     use rather than ≈ 6–7 h.
   - **Charge input is 8.4 V / 2 A on a DC barrel jack**, not USB-C PD. r4's printed case carries a
     **5.5 × 2.1 mm DC socket** through its top wall; **r5 mounts the same socket in the deck**, so the
     bought Peli needs no hole (charging is done with the lid open). Any internal solar/crank module must
     output **8.4 V**; a PD panel cannot feed this HAT directly.
   - The gauge is an **INA219 at 0x42** (not the BQ4050 at 0x2D), so the firmware driver is
     `firmware/src/ups_hat_b.cpp`. It reports pack voltage/current/power; **no per-cell data and no
     capacity percentage** — the percentage is derived from the 2S pack voltage.
   - The board carries its **own 18650 holders**, so there is no printed cell tray and no 21700 cells in this
     build.
3. **Keyboard.** The **Rii K06** (151 × 59 × 11 mm, touchpad, 2.4 GHz + Bluetooth) replaces the Phistone
   (134 × 74 × 12.7). At 11 mm it sits entirely inside the 14.42 mm face part; the 155 × 89 × 16.5 figure on
   Rii's product page is the **i4**, which is why the pocket used to be described as crossing the split
   plane. Its touchpad replaces the r2 Pimoroni trackball.
4. **Active Cooler — does not fit.** The Raspberry Pi Active Cooler is 63.5 × 42.5 × 13.7 mm and clips onto the
   Pi's **component side**, which is exactly where the UPS board and its pogo pins sit (6 mm gap). It cannot
   be fitted in r4 or r5, nor in r2/r3. Do not buy it.
5. **Storage and clocks.** The M.2 BASE + SN740 and the ML-2020 are r4/r5 parts. The 512 GB drive is a
   deliberate stopgap: it holds the OS, Wikipedia, the maps and the small references, **not** the whole
   833 GiB library (note 7). The DS3231 still needs its CR1220.
6. **The HAT (B) includes its 8.4 V / 2 A supply.** r4's case still needs the **panel socket** through its
   wall; r5's is the deck-mounted one and needs no host hole. Either build needs the solar/crank module if
   you build that path. A 5 V / USB-C or 5.5 × 2.5 mm bench adapter does
   **not** substitute: the HAT needs 8.4 V on a 5.5 × 2.1 mm barrel, and the Pi 5 itself has no barrel input
   at all — it takes USB-C only.
7. **The NVMe board has no home in the CAD yet.** `cad/` contains no NVMe geometry: the UPS HAT (B) owns the
   Pi's underside (6.5 mm pogo gap) and the floor is taken by the DS3231, charger module and FireBeetle. The
   BASE plus a 2.38 mm card is ≈ 10 mm tall, so it cannot simply be stacked under the Pi. Resolve that
   before printing the bottom shell.
   Also: the drive formats to ≈ 477 GiB against an 833 GiB library, so Wikipedia + maps + the small
   references fit, Gutenberg and Khan Academy do not. A 1 TB 2242 or a 2.5" SATA SSD (via a USB adapter) is
   the upgrade path.

## C. r2/r3 reference list

For the older build (`export.py --r2`, `-D R4=false`): DFRobot **DFR0550-V2** display + Standard–Mini
cable, **Waveshare UPS HAT (E)** + 4× 21700 (in printed cradles, wired to V1–V4), **Phistone Mini Keyboard**,
optional Pimoroni trackball, Pi 5 + ML-2020, Seeed M.2 BASE + 2230 SSD, DS3231 + CR1220, FireBeetle +
OLED, PBS-33B button, sealed **USB-C** panel port + MPPT module (5 V out), M2.5 set.

> **Safety.** The HAT (B) is a **2S** pack: 7.4 V nominal, 8.4 V full, and it can deliver 5 A at 5 V out.
> Use two matched, unprotected flat-top cells from the same batch, check polarity against the PCB markings
> (the HAT has reverse-connection warning LEDs **and will be damaged by a reversed cell**), fuse the pack
> lead, and never assemble or rewire the pack with the board powered.

# Pi Fluks r2 — shopping list / BOM

Scope: the hardware in `README.md` ("Target hardware") for the **r2** build. The **r3** build uses the same
parts, with the Phistone Mini Keyboard instead of a wired USB keyboard; see [`docs/R3.md`](docs/R3.md).
The **DFRobot FireBeetle 2 ESP32-UE** and the **1.3" 128×64 I²C OLED** are already owned and are
excluded from the total.

Prices were checked at **Kiwi Electronics on 19 Oct 2026** and include VAT, excluding shipping.
Stock changes quickly; several key Kiwi items are currently out of stock, so Tinytronics / Robotshop /
Bol search links are given as alternates. Treat `≈` prices as estimates.

Preferred shops: **Kiwi Electronics** (primary, NL), **Tinytronics**, **Robotshop EU**, **Bol.com**.
No Amazon links.

Wiring/connection diagrams: [`docs/WIRING.md`](docs/WIRING.md).

PocketTerm35 donor feasibility: [`docs/POCKETTERM35-FEASIBILITY.md`](docs/POCKETTERM35-FEASIBILITY.md).

---

## Read this first — fit / compatibility notes

1. **Display / Pi 5:** the DFR0550-V2 is a 15-pin DSI display; the Pi 5 has a 22-pin DSI connector. Use the
   **Raspberry Pi 5 “Standard–Mini” display cable** below. Kiwi’s DFR0550 listing currently says it
   *“does not (yet) work with the Raspberry Pi 5”* — confirm the driver/overlay before ordering. If you
   already have the r1 Waveshare 5" DSI display, it is the safe fallback. The CAD assumes **5 mm**
   display/Pi standoffs; DFRobot supplies 8 mm standoffs, so use 5 mm spacers or set `DISP_POST=8` in
   `cad/common.scad` (this adds 3 mm to the case depth).
2. **UPS HAT (E):** it is a **4S 21700** board (cells in series) with pogo-pin power and a USB-C PD input.
   The r2 CAD removes the stock acrylic base and 46 mm standoffs and puts the cells in a single-row printed
   tray, so the cells must be wired to **V1–V4** with 20–22 AWG wire. Use **flat-top, unprotected, matched**
   21700 cells. Add a fuse in the pack positive lead.
3. **No active cooler / no 40-pin header** in the r2 stack: the UPS board occupies the Pi component side.
   The 6.5 mm gap is for the pogo pins and UPS components.
4. **NVMe stacking:** the official Raspberry Pi M.2 HAT+ stacks on the GPIO side and **conflicts with the
   UPS HAT (E)**. Use the **Seeed PCIe to M.2 BASE** (back-mounted under the Pi) or a USB-C NVMe enclosure.
   Check the BASE + 2230 SSD height against the 5 mm display/Pi standoff; the CAD may need `DISP_POST`
   increased by a few mm.
5. **Status button:** the README’s **TinyTronics PBS-33B** 12 mm button fits the modelled 12.2 mm hole but
   is **not IP-rated**. Add a 12 mm rubber boot for the sealed build, or use a 16 mm IP67 metal button and
   enlarge the CAD hole. The Kiwi 12 mm metal button is 21.3 mm long and can hit the cell row in the current
   CAD, so it is not the default.
6. **Keyboard:** there is no verified off-the-shelf 137 × 72 mm wired USB keyboard. Reuse the r1 keyboard
   PCB if you have it, use a BBQ20KBD (if available), or build a custom 137 × 72 PCB. This is the only
   major item not fully specified here.

---

## A. Core computer / electronics (must have)

| # | Item | Qty | Recommended source | Price | Notes |
|---|---|---|---|---|---|
| 1 | **Raspberry Pi 5 – 4 GB** | 1 | [Kiwi 11579](https://www.kiwi-electronics.com/en/raspberry-pi-5-4gb-11579) · [Tinytronics search](https://www.tinytronics.nl/en/search?search=Raspberry%20Pi%205%204GB) · [Robotshop search](https://eu.robotshop.com/nl/search?q=Raspberry%20Pi%205%204GB) | € 120.99 | Kiwi currently out of stock. 8 GB works but the README selects 4 GB. |
| 2 | **DFRobot DFR0550-V2 5" DSI display** | 1 | [Kiwi 4050](https://www.kiwi-electronics.com/en/5quot-800x480-tft-raspberry-pi-dsi-touchscreen-4050) · [Tinytronics search](https://www.tinytronics.nl/en/search?search=DFR0550) · [Robotshop search](https://eu.robotshop.com/nl/search?q=DFR0550) | € 57.46 | Kiwi out of stock. **Read compatibility note 1.** Includes 45 mm 15-pin FFC + M2.5 standoffs/screws. |
| 3 | **Raspberry Pi 5 display cable – Standard–Mini, 300 mm** | 1 | [Kiwi 11592](https://www.kiwi-electronics.com/en/raspberry-pi-display-cable-standard-mini-300mm-11592) | € 2.29 | 22-pin Pi 5 → 15-pin display. Buy a spare if you can. |
| 4 | **Waveshare UPS HAT (E)** | 1 | [Kiwi 20623](https://www.kiwi-electronics.com/en/ups-hat-e-for-raspberry-pi-with-4x-21700-battery-support-and-5v-6a-output-20623) · [Tinytronics search](https://www.tinytronics.nl/en/search?search=UPS%20HAT%20E) · [Robotshop search](https://eu.robotshop.com/nl/search?q=UPS%20HAT%20E) | € 37.92 | Kiwi out of stock, new stock expected 01-11-2026. Check Tinytronics/Robotshop. |
| 5 | **21700 Li-ion cells – 5000 mAh, flat-top, unprotected** | 4 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=21700%205000mAh) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=21700%205000mAh%20Samsung%2050E) · [Robotshop search](https://eu.robotshop.com/nl/search?q=21700%205000mAh) | ≈ € 8 each | Samsung INR21700-50E or similar. Matched set, same batch. **No button-top/protected cells.** |
| 6 | **21700 single-cell holders with solder tabs** | 4 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=21700%20battery%20holder) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=21700%20batterijhouder%20soldeerlip) | ≈ € 2 each | For the single-row r2 tray. Reuse the holders supplied with the UPS HAT if your batch includes them. |
| 7 | **Battery wiring kit** – 20–22 AWG silicone wire, 5 A fuse + holder, heat-shrink, insulation rings | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=silicone%20wire%2022AWG) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=silicone%20draad%2022AWG%20rood%20zwart) | ≈ € 12 | 4S pack; fuse in the positive lead. Keep the series wiring short and insulated. |
| 8 | **Pimoroni BME688 breakout** | 1 | [Kiwi 10899](https://www.kiwi-electronics.com/en/bme688-4-in-1-air-quality-breakout-gas-temperature-pressure-humidity-10899) · [Tinytronics search](https://www.tinytronics.nl/en/search?search=Pimoroni%20BME688) | € 25.40 | PIM575, Qw/ST connector, 3.3 V. Fits the vented side pocket. |
| 9 | **DS3231 RTC breakout** | 1 | [Kiwi 2252](https://www.kiwi-electronics.com/en/adafruit-ds3231-precision-rtc-breakout-2252) | € 19.35 | Adafruit 23 × 17.6 mm; CR1220 backup. Keeps the FireBeetle clock when the Pi is off. |
| 10 | **CR1220 coin cell** | 1 | [Kiwi 750](https://www.kiwi-electronics.com/en/cr1220-battery-750) | € 2.77 | For the DS3231. |
| 11 | **Pi 5 RTC battery – Panasonic ML-2020 with JST plug** | 1 | [Kiwi 11586](https://www.kiwi-electronics.com/en/rtc-battery-for-raspberry-pi-5-11586) | € 5.43 | Official Pi 5 RTC cell; fits J5. |
| 12 | **Seeed PCIe to M.2 BASE for Pi 5** | 1 | [Kiwi 20204](https://www.kiwi-electronics.com/en/pcie-to-m-2-base-for-raspberry-pi-5-20204) | € 6.40 | Back-mounted, 2230/2242/2260/2280, does not block the GPIO side. **Read note 4.** |
| 13 | **1 TB M.2 2230 NVMe SSD** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=1TB%20NVMe%202230) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=1TB%20NVMe%202230) · [Robotshop search](https://eu.robotshop.com/nl/search?q=1TB%20NVMe%202230) | ≈ € 95 | Crucial P310 / WD SN770M / Samsung PM9B1 class. 2230 only for the back-mounted BASE. |
| 14 | **32 GB microSD with Raspberry Pi OS – 64-bit** | 1 | [Kiwi 20536](https://www.kiwi-electronics.com/en/32gb-microsd-with-raspberry-pi-os-64-bit-20536) | € 36.29 | Initial boot/setup. A bare 32 GB A1/A2 card is cheaper if you flash it yourself. |
| 15 | **Status button – TinyTronics PBS-33B 12 mm momentary NO** | 1 | [Tinytronics PBS-33B](https://www.tinytronics.nl/en/switches/manual-switches/push-buttons-and-switches/black-push-button-12mm-reset-pbs-33b) | ≈ € 1.50 | Fits the 12.2 mm hole; **not IP-rated**. Add a 12 mm rubber boot. GPIO4 → GND in firmware. |
| 16 | **Adafruit bq25185 USB/DC/Solar LiPo Charger + 5 V Boost** | 1 | [Kiwi 20429](https://www.kiwi-electronics.com/en/adafruit-bq25185-usb-dc-solar-charger-with-5v-boost-board-20429) | € 10.27 | 30 × 19 × 10 mm; 5–18 V solar input, 5 V/1 A out. **Not a true MPPT**; adequate for the crank/bare panel. A foldable panel with regulated USB-C PD can feed the UPS port directly. |
| 17 | **Sealed USB-C panel pigtail – female outside, male inside, with gasket** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=USB-C%20panel%20mount) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=USB-C%20paneel%20mount%20female%20male%20IP67) | ≈ € 10 | Fits the 9.2 × 3.5 mm opening + 16 × 8 mm plug recess. Print `charge_plug.stl` in TPU. |
| 18 | **Ø12 mm ePTFE membrane vent (adhesive)** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=membraan%20ventiel) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=ePTFE%20membraan%20ventiel%2012mm) | ≈ € 5 | Stick-on Gore/ePTFE vent over the sensor pocket’s Ø12 seat. |
| 19 | **M2.5 screw/standoff set** | 1 | [Kiwi 10252](https://www.kiwi-electronics.com/en/m2-5-screw-and-stand-off-set-black-nylon-380-pieces-10252) · [Kiwi brass set](https://www.kiwi-electronics.com/en/brass-male-female-spacer-set-m2-5-120pcs-9965) | € 12.09 / € 13.30 | Needs 6× M2.5×10 case screws. DFRobot supplies 8× M2.5×6 screws + 8× M2.5×8 standoffs for the display/Pi. |
| 20 | **STEMMA QT / Qwiic JST-SH 4-pin cable, 200 mm** | 2 | [Kiwi 10389](https://www.kiwi-electronics.com/en/stemma-qt-qwiic-jst-sh-4-pin-cable-200mm-long-10389) | € 1.44 each | BME688 and DS3231; add one for the r2-only trackball if used. |
| 21 | **STEMMA QT to male-header cable, 150 mm** | 1 | [Kiwi 10386](https://www.kiwi-electronics.com/en/stemma-qt-qwiic-jst-sh-4-pin-to-premium-male-headers-cable-150mm-long-10386) | € 1.15 | FireBeetle header → Qw/ST bus. |
| 22 | **USB-A to USB-C short cable, 20–30 cm** | 2 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=USB-A%20USB-C%20kabel%2030cm) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=USB-A%20naar%20USB-C%20kabel%2030cm) | ≈ € 5 each | FireBeetle ↔ Pi and keyboard ↔ Pi. |
| 23 | **Dupont jumper wires, female–female, 20 cm** | 1 set | [Kiwi search](https://www.kiwi-electronics.com/en/search?search=dupont%20female) · [Tinytronics search](https://www.tinytronics.nl/en/search?search=dupont%20kabels) | ≈ € 5 | UPS HAT I²C (0x2D) / 5 V to the FireBeetle or Pi. |
| 24 | **Raspberry Pi 27 W USB-C PSU – EU** | 1 | [Kiwi 11582](https://www.kiwi-electronics.com/en/raspberry-pi-27w-usb-c-power-supply-black-eu-11582) | € 12.09 | Bench/initial charging via the UPS USB-C input. Not needed in the field. |
| 25 | **USB-C to USB-C cable, 1 m** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=USB-C%20naar%20USB-C%20kabel) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=USB-C%20naar%20USB-C%20kabel%201m) | ≈ € 8 | PSU ↔ UPS. |
| 26 | **USB-A to 2-pin 5 V power lead (JST-XH/dupont)** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=USB-A%20JST%20kabel) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=USB-A%20naar%20JST-XH%20kabel) | ≈ € 5 | UPS USB-A 5 V → FireBeetle 5 V/GND. Keep the FireBeetle USB-C free for serial to the Pi. |

**Known-price Kiwi subtotal (items 1–4, 8–12, 14, 16, 19–21, 24): ≈ € 353.**
With the estimated items (cells, holders, wiring, SSD, button, panel port, vent, USB cables, jumpers) the
core build is roughly **€ 535–605 + shipping**, excluding keyboard, solar panel and crank.

---

## B. Power / charging (recommended)

| Item | Qty | Recommended source | Price | Notes |
|---|---|---|---|---|
| **Foldable 20–30 W solar panel with regulated USB-C PD output** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=opvouwbaar%20zonnepaneel%20USB-C) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=opvouwbaar%20zonnepaneel%2028W%20USB-C%20PD) | ≈ € 50–80 | Main solar. Must have a **regulated USB-C PD** output, not a bare 18 V barrel plug. |
| **USB-C hand-crank generator (commercial)** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=hand%20crank%20generator%20USB) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=hand%20crank%20generator%20USB-C) | ≈ € 30–60 | Backup only; separate from the case. Alternatively build the axial-flux generator from `reference/yt/`. |
| **5 W 6 V ETFE panel for the case back** | 1 | [Kiwi 10923](https://www.kiwi-electronics.com/en/5-watt-6-volt-solar-panel-etfe-10923) | € 42.34 | Nice-to-have; pair with the bq25185/MPPT. Fits the 150 × 205 mm back at ~5 W peak. |
| **Small MPPT/charge module** (true MPPT) | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=DFRobot%20Solar%20Power%20Manager%205V) · [Robotshop search](https://eu.robotshop.com/nl/search?q=solar%20power%20manager%205V) | ≈ € 20–35 | Replace the bq25185 if you want real MPPT. The bq25185 is smaller and already counted. |
| **1S LiPo buffer, 500–1000 mAh** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=LiPo%201S%20500mAh) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=LiPo%201S%20500mAh) | ≈ € 8 | Only needed with the bq25185 for a bare panel/crank. Skip it with a regulated USB-C PD panel or USB-C crank. |
| **12 mm rubber boot for PBS-33B** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=rubber%20boot%20pushbutton%2012mm) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=rubber%20kap%20drukknop%2012mm) | ≈ € 3 | Seals the non-IP-rated status button. |
| **Silicone O-ring / foam gasket assortment** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=O-ring%20assortiment) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=silicone%20O-ring%20assortiment) | ≈ € 10 | Case seam, charge port, button. |

---

## C. Optional sensors / keyboard

| Item | Qty | Recommended source | Price | Notes |
|---|---|---|---|---|
| **Pimoroni Trackball Breakout (r2 optional)** | 1 | [Kiwi 20243](https://www.kiwi-electronics.com/en/trackball-breakout-20243) · [Tinytronics search](https://www.tinytronics.nl/en/search?search=Pimoroni%20trackball) | € 18.74 | I²C 0x0A; **r2 only**. Not used in r3 — the Phistone keyboard's air mouse and the touchscreen provide pointer input. |
| **Sensirion SEN66 + Adafruit SEN6x breakout** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=SEN66) · [Robotshop search](https://eu.robotshop.com/nl/search?q=SEN66) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=SEN66%20Sensirion) | ≈ € 60–80 | Optional PM/CO₂/VOC sensor; build the CAD with `-D SEN66=true` for the larger pocket. |
| **Solder Party BBQ20KBD** | 1 | [Solder Party](https://www.solder.party/) · [Tinytronics search](https://www.tinytronics.nl/en/search?search=BBQ20KBD) | ≈ € 50–70 | USB HID, Q20 keys + trackpad. Sold out at times; check availability. |
| **Custom 137 × 72 keyboard kit** | 1 | [Kiwi Pico](https://www.kiwi-electronics.com/en/raspberry-pi-pico-10494) · [Tinytronics Choc switches](https://www.tinytronics.nl/en/search?search=Kailh%20Choc) · [Bol keycaps](https://www.bol.com/nl/nl/s/?searchtext=Kailh%20Choc%20keycaps) | ≈ € 60–100 | RP2040/Pico + Choc switches + keycaps + diodes + USB-C + PCB. Fits the existing `KB_PCB` 137 × 72 footprint. |
| **r3: Phistone Mini Keyboard** | 1 | — (already owned / original r1 source) | € 0 | 2.4 GHz + Bluetooth 5.0, 134 × 74 × 12.7 mm, USB-C, 100 h, RGB/air mouse. Fits the r2/r3 137 × 72 keyboard support/window like the r1; use the 2.4 GHz dongle in the spare Pi USB-A or pair via Bluetooth. Awkward Ctrl/punctuation layout; set its 2.4G/BT switch before closing and charge it before assembly. |
| **PLA/PETG filament for the case** | ≈ 400 g | local | ≈ € 15 | Bottom, face, keyboard support. PETG is tougher; PLA is fine indoors. |
| **TPU filament for the charge plug** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=TPU%20filament) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=TPU%20filament%201.75mm) | ≈ € 20 | Only if you do not already print TPU. |
| **Thin thermal pad / copper shim** | 1 | [Tinytronics search](https://www.tinytronics.nl/en/search?search=thermal%20pad) · [Bol search](https://www.bol.com/nl/nl/s/?searchtext=thermisch%20pad%200.5mm) | ≈ € 5 | No active cooler in r2; only if it fits the 6.5 mm gap. |
| **M2.5 heat-set inserts** | 1 set | [Kiwi brass spacer set](https://www.kiwi-electronics.com/en/brass-male-female-spacer-set-m2-5-120pcs-9965) · [Tinytronics search](https://www.tinytronics.nl/en/search?search=heat%20set%20insert%20M2.5) | ≈ € 13 | Optional; CAD `BRASS_INSERT=true`. |

---

## D. Already owned (not in total)

| Item | Notes |
|---|---|
| **DFRobot FireBeetle 2 ESP32-UE (DFR1140)** | 25.4 × 60 mm, ESP32-WROOM-32UE-N16R2. |
| **1.3" 128×64 4-pin I²C OLED** | SH1106 default / SSD1306 option; 35 × 34 mm module. |

---

## E. Quick alternates / where to search

- **Tinytronics:** <https://www.tinytronics.nl/en/search?search=DFR0550> · `UPS HAT E` · `21700 5000mAh` ·
  `Pimoroni BME688` · `1TB NVMe 2230` · `SEN66` · `USB-C panel mount`.
- **Robotshop EU:** <https://eu.robotshop.com/nl/search?q=DFR0550> · `UPS HAT E` · `21700` · `SEN66`.
- **Bol.com:** consumer items only — 21700 cells/holders, USB-C panel pigtail, short USB cables, solar panel,
  hand crank, 12 mm rubber boot, membrane vent.
- **Kiwi:** most small electronics in one order; free shipping from € 149.99, otherwise from ≈ € 4.22 in NL.

> Safety: 4× 21700 in series is a 14.4 V nominal / 16.8 V full pack with high short-circuit current.
> Use matched cells, insulate all terminals, fuse the positive lead, and never assemble the pack while the
> UPS is powered.

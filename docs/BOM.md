# Ktemata — BOM

Parts for the implemented R5 build and the proposed R6 revision inside a bought Peli case. **R6 power
substitutions are marked explicitly**; R5 remains the mechanical baseline until the R6 CAD is complete. The
earlier printed exteriors (r1–r4) are no longer modelled, and their parts are gone from this list.

Prices are indicative, in euro, for scale only.

Wiring: the preserved [`R5 KiCad project`](../cad/kicad/r5/ktemata.kicad_pro) and proposed [`R6 KiCad project`](../cad/kicad/r6/ktemata.kicad_pro), with [`WIRING.md`](WIRING.md)
for the assembly rules. **This list is not derived from the schematic** - it carries prices, suppliers,
quantities and mechanical parts a schematic has none of - but the two are cross-checked: each schematic
block names its item here in a `Part` field, and `python3 work/scripts/check_bom.py` fails if a block
points at an item that does not exist. Re-export the netlist first (see `WIRING.md` §1).

Design notes: [`R5.md`](R5.md) and the proposed [`R6.md`](R6.md).

---

## A. Parts

| # | Part | Qty | Spec / role | ≈ Price |
|---|---|---|---|---|
| 1 | Raspberry Pi 5, 4 GB | 1 | 58 × 49 mm mount. R5 uses no 40-pin header because the UPS HAT occupied the component side. In R6 the Pi + Duo instead mount behind the Waveshare 7-inch panel; keep the Pi power and display terminations exactly as shown in the selected revision's KiCad project. | € 121 |
| 2 | **Raspberry Pi Touch Display 2, 5"** (the 7" Waveshare 7inch DSI LCD (C) is the alternative lid part) | 1 | **143.4 × 91.46 mm**, active **110.7 × 62.3**, **14.92 mm** deep (6.42 body + 8.5 M2.5 standoffs), 4× **M2.5** standoffs at a 122.74 × 72.96 span, 1.4 W. r5 and r4 both hang it landscape with its glass flush; the lid cover screws through its 4 mm rear skin with **M2.5 × 8**. The 7" Waveshare module (192.96 × 110.76, 10.50 mm to the PCB back, M3 inserts) needs its own cover part and **M3 × 6** screws. | € 62 |
| 3 | 4-pin 5 V / I²C lead, 30 cm | 1 | The display's included lead is only 6 cm; the display's 4-pin header is at the corner opposite the hinge, so a longer lead is needed to reach the Pi. Header is `GND SDA SCL 5V`; the Pi end is soldered to the 40-pin pads (5 V, GND, GPIO2/3) because the build has no 40-pin header. | € 3 |
| 4 | **Waveshare UPS Module 3S** | 1 | **R6 power board.** 3S 18650 (9–12.6 V), 5 V / 5 A out, **12.6 V / 2 A charge input**, INA219 at **0x41** with a **0.1 Ω** shunt. 93 × 60 mm board, 86 × 46 mm mounting pattern, Ø3 mm holes. Cells not included. The supplied cable harness, remote output switch, insulating panels and fixings remove R5's custom soldered Pi power feed; use the supplied 12.6 V / 2 A adapter or a verified 3S regulator. | € 22 + adapter |
| 5 | 18650 Li-ion cells, flat-top, unprotected, matched triple | **3** | Same batch, ≤ 67 mm long, 3.0–3.5 Ah. Three in series for the R6 UPS Module 3S; do not mix old/new or different cell models. | € 5 ea |
| 7 | Rii K06 keyboard | 1 | 151 × 59 × 11 mm, touchpad, 2.4 GHz + Bluetooth. Fits the 172 mm width and the 11 mm pocket. | € 40 |
| 8 | **Pimoroni NVMe Base Duo (PIM704)** | 1 | Two M.2 M-key slots (2230–2280) behind an **ASM1182e** PCIe Gen 2 packet switch: ≈450 MB/s total, ≈220 MB/s each with both drives busy, so run it at Gen 2. 85 × 56 mm, mounts **under the Pi on its own 12 mm M2.5 standoffs** with both drives on its top face; power comes over the PCIe FPC (5 V/GND pads on the board if a drive needs more). The straight FPC covers the Pi's microSD slot. Firmware ≥ 2024-05-17 for NVMe boot; **slot B is picked first** at boot. | € 40 |
| 9 | WD SN740 512 GB, M.2 2242 | 1 | 2.38 mm single-sided, 4.7 W max, 300 TBW. Mount at the **42 mm** hole; the bundled 2280 bracket is unused. | € 40–60 |
| 10 | microSDHC 32 GB (A1/V30) | 1 | Boot card. Too small for the library; that stays on the NVMe. | € 13 |
| 11 | Raspberry Pi 5 27 W USB-C supply | 1 | Bench power for the Pi alone. It **cannot charge the R6 UPS Module 3S** and must not be connected simultaneously with the UPS Pi-power lead. | € 12 |
| 12 | Panasonic ML-2020, JST plug | 1 | Pi 5 clock backup on J5. Enable with `dtparam=rtc_bbat_vchg=3000000`. | € 5.43 |
| 13 | Adafruit DS3231 RTC breakout | 1 | FireBeetle clock at 0x68, keeps time with the Pi off. **CR1220 not included.** | € 19.35 |
| 14 | CR1220 coin cell | 1 | DS3231 backup; without it the OLED clock resets on power loss. | € 2.77 |
| 15 | DFRobot FireBeetle 2 ESP32-UE (DFR1140) | 1 | ESP32-WROOM-32UE-N16R2, 16 MB flash, 2 MB PSRAM, 25.4 × 60 mm, all radios off. | € 10 |
| 16 | 1.3" 128 × 64 I²C OLED, 4-pin | 1 | SH1106 default / SSD1306 option, 35 × 34 mm module. | € 5 |
| 17 | **PBS-33B 12 mm momentary NO button** (TinyTronics 001543) + 12 mm rubber boot | 1 + 1 | Cycles the OLED screens / wakes it (`PIN_BUTTON` GPIO4 → GND). M12×0.75, **thread 6 mm, panel max 3.0 mm**, so the 4.5 mm deck gets a **16 × 2 mm spot face** on the underside at `R5_OLED_BTN_*` (leaves 2.5 mm); cap Ø18, to the right of the OLED and centred on it. The spot face must be wider than your nut — measure it before printing. The boot seals it. | € 0.65 + € 3 |
| 18 | STEMMA QT / Qwiic JST-SH 4-pin cable, 200 mm | 2 | I²C chain: DS3231, OLED (FireBeetle side uses the header cable below). | € 1.44 ea |
| 19 | STEMMA QT / Qwiic → male headers, 150 mm | 1 | FireBeetle header → Qw/ST bus. | € 1.15 |
| 20 | Dupont jumpers, female–female, 20 cm | 1 set | R6 UPS INA219 I²C (**0x41**) + auxiliary 5 V to the FireBeetle. The Module 3S gauge has a 0.1 Ω shunt; firmware calibration must change with it. | € 5 |
| 20a | Resistors **47k** and **10k** (1 %, 0.25 W) + **100 nF** ceramic | 1 + 1 + 1 | R6 charge-input sense divider on the UPS Module 3S input → `A0` (ADC1). **12.6 V → 2.21 V**, 221 µA; leaves ADC margin unlike R5's 30k/10k divider. Soldered inline; the circuit is on the `/Power` sheet of the [`R6 KiCad project`](../cad/kicad/r6/ktemata.kicad_pro). | € 0.30 |
| 21 | USB-A → USB-C **data** cable, 20–30 cm | 1 | FireBeetle ↔ Pi serial. Any data cable; its +5 V wire is fed through 21a, not straight from the Pi. | € 5 |
| 21a | **1N5819 Schottky diode**, in the cable's +5 V wire at the Pi end | 1 | **An open-circuit power blocker does not work here.** The DFR1140 powers its CH340K from USB VBUS (U4 VCC = VUSB), so with VBUS cut the Pi sees no serial device. The diode keeps the CH340 alive at ≈4.7 V while the FireBeetle's VCC stays on the UPS 5 V, so with the UPS on the board's D2 stays reverse-biased and the Pi cannot backfeed the UPS. Band toward the FireBeetle; splice it into the red wire or build a 5 cm A-male → A-female adapter. The PortaPow USB Power Blocker (5 V open) is **not usable** for this link. | € 0.20 |
| 22 | 2-pin auxiliary 5 V lead (JST-XH / Dupont, as fitted) | 1 | R6 UPS Module 3S auxiliary 5 V output → FireBeetle; keeps the status system alive with the Pi off. The Module 3S has no R5-style USB-A output; use its header and supplied harness where compatible. | € 5 |
| 23 | [M3 × 10 **countersunk hex screws**, steel](https://www.kingmicroschroeven.nl/bzk-inbus-verzonkenkopschroef-staal-din-7991-m3x10.html) | **7** | DIN 7991 / ISO 10642; **dk 6.0 mm, k 1.7 mm, 2.0 mm hex**. Seven R5 deck screws into the heat-set inserts. **R6's full-face deck instead needs 4 × M3 × 20** countersunk into the tray's Ø2.6 pilots (13.5 mm deck + 6.5 mm engagement), and the panel screws through the deck's 3 mm floor are **4 × M3 × 6–8**. Sold in packs of 25. | € 2.60 / 25 |
| 23a | [M3 × 6 **countersunk hex screws**, steel](https://www.kingmicroschroeven.nl/inbus-torx-schroeven/inbusbout-met-verzonken-kop-staal/inbusbout-verzonkenkop-m3/) | **4** | Same DIN 7991 head and 2.0 mm hex. For the 4 mm lid cover **or** alternate plate into the display's rear inserts; gives ≈1.04 mm engagement. **Do not substitute M3 × 8**, which can bottom out. Sold in packs of 25. | € 2.45 / 25 |
| 23b | **Waveshare XH2.54 self-lock output button**, red/black, 15 cm | 1 | Supplied with the UPS Module 3S (item 4). Plugs directly into the UPS switch port; no PCH connection or LED. Shut the Pi down in software before switching off. | Included |
| 23c | **XH2.54 → DC5521 female charge lead**, 15 cm | 1 | Supplied with the UPS Module 3S (item 4). The 12.6 V / 2 A source plugs directly into the UPS through this lead. PCH J1 is only a high-impedance charge-sense tap, not a charge-current path. | Included |
| 24 | **Fuse holder 5×20 mm, PCB, 5 A** — BLX-A-5X20MM (TinyTronics 001195) | 1 | Holds a standard 5 × 20 mm cartridge, **holder rated 5 A / 250 V**, hinged cover so the fuse is replaceable in the field, ~26 × 9 × 18 mm, two 1.2 mm PCB legs. In a wired harness: solder the pack lead to the legs, heat-shrink the joints, and strap the body down. | € 0.50 |
| 24a | **Fuse 5 × 20 mm, 250 V, 5 A, fast-acting (F)** — FUSE5X20MM5A (TinyTronics 007152) | 1 (spare advised) | ESKA 5 × 20 F, 250 V AC, 5 A, ≈0.03 Ω, IEC 60127-2. R6 retains a 5 A pack-fuse requirement pending physical placement review: full 25 W output is ≈3.2 A at 9 V with 88% conversion efficiency, below 5 A but with less margin than R5. **Not** for the 2 A charge input. Verify the fuse location with the UPS Module 3S factory holders before assembly. | € 0.40 |
| 25 | Silicone O-ring / gasket assortment | 1 | Case seam, DC socket, button. | € 10 |
| 26 | Filament, PETG/PLA + TPU | ≈ 500 g | The r4 shells or the r5 cassette; the TPU is only for the charge plug. | € 15 + € 20 |
| 27 | Peli 1200 hard case (r5 only; a 1400 is also accepted) | 1 | 236.5 × 181.1 × 30.2 mm base + 74.4 mm lid interior. See [`R5.md`](R5.md). | € 100–145 |

The historical R5 list totalled ≈ **€ 460** before the Peli. Do not reuse that total for R6: the UPS adapter,
third cell, 3S regulator, mounting extensions and lid harness change the total; price R6 after those parts are
selected and bench-verified.

## B. Nice to have

| Item | Qty | Note | ≈ Price |
|---|---|---|---|
| **3S solar/charger module with 12.6 V output** (MPPT or CC/CV) | 1 | R6 solar/crank path. **Must be 12.6 V out**, regulated for the UPS Module 3S; R5's 8.4 V module is incompatible. Verify input ripple and simultaneous charge/load operation. | € 20–35 |
| Foldable 20–30 W solar panel | 1 | Must suit the 3S regulator's input range and provide useful current after conversion to 12.6 V; a PD-only panel is unsuitable. The UPS accepts up to 2 A at 12.6 V (25.2 W input rating). | € 50–80 |
| 5 W ETFE panel for the case back | 1 | Fits the 172 × 237 mm r4 back. | € 42.34 |
| Hand crank generator | 1 | Feeds the R6 charge input through a suitable **12.6 V / 3S regulator**; the regulator, not the bare crank, sets the UPS input. Expect longer full-charge effort than R5 because the pack has 50% more energy. Separate [handcrank](https://github.com/jsoeterbroek/handcrank) project, not part of this repo. | € 30–70 |
| M2.5 heat-set inserts | — | Only with `BRASS_INSERT=true` (r4 face). | € 13 |
| M3 heat-set inserts (4.6 mm OD × 5.7 mm) | 7 | r5 deck bosses, `M3_INS_*` in `common.scad`. The r4 case does not use them. | € 8 |
| Thin thermal pad | 1 | No active cooler; only if it fits the 6 mm UPS gap. | € 5 |
| **≥5 A latching switch** (16 mm, M16×1) **or** a **MOSFET/relay module** driven by the fitted button | 1 | **Future add.** The fitted ABS16CG11ZCB3V is rated 3 A / 24 V, so it only switches the R6 12.6 V charge input. For a real main switch, use a latching switch rated **≥5 A at 5 V DC** (the Pi 5 rail is rated 5 A; this build peaks ≈2.8 A), or keep the button as a low-current control driving a logic-level MOSFET or automotive relay in the 5 V pair. Either way it is still a hard cut — shut the Pi down in software first. | € 5–15 |

---

## Notes

1. **Display.** r5 and r4 both use the **Raspberry Pi Touch Display 2, 5"**: 143.4 × 91.46 mm,
   720 × 1280, active 110.7 × 62.3, 14.92 mm deep (6.42 body + 8.5 **M2.5** standoffs), four standoffs
   on a 122.74 × 72.96 pattern, 1.4 W. In r5 four **DIN 7991 M2.5 × 8** screws pass through the lid
   cover's 4 mm rear skin into those standoffs; their heads sit in 90° countersinks on the tape side,
   and the display glass is **flush with the entire front face**. It runs landscape in the host lid,
   auto-detected by Pi OS. DSI1 + I2C1 (`i2c1` overlay parameter); the touch is a Goodix at 0x14.
   The **7" Waveshare 7inch DSI LCD (C)** (192.96 × 110.76, 1024 × 600, 10.50 mm to the PCB back, four
   **M3** inserts at a 126.25 × 65.49 span) is kept as an alternative lid part,
   `ktemata_r5_lid_cover_waveshare_7in`; it needs **M3 × 6** screws instead and its 33.67 mm latch band
   is what pushed the power button onto the deck.
   *One consequence (r4 only):* the 5" TD2's **inner** Pi hole pattern is 51 × 49 mm (the Pi is 58 × 49),
   so the Pi is held by the case posts and the display by its own **outer** standoffs (122.74 × 72.96 mm).
2. **UPS — R6 uses the Waveshare UPS Module 3S.** It is not a drop-in HAT (B) replacement:
   - **3× 18650 in 3S** give approximately 11.1 V nominal, 12.6 V full and 50% more energy than R5 with
     identical cells. The larger Waveshare 7-inch display consumes part of that gain; see [`R6.md`](R6.md) for the
     runtime model.
   - **Charge input is 12.6 V / 2 A.** Replace R5's 8.4 V adapter and 2S solar/crank regulator. The panel or
     crank can be retained only if the new regulator accepts their output and supplies a clean 12.6 V rail.
   - The gauge is an **INA219 at 0x41 with a 0.1 Ω shunt**. The firmware must change address, current/power
     calibration, pack-voltage model and capacity. The current channel can saturate near 3.2 A at low pack
     voltage and full output; voltage-based protection must remain valid.
   - The board is **93 × 60 mm**, with an **86 × 46 mm** Ø3 mm mounting pattern and its own three-cell holder.
     Preserve the supplied insulating panels and access for cell service and initial BOOT activation.
   - The supplied cable harness powers the Pi without R5's custom soldered feed. No USB-PD capability is
     documented, so verify loaded voltage and Pi peripheral-current behaviour rather than assuming PD.
3. **Keyboard.** The **Rii K06** (151 × 59 × 11 mm, touchpad, 2.4 GHz + Bluetooth) replaces the Phistone
   (134 × 74 × 12.7). At 11 mm it sits entirely inside the 14.42 mm face part; the 155 × 89 × 16.5 figure on
   Rii's product page is the **i4**, which is why the pocket used to be described as crossing the split
   plane. Its touchpad replaces the r2 Pimoroni trackball.
4. **Active Cooler — does not fit.** The Raspberry Pi Active Cooler is 63.5 × 42.5 × 13.7 mm and clips onto the
   Pi's **component side**, which is exactly where the UPS board and its pogo pins sit (6 mm gap). It cannot
   be fitted in r4 or r5, nor in r2/r3. Do not buy it.
5. **Storage and clocks.** The NVMe Base Duo + drives and the ML-2020 are the storage side. One 512 GB
   drive holds the OS, Wikipedia, the maps and the small references, **not** the whole 833 GiB library —
   the second slot is what closes that gap (note 7). The DS3231 still needs its CR1220.
6. **The UPS Module 3S is offered with a 12.6 V / 2 A supply.** Use that supply or a verified 3S regulator;
   R5's 8.4 V adapter is incompatible. The panel-mount charge hardware stays inside the cassette so the
   bought Peli needs no hole. A 5 V USB-C charger cannot charge the 3S pack, and the Pi's bench USB-C supply
   is not an input to the UPS. The UPS-to-Pi manufactured lead is the normal R6 Pi power path.
7. **The NVMe board.** The NVMe Base Duo has a home in the cassette: it sits on the four Ø8 posts under the
   Pi at x 152–208, y 16–101 (`R5_M2_BOT` is the post top, 7.4 mm), with its own 12 mm standoffs carrying the
   Pi above it and both SSDs on its top face inside that gap. The four corner screws clamp the Duo; the Pi is
   fixed to the Duo's standoffs, so nothing passes through to the tray.
   Capacity: one 512 GB drive formats to ≈477 GiB against an 833 GiB library — Wikipedia + maps + the small
   references fit, Gutenberg and Khan Academy do not. The second slot closes that: 2× 1 TB is two full
   copies of the library, and Pimoroni's tested list includes the SN740 512 GB in this very build.
   Boot order is worth knowing: with two drives the Pi boots from **slot B**, so put the OS there.

## C. r2/r3 reference list

Earlier-build parts, kept only as history (the CAD no longer models them): DFRobot **DFR0550-V2** display + Standard–Mini
cable, **Waveshare UPS HAT (E)** + 4× 21700 (in printed cradles, wired to V1–V4), **Phistone Mini Keyboard**,
optional Pimoroni trackball, Pi 5 + ML-2020, DS3231 + CR1220, FireBeetle +
OLED, PBS-33B button, sealed **USB-C** panel port + MPPT module (5 V out), M2.5 set.

> **Safety.** R6's UPS Module 3S uses a **3S** pack: 11.1 V nominal, 12.6 V full, with up to 5 A at 5 V out.
> Use three matched, unprotected flat-top cells from one batch; check polarity and the module's reverse-warning
> indicators before charging. Verify pack-fuse placement with the factory holders, keep the supplied insulating
> panels fitted, and never assemble or rewire the pack powered. Press BOOT only as the manufacturer directs for
> initial protection-chip activation.

## D. PCH board

Carrier board for the R6 power/communication hub — project [`cad/kicad/r6/PCH/PCH.kicad_pro`](../cad/kicad/r6/PCH/PCH.kicad_pro).
Parts as exported from `PCH.csv`; connectors and passives are not yet priced.

| Ref | Value | Qty | Part |
|---|---|---|---|
| J1 | CHG_SENSE_IN | 1 | JST XH 2.54mm 2 pin 15cm |
| J5 | UPS3S_HDR_2X4 | 1 | 2.54mm 2x4 pin header |
| J6 | HOST_AUX_PWR_I2C | 1 | 2.54mm 1x5 pin header |
| J7 | UPS_12V6_IN | 1 | JST XH 2.54mm 2 pin 15cm |
| J8 | AUX_12V6_OUT | 1 | JST XH 2.54mm 2 pin 15cm |

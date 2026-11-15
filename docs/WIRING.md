# Ktemata r5 — wiring

The wiring of this build is defined **in KiCad**, not here: `docs/kicad/` is a KiCad 10 project whose
sheets are the netlist. This page says how to open it, what each sheet holds, and the assembly rules a
schematic cannot state. **If this page and the schematic ever disagree, the schematic is right.**

```bash
open docs/kicad/ktemata.kicad_pro          # macOS; or open the folder in KiCad and pick the project
```

## 1. The project

| sheet | file | holds |
|---|---|---|
| `/` | `ktemata.kicad_sch` | A3 index: the three sheets below, plus the reading notes |
| `/Power` | `power.kicad_sch` | 8.4 V source, DC-099 panel jack, 16 mm latching switch, 2S pack + 5 A fuse, charge-sense divider, UPS HAT (B) with its INA219 |
| `/Pi 5 and its peripherals` | `pi.kicad_sch` | Pi 5, Touch Display 2, Pimoroni NVMe Base Duo, K06 dongle, ML-2020 cell |
| `/FireBeetle …` | `mcu.kicad_sch` | FireBeetle 2, 1.3" OLED, DS3231, PBS-33B button |

It is a **net-label schematic**: one connector-shaped block per module (`Ktemata:` symbols, embedded
in each sheet, so nothing has to be installed), a short wire and a **global label** per pin. A net with
the same name on two sheets is one net; nothing is routed, and moving blocks around changes nothing
electrically. The same 15 symbols are also a real library, `ktemata.kicad_sym`, registered by the
project's `sym-lib-table`, so the library browser and copy-paste between sheets work — and **ERC is
clean: 0 violations**.

Derived views, generated from the project — never edited by hand:

```bash
kicad-cli sch export pdf -o ktemata_r5_wiring.pdf docs/kicad/ktemata.kicad_sch
kicad-cli sch erc --severity-all -o erc.rpt docs/kicad/ktemata.kicad_sch
kicad-cli sch export netlist --format kicadxml -o /tmp/kt.xml docs/kicad/ktemata.kicad_sch
python3 work/scripts/kicad_netlist_csv.py /tmp/kt.xml -o docs/kicad/ktemata_r5_connections.csv
```

`docs/kicad/ktemata_r5_connections.csv` is that last step's output: one row per pin on every net, so it
cannot drift from the schematic. Editing the schematic is how a connection changes.

[`BOM.md`](BOM.md) stays a separate purchasing list — prices, suppliers, mechanical parts, none of which a
schematic has. The link between the two is a `Part` field on every block naming its BOM item, and

```bash
python3 work/scripts/check_bom.py /tmp/kt.xml
```

fails if a block names an item the BOM does not have, or if two blocks claim the same one. BOM items with
no symbol (screws, cables, the case) are listed, not failed.

## 2. Assembly rules

These are the constraints the drawing cannot carry. Values live in the schematic; the *practice* is here.

1. **One ground node.** HAT, Pi, FireBeetle, OLED, DS3231, both buttons and the charge jack share GND,
   with the star point at the HAT. The keyboard is the exception: it is wireless and has no electrical
   connection.
2. **One I²C master.** The FireBeetle owns the bus. Do not connect the HAT's I²C — or anything else on
   it — to the Pi.
3. **Pull-ups.** OLED, DS3231 and the HAT's INA219 may each carry 4.7–10 kΩ pull-ups; in parallel they
   load the bus. Keep **one** set and check with a meter before powering.
4. **3.3 V only** on the I²C modules and the HAT's I²C logic. Never power the OLED or DS3231 from 5 V.
5. **FireBeetle power vs USB.** Its 5 V comes from the HAT's USB-A, so the OLED works with the Pi off;
   the USB-C link to the Pi is data only. Use a data-only cable, or cut VBUS, so the Pi is not backfed.
6. **Never feed the Pi twice.** With the HAT's 5 V soldered onto the Pi, do not plug a supply into the
   Pi's USB-C.
7. **Display.** The Touch Display 2 needs its 3-pin power cable as well as the DSI FFC; it is
   auto-detected, so fit **no** `vc4-kms-dsi-…` overlay.
8. **Pack.** 2S = 7.4 V nominal, 8.4 V full. Matched cells, insulation rings, the 5 A fuse in the
   positive lead, and never assemble or rewire the pack with the HAT powered.
9. **Buttons and switch.** The PBS-33B is not IP-rated — fit the 12 mm rubber boot. The 16 mm switch is
   **latching**: shut the Pi down in software, then cut. Its LED is fed from 5 V, not from the 8.4 V rail.
10. **NVMe.** Check the Duo plus drives stack against the tray before final assembly
    ([`BOM.md`](BOM.md) note 7).
11. **First power-up:** Pi disconnected. Feed 8.4 V and check the pack voltage, the fused + lead and the
    5 V / USB-A outputs; then the I²C scan should show `0x3C`, `0x42`, `0x68`; then connect the Pi and
    check `vcgencmd get_throttled` = `0x0`.
12. **Keyboard link.** 2.4 GHz dongle in a Pi USB-A, or Bluetooth with the Pi's radio enabled and a wired
    keyboard kept for first boot and recovery. Wi-Fi stays off; the FireBeetle radios stay off; the
    keyboard's own link is the single allowed radio exception.

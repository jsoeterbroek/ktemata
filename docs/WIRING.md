# Ktemata wiring — R5 and R6

Wiring is defined **in KiCad**, not here. Two self-contained KiCad 10 projects share the same sheet layout
but have separate libraries and derived netlists. **If this page and a schematic ever disagree, that
revision's schematic is right.**

| Revision | Project | Status |
|---|---|---|
| R5 | `docs/kicad/r5/ktemata.kicad_pro` | Preserved implemented build |
| R6 | `docs/kicad/r6/ktemata.kicad_pro` | Proposed layout and UPS/display revision; bench verification still required |

```bash
open docs/kicad/r5/ktemata.kicad_pro
open docs/kicad/r6/ktemata.kicad_pro       # macOS; or pick each project in KiCad
```

## 1. The projects

Both revisions use an A3 index and three A4 sheets:

| sheet | file | R5 | R6 |
|---|---|---|---|
| `/` | `ktemata.kicad_sch` | Index and reading notes | Same structure, R6 titles and export path |
| `/Power` | `power.kicad_sch` | 2S pack, 8.4 V charging, UPS HAT (B) | **3S pack, 12.6 V charging, UPS Module 3S**, revised sensing |
| `/Pi 5 and its peripherals` | `pi.kicad_sch` | Touch Display 2, NVMe, keyboard, RTC | **Waveshare 7inch DSI LCD (C)** including its touch interface; other functions retained |
| `/FireBeetle …` | `mcu.kicad_sch` | Controller and status components on the deck | FireBeetle/RTC in the base; OLED/button in the lid through a serviceable harness |

One connector-shaped block per module (`Ktemata:` symbols — also a real library, `ktemata.kicad_sym`,
registered by the project's `sym-lib-table`). Within a sheet the nets are **routed**: each multi-pin net
gets a vertical trunk in the left gutter with a horizontal tap to every pin, junctions where a tap meets
the trunk, and its name on a global label at the top of the trunk. Pins whose net leaves the sheet get a
stub and a global label instead. Wire colour is cosmetic and per-wire: on the power sheet **J3's four
terminals are drawn in their bench colours** — C green, NO white, LED+ red, LED− black — so the code
matches the harness; white disappears on white paper, so read it in the editor. Global labels throughout means a net keeps one bare name across the
whole project, which is what the CSV and this page refer to — and **ERC is clean: 0 violations**.

Derived views, generated from the project — never edited by hand:

```bash
for rev in r5 r6; do
  kicad-cli sch export pdf -o "ktemata_${rev}_wiring.pdf" "docs/kicad/${rev}/ktemata.kicad_sch"
  kicad-cli sch erc --severity-all -o "/tmp/ktemata_${rev}_erc.rpt" "docs/kicad/${rev}/ktemata.kicad_sch"
  kicad-cli sch export netlist --format kicadxml -o "/tmp/ktemata_${rev}.xml" "docs/kicad/${rev}/ktemata.kicad_sch"
  python3 work/scripts/kicad_netlist_csv.py "/tmp/ktemata_${rev}.xml" \
    -o "docs/kicad/${rev}/ktemata_${rev}_connections.csv"
  python3 work/scripts/check_bom.py "/tmp/ktemata_${rev}.xml"
done
```

`docs/kicad/r5/ktemata_r5_connections.csv` and `docs/kicad/r6/ktemata_r6_connections.csv` are generated
outputs: one row per pin on every net, so they cannot drift from their schematics. Edit the relevant
schematic to change a connection; never edit either CSV by hand.

[`BOM.md`](BOM.md) stays a separate purchasing list — prices, suppliers, mechanical parts, none of which a
schematic has. The link between the two is a `Part` field on every block naming its BOM item, and

```bash
python3 work/scripts/check_bom.py /tmp/kt.xml
```

fails if a block names an item the BOM does not have, or if two blocks claim the same one. BOM items with
no symbol (screws, cables, the case) are listed, not failed.

## 2. R5 assembly rules

These rules apply to the preserved **R5** project only. Values live in the R5 schematic; the *practice* is here.

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

## 3. R6 assembly rules

Use the **R6** schematic for the proposed build; none of the R5 voltage, pack or display rules above carries
over automatically.

1. **Pack and charging.** Three matched cells in 3S, with 12.6 V / 2 A charge equipment. The R5 adapter and
   2S regulator are incompatible. Keep the insulating panels fitted and verify pack-fuse placement with the
   factory holders before assembly.
2. **Pi power.** Use the UPS manufacturer's Pi power lead. Never connect the bench USB-C supply and the UPS
   to the Pi simultaneously. No USB-PD capability is documented; verify loaded voltage, peripheral-current
   behaviour and `vcgencmd get_throttled` rather than relying on the desktop warning.
3. **Base/lid split.** FireBeetle and DS3231 stay in the cassette. Only the OLED and its button move to the
   lid. Use the specified five-conductor flexible harness with a keyed disconnect, strain relief and service
   loops; do not route a display ribbon across the hinge.
4. **Two controller domains.** The FireBeetle remains the sole master of the status/UPS bus. The Waveshare
   display's touch interface belongs to the Pi and is a separate connection; do not join the two buses.
5. **Display software.** The Waveshare panel is not the automatically configured Touch Display 2. Validate
   the R6 overlay and touch operation on the intended Ubuntu release before final assembly.
6. **Charge sensing.** The R6 divider values are in the R6 power sheet. Do not reuse R5's resistor values;
   calibrate the reading against a measured 12.6 V input.
7. **First power-up.** Follow the R6 schematic with the Pi disconnected, verify the pack and regulated
   outputs, then confirm the status devices including the UPS gauge at `0x41`. Connect the Pi only after
   those checks pass, then repeat the undervoltage check under load.
8. **Proposal gate.** ERC and netlist validation are complete, but the UPS, display, spacer stack, harness
   and thermal design still require the bench and fit gates in [`R6.md`](R6.md).

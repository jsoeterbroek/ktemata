# Ktemata wiring — R6

Wiring is defined **in KiCad**, not here. Two self-contained KiCad 10 projects: the R6 system schematic and
the R6 PCH, a single-sheet board project with its own PCB. Each is opened and checked on its own. **If this
page and a schematic ever disagree, the schematic is right.**

| Project | Path | Status |
|---|---|---|
| R6 | `cad/kicad/r6/ktemata.kicad_pro` | Build and test on a prototyping board; final cassette assembly pending |
| R6 PCH | `cad/kicad/r6/PCH/PCH.kicad_pro` | Custom board; build and test |

```bash
open cad/kicad/r6/ktemata.kicad_pro       # macOS; or pick each project in KiCad
open cad/kicad/r6/PCH/PCH.kicad_pro
```

## 1. The projects

The R6 system project uses an A3 index and three A4 sheets:

| sheet | file | Contents |
|---|---|---|
| `/` | `ktemata.kicad_sch` | Index and reading notes |
| `/Power` | `power.kicad_sch` | **3S pack, 12.6 V charging, UPS Module 3S, PCH block (J16)**, revised sensing |
| `/Pi 5 and its peripherals` | `pi.kicad_sch` | **Waveshare 7inch DSI LCD (C)** including its touch interface; other functions retained |
| `/FireBeetle …` | `mcu.kicad_sch` | FireBeetle/RTC in the base; OLED/button in the lid through a serviceable harness |

The **R6 PCH** is a separate single-sheet project and a 63 × 66 mm two-layer board. It carries the
charge-input sense tap, UPS header and 12.6 V auxiliary output. The supplied DC5521 charge lead and
self-lock button plug directly into the UPS, not into the PCH. Its schematic, exported
netlist and board are `PCH.kicad_sch`, `PCH.net` and `PCH.kicad_pcb`; parts are in
[`BOM.md`](BOM.md) section D. The R6 `/Power` sheet includes it as block **J16**; the Pi and MCU sheets use
the same global nets, so they do not repeat the block. Connector pinouts stay in the project, not in this page.

In the system project, one connector-shaped block per module (`Ktemata:` symbols — also a real library, `ktemata.kicad_sym`,
registered by the project's `sym-lib-table`). Within a sheet the nets are **routed**: each multi-pin net
gets a vertical trunk in the left gutter with a horizontal tap to every pin, junctions where a tap meets
the trunk, and its name on a global label at the top of the trunk. Pins whose net leaves the sheet get a
stub and a global label instead. Wire colour is cosmetic and per-wire: on the power sheet the supplied
UPS button's two terminals are drawn red and black to match its harness. Global labels throughout means a net keeps one bare name across the
whole project, which is what the CSV and this page refer to — and **ERC is clean: 0 violations**.

Derived views, generated from the project — never edited by hand:

```bash
kicad-cli sch export pdf -o ktemata_r6_wiring.pdf cad/kicad/r6/ktemata.kicad_sch
kicad-cli sch erc --severity-all -o /tmp/ktemata_r6_erc.rpt cad/kicad/r6/ktemata.kicad_sch
kicad-cli sch export netlist --format kicadxml -o /tmp/ktemata_r6.xml cad/kicad/r6/ktemata.kicad_sch
python3 work/scripts/kicad_netlist_csv.py /tmp/ktemata_r6.xml \
  -o cad/kicad/r6/ktemata_r6_connections.csv
python3 work/scripts/check_bom.py /tmp/ktemata_r6.xml
```

The PCH board is checked separately — ERC for the schematic, DRC for the PCB:

```bash
kicad-cli sch erc --severity-all -o /tmp/pch_erc.rpt cad/kicad/r6/PCH/PCH.kicad_sch
kicad-cli pcb drc --severity-all -o cad/kicad/r6/PCH/DRC.rpt cad/kicad/r6/PCH/PCH.kicad_pcb
```

`cad/kicad/r6/PCH/PCH.net` is the exported netlist. The PCH uses library symbols embedded in the schematic,
so ERC reports `lib_symbol_mismatch` warnings but no electrical errors; DRC is clean.

`cad/kicad/r6/ktemata_r6_connections.csv` is a generated output: one row per pin on every net, so it
cannot drift from the schematic. Edit the schematic to change a connection; never edit the CSV by hand.

[`BOM.md`](BOM.md) stays a separate purchasing list — prices, suppliers, mechanical parts, none of which a
schematic has. The link between the two is a `Part` field on every block naming its BOM item, and

```bash
python3 work/scripts/check_bom.py /tmp/kt.xml
```

fails if a block names an item the BOM does not have, or if two blocks claim the same one. BOM items with
no symbol (screws, cables, the case) are listed, not failed.

## 2. R6 assembly rules

Use the **R6** schematic for the prototyping build. The custom PCH is a separate build with its own rules in
§3; on the prototyping board, make the same connections with the Dupont jumpers (BOM 20).

1. **Pack and charging.** Three matched cells in 3S, with 12.6 V / 2 A charge equipment. Keep the
   insulating panels fitted and verify pack-fuse placement with the factory holders before assembly. The
   supplied DC5521 lead connects directly to the UPS charge input; only the PCH's high-impedance sense tap
   is added. The supplied self-lock button plugs directly into the UPS switch input.
2. **Pi power.** Use the UPS manufacturer's Pi power lead. Never connect the bench USB-C supply and the UPS
   to the Pi simultaneously. No USB-PD capability is documented; verify loaded voltage, peripheral-current
   behaviour and `vcgencmd get_throttled` rather than relying on the desktop warning.
3. **Base/lid split.** FireBeetle and DS3231 stay in the cassette. Only the OLED and its button move to the
   lid. Use the specified five-conductor flexible harness with a keyed disconnect, strain relief and service
   loops; do not route a display ribbon across the hinge.
4. **Two controller domains.** The FireBeetle remains the sole master of the status/UPS bus. The Waveshare
   display's touch interface belongs to the Pi and is a separate connection; do not join the two buses.
5. **FireBeetle serial link.** A USB-A → USB-C **data** cable carries the Pi ↔ FireBeetle serial link; the
   FireBeetle stays on the UPS, so the Pi's 5 V must not reach it. Cut the cable's **VBUS** wire (normally
   red; confirm by continuity) near the A plug and splice in the `1N5819` (BOM 21a), **band toward the
   FireBeetle**; leave GND, D+ and D− intact, and heat-shrink the joint. Do **not** cut VBUS outright and do
   **not** use a USB power blocker: the DFR1140 powers its CH340 from USB VBUS, so either leaves the Pi with
   no serial device. With the diode the CH340 runs at ≈4.7 V while the FireBeetle's 5 V rail stays at the
   UPS 5.0 V. Check 5.0 V on the Pi side of the diode and ≈4.7 V on its FireBeetle side, then confirm
   `lsusb` shows `1a86:7523` and `/dev/ttyUSB0` appears.
6. **Display software.** The Waveshare panel is not the automatically configured Touch Display 2. Validate
   the R6 overlay and touch operation on the intended Ubuntu release before final assembly.
7. **Charge sensing.** The divider values are in the power sheet; calibrate the reading against a
   measured 12.6 V input.
8. **First power-up.** Follow the R6 schematic with the Pi disconnected, verify the pack and regulated
   outputs, then confirm the status devices including the UPS gauge at `0x41`. Connect the Pi only after
   those checks pass, then repeat the undervoltage check under load.
9. **Proposal gate.** ERC and netlist validation are complete, but the UPS, display, spacer stack, harness
   and thermal design still require the bench and fit gates in [`R6.md`](R6.md).

## 3. R6 PCH assembly rules

The PCH is a passive connector hub — no conversion, no fuse, no protection of its own. Nets and pins live in
[`PCH.kicad_pro`](../cad/kicad/r6/PCH/PCH.kicad_pro); the practice is here.

1. **Match pin 1.** Mate the PCH's 2×4 UPS header one-to-one with the module's header and mark pin 1 on the
   cable. A reversed ribbon puts 5 V on an I²C line and 3.3 V on ground; use a keyed connector or a
   shrouded header if you can.
2. **Auxiliary 5 V only.** The PCH's 5 V output feeds the status side. The Pi 5 and 7-inch display stay on the
   UPS Module 3S's USB-C lead; do not route the Pi's 5 A through this board.
3. **Direct supplied harnesses.** The red/black self-lock button plugs directly into the UPS switch input;
   the supplied DC5521 lead plugs directly into the UPS charge input. PCH J1 is only a high-impedance
   sense tap on that input. The pack charges with the output switch off.
4. **No fuse on the PCH.** The Module 3S's protection covers the in-module 3S pack; the PCH only carries
   post-protection 2 A branches. Do not fit the 5 A cartridge here. If a pack is built outside the module,
   its fuse belongs in the pack's positive lead, upstream of the module.
5. **Ground and mounting.** GND is a filled zone on both copper layers (F.Cu coplanar with the routing, B.Cu solid underneath); re-check both fills after any layout change. Mount on
   the four M2.5 holes with nylon standoffs so the JST shells cannot touch the tray or shielding.
6. **First power-up.** With the UPS output off, check the 12.6 V branches for shorts. Then connect the charge
   source and the UPS and confirm the aux rails and the UPS gauge at `0x41`; connect the Pi last.
7. **PCH↔UPS cables.** C3 is the 2×4 header and C4 is the 12.6 V branch. C1 charging and C2 switch use
   the supplied harnesses directly at the UPS, not the PCH. The only additional input connection is the
   high-impedance sense tap at PCH J1. The UPS header's 3.3 V pins are left open — the FireBeetle's
   regulator supplies the status 3.3 V rail — and the J8 12.6 V aux remains unused.

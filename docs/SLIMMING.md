# Slimming the package — feasibility notes

Written 24 Oct 2026, when the r4 dimensions were **accepted as they are** (172 × 237 × 52.97 mm). This file
records the analysis of the two obvious ways to make the device flatter, the numbers behind them, and what a
future attempt would have to change. Nothing here is implemented; the CAD still models the r4 stack.

Read [`R4.md`](R4.md) first for the parts and the derived stack.

## 1. Where the thickness actually goes

`T = DISP_Z_FRONT + PLATE`, and the display sits on the Pi, so the r4 stack is:

| z (mm) | Layer | Fixed by |
|---|---|---|
| 0 – 2.00 | back plate | `FLOOR` |
| 2.00 – 3.00 | cell clearance | `CELL_Z0` |
| 3.00 – 26.35 | **2× 18650 + the HAT's soldered holders** (23.35) | cells, not the board |
| 26.35 – 27.95 | HAT (B) pcb | 1.6 |
| 27.95 – 34.45 | pogo/component gap (6.5) | pogo pins + the HAT's 6–7 mm components |
| 34.45 – 36.05 | Pi pcb | 1.6 |
| 36.05 – 44.55 | display standoffs (8.5) | Touch Display 2 |
| 44.55 – 50.97 | display panel body (6.42) | Touch Display 2 |
| 50.97 – 52.97 | face plate | `PLATE` |

Two conclusions follow immediately:

* **The display commits 16.92 mm above the Pi top** and cannot be stacked away. That is the floor of any
  design using the Touch Display 2.
* **The cells commit 25 mm below the HAT pcb** (23.35 holder side + 1.6 pcb). They — not the pogo pins, not the
  Pi — are what makes the bottom shell 38.55 mm tall.

The pogo stack is therefore *not* the problem. Removing it saves 6.5 mm at most, and some of that has to be
given back wherever the HAT's cell block goes instead.

## 2. Option A — Pi and HAT side by side, wired

Replace the pogo connection with 5 V/GND wires and lay the HAT beside the Pi instead of under it.

**What it wins**

* The Pi's underside is free — the ordered **Seeed M.2 BASE + SN740** (≈10 mm with the card) finally has a home,
  which `BOM.md` note 7 and `R4.md` item 6 currently record as unsolved.
* No pogo contact. Waveshare's own FAQ names pogo seating as the cause of undervoltage reports
  ("The pogo pin contact is not good, please reassemble the UPS").
* Room for a 40-pin header if wanted (do **not** add a second I²C master; the FireBeetle stays the master).

**What it cannot win**

The cell block still has to exist, and there are only two places it can go:

| Position | Why it fails / costs |
|---|---|
| Beside the Pi, in the display zone | Blocked by the four display posts (`DISP_HOLES`, Ø6.5). The clear rectangle between them is **116.24 × 66.46 mm**; the Pi takes 85 of the 116.24, leaving **31 mm**, and 66.46 across is shorter than the HAT's 85. Shifting the Pi is not free — it hangs on the display's standoff pattern. |
| **Under the keyboard** (the only ~100 mm of free length) | Feasible. Cell block 0–26.35 + pcb to 27.95 must clear the K06 body, whose back then sits at `T − 2 − 11`. |

With the correct 11 mm K06 the display is what binds; the keyboard used to (it was sized for the i4):

```
HAT pcb top            27.95
K06 back   = T − 13.00  must be ≥ 27.95   →   T ≥ 40.95
display    = T − 16.92  must be ≥ 27.95   →   T ≥ 44.87
```

**Result: the display now binds at T ≈ 44.9 mm, i.e. ≈ 8 mm (15 %) saved** — not the "considerably
thinner" the idea suggests. (With the correct 11 mm K06 the keyboard is no longer the constraint.)

**What it costs**

* Bottom floor plan rewritten: `RTC_*`, `MPPT_*`, `FB_*` and the `KBS_POSTS` columns all sit under the keyboard
  today; they must move into the 35.5 mm band between display and keyboard, or into the x margins.
* `SENSOR_*` (left wall, y 176–224) collides with a 56 × 85 block there; the sensor pocket has to move, and it
  should not end up next to charging cells (heat skews the environment screen).
* `H_BOT`, `KBS_Z0`, the split-plane rule (`H_BOT ≥ PI_PCB_TOP + 2.5`) and `keyboard_support.scad` all change.
* Power wiring: take **5 V/GND from the HAT's `5V`/`GND` pads** (20 AWG, ~10 cm) to the Pi's pogo pads or GPIO
  pins 2/6. Do **not** feed the Pi from the HAT's USB-A: without PD the Pi treats it as a 5 V/3 A supply and
  throttles its own USB ports.
* The 8.4 V jack is on the HAT's +y edge, so moving the board moves the sealed charge port with it.
* New `CHECK` pairs needed: `bottom:ups`, `bottom:nvme`, plus the existing `bottom:kbs`.

## 3. Option B — attack the cells, not the layout

The 25 mm block is 2× 18650 in Waveshare's own holders. A **2S LiPo pouch pack (~10–12 mm)** replaces it:

```
2 + 1 + 12 + 1.6 = 16.6   HAT pcb top
16.6 + 13.0      = 29.6   T (display still binds at 44.9)
```

**Result: T ≈ 35–40 mm** only if the display is also changed; with the Touch Display 2 the floor is 44.9 mm.

**Caveats — why this is an experiment, not a plan**

* The HAT (B)'s holders *are* the battery circuit; its HY2213 balancing is built around them. Wiring a pouch to
  B−/BM/B+ puts your pack in parallel with that balancing, which Waveshare does not document. The safe version
  is a **different 2S charger/monitor board** (or a 2S pack with an integrated BMS) plus a separate gauge.
* You lose the "8.4 V supply in the box" fit and the INA219 telemetry that the status OLED depends on, unless
  the replacement board also exposes I²C.
* Pouch cells need physical protection and a fire-resistant enclosure in a handheld.

## 4. Recommendation

**Keep the r4 stack.** 6.5 mm is not worth a floor-plan rewrite that also risks the sensor pocket, the
keyboard support frame and the charge-port alignment — and 53 → 46.5 mm does not change how the device feels.

Revisit this only if one of these becomes true:

1. **The NVMe bay matters more than the 6.5 mm.** Then unstack — but treat it as an **r5** with the Pi low under
   the display, the BASE beneath it, and the HAT under the keyboard on four printed bosses. Budget `T ≈ 46.5`.
2. **A 2S pouch pack (or a different charger board) is acceptable.** Then `T ≈ 35–40`; this is a battery change,
   not a mechanical one.

Do not combine both without measuring: a pouch pack under the Pi plus the HAT pcb in the keyboard band is the
only combination that reaches `T ≈ 35`, and it needs the HAT's power path reworked anyway.

## 5. Numbers worth keeping

Measured from Waveshare's `ups_hat_b__asm.stp` (see `R4.md` for the source):

| | mm |
|---|---|
| HAT pcb | 85 × 56 × 1.6 |
| HAT mounting holes | **58 × 49**, 3.5 from the edges — same as the Pi |
| HAT cell/holder side below the pcb | 23.35 |
| HAT components above the pcb | 6–7 (tallest 6.9, the barrel jack and the 8.4 V/USB-A bodies) |
| HAT `5V`/`SCL`/`SDA`/`GND` pins | 10 tall, 0–10 above the pcb, at the +y edge (in the 29 mm that overhangs the Pi). They are the only parts above the pcb in that overhang; on the Pi-side half the tallest part is 6.9 mm |
| Pi pcb | → the 27.95–34.45 gap is the only place the BASE could go in the current layout |

Room if the HAT moves: **166 mm** interior width, **116.24 × 66.46 mm** clear between the display posts and
**35.5 mm** between the display and the keyboard window. The case is 2.16 L at 172 × 237 × 53 mm.

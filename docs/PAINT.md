# r5 paint schemes — deck and lid cover

Three airbrush designs for the two printed surfaces you actually look at: the **deck** (keyboard
side, seen when the case is open) and the **lid cover** (bezel round the Touch Display 2, seen when
it is closed). Each scheme is one continuous design across both parts, not two decorations that
happen to share a palette.

```
python3 cad/tools/paint.py              # all three sheets + a side-by-side contact sheet
python3 cad/tools/paint.py --scheme 2   # one scheme
python3 cad/tools/paint.py --no-png     # SVGs only
```

Output lands in `docs/paint/`:

| File | What it is |
|---|---|
| `ktemata_paint_1_meridian.svg` / `.png` | **MERIDIAN** — a chart graticule ruled from the hinge |
| `ktemata_paint_2_strata.svg` / `.png` | **STRATA** — five bands up both rails, straight past the seam |
| `ktemata_paint_3_bearing.svg` / `.png` | **BEARING** — a slate border and one amber trace through the seam |
| `ktemata_paint_all.png` | the three sheets side by side, for choosing |

The SVGs are **1:1 in millimetres** and are drawn from the model, so they print as masking
templates: 400 gsm card or vinyl, cut to the panels, laid on the part. There is a 50 mm scale bar
on each sheet to check the printer did not rescale.

## The rule the three schemes share

The case opens flat into one 233.5 × 356.2 mm face. Both panels are measured **from the hinge**
(`y = 0`), exactly as `common.scad` does, and they share **one x axis**. So a mark at `x = 214`
is 19.5 mm from the right edge on the cover *and* on the deck, and a mark at `y = 40` is 40 mm
from the seam on whichever half you are looking at.

Everything continuous in these designs is keyed to that datum:

- **MERIDIAN** lays its graticule out from the hinge at `L/10 = 17.81 mm` pitch, so line *n* is
  the same distance from the seam on either half.
- **STRATA** keys its bands to **x**, not y: each rail runs dead straight from the cover into the
  deck, and the U closes across the hinge.
- **BEARING** runs one 3 mm trace on `x = 215.5` down both parts, meeting in a gateway square
  straddling the seam.

## What the hardware allows — measured, not guessed

These are the constraints the artwork obeys, and `cad/tools/paint_probe.scad` feeds them to the
generator straight from `common.scad`. Change a part and the sheets follow; the assertions fail
rather than drawing a line through a fan.

- **The cover's display well is 144.4 × 92.46 mm** (`DISP_W/H` + 0.5 clearance), with only 7 mm of
  bezel round it. It takes the whole hinge-side frame: from `x 44.55` to `188.95`. Anything that
  has to be continuous across the seam on the cover must therefore live in the **latch band**
  (`y > 99`; the button is at `y 152.9..169.1`, the finger slots at `y 164.1..178.1`) or in the
  **44.55 mm side margins**.
- **The deck's free fields** are the **40.95 mm side rails**, the **35.6 mm strip** between the OLED
  window (ends `y 66.9`) and the keyboard pocket (starts `y 102.5`), and the **16 mm** between the
  keyboard pocket (ends `y 162.1`) and the latch edge.
- **Only one vertical lane is clear on both parts at once** across their whole length:
  **x 216.5 .. 223.0**. That is why BEARING's trace runs there and not up the more obvious left
  rail — the deck's left rail is crossed by the fan (x 25..63, y 19..57), the FireBeetle access
  hole (x 14..30, y 148..158) and a screw, and the cover's left margin is crossed by the power
  button (x 5.6..28.6, y 152.9..169.1) and by the display well from `x 44.55`.
- **The lettering blocks are part of the mask.** MERIDIAN's graticule stops at the wordmark and
  the motto rather than running under them — the blocks are declared in `Model.type_boxes`, so
  no scheme can paint through them by accident.

## Paint order and finish

All three use the same process; only the masks change.

1. Scuff 400, clean, adhesion promoter for PETG, then **graphite base** (`#151b21`, the site's
   `--bg`) over the whole face.
2. Lay the masks for the first colour, spray, let it flash off. Thin coats — airbrush paint builds
   up in an aperture and reads as a burr.
3. Repeat per colour. The order on each sheet is the order to spray; darkest to lightest, so a
   light slip can be covered and a dark one cannot.
4. **Matte 2K clear** over everything except the lettering.
5. Lettering last, through a stencil, un-cleared, so it keeps its edge.

### Palette

Taken from `site/style.css` so the case and the site are the same object:

| Name | Hex | Role |
|---|---|---|
| graphite | `#151b21` | `--bg` — base coat, all three |
| amber | `#c99a63` | `--accent` — the line work that crosses the seam |
| deep amber | `#8a6234` | `--accent-soft` — the seam rule, shading |
| slate | `#26313a` | `--panel`, lifted one step so it reads next to graphite at 300 mm |
| ash | `#7c8993` | secondary line work |
| light grey | `--muted` `#a9b2bb` | short graticule ticks, chart dots |
| light amber | `#e2bd8d` | long ticks, the deck wordmark |
| ivory | `--fg` `#f2ebe0` | the motto |

Every sheet's `PALETTE` strip carries the five colours that scheme actually uses.

## Reading a sheet

```
┌──────────────────────────────────────────────┐
│ LID COVER · bezel face       233.5 × 178.1   │  the cover, hinge edge at the BOTTOM
│  ┌────────────────────────────────────────┐  │
│  │  painted artwork, clipped by the mask  │  │
│  └────────────────────────────────────────┘  │
├──────────── HINGE (dashed) ───────────────────┤  the seam: paint crosses it
│ DECK · top face              233.5 × 178.1   │  the deck, hinge edge at the TOP
│  ┌────────────────────────────────────────┐  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

The cover is drawn **mirrored in y** so that its hinge edge meets the deck's at the dashed line —
that is the open-flat view, looking at both faces from the front. Consequently the cover's panel
(the display) appears "above" the hinge line rather than below it. The x axis is *not* mirrored.

Grey text and grey outlines name printed features — fan, screws, keyboard well, OLED window,
panel, button, cable relief. They are annotations, not paint. Every painted element is clipped by
the part's real apertures (`deck_holes_d`, `cover_holes_d`), so a line that reaches the Pi opening
or the power button **stops there** in the drawing exactly as it would under tape. Nothing in these
sheets is "touched up by hand" after masking.

## Printing notes

- All three are designed for parts painted **before assembly**: the deck top-face-down on the
  bench, the cover lid-face-down. Both faces are the print bed face, so the paint sits on a
  texture the slicer left — scuff it, do not sand it flat.
- Mask the apertures from the back where you can; the deck's fan grille bars are flush with the
  top face and will pick up overspray through the slots.
- The key faces (K06 keys, the display glass) are not painted and must stay masked throughout.

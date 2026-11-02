# r5 paint schemes — deck and lid cover

**Meridian is the chosen scheme.** It is the design to build; Strata and Bearing are kept as record
of the alternatives and because the generator still produces them.

Three airbrush designs for the two printed surfaces you actually look at: the **deck** (keyboard
side, seen when the case is open) and the **lid cover** (bezel round the Touch Display 2, seen when
it is closed). Each scheme is one continuous design across both parts, not two decorations that
happen to share a palette.

```
python3 cad/tools/paint.py                          # all three sheets + contact sheet
python3 cad/tools/paint.py --scheme 1 --stencils    # Meridian + its cut files
python3 cad/tools/paint.py --scheme 2               # one scheme
python3 cad/tools/paint.py --no-png                 # SVGs only
```

Output lands in `docs/paint/`:

| File | What it is |
|---|---|
| `ktemata_paint_1_meridian.svg` / `.png` | **MERIDIAN** — a chart graticule ruled from the hinge |
| `ktemata_paint_2_strata.svg` / `.png` | **STRATA** — five bands up both rails, straight past the seam |
| `ktemata_paint_3_bearing.svg` / `.png` | **BEARING** — a slate border and one amber trace through the seam |
| `ktemata_paint_all.png` | the three sheets side by side, for choosing |
| `ktemata_stencil_{deck,cover}_{ash,amber,seam,bezel}.svg` | **cut files**, one per paint pass, `--stencils` |

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

## Cutting the masks

`--stencils` writes one cut file per paint pass, derived from the same mark data as the sheet:

| File | Pass | Cut |
|---|---|---|
| `ktemata_stencil_deck_ash.svg` | ash | the 0.5 mm graticule and the short rules |
| `ktemata_stencil_deck_amber.svg` | amber | the 0.9 mm graticule, every fifth rule |
| `ktemata_stencil_deck_seam.svg` | deep amber | the seam rule at the hinge, the end stop at the latch edge |
| `ktemata_stencil_cover_*.svg` | as above, plus `bezel` | the same on the lid cover; `bezel` is the slate ring |

Black is the sheet you lay on the part; white is what the blade removes. Three practical points,
because they decide whether the mask survives being handled:

- **Kiss-cut and apply with transfer tape.** A slot that runs the full width of a panel severs the
  mask into strips — that is visible in `ktemata_stencil_cover_ash.svg` and it is not a fault. Cut
  the vinyl but leave the backing on, lay application tape over the face, and lift the whole
  assembly onto the part in one go; the tape holds every island in register. Peel the tape last.
- **The bezel ring needs bridges or transfer tape.** Cutting a closed ring frees it from the
  surrounding sheet. Transfer tape carries it; without tape, add two 2 mm bridges at the ring's
  top and bottom and accept two hairlines in the slate.
- **0.5 mm is at the limit for a blade.** If your cutter cannot hold a 0.5 mm line cleanly, lay the
  ash graticule with 0.5 mm pinstripe tape instead — it is a stock product, and the grid is on a
  17.81 mm pitch so the tape wants no measuring beyond the first line. The stencils then cover
  amber, seam and bezel only, which are all wide enough to cut and lift cleanly.

The registration crosses in the margins align the passes: lay pass 1, spray, lift, lay pass 2 on
the same crosses. The part outline is the datum, so each mask lands without measuring.

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

## Meridian: what to spray

The chosen scheme, in the order the sheet gives:

1. Scuff 400, adhesion promoter, **graphite** (`#151b21`) over the whole face.
2. **Ash** pass: the graticule at 17.81 mm pitch, 0.5 mm lines.
3. **Amber** pass: every fifth line at 0.9 mm, plus the two rules.
4. **Deep amber** pass: the 1.7 mm seam rule at `y 2.2` and the end stop at `y l-8`. On the deck the
   seam rule is **two pieces**, not one — the Pi opening cuts it at `x 150..203.4`. That is correct
   and deliberate: the cut file is the authority, and a line that crosses a hole is not a line.
5. **Slate** pass (cover only): the 7 mm bezel ring.
6. **Word** stencil: `KTEMATA` and the tagline on the deck, the motto on the cover.
7. Matte 2K clear over everything except the lettering.

## Printing notes

- All three are designed for parts painted **before assembly**: the deck top-face-down on the
  bench, the cover lid-face-down. Both faces are the print bed face, so the paint sits on a
  texture the slicer left — scuff it, do not sand it flat.
- Mask the apertures from the back where you can; the deck's fan grille bars are flush with the
  top face and will pick up overspray through the slots.
- The key faces (K06 keys, the display glass) are not painted and must stay masked throughout.

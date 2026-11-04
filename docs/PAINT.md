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
python3 cad/tools/paint.py --stickers                # the two type blocks as sticker PDFs
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
| `ktemata_sticker_deck_wordmark_91x22.4mm_bleed.pdf` | **the deck wordmark sticker**, artwork only, `--stickers` |
| `ktemata_sticker_cover_motto_82.1x17.3mm_bleed.pdf` | **the lid motto sticker**, artwork only, `--stickers` |

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

- **The cover's display well is 190.32 × 121.24 mm** (`R5_PANEL` + 0.5 clearance), with 7 mm of
  bezel round it, and the 7" panel is **centred**: the well runs `x 21.59..211.91`, `y 28.43..149.67`.
  That leaves only **14.6 mm of plate outside the bezel in x** and a **28.4 mm latch band**, so the
  cover's usable paint is the flat ring round the bezel, not the rails the 5" layout had. Anything
  that has to be continuous across the seam on the cover must therefore live in that **latch band**
  (`y > 149.7`; the finger slots are at `y 161..171`) or in the **14.6 mm side margins**.
- **The deck's free fields** are the **40.95 mm side rails**, the **35.6 mm strip** between the OLED
  window (ends `y 66.9`) and the keyboard pocket (starts `y 102.5`), and the **16 mm** between the
  keyboard pocket (ends `y 162.1`) and the latch edge.
- **Only one vertical lane is clear on both parts at once** across their whole length:
  **x 216.5 .. 223.0**. That is why BEARING's trace runs there and not up the more obvious left
  rail — the deck's left rail is crossed by the fan (x 25..63, y 19..57), the FireBeetle access
  hole (x 14..30, y 148..158), a screw and now the **power button** (Ø16.2 at 213.0, 160.1), and
  the cover's left margin is crossed by the display well from `x 21.59`.

  The power button is why the deck now has a hole where the 5" layout had clean rail: it moved
  off the lid when the panel grew to 7", and the rail at x 213 is the only place on the deck that
  is both clear of the keyboard pocket and clear of every board underneath. Its Ø19 nut needs
  9.2 mm of clearance to the keyboard skirt, which is exactly what the rail gives.
- **The lettering blocks are part of the mask.** MERIDIAN's graticule stops at the wordmark and
  the motto rather than running under them — the blocks are declared in `Model.type_boxes`,
  derived from the sticker trim, so no scheme can paint through them by accident and the
  graticule never ends as a sliver under the vinyl's edge.

## Paint order and finish

All three use the same process; only the masks change.

1. Scuff 400, clean, adhesion promoter for PETG, then **graphite base** (`#151b21`, the site's
   `--bg`) over the whole face.
2. Lay the masks for the first colour, spray, let it flash off. Thin coats — airbrush paint builds
   up in an aperture and reads as a burr.
3. Repeat per colour. The order on each sheet is the order to spray; darkest to lightest, so a
   light slip can be covered and a dark one cannot.
4. **Matte 2K clear** over everything.
5. Lettering last: MERIDIAN's two type blocks are **printed stickers** laid on the cleared plate
   (see below); STRATA and BEARING keep the stencil pass, un-cleared, so it keeps its edge.

### Palette

Taken from `site/style.css` so the case and the site are the same object:

| Name | Hex | Role | Pantone (Solid Coated) | Vallejo Model Air |
|---|---|---|---|---|
| graphite | `#151b21` | `--bg` — base coat, all three | Black 6 C `#101820` ΔE 1.7 | 71.057 Black ΔE 7.1 |
| amber | `#c99a63` | `--accent` — the line work that crosses the seam | 7509 C `#d6a461` ΔE 3.9 | 71.348 USAF Tan ΔE 2.9 |
| deep amber | `#8a6234` | `--accent-soft` — the seam rule, shading | 7575 C `#835d32` ΔE 2.2 | 71.032 Golden Brown ΔE 4.0 |
| slate | `#26313a` | `--panel`, lifted one step so it reads next to graphite at 300 mm | 7546 C `#253746` ΔE 3.5 | 3 : 1 71.057 Black + 71.087 Steel Blue ΔE 2.4 |
| ash | `#7c8993` | secondary line work | 430 C `#7c878e` ΔE 1.6 | 71.307 BS Medium Sea Grey ΔE 3.5 |
| light grey | `--muted` `#a9b2bb` | short graticule ticks, chart dots | 429 C `#a2aaad` ΔE 3.8 | 71.345 Russian AF Grey N.8 ΔE 4.4 |
| light amber | `#e2bd8d` | long ticks, the deck wordmark | 7508 C `#e1b87f` ΔE 2.4 | 71.074 Radome Tan ΔE 3.6 |
| ivory | `--fg` `#f2ebe0` | the motto | 7527 C `#d6d2c4` ΔE 6.3 | 71.279 Insignia White ΔE 3.9 |

Every sheet's `PALETTE` strip carries the five colours that scheme actually uses.

**How to read the two mixed columns.** ΔE is CIEDE2000 between the site hex and the matched
swatch, computed in CIELAB from the sRGB values; **below ~2 is indistinguishable side by side,
below ~5 reads the same at arm's length in daylight**, and everything in the table is under 5
except graphite and ivory. Those two are at the ends of the range where neither system has a
chip: nothing in Model Air is as dark as `#151b21` (71.057 is a half-step lighter, which the matte
clear mostly hides), and every Pantone chip near `#f2ebe0` is yellower — 7527 C is the closest
neutral and Pantone has no true off-white. Slate needs the two-pot mix because no single matte
Model Air matches it; 71.300 Glossy Sea Blue is closer but gloss, which is wrong under the 2K
clear on a bezel.

The Pantone column is for **checking, not spraying** — Pantone sells no paint. Use the chip at the
hobby shop to judge a tint under daylight, or to order the same tone from a paint mixer. The
Vallejo column is the **Model Air** number (the airbrush range, 71.xxx) because every pass here is
sprayed; Model Color (70.xxx) has hand-brush equivalents that are close but not identical, and
Model Color is brush-ready, so it will not go through a 0.2 mm nozzle without thinning and has no
place in these masks. Vallejo publishes no official RGB values — the hexes behind the ΔE numbers
come from community colour databases, so treat ΔE as a comparison between two approximations of
each colour, not as a measurement of the bottle in your hand.

## Cutting the masks

`--stencils` writes one cut file per paint pass, derived from the same mark data as the sheet:

| File | Pass | Cut |
|---|---|---|
| `ktemata_stencil_deck_ash.svg` | ash | the 0.5 mm graticule and the short rules |
| `ktemata_stencil_deck_amber.svg` | amber | the 0.9 mm graticule, every fifth rule |
| `ktemata_stencil_deck_seam.svg` | deep amber | the seam rule at the hinge, the end stop at the latch edge |
| `ktemata_stencil_cover_*.svg` | as above, plus `bezel` | the same on the lid cover; `bezel` is the slate ring |

The same masks are also printable as rigid 1.2 mm panels (`stl/stencil_*.stl`, one file per pass)
for anyone who would rather not cut vinyl — see **Printed masks** below. The sheets and the STLs
come from the same mark data, so they cannot disagree.

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

## Printed masks

```bash
python3 cad/tools/stencil_stl.py                  # five masks, 1.2 mm thick
python3 cad/tools/stencil_stl.py --part cover      # one part
python3 cad/tools/stencil_stl.py --thickness 2.0   # stiffer
```

Writes `stl/stencil_{deck,cover}_{amber,seam}.stl` and `stl/stencil_cover_bezel.stl`: the part
outline with that pass's slots cut straight through, no handling margin, 233.5 × 178.1 mm. They
land on the part with their own outline as the datum, exactly like the sheets.

**The ash pass is not printed, and cannot be.** A mask is the sheet minus its slots, so it holds
together only if the slots do not close a loop. The graticule does: 8 horizontal rows and 10
vertical columns on the deck, which divides the panel into ~80 cells. Measured on the deck's ash
mask: 23 separate solids with no ligament, 11 at 0.8 mm, and still 11 at 4.0 mm — the cuts meet
each other in the middle of the plate, so the split is inherent to the artwork rather than to the
tie width. Ash therefore stays vinyl: 0.5 mm pinstripe tape on a 17.81 mm pitch, as the note above
already suggests. `--include-vinyl` will emit it anyway if you want to see the strips.

**The cover is two planes, and the masks respect that.** Its plate's painted face is at z 4.0 and
its bezel stands 7.92 mm above it. A flat 1.2 mm mask cannot bridge a step that size, so the
plate-level masks have the bezel's footprint cut away and lie on the plate with the ring poking
through, while `stencil_cover_bezel` is a ring-shaped mask that sits on the bezel's top face.
`cover_hit()` enforces the same rule for the artwork, so no mark crosses the step.

Two corrections came out of building these, both in the sheet output rather than the STLs:

- **The cover's apertures were not mirrored with its marks.** The cover is drawn mirrored in y on
  the open-flat sheet, so that its hinge edge meets the deck's at the seam, and the marks were
  flipped while the cut-outs were not — the DSI notch appeared at the latch end and both finger
  slots at the hinge. Apertures are now one `Aperture` shape rendered for both consumers.
- **The motto sat on the raised bezel.** Its block was centred in the band below the display well
  rather than below the bezel, so 5 mm of it lay on a surface 7.92 mm higher. The flat band is
  21.4 mm, the block is scaled into it (cap 6.0, trim 82.1 × 17.3 mm) and centred.

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
6. Matte 2K clear over everything.
7. **Stickers last**: the deck wordmark and the lid motto, on the bare plate the mask reserved.
   See [Stickers instead of stencilled type](#stickers-instead-of-stencilled-type).

## Stickers instead of stencilled type

The two type blocks — `KTEMATA` / `OFFLINE LIBRARY` on the deck and `κτῆμα ἐς ἀεί` / the
translation on the cover — are the only place in Meridian where the lettering is not masked
paint. `--stickers` writes them as print-ready vinyl instead:

| File | Block | Trim (cut size) | Where it goes |
|---|---|---|---|
| `ktemata_sticker_deck_wordmark_91x22.4mm_bleed.pdf` | `KTEMATA` + `OFFLINE LIBRARY` | **91 × 22.4 mm** | deck, x 71.25..162.25, y 68.40..90.80 |
| `ktemata_sticker_cover_motto_82.1x17.3mm_bleed.pdf` | `κτῆμα ἐς ἀεί` + translation | **82.1 × 17.3 mm** | cover, x 75.70..157.80, y 158.73..176.03 — the 21.4 mm flat band below the raised bezel |

Upload the **PDF**. It is vector (PDF 1.7, not the 1.4 they reject), all lettering already
converted to outlines, RGB — they convert to their CMYK profile themselves — and it carries **no
cut line and no crop marks**, which is what their upload form requires. Each file has 1 mm of
bleed on all four sides beyond the trim, so the artwork measures 93 × 24.4 mm and 84.1 × 19.3 mm;
order a **contour-cut rectangle at the trim size above**, centred. Matte
laminate, so it matches the 2K clear it is going under. The trim size is also in the file name
and the SVG `<title>`, because the order form asks for it as a number and a file name is harder
to lose than a note.

Why the design survives as a sticker when it would not survive as a stencil:

- The tagline and the translation are 2.4–2.6 mm text. That is a 0.3 mm stroke through a hand-cut
  vinyl mask — below what a blade holds cleanly, and a slipped stencil cannot be repaired
  invisibly. Printed, it is just ink.
- The block is a **filled graphite rectangle**, not a transparent cut-out. A die-cut that follows
  the lettering is impossible at 0.3 mm, so the lettering needs a carrier. Printing that carrier
  in the scheme's own `#151b21` means the only visible change is a 2.5 mm graphite margin round
  the type — a small brand plate, not a white label. The 1 mm bleed is the same graphite, so a
  cut a fraction off-centre cannot expose white.
- `type_boxes` in the model is now **derived from the sticker trim** (`sticker_trim()`), so the
  graticule stops exactly at the vinyl's edge. Resize the sticker and the keep-out in the mask
  follows; a grid line can never end up a sliver under the edge.

Lay them **after** the 2K clear, not before: the clear is the part's mechanical protection, and a
sticker under it would have to pass the same wet-coat test the paint does. Press down hard on a
clean, de-greased clear coat; a vinyl sticker on scuffed PETG without clear under it is the one
joint that will lift at the corner in a pocket.

Text metrics are measured from the same font (`DejaVu Sans`, cap height 10.5 mm on both blocks)
that draws the sheets, so the sticker and the painted artwork are the same design, not a
lookalike.

## Printing notes

- All three are designed for parts painted **before assembly**: the deck top-face-down on the
  bench, the cover lid-face-down. Both faces are the print bed face, so the paint sits on a
  texture the slicer left — scuff it, do not sand it flat.
- Mask the apertures from the back where you can; the deck's fan grille bars are flush with the
  top face and will pick up overspray through the slots.
- The key faces (K06 keys, the display glass) are not painted and must stay masked throughout.

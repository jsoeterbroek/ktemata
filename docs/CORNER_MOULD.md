# Corner caps — silicone overmoulding

Soft-rubber corner caps for the r4 case, cast **one corner at a time** in addition-cure (platinum)
silicone, using the printed case itself as the inner mould half. Tool: [`cad/corner_mould.scad`](../cad/corner_mould.scad).

This is a **retrofit accessory**, not part of the case assembly: the caps slide on afterwards, so the STLs
`ktemata_bottom` / `ktemata_face` are unchanged.

## What you get

A 2 mm rubber shell over each corner bumper, from z = 5 to z = 35 mm — above the 3 mm edge chamfer, below the
38.55 mm split plane, so it covers the seam and both shells. It follows the bumper's own 45° taper and stops
26 mm along the top/bottom walls and 23 mm along the sides.

**Silicone per corner: ≈ 3.3 ml** (0.25 mm clearance included ≈ 3.4 ml). Four corners ≈ 14 ml, so a 250 ml
kit is ample.

## The tool

Three pieces, all sliding off along **+z** after curing:

| Piece | STL | Role |
|---|---|---|
| `cm_plate()` | `ktemata_corner_plate.stl` | seals the bottom edge of the rubber; its bore hugs the case |
| `cm_cup()` | `ktemata_corner_cup.stl` | the cavity — its inner surface **is** the cap's outer surface |
| `cm_lid()` | `ktemata_corner_lid.stl` | top seal, with a fill port (Ø3.2) and an air vent (Ø2.0) |

Why a z-split and not a two-piece tool on the corner's 45° diagonal: each half of a diagonal split wraps one
wall, so sliding it along the split normal drags it through the other wall. The corner cross-section is only
prismatic along z, so z is the only demould direction that works without a sliding core.

The case clearance (`CM_FIT = 0.15`) is used by the rubber's inner face **and** by every tool bore, so the
cavity equals the cap exactly: the cap slides on, and the plate/lid seal on the same surface. The 0.15 mm
line of flash left around each cap is trimmed with a blade after curing.

## Print

| Part | Material | Orientation | Notes |
|---|---|---|---|
| cup | PLA/PETG | as exported (open face up) | 2 walls, 20 % infill; the cavity needs no supports |
| plate | PLA/PETG | as exported | flat, prints on its bottom |
| lid | PLA/PETG | as exported | flat |
| **test cap** | **TPU 95A** | as exported (flipped) | optional but recommended — proves the fit before silicone |

Tool parts must be **smooth**: 0.12 mm layers and, if your silicone is thin, a coat of release agent.
Silicone sticks to PETG far less than to PLA; PLA is fine with a mould release.

```bash
python3 cad/tools/export.py corner_cap corner_plate corner_cup corner_lid
```

One tool set does one corner. Print four sets for all four, or cast the corners one at a time and reuse the
set (the plate and cup see the same geometry on all four corners; only the *sensor pocket* corner differs —
see below).

## Casting

1. **Test-fit first.** Print `ktemata_corner_cap.stl` in TPU and slide it onto the corner. It must go on
   with light pressure and sit flush. If it will not, raise `CM_FIT` to 0.25 and re-export.
2. **Clean the case corner** with IPA. Any grease or dust becomes a mould line.
3. Fit the **plate** on the case from below, then slide the **cup** down onto it over the corner. The two
   M3 screws pull the cup onto the plate; the alignment pins set the register.
4. Mix the silicone (1:1 or 10:1 depending on the kit) and **de-air** it — 2 min in a vacuum chamber, or tap
   the cup for a minute. Bubbles are the main cosmetic failure.
5. **Pour slowly into the fill port** in one continuous stream, letting the air escape through the vent. Fill
   until it stands in the basin. Do not overfill the basin: it is a reservoir, and the level drops as the
   rubber settles.
6. Cure per the datasheet (typically 4 h at 23 °C, or 1 h at 60 °C). A warm box shortens it and improves
   tear strength.
7. **Demould:** unscrew the lid, lift the cup straight up, then remove the plate downwards. Peel the flash
   line off with a sharp blade; the cap is already bonded to the case only by friction — it is a *sleeve*,
   not an adhesive joint. That is deliberate: it stays replaceable.

## Corner-specific notes

* **Sensor chamber (left wall).** The BME688 chamber spans drawing y 196–224, i.e. real y 13–41, and its Ø16
  membrane seat real y 33–49 — measured from the *other* short wall. Both short corners on the left wall
  therefore overlap the chamber at 23 mm reach. Two options: use `-D CM_LY=12` on the two left corners (cap
  ends before the bumper does, so they look shorter), or accept that the cap covers the vent — **don't**: the
  sensor needs that hole open. Check your own build's vent position before casting the left-side caps.
* **Top wall and the OLED button.** The cap reach is `CM_LX = 26`, exactly the bumper length: the button's
  Ø16 recess starts at x 27, so a longer reach would run under the seal. Do not raise `CM_LX` past 26.
* **Right wall near the Pi ports.** The port windows start at real y 151.7 (drawing y 70.7) — far from either
  short wall — so the caps do not touch them. The +y caps do sit beside the OLED button and the DC socket,
  which is what `CM_LX = 26` protects.
* **The two corners on the +x side** use the mirrored tool: `-D CM_MX=true` (and `-D CM_MY=true` for the
  +y corners). `cm_place()` handles it; the STL is identical either way.
* **Chamfer.** `CM_Z0 = 5` clears the 3 mm edge chamfer plus the bumper's 1.2 mm chamfer. Lowering it will
  make the cap bridge the chamfer and thin out at the bottom edge.

## Silicone choice

| Type | Shore | Why / why not |
|---|---|---|
| Platinum-cure (addition) RTV, 1:1 | 10–20 A | Best. Skin-safe, low shrinkage, long pot life, cures at room temp. |
| Platinum-cure 10:1 "mould making" | 10–30 A | Cheaper per litre, slightly stiffer. |
| Tin-cure (condensation) RTV | 20–40 A | Works, but shrinks, smells of acetic acid, and can corrode the case's electronics if used nearby. Avoid. |
| 2-part polyurethane | 40–70 A | Much harder — a hard plastic cap, not a rubber bumper. |

Target 10–20 Shore A: soft enough to absorb a drop, firm enough not to peel off in a pocket.

## Limits

* The cap is a **sleeve over the existing bumper**, not a redesign of it: it adds 2 mm per side, so the case
  grows by up to 4 mm in each of width and length at the four corners.
* It does not seal the case — the case is already sealed by the lip and the screws. The cap covers the seam
  visually and cushions the corner.
* One tool set casts one corner; nothing here is a four-cavity production mould.
* A silicone cap is not a drop rating. It softens a corner impact; it does not make the device ruggedised
  beyond what the printed shell already is.

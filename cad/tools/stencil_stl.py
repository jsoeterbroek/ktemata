#!/usr/bin/env python3
"""Ktemata r5 - the Meridian stencils as printable STL masks.

The SVG cut files in docs/paint/ are 261.5 x 234.1 mm (cover) and 271.3 x 242.8 mm (deck) sheets:
the part plus a 14 mm handling margin for the title, the caption and the registration crosses.
That is right for a blade and a sheet of vinyl, and the deck's is 15.3 mm too wide for a 256 mm
printer bed.  These files are the same masks as solid panels that land on the part with their own
outline as the datum - no margin, no measuring, no rescaling.  The deck's plate is 243.3 x 186.8
(the host's cavity at deck height, R5_DECK_* in common.scad), so it still fits the bed.

    python3 cad/tools/stencil_stl.py                   # every pass, both parts
    python3 cad/tools/stencil_stl.py --part deck        # one part
    python3 cad/tools/stencil_stl.py --pass bezel       # one paint pass
    python3 cad/tools/stencil_stl.py --thickness 2.0    # a stiffer mask (default 1.2 mm)
    python3 cad/tools/stencil_stl.py --include-vinyl    # also emit ash, as loose strips

Output: stl/stencil_<part>_<pass>.stl.

WHY THE GEOMETRY COMES FROM paint.py, NOT FROM THE SVG
    An SVG is a drawing: its marks are filled paths and the part is a clip path.  Rasterising it
    back into geometry would quantise the 0.5 mm graticule slot, which is the one dimension that
    has to survive the round trip.  paint.py already carries every mark as a rounded rectangle
    (`Mark`) and every aperture as a shape (`Aperture`), and the sheets are rendered from exactly
    that data - so this module reads the same objects and the two cannot drift apart.

THE COVER IS TWO PLANES, NOT ONE
    Its plate's painted face is at z 4.0 and its bezel stands to z 11.92: a 7.92 mm step.  A flat
    mask cannot bridge it, so the cover's plate-level masks have the bezel's whole footprint cut
    away (they lie on the plate and the ring pokes through), and the `bezel` pass is its own
    ring-shaped mask that sits on the bezel's top face.  `cover_hit()` enforces the same rule for
    the artwork, so no mark crosses the step in the first place.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
OUT = REPO / "stl"

sys.path.insert(0, str(HERE))
import paint  # noqa: E402  (same directory: shares Model, meridian_marks, apertures)

THICKNESS = 1.2      # thin enough to follow the plate, thick enough to survive handling
EXIT = 0.5           # over-cut for a slot that ends on the part outline (see mask_source)
NUDGE = 0.05         # ... and the perpendicular nudge that keeps a cut off a corner tangent

# WHICH PASSES ARE PRINTABLE
# A mask is the sheet minus its slots, so it stays in one piece only if the slots do not form a
# closed grid.  The ash graticule does, twice over: 8 horizontal rows and 10 vertical columns on
# the deck, which cuts the sheet into ~80 cells and comes out of the slicer as 11 loose strips.
# No amount of edge ligament fixes that - the cuts meet each other in the middle of the plate, so
# the islands are inherent to the artwork, not to the tie width (measured: 23 pieces at 0 mm tie,
# 11 at 0.8, 1.5, 2.5 and 4.0).
#
# So the ash pass is NOT generated.  It stays vinyl - 0.5 mm pinstripe tape is a stock product on
# a 17.81 mm pitch, and PAINT.md already recommends it for exactly this reason.  The other three
# passes are one solid each: amber is 5-7 separated rules, seam is 2-6 end bars plus the hinge
# rule, and the bezel is a single closed ring.
VINYL_ONLY = {"ash"}


# ---------------------------------------------------------------- OpenSCAD emitters
def rrect_2d(x, y, w, h, r) -> str:
    """A rounded rectangle of exactly w x h at (x, y).

    `offset(r=R)` grows a shape by R in every direction, so the square has to be inset by R and
    pushed back out by the same amount.  Used raw it made every mask 2R too big in both axes,
    which is not obvious on screen and is a print that does not fit the part.
    """
    r = max(0.0, min(r, w / 2, h / 2))
    if r <= 0:
        return f"translate([{x:.4f}, {y:.4f}]) square([{w:.4f}, {h:.4f}]);"
    return (f"translate([{x + r:.4f}, {y + r:.4f}]) "
            f"offset(r={r:.4f}) square([{w - 2 * r:.4f}, {h - 2 * r:.4f}]);")


def rrect_solid(x, y, w, h, r, z, tz) -> str:
    """A rounded rectangle as an OpenSCAD solid, with an over-cut in z at both faces."""
    return f"translate([0, 0, {z:.4f}]) linear_extrude({tz:.4f}) " + rrect_2d(x, y, w, h, r)


def circle_solid(cx, cy, d, z, tz) -> str:
    return (f"translate([{cx:.4f}, {cy:.4f}, {z:.4f}]) "
            f"cylinder(d={d:.4f}, h={tz:.4f}, $fn=64);")


def mask_source(m: "paint.Model", cover: bool, group: str,
                thickness: float) -> tuple[str, str]:
    """OpenSCAD source for one mask, plus a one-line description of what it is."""
    if cover:
        x0, y0, w, l, r = 0.0, 0.0, m.w, m.l, m.cover_r
    else:
        x0, y0, w, l, r = m.deck              # the deck's plate, larger than the cassette
    # The parts are modelled with the hinge at y = 0 and the latch end at y = l, in a frame whose
    # y grows towards the latch.  A printed mask just has to match the part it lies on, so it is
    # emitted in the SAME frame as the part - no mirroring: paint.py mirrors only for the sheet,
    # where the cover is drawn above the deck to make one open-flat picture.  The deck's outline
    # starts at (x0, y0) (it overhangs the tray); the finished mask is shifted to the origin so it
    # prints as a plain w x l panel.
    solids = [f"linear_extrude({thickness:.4f}) " + rrect_2d(x0, y0, w, l, r)]
    cuts: list[str] = []

    for mk in paint.meridian_marks(m, cover):
        if mk.group != group:
            continue
        # A slot that ends exactly ON the part outline leaves a coincident face - CGAL emits a
        # zero-area wall there and the mesh comes out with open edges (the cover's seam bars do
        # this at x 233.5).  Grow the cut a hair past the outline so it is a clean through-slot
        # instead: 0.5 mm is the same over-cut the r5 cover uses for its panel well.
        # grow only the edge that actually meets the outline - growing both ends would move the
        # slot's other edge and change the mark
        ex0 = EXIT if mk.x0 <= 1e-6 else 0.0
        ex1 = EXIT if mk.x1 >= w - 1e-6 else 0.0
        ey0 = EXIT if mk.y0 <= 1e-6 else 0.0
        ey1 = EXIT if mk.y1 >= l - 1e-6 else 0.0
        # A slot that exits sideways can still have an edge EXACTLY tangent to a corner arc -
        # the cover's latch-edge seam bar ends at y 170.1, which is where its R8 corner starts
        # (178.1 - 8).  A tangential vertex is a degenerate face, so nudge the perpendicular
        # pair by a hair; 0.05 mm is invisible in paint and well clear of CGAL's tolerance.
        if ex0 or ex1:
            ey0 = ey0 or NUDGE
            ey1 = ey1 or NUDGE
        if ey0 or ey1:
            ex0 = ex0 or NUDGE
            ex1 = ex1 or NUDGE
        cuts.append(rrect_solid(mk.x0 - ex0, mk.y0 - ey0,
                                (mk.x1 - mk.x0) + ex0 + ex1,
                                (mk.y1 - mk.y0) + ey0 + ey1, mk.r,
                                -1.0, thickness + 2.0))
        # A ring mark's inner rectangle is not a cut: the hole in a frame is the thing you spray
        # THROUGH, so the mask is the ring itself.  Nothing to do - the ring is already the shape.

    for a in paint.apertures(m, cover):
        if a.kind == "circle":
            cuts.append(circle_solid(a.x, a.y, 2 * a.r, -1.0, thickness + 2.0))
        else:
            cuts.append(rrect_solid(a.x, a.y, a.w, a.h, a.r, -1.0, thickness + 2.0))

    # The cover's raised bezel: plate-level masks cannot cross a 7.92 mm step, so they carry a
    # hole where the ring stands and the ring gets its own mask on its top face.
    if cover and group != "bezel":
        bx, by, bw, bh, br = m.bezel_ring
        cuts.append(rrect_solid(bx, by, bw, bh, br, -1.0, thickness + 2.0))

    body = "difference() { union() { " + " ".join(solids) + " } " + " ".join(cuts) + " }"
    if x0 or y0:
        body = f"translate([{-x0:.4f}, {-y0:.4f}]) " + body

    if cover and group == "bezel":
        # the bezel mask is the ring's top face and nothing else: it is placed on the raised
        # face, not on the plate
        bx, by, bw, bh, br = m.bezel_ring
        wx, wy, ww, wh, wr = m.well
        body = ("difference() { "
                f"linear_extrude({thickness:.4f}) " + rrect_2d(bx, by, bw, bh, br) +
                f" translate([0, 0, -1]) linear_extrude({thickness + 2:.4f}) "
                + rrect_2d(wx, wy, ww, wh, wr) + " }")


    desc = f"{'LID COVER' if cover else 'DECK'} - {group} pass, {thickness} mm mask"
    return body, desc


def emit(m: "paint.Model", cover: bool, group: str, thickness: float) -> Path:
    src, desc = mask_source(m, cover, group, thickness)
    side = "cover" if cover else "deck"
    name = f"stencil_{side}_{group}"
    out = OUT / f"{name}.stl"
    with tempfile.TemporaryDirectory() as td:
        scad = Path(td) / "m.scad"
        scad.write_text("$fn = 64;\n" + src + "\n")
        # binary STL, like every other file export.py writes: ASCII triples the file size and
        # every other tool in this repo reads the binary header
        res = subprocess.run(["openscad", "-o", str(out), "--export-format=binstl", str(scad)],
                             capture_output=True, text=True)
        if res.returncode or not out.exists():
            sys.exit(f"{name}: openscad failed\n{res.stderr[-2000:]}")
        vols = [ln for ln in res.stderr.splitlines() if "Volumes:" in ln]
        pieces = int(vols[-1].split(":")[1]) - 1 if vols else 0
    print(f"{out.relative_to(REPO)}   {desc}   ({pieces} piece{'s' if pieces != 1 else ''})")
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--part", choices=("deck", "cover", "both"), default="both")
    ap.add_argument("--pass", dest="group", choices=tuple(g for g, _, _ in paint.STENCIL_PASSES),
                    help="only this paint pass")
    ap.add_argument("--thickness", type=float, default=THICKNESS,
                    help=f"mask thickness in mm (default {THICKNESS})")
    ap.add_argument("--include-vinyl", action="store_true",
                    help="also emit the ash pass, knowing it prints as ~11 loose strips")
    args = ap.parse_args()

    m = paint.Model(paint.probe())
    dx0, dy0, dw, dl, dr = m.deck
    print(f"cassette {m.w} x {m.l} mm, deck {dw} x {dl} mm (R{dr}), cover R{m.cover_r}, "
          f"mask {args.thickness} mm")
    OUT.mkdir(parents=True, exist_ok=True)
    made = []
    for cover, side in ((False, "deck"), (True, "cover")):
        if args.part not in ("both", side):
            continue
        for group, _name, _blurb in paint.STENCIL_PASSES:
            if args.group and group != args.group:
                continue
            if group in VINYL_ONLY and not args.include_vinyl:
                print(f"{side:5s} {group:6s} skipped: stays vinyl (see VINYL_ONLY)")
                continue
            if not any(mk.group == group for mk in paint.meridian_marks(m, cover)):
                continue
            made.append(emit(m, cover, group, args.thickness))
    print(f"{len(made)} file(s) in {OUT.relative_to(REPO)}/")


if __name__ == "__main__":
    main()

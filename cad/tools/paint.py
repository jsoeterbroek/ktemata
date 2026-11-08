#!/usr/bin/env python3
"""Ktemata r5 - three airbrush paint schemes for the deck and the lid cover.

Writes 1:1 SVG artwork and PNG previews into docs/paint/.  Every dimension comes out of the
OpenSCAD model through cad/tools/paint_probe.scad, so the apertures on the sheet are the real ones and
the sheet can be printed and used as a masking template without rescaling.

    python3 cad/tools/paint.py             # three schemes + contact sheet
    python3 cad/tools/paint.py --scheme 2  # one scheme
    python3 cad/tools/paint.py --no-png    # SVGs only

Layout is the case OPEN FLAT: the lid cover above the hinge line, the deck below it, both with the
hinge edge on that line and y measured from it, exactly as common.scad does it (y = 0 at the
hinge, latch end at y = R5_L).  Paint that crosses the centre line therefore continues from one
printed part into the other - the three schemes are built on that.

Two facts drive the artwork and are enforced in code, not by eye:
  * the cover has one flat front at z = 14.50 mm. Its 193.96 x 111.76 mm display opening (the
    module plus 0.5 mm clearance per side) recedes 10.50 mm to the 4.00 mm rear skin. The 7 mm
    slate border is paint on that same front, not a keep-out; only the opening, cable notch and
    reserved type interrupt marks;
  * the deck's own free fields are the 40.95 mm side rails, the strip between the OLED and the
    keyboard (y 72.2..102.5) and the 30 mm along the latch edge.
"""
from __future__ import annotations

import argparse
import ast
import math
import shutil
import subprocess
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.font_manager as fm  # noqa: E402
import matplotlib.textpath as tp  # noqa: E402
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
OUT = REPO / "docs" / "paint"

# ---------------------------------------------------------------- palette
# site/style.css plus the lighter accent highlight paint needs.  These are paint references:
# keep them in step with the site's custom properties.
INK = "#05080b"        # cavities, never painted
BASE = "#151b21"      # --bg           graphite base coat, all three schemes
SLATE = "#26313a"     # --panel, one step up so it reads next to the base at 300 mm
STEEL = "#2f3a45"     # --line         masked hairlines
GREY = "#7c8993"      # ash
GREY_L = "#a9b2bb"    # --muted
AMBER = "#c99a63"     # --accent
AMBER_D = "#8a6234"   # --accent-soft
AMBER_L = "#e2bd8d"   # accent highlight
IVORY = "#f2ebe0"     # --fg

PAPER = "#efe9de"
PAPER_INK = "#151b21"
PAPER_MUTED = "#7a7165"

FONT = "DejaVu Sans"
LABEL = "#8fa0ad"     # the grey that names printed features


# ---------------------------------------------------------------- model probe
def probe() -> dict:
    """Geometry, straight from OpenSCAD.  No dimension in this file is guessed."""
    if not shutil.which("openscad"):
        sys.exit("openscad not found: the sheets are generated from the model")
    res = subprocess.run(
        ["openscad", "-D", "R5=true", "-o", "/tmp/ktemata_paint_probe.csg",
         str(HERE / "paint_probe.scad")],
        capture_output=True, text=True,
    )
    if res.returncode != 0:
        sys.exit("probe failed:\n" + (res.stderr or res.stdout).strip())
    # OpenSCAD writes ECHO to stderr and the mesh to -o
    vals: dict[str, object] = {}
    for line in (res.stderr + res.stdout).splitlines():
        if not line.startswith("ECHO: "):
            continue
        key, _, raw = line[6:].partition(" = ")
        try:
            vals[key.strip()] = ast.literal_eval(raw.strip())
        except (ValueError, SyntaxError):
            # a mangled probe line would otherwise surface as a KeyError far from the cause
            sys.exit(f"paint_probe.scad emitted an unparsable value: {line!r}")
    if "P_W" not in vals:
        sys.exit("probe produced no geometry:\n" + res.stderr[-2000:])
    return vals


class Model:
    def __init__(self, v: dict[str, object]) -> None:
        g = lambda k: float(v[k])  # noqa: E731
        self.w, self.l = g("P_W"), g("P_L")
        # the deck's own plate: (x0, y0, w, l, r) in the cassette frame, so x0/y0 are negative
        # where the plate overhangs the tray.  Everything the artwork and the masks do for the
        # deck is still in cassette coordinates; only the outline (and the port, which starts at
        # the plate's hinge edge, not the tray's) moves.
        self.deck = (g("P_DECK_X0"), g("P_DECK_Y0"), g("P_DECK_W"), g("P_DECK_L"),
                     g("P_DECK_R"))
        self.cover_r = g("P_COVER_R")

        self.kb = (g("P_KB_X0"), g("P_KB_Y0"), g("P_KB_W"), g("P_KB_H"), g("P_KB_R"))
        self.oled = (g("P_OLED_X0"), g("P_OLED_Y0"), g("P_OLED_W"), g("P_OLED_H"))
        # the hinge opening runs from the PLATE's edge to R5_OPEN_D (not from y = 0)
        self.port = (g("P_OPEN_X0"), self.deck[1], g("P_OPEN_X1"), g("P_OPEN_D"))
        self.fan = (g("P_FAN_X"), g("P_FAN_Y"), g("P_FAN_D"))
        self.fan_bars, self.fan_bar = int(v["P_FAN_BARS"]), g("P_FAN_BAR")
        self.screws = [(g(f"P_S{i}"), g(f"P_S{i}Y")) for i in range(7)]

        self.gap = g("P_C_GAP")
        self.frame = g("P_C_FRAME")
        # the flat painted border's footprint: panel outline + COVER_GAP + COVER_FRAME
        self.bezel_d = g("P_C_GAP") + g("P_C_FRAME")
        self.panel = (g("P_PANEL_X"), g("P_PANEL_Y"), g("P_DISP_W"), g("P_DISP_H"), g("P_DISP_R"))
        px, py, pw, ph, pr = self.panel
        self.well = (px - self.gap, py - self.gap, pw + 2 * self.gap, ph + 2 * self.gap,
                     pr + self.gap)
        d = self.bezel_d
        self.bezel_ring = (px - d, py - d, pw + 2 * d, ph + 2 * d, pr + d)
        self.active = (g("P_ACTIVE_W"), g("P_ACTIVE_H"))
        # the button is on the DECK now (a centred 7" panel leaves no latch band for it)
        self.btn = (g("P_BTN_X"), g("P_BTN_Y"), g("P_BTN_D"))
        self.btn_body = g("P_BTN_BODY")
        # 8.4 V charge socket through the deck's right rail: hole + the bezel/nut envelope
        self.chg = (g("P_CHG_X"), g("P_CHG_Y"), g("P_CHG_D"), g("P_CHG_NUT_D"))
        self.cable = (g("P_CABLE_X"), g("P_CABLE_Y"), g("P_CABLE_W"), g("P_CABLE_H"))

        # ---- the type blocks are part of the mask, not something painted over ----
        # A grid line or a band running under a wordmark reads as a printing error, and no
        # signwriter would leave one there.  Declaring the blocks here means every scheme stops
        # at the lettering by construction instead of relying on draw order.
        x, y, bw, bh, _ = self.kb
        # baseline in the 35.6 mm strip between the OLED window (ends y 66.9) and the keyboard
        # (starts y 102.5): 4 mm clear above the cap, 4 mm below the small line
        self.deck_text_y = g("P_OLED_Y0") + g("P_OLED_H") + 4.0 + 10.5
        # Keep the cover block in the latch band below the painted border. The border is still a
        # useful layout datum, but it is not a height change: the sticker and every painted pass
        # share the same flat front. The band's top comes from the panel, clearance and frame;
        # its bottom is the part edge.
        self.cover_band_y0 = py + ph + self.bezel_d
        self.cover_band = self.l - self.cover_band_y0
        # Pick the largest cap whose block, trim and both margins fit the band. Done here, before
        # any box is built, because the sticker, the reserved plate and the sheet all read it.
        self.cover_cap = next((c for c in COVER_CAPS
                               if sticker_trim("cover", c)[1] + 2 * 2.0 <= self.cover_band),
                              COVER_CAPS[-1])
        # The block is CENTRED in the flat band, not hung off its top edge: the cap is fitted to
        # the band, so a 2 mm offset from one edge would leave the other margin short.
        # In the cover's mirrored frame the sticker box's top edge is at (baseline - by1 -
        # STICKER_MARGIN), so place that edge where the centring wants it and solve for baseline.
        _bx0, _by0, _bx1, _by1 = _sticker_box(self.cover_spec())
        _th = sticker_trim("cover", self.cover_cap)[1]
        _top = self.cover_band_y0 + (self.cover_band - _th) / 2
        self.cover_text_y = _top + _by1 + STICKER_MARGIN
        # drawing y grows hinge -> latch, so a glyph stands ABOVE its baseline at smaller y on
        # the deck (unflipped) and at larger y on the cover (drawn flipped to keep the hinge at
        # the seam).  Build each block in the part's own frame.
        #
        # The reserved plate IS the sticker (see sticker_specs): tw x th of vinyl, printed in the
        # base graphite, laid where the graticule was told to stop.  Deriving the box from the
        # sticker means a line can never end under the vinyl's edge, and resizing the artwork
        # moves the keep-out with it.
        boxes = {}
        for side, base in (("deck", self.deck_text_y), ("cover", self.cover_text_y)):
            tw, th = sticker_trim(side, self.cover_cap)
            bx0, by0, _bx1, by1 = _sticker_box(self.spec_for(side))
            # the deck is drawn upright, so artwork "above the baseline" is at smaller part y;
            # the cover is drawn mirrored, so the same ink sits at larger y there
            y0 = (base - by1 - STICKER_MARGIN) if side == "cover" else (base + by0 - STICKER_MARGIN)
            boxes[side] = (self.w / 2 - tw / 2, y0, tw, th)
        self.type_boxes: dict[str, tuple[float, float, float, float]] = boxes

        # ---- free fields, derived and checked ----
        self.rail_l = x                       # deck free rail, 40.95
        self.rail_r = self.w - (x + bw)       # 40.95
        # Cover margin outside the painted border. The border remains a layout datum, not an
        # aperture or a separate surface.
        self.cover_margin = px - self.gap - self.frame
        self.band_x0 = px - self.gap          # 19.77: display opening, left edge
        self.band_x1 = px + pw + self.gap      # 213.73: display opening, right edge
        assert self.cover_margin >= 10.0, \
            f"only {self.cover_margin:.1f} mm of cover plate outside the painted border"

        # The lettering must sit on clean plate, and its block must not swallow a feature - a
        # wordmark that has to dodge a fan is a wordmark in the wrong place.  Only the features
        # of its OWN part matter: the two parts are judged separately.
        for name, box, own in (("deck", self.type_boxes["deck"],
                                (self.kb, self.oled)),
                               ("cover", self.type_boxes["cover"],
                                (self.well, self.cable))):
            for h in own:
                assert not _overlaps(box, h), f"the {name} lettering runs into {h}"
            if name == "deck":
                assert not any(_overlaps(box, (sx - 6.0, sy - 6.0, 12.0, 12.0))
                               for sx, sy in self.screws), "the deck lettering runs into a deck screw"
            assert 2.0 < box[1] and box[1] + box[3] < self.l - 2.0, \
                f"the {name} lettering runs off the part: {box}"


    # ---- derived type metrics ----
    def cover_spec(self) -> dict:
        return next(s for s in sticker_specs(self.cover_cap) if s["side"] == "cover")

    def _cover_block_h(self, cap: float) -> float:
        """Block height for one cap, in mm, before the sticker margin."""
        spec = dict(sticker_specs(cap)[1])
        bx0, by0, bx1, by1 = _sticker_box(spec)
        return by1 - by0

    def spec_for(self, side: str) -> dict:
        return self.cover_spec() if side == "cover" else sticker_specs()[0]


# ---------------------------------------------------------------- svg primitives
def f(v: float) -> str:
    s = f"{v:.3f}"
    return s.rstrip("0").rstrip(".") if "." in s else s


def rrect_d(x: float, y: float, w: float, h: float, r: float) -> str:
    r = max(0.0, min(r, w / 2, h / 2))
    if r <= 0:
        return f"M{f(x)} {f(y)}H{f(x + w)}V{f(y + h)}H{f(x)}Z"
    return (f"M{f(x + r)} {f(y)}H{f(x + w - r)}A{f(r)} {f(r)} 0 0 1 {f(x + w)} {f(y + r)}"
            f"V{f(y + h - r)}A{f(r)} {f(r)} 0 0 1 {f(x + w - r)} {f(y + h)}"
            f"H{f(x + r)}A{f(r)} {f(r)} 0 0 1 {f(x)} {f(y + h - r)}"
            f"V{f(y + r)}A{f(r)} {f(r)} 0 0 1 {f(x + r)} {f(y)}Z")


def circle_d(cx: float, cy: float, r: float) -> str:
    return (f"M{f(cx - r)} {f(cy)}A{f(r)} {f(r)} 0 1 1 {f(cx + r)} {f(cy)}"
            f"A{f(r)} {f(r)} 0 1 1 {f(cx - r)} {f(cy)}Z")


# ---------------------------------------------------------------- text as outlines
_CAP: float | None = None
_CACHE: dict[tuple, tuple[str, float]] = {}


def _cap_units() -> float:
    global _CAP
    if _CAP is None:
        verts, _ = tp.TextToPath().get_text_path(
            fm.FontProperties(family=FONT, size=100), "H")
        _CAP = float(np.max(np.asarray(verts)[:, 1]))
    return _CAP


def _text_path(text: str, cap: float, italic: bool, track: float) -> tuple[str, float]:
    """Glyph outlines in mm, baseline at y = 0, cap height `cap`, letter gap `track` mm."""
    key = (text, round(cap, 4), italic, round(track, 4))
    if key in _CACHE:
        return _CACHE[key]
    t2p = tp.TextToPath()
    prop = fm.FontProperties(family=FONT, style="italic" if italic else "normal", size=100)
    scale = cap / _cap_units()
    d: list[str] = []
    pen = 0.0
    for ch in text:
        verts, codes = t2p.get_text_path(prop, ch)
        verts, codes = np.asarray(verts), np.asarray(codes)
        i = 0
        while i < len(codes):
            c = int(codes[i])
            x, y = verts[i]
            if c == 1:
                d.append(f"M{f(x * scale + pen)} {f(-y * scale)}")
            elif c == 2:
                d.append(f"L{f(x * scale + pen)} {f(-y * scale)}")
            elif c == 3 and i + 1 < len(codes) and int(codes[i + 1]) == 3:
                (cx, cy), (ex, ey) = verts[i], verts[i + 1]
                d.append(f"Q{f(cx * scale + pen)} {f(-cy * scale)} "
                         f"{f(ex * scale + pen)} {f(-ey * scale)}")
                i += 1
            elif (c == 4 and i + 2 < len(codes)
                  and int(codes[i + 1]) == 4 and int(codes[i + 2]) == 4):
                (c1x, c1y), (c2x, c2y), (ex, ey) = verts[i], verts[i + 1], verts[i + 2]
                d.append(f"C{f(c1x * scale + pen)} {f(-c1y * scale)} "
                         f"{f(c2x * scale + pen)} {f(-c2y * scale)} "
                         f"{f(ex * scale + pen)} {f(-ey * scale)}")
                i += 2
            elif c == 79:
                d.append("Z")
            i += 1
        pen += t2p.get_text_width_height_descent(ch, prop, False)[0] * scale + track
    out = (" ".join(d), max(0.0, pen - track))
    _CACHE[key] = out
    return out


def text_w(text: str, cap: float, track: float = 0.0, italic: bool = False) -> float:
    return _text_path(text, cap, italic, track)[1]


# ---------------------------------------------------------------- the two type blocks
# Defined here, above the Model, because the mask and the sticker are the same footprint: the
# reserved plate on the sheet IS the sticker, so a graticule line stops just short of the vinyl
# instead of leaving a painted sliver under its edge.  One definition, two consumers.
STICKER_MARGIN = 2.5     # graphite visible round the ink, inside the cut line
STICKER_BLEED = 1.0      # print past the cut line, per the printer's spec
STICKER_CAP = 10.5       # matches brand_deck's cap


# The motto block lives in the latch band below the painted border. Its cap is fitted to the
# probed band rather than moving the centred display. Model.cover_cap picks the largest cap that
# fits; sticker_specs() takes it.
COVER_CAPS = [10.5, 10.0, 9.5, 9.0, 8.5, 8.0, 7.5, 7.0, 6.5, 6.0, 5.5, 5.0, 4.5]


def sticker_specs(cover_cap: float = STICKER_CAP) -> list[dict]:
    cap = STICKER_CAP
    return [
        dict(side="deck", name="wordmark",
             lines=[("KTEMATA", cap, cap * 0.28, False, AMBER_L, 0.0),
                    ("OFFLINE  LIBRARY", 2.6, 1.5, False, GREY_L, 6.8)],
             rule=(3.0, text_w("KTEMATA", cap, cap * 0.28) / 2, AMBER, 0.8),
             note="KTEMATA wordmark, deck top face"),
        # The cover block is SCALED, not merely re-capped: a block whose tagline sits at a fixed
        # 9.8 mm under the baseline cannot shrink into the latch band however small the Greek is
        # set. Every vertical offset is therefore a fraction of the cap (0.495 for the rule,
        # 0.933 for the tagline - the ratios the original 10.5 mm block had), so the whole block
        # scales as one. The band is a layout choice on the flat front, not a step constraint.
        dict(side="cover", name="motto",
             lines=[("κτῆμα ἐς ἀεί", cover_cap, 0.0, True, IVORY, 0.0),
                    ("KTEMATA  ·  A POSSESSION FOR ALL TIME", max(1.9, cover_cap * 0.229),
                     max(0.6, cover_cap * 0.105), False, GREY_L, cover_cap * 0.933)],
             rule=(cover_cap * 0.495,
                   text_w("κτῆμα ἐς ἀεί", cover_cap, 0.0, True) / 2 + cover_cap * 0.76,
                   AMBER, 0.8),
             note="motto, lid cover front face"),
    ]


def _sticker_box(spec: dict) -> tuple[float, float, float, float]:
    """Ink bounds of one block: x from its centre, y down-positive from the baseline."""
    x0 = y0 = math.inf
    x1 = y1 = -math.inf
    for text, cap, track, italic, _fill, dy in spec["lines"]:
        ax0, ay0, ax1, ay1 = _text_ink(text, cap, italic, track)
        half = text_w(text, cap, track, italic) / 2
        x0, x1 = min(x0, ax0 - half), max(x1, ax1 - half)
        y0, y1 = min(y0, ay0 + dy), max(y1, ay1 + dy)
    dy, half, _fill, sw = spec["rule"]
    return (min(x0, -half), min(y0, dy - sw / 2),
            max(x1, half), max(y1, dy + sw / 2))


def sticker_trim(side: str, cover_cap: float = STICKER_CAP) -> tuple[float, float]:
    """Trim size of the sticker for one part: ink + margin, rounded up to 0.1 mm.

    The order form wants whole numbers and the die is placed by eye against a ruler, so a
    sub-0.1 mm trim is false precision. Rounding UP keeps the declared margin instead of eating
    into it.
    """
    bx0, by0, bx1, by1 = _sticker_box(next(s for s in sticker_specs(cover_cap)
                                            if s["side"] == side))
    up = lambda v: math.ceil(v * 10.0 - 1e-9) / 10.0  # noqa: E731
    return (up(bx1 - bx0 + 2 * STICKER_MARGIN), up(by1 - by0 + 2 * STICKER_MARGIN))


_INK: dict[tuple, tuple[float, float, float, float]] = {}


def _text_ink(text: str, cap: float, italic: bool, track: float):
    """Ink extents of a line of glyphs: (x0, y0, x1, y1), y down-positive from the baseline.

    `text_w` measures the pen advance, which includes the trailing letter gap and ignores
    overhangs.  A die-cut sticker has to be sized to the ink, not to the pen: the italic motto's
    circumflex rises 1 mm above the cap height, and a file cut to the advance would shave it.
    """
    key = (text, round(cap, 4), italic, round(track, 4))
    if key in _INK:
        return _INK[key]
    t2p = tp.TextToPath()
    prop = fm.FontProperties(family=FONT, style="italic" if italic else "normal", size=100)
    scale = cap / _cap_units()
    pen = 0.0
    x0 = y0 = math.inf
    x1 = y1 = -math.inf
    for ch in text:
        verts, _ = t2p.get_text_path(prop, ch)
        v = np.asarray(verts, dtype=float)
        if len(v):
            xs = v[:, 0] * scale + pen
            ys = -v[:, 1] * scale
            x0, x1 = min(x0, float(xs.min())), max(x1, float(xs.max()))
            y0, y1 = min(y0, float(ys.min())), max(y1, float(ys.max()))
        pen += t2p.get_text_width_height_descent(ch, prop, False)[0] * scale + track
    out = (x0, y0, x1, y1) if x0 < x1 else (0.0, 0.0, 0.0, 0.0)
    _INK[key] = out
    return out


def tspan(text: str, cap: float, x: float, y: float, fill: str, *,
          italic: bool = False, track: float = 0.0, anchor: str = "start",
          opacity: float | None = None) -> str:
    """Glyph outlines, baseline at y, with the anchor resolved and the baseline flipped if needed.

    Every caller passes a *sheet* coordinate, so this is the only place that has to know that a
    flipped part's type must not be mirrored.
    """
    d, width = _text_path(text, cap, italic, track)
    if anchor == "middle":
        x -= width / 2
    elif anchor == "end":
        x -= width
    op = f' opacity="{f(opacity)}"' if opacity is not None else ""
    return (f'<path d="{d}" fill="{fill}"{op} fill-rule="nonzero" '
            f'transform="translate({f(x)} {f(y)})"/>')


# ---------------------------------------------------------------- drawing surface
class Surface:
    """SVG elements in part millimetres, y = 0 at the hinge.

    `flipped` mirrors the whole drawing in y: the cover is hinged on the same edge as the deck
    but is drawn above it, so its hinge edge has to land at the bottom of its panel.  The
    conversion happens in the primitives (y -> L - y), not in a group transform, so type stays
    upright and every offset means what it says on the sheet.

    `paint`, `features` and the caller's own layers are kept apart so the printed features can be
    drawn over the mask and never be clipped by it.
    """

    def __init__(self, model: Model, flipped: bool = False) -> None:
        self.m = model
        self.flipped = flipped
        self.paint: list[str] = []
        self.features: list[str] = []
        # `group="ash"` etc. records the same element under a name, so a scheme drawn once can be
        # re-emitted as one cut file per paint pass without drawing it again
        self.groups: dict[str, list[str]] = {}

    # ---- coordinate conversion ----
    def y(self, v: float) -> float:
        return (self.m.l - v) if self.flipped else v

    def below(self, y: float, d: float) -> float:
        """`d` mm under the baseline as it reads on the sheet, in the part's drawing coordinates.

        Type is always drawn upright on the sheet, so a mirrored part needs the offset applied
        the other way round in its own frame.  Getting this wrong puts a rule through the letters.
        """
        return (y - d) if self.flipped else (y + d)

    def _add(self, layer: str, el: str, group: str | None = None) -> None:
        getattr(self, layer).append(el)
        if group:
            self.groups.setdefault(group, []).append(el)

    def rrect(self, x, y, w, h, r) -> str:
        """A rounded rectangle as path data in sheet coordinates (flip-aware).

        Needed for even-odd rings, where two outlines have to be joined into one <path>; the
        rectangle primitive alone cannot express that.
        """
        top = self.y(y + h) if self.flipped else y
        return rrect_d(x, top, w, h, r)

    def rect(self, x, y, w, h, fill, r=0.0, *, layer="paint", stroke=None, sw=0.0,
             dash=None, opacity=None, group=None) -> None:
        self.path(self.rrect(x, y, w, h, r), fill, layer=layer, stroke=stroke, sw=sw,
                  dash=dash, opacity=opacity, group=group)

    def circle(self, cx, cy, r, fill, *, layer="paint", stroke=None, sw=0.0,
               opacity=None, group=None) -> None:
        self.path(circle_d(cx, self.y(cy), r), fill, layer=layer, stroke=stroke, sw=sw,
                  opacity=opacity, group=group)

    def path(self, d, fill, *, layer="paint", stroke=None, sw=0.0, dash=None,
             opacity=None, rule=None, group=None) -> None:
        attrs = [f'd="{d}"', f'fill="{fill}"']
        if stroke:
            attrs += [f'stroke="{stroke}"', f'stroke-width="{f(sw)}"']
        if dash:
            attrs.append(f'stroke-dasharray="{dash}"')
        if opacity is not None:
            attrs.append(f'opacity="{f(opacity)}"')
        if rule:
            attrs.append(f'fill-rule="{rule}"')
        self._add(layer, "<path " + " ".join(attrs) + "/>", group)

    def line(self, pts, stroke, sw, *, layer="paint", dash=None, opacity=None,
             cap="square", join="round", group=None) -> None:
        d = "M" + " L".join(f"{f(x)} {f(self.y(yy))}" for x, yy in pts)
        attrs = [f'd="{d}"', 'fill="none"', f'stroke="{stroke}"', f'stroke-width="{f(sw)}"',
                 f'stroke-linecap="{cap}"', f'stroke-linejoin="{join}"']
        if dash:
            attrs.append(f'stroke-dasharray="{dash}"')
        if opacity is not None:
            attrs.append(f'opacity="{f(opacity)}"')
        self._add(layer, "<path " + " ".join(attrs) + "/>", group)

    def text(self, s, cap, x, y, fill, *, layer="paint", group=None, **kw) -> None:
        self._add(layer, tspan(s, cap, x, self.y(y), fill, **kw), group)

    def label(self, s, cap, x, y, fill=LABEL, **kw) -> None:
        """A grey annotation naming a printed feature.  Not paint."""
        self.text(s, cap, x, y, fill, layer="features", opacity=0.95, **kw)


def _off_plate(px, py, w: float, h: float, r: float) -> bool:
    """True outside the part outline, including its rounded corners.

    "There is no plate here" has two causes - an aperture, or the edge - and a painted mark has to
    respect both.  Without this the seam rule runs past the corner radius and the cut file ends up
    with a loose black scrap outside the mask.
    """
    if px < 0.0 or py < 0.0 or px > w or py > h:
        return True
    # distance into a corner arc
    cx = r - px if px < r else (px - (w - r) if px > w - r else 0.0)
    cy = r - py if py < r else (py - (h - r) if py > h - r else 0.0)
    return cx > 0.0 and cy > 0.0 and math.hypot(cx, cy) > r


def _in_rect(px, py, box, pad=0.0) -> bool:
    x, y, w, h = box[:4]
    return x - pad < px < x + w + pad and y - pad < py < y + h + pad


def _overlaps(a: tuple[float, ...], b: tuple[float, ...]) -> bool:
    """Boxes are (x, y, w, h) everywhere - the model's feature tuples and the type blocks alike."""
    return not (a[0] + a[2] <= b[0] or b[0] + b[2] <= a[0]
                or a[1] + a[3] <= b[1] or b[1] + b[3] <= a[1])


def _in_circle(px, py, cx, cy, r, pad=0.0) -> bool:
    return (px - cx) ** 2 + (py - cy) ** 2 < (r + pad) ** 2


# ---------------------------------------------------------------- apertures, as shapes
# Apertures are emitted as data first and rendered twice: to SVG path data for the cut sheets and
# to OpenSCAD solids for the printed masks (cad/tools/stencil_stl.py).  Keeping the two renderings
# off one shape list is what stops the sheet and the STL from disagreeing about where a hole is -
# they did, because the cover's marks are mirrored into the sheet's frame and its apertures were
# not, which put the DSI notch on the wrong half of the drawing.
class Aperture:
    """One opening in the part: a rounded rectangle or a circle, in drawing coordinates."""
    __slots__ = ("kind", "x", "y", "w", "h", "r")

    def __init__(self, kind, x, y, w, h, r=0.0):
        self.kind, self.x, self.y, self.w, self.h, self.r = kind, x, y, w, h, r

    @staticmethod
    def rrect(x, y, w, h, r=0.0):
        return Aperture("rrect", x, y, w, h, r)

    @staticmethod
    def circle(cx, cy, d):
        return Aperture("circle", cx, cy, d, d, d / 2)

    def d(self, fy=lambda y: y) -> str:
        """SVG path data. `fy` is a pure mirror of ONE y coordinate (y -> l - y), never a
        rectangle's translation: the rectangle's two y edges are mapped here, once, and drawn
        from the smaller of the two.  (This used to assume every caller flipped, so an unflipped
        deck drew every aperture one height too low: the keyboard hole landed at the latch edge
        and the Pi opening 20 mm inside the plate instead of on it.)"""
        if self.kind == "circle":
            return circle_d(self.x, fy(self.y), self.r)
        ya, yb = fy(self.y), fy(self.y + self.h)
        return rrect_d(self.x, min(ya, yb), self.w, abs(yb - ya), self.r)

    def rect(self) -> tuple[float, float, float, float]:
        """Axis-aligned bounds (x, y, w, h) in drawing coordinates."""
        if self.kind == "circle":
            return (self.x - self.r, self.y - self.r, 2 * self.r, 2 * self.r)
        return (self.x, self.y, self.w, self.h)


def part_box(m: Model, cover: bool) -> tuple[float, float, float, float, float]:
    """The part's painted plate: (x0, y0, w, l, r).  The deck's is larger than the cassette and
    starts at a negative x/y; the cover's is the cassette rectangle."""
    return (0.0, 0.0, m.w, m.l, m.cover_r) if cover else m.deck


def deck_apertures(m: Model) -> list[Aperture]:
    """The deck's openings: paint cannot land where the plate is cut."""
    kx, ky, kw, kh, kr = m.kb
    ox, oy, ow, oh = m.oled
    px, py, pw, ph = m.port
    fx, fy, fd = m.fan
    out = [Aperture.rrect(kx, ky, kw, kh, kr), Aperture.rrect(ox, oy, ow, oh, 0.8),
           Aperture.rrect(px, py, pw - px, ph - py, 0.0), Aperture.circle(fx, fy, fd)]
    out += [Aperture.circle(sx, sy, 2 * 3.1) for sx, sy in m.screws]
    # the 16 mm power button lives on the deck now, and so does the charge socket
    out.append(Aperture.circle(m.btn[0], m.btn[1], m.btn[2]))
    out.append(Aperture.circle(m.chg[0], m.chg[1], m.chg[2]))
    return out


def cover_apertures(m: Model) -> list[Aperture]:
    wx, wy, ww, wh, wr = m.well
    cx, cy, cw, ch = m.cable
    return [Aperture.rrect(wx, wy, ww, wh, wr), Aperture.rrect(cx, cy, cw, ch, 0.0)]


def apertures(m: Model, cover: bool) -> list[Aperture]:
    return cover_apertures(m) if cover else deck_apertures(m)


def deck_holes_d(m: Model) -> list[str]:
    return [a.d() for a in deck_apertures(m)]


def cover_holes_d(m: Model) -> list[str]:
    """Apertures in the SHEET's frame.

    The cover is drawn mirrored in y so its hinge edge meets the deck's at the seam, and its
    MARKS are mirrored to match.  Its apertures were not, which put the DSI notch at the latch
    end instead of the hinge (see docs/PAINT.md).  A rectangle's flipped top edge is
    l - (y + h); a circle's centre is simply mirrored.
    """
    l = m.l
    return [a.d(lambda y: l - y) for a in cover_apertures(m)]


def deck_hit(m: Model, px, py, pad=0.0) -> bool:
    """True where the deck's top face is interrupted, or is reserved for the lettering."""
    dx0, dy0, dw, dl, dr = m.deck
    x0, y0, x1, y1 = m.port
    fx, fy, fd = m.fan
    bx, by, bd = m.btn
    cx, cy, cd, cnut = m.chg
    return (_off_plate(px - dx0, py - dy0, dw, dl, dr)
            or _in_rect(px, py, m.type_boxes["deck"], pad)
            or _in_rect(px, py, m.kb, pad) or _in_rect(px, py, m.oled, pad)
            or _in_rect(px, py, (x0, y0, x1 - x0, y1 - y0), pad)
            or _in_circle(px, py, fx, fy, fd / 2, pad)
            or _in_circle(px, py, bx, by, bd / 2 + 3.0, pad)
            or _in_circle(px, py, cx, cy, cnut / 2 + 2.0, pad)
            or any(_in_circle(px, py, sx, sy, 3.7, pad) for sx, sy in m.screws))


def cover_hit(m: Model, px, py, pad=0.0) -> bool:
    """True where the flat cover front is interrupted or reserved for the lettering.

    The entire broad front and the display glass are coplanar at z = 14.50 mm. The 7 mm slate
    border is paint, so it is deliberately NOT a keep-out: graticule marks and rigid-mask slots
    may cross it. Only real apertures (the display opening and cable notch), the part outline and
    the reserved type block interrupt the non-border passes.
    """
    return (_off_plate(px, py, m.w, m.l, m.cover_r)
            or _in_rect(px, py, m.type_boxes["cover"], pad)
            or _in_rect(px, py, m.well, pad) or _in_rect(px, py, m.cable, pad))


# ---------------------------------------------------------------- runs over real face
def runs_clear(test, a: float, b: float, step: float = 1.0) -> list[tuple[float, float]]:
    """Split the interval a..b into runs where `test(t)` is false (no hole, no feature).

    Paint can only be laid where there is plate, so a painted line that meets an aperture has to
    stop.  Drawing the surviving segments explicitly (rather than relying on the clip) keeps the
    sheet honest: what you see is what the mask lets through.
    """
    runs: list[tuple[float, float]] = []
    t = a
    start = None
    while t <= b + 1e-9:
        clear = not test(t)
        if clear and start is None:
            start = t
        elif not clear and start is not None:
            if t - step - start > 0.05:
                runs.append((start, t - step))
            start = None
        t += step
    if start is not None and b - start > 0.05:
        runs.append((start, b))
    return runs


# ---------------------------------------------------------------- branding (shared)
# Both brand blocks are positioned in drawing coordinates (y from the hinge), so they land in
# the same place whether the part is drawn as modelled or hinged above the deck.
def brand_deck(p: Surface, tagline: str, cap: float = 10.5) -> None:
    """Wordmark in the deck's free strip between the OLED and the keyboard (y 72.2 - 102.5)."""
    m = p.m
    x, y = m.w / 2, m.deck_text_y
    p.text("KTEMATA", cap, x, y, AMBER_L, track=cap * 0.28, anchor="middle", group="word")
    half = text_w("KTEMATA", cap, cap * 0.28) / 2
    yr, yt = p.below(y, 3.0), p.below(y, 6.8)
    p.line([(x - half, yr), (x + half, yr)], AMBER, 0.8, opacity=0.9, group="word")
    p.text(tagline, 2.6, x, yt, GREY_L, track=1.5, anchor="middle", group="word")


def brand_cover(p: Surface, cap: float = 10.0) -> None:
    """Motto in the cover's latch band, clear of the display opening."""
    m = p.m
    x, y = m.w / 2, m.cover_text_y
    p.text("κτῆμα ἐς ἀεί", cap, x, y, IVORY, italic=True, anchor="middle", group="word")
    rule = text_w("κτῆμα ἐς ἀεί", cap, 0.0, True) / 2 + 8.0
    yr, yc = p.below(y, 5.2), p.below(y, 9.8)
    p.line([(x - rule, yr), (x + rule, yr)], AMBER, 0.8, opacity=0.85, group="word")
    p.text("KTEMATA  ·  A POSSESSION FOR ALL TIME", 2.4, x, yc, GREY_L,
           track=1.1, anchor="middle", group="word")


# ---------------------------------------------------------------- scheme 1
class Mark:
    """One painted mark: a rounded rectangle, optionally with a rounded hole in it (a ring).

    Rects alone cannot express the painted border: four rects leave sharp slivers at the display
    opening's rounded corners. `inner` makes the ring exact, and both consumers - the colour sheet
    and the cut file - build their geometry from this one object, so they cannot disagree.
    """
    __slots__ = ("x0", "y0", "x1", "y1", "fill", "group", "r", "inner", "opacity")

    def __init__(self, x0, y0, x1, y1, fill, group, r=0.0, inner=None, opacity=None):
        self.x0, self.y0, self.x1, self.y1 = x0, y0, x1, y1
        self.fill, self.group, self.r, self.inner = fill, group, r, inner
        self.opacity = opacity

    def d(self, fy=lambda y: y) -> str:
        ya, yb = fy(self.y0), fy(self.y1)
        out = rrect_d(self.x0, min(ya, yb), self.x1 - self.x0, abs(yb - ya), self.r)
        if self.inner:
            ix0, iy0, ix1, iy1, ir = self.inner
            iya, iyb = fy(iy0), fy(iy1)
            out += " " + rrect_d(ix0, min(iya, iyb), ix1 - ix0, abs(iyb - iya), ir)
        return out

    @property
    def rule(self) -> str | None:
        return "evenodd" if self.inner else None


def meridian_marks(m: Model, cover: bool) -> list[Mark]:
    """MERIDIAN as axis-aligned rectangles: (x0, y0, x1, y1, fill, pass).

    One source for both outputs. The colour sheet renders these rects; the stencil generator cuts
    them. Written as data because every mark in this scheme is a rectangle - a 0.5 mm grid line is
    a 0.5 mm-wide rect - so the cut file and the picture cannot drift apart.

    `pass` names the tape pass a mark belongs to: ash, amber, seam, bezel, word.
    """
    w, l = m.w, m.l
    out: list[Mark] = []
    pitch = l / 10.0
    # a line stops where the plate is cut AND where the lettering is reserved: the type blocks
    # are in type_boxes, and deck_hit/cover_hit already report them
    hit = (lambda x, y: cover_hit(m, x, y, 1.6)) if cover else \
          (lambda x, y: deck_hit(m, x, y, 1.6))

    def hline(y, x0, x1, t, fill, group):
        out.append(Mark(x0, y - t / 2, x1, y + t / 2, fill, group,
                        opacity=0.95 if fill == AMBER else (0.55 if fill == GREY else None)))

    def vline(x, y0, y1, t, fill, group):
        out.append(Mark(x - t / 2, y0, x + t / 2, y1, fill, group,
                        opacity=0.95 if fill == AMBER else (0.55 if fill == GREY else None)))

    # Horizontals are ruled FROM the hinge, so line n is the same distance from the seam on both
    # parts and the grid registers across it.  Verticals use the same pitch, so the cells are
    # square, but are centred on the part: pitched from x = 0 they would stop at 160.3 and leave a
    # 73 mm dead band on the right.  Nothing about a vertical has to line up across the hinge.
    for i in range(1, 10):
        y, strong = i * pitch, i % 5 == 0
        for x0, x1 in runs_clear(lambda x: hit(x, y), 0.0, w):
            hline(y, x0, x1, 0.9 if strong else 0.5,
                  AMBER if strong else GREY, "amber" if strong else "ash")
    k = 1
    while k * pitch < w / 2 - 2.0:
        for x in (w / 2 - k * pitch, w / 2 + k * pitch):
            if 2.0 < x < w - 2.0:
                strong = k % 5 == 0
                for y0, y1 in runs_clear(lambda y: hit(x, y), 0.0, l):
                    vline(x, y0, y1, 0.9 if strong else 0.5,
                          AMBER if strong else GREY, "amber" if strong else "ash")
        k += 1

    # The seam rule and the scale's end stop, identical on both parts.  They are split by the
    # same runs_clear test as the grid: the seam rule at y 2.2 crosses the deck's Pi opening
    # (x 150..203.4, y 0..16), so on the deck it is two pieces, not one.  The colour sheet used to
    # hide that behind its clip while the cut file had the line intact - the cut file is the one
    # that lands on the part, so the marks are what gets split.
    for y0, y1 in ((2.2, 3.9), (l - 8.0, l - 6.8)):
        yc = (y0 + y1) / 2
        for x0, x1 in runs_clear(lambda x: hit(x, yc), 0.0, w):
            out.append(Mark(x0, y0, x1, y1, AMBER_D, "seam"))

    if cover:
        # The 7 mm border is a flat slate paint pass, not a raised wall. Other passes may cross
        # its footprint; this later pass covers them. The display opening remains a real hole.
        wx, wy, ww, wh, wr = m.well
        fr = m.frame
        # one ring mark, not four rects: the inner edge has to follow the well's corner radii or
        # the corners come out as sharp slivers
        out.append(Mark(wx - fr, wy - fr, wx + ww + fr, wy + wh + fr, SLATE, "bezel",
                        r=wr + fr, inner=(wx, wy, wx + ww, wy + wh, wr)))
    return out


def scheme_meridian(p: Surface, cover: bool) -> None:
    """MERIDIAN - a chart graticule, ruled from the hinge; one amber seam line."""
    m = p.m
    x0, y0, bw, bl, br = part_box(m, cover)
    p.rect(x0, y0, bw, bl, BASE, br)
    for mk in meridian_marks(m, cover):
        p.path(mk.d(p.y), mk.fill, rule=mk.rule, opacity=mk.opacity, group=mk.group)
    if cover:
        brand_cover(p, m.cover_cap)
    else:
        brand_deck(p, "OFFLINE  LIBRARY", 10.5)


# ---------------------------------------------------------------- scheme 2
def strata_marks(m: Model, cover: bool) -> list[Mark]:
    """STRATA as rectangles shared by the colour sheet and both stencil outputs."""
    w, l = m.w, m.l
    out: list[Mark] = []
    # 32 mm of bands per rail: inside the deck's 40.95 mm rail, but wider than the cover margin
    # outside Meridian's 7 mm border datum. The cover front is flat, so the bands continue across
    # that datum; only the actual display opening and other apertures clip them. The innermost
    # 4 mm is base coat, so it has no stencil pass.
    bands = [(8.0, AMBER_D, "deep_amber"), (5.0, SLATE, "slate"),
             (12.0, AMBER, "amber"), (3.0, GREY, "ash"), (4.0, BASE, "base")]
    for mirror in (False, True):
        x = 0.0
        for width, colour, group in bands:
            left = w - x - width if mirror else x
            out.append(Mark(left, 0.0, left + width, l, colour, group))
            x += width
    for edge in (8.0, w - 8.0):
        out.append(Mark(edge - 0.3, 0.0, edge + 0.3, l, AMBER_L, "hairline", opacity=0.85))

    # Latch band: the U closed, 2.6 mm deep amber, full width, with a graphite shadow.
    out.append(Mark(0.0, 2.6, w, 5.2, AMBER_D, "deep_amber"))
    out.append(Mark(0.0, 5.2, w, 5.8, INK, "ink", opacity=0.7))
    return out


def scheme_strata(p: Surface, cover: bool) -> None:
    """STRATA - five bands in the side rails, keyed to x so they cross the hinge dead straight."""
    m = p.m
    w, l = m.w, m.l
    x0, y0, bw, bl, br = part_box(m, cover)
    p.rect(x0, y0, bw, bl, BASE, br)
    for mk in strata_marks(m, cover):
        p.path(mk.d(p.y), mk.fill, rule=mk.rule, opacity=mk.opacity, group=mk.group)
    if cover:
        brand_cover(p, m.cover_cap)
    else:
        brand_deck(p, "A  POSSESSION  FOR  ALL  TIME", 10.5)
        p.text("r5", 2.8, w / 2, l - 6.5, GREY, track=1.4, anchor="middle")


# ---------------------------------------------------------------- scheme 3
def scheme_bearing(p: Surface, cover: bool) -> None:
    """BEARING - slate border, chart dots, and one amber trace that leaves the hinge."""
    m = p.m
    w, l = m.w, m.l
    x0, y0, bw, bl, r = part_box(m, cover)
    p.rect(x0, y0, bw, bl, BASE, r)

    # the field: within 34 mm of the edge, one even-odd path - no clipping needed.  The trace at
    # x = 215.5 lies inside this border (the field ends at 199.5), so the amber sits on slate.
    e = 34.0
    p.path(p.rrect(0, 0, w, l, r) + " " + p.rrect(e, e, w - 2 * e, l - 2 * e, max(2.0, r - 24)),
           SLATE, rule="evenodd")

    # chart dots on the same 17.81 mm grid the other two schemes are ruled with, skipping the
    # middle of the part so the wordmark and the field stay quiet
    pitch = l / 10.0
    for gx in np.arange(pitch / 2, w, pitch):
        for gy in np.arange(pitch / 2, l, pitch):
            if math.hypot(gx - w / 2, gy - l / 2) < 52:
                continue
            if cover and cover_hit(m, gx, gy, 2.5):
                continue
            if not cover and deck_hit(m, gx, gy, 2.5):
                continue
            p.circle(float(gx), float(gy), 0.55, GREY_L, opacity=0.7)

    # One lane, both parts, free along its whole length. x = 215.5, checked against the model:
    #   deck  - 10.6 mm clear of the Pi opening (ends 203.4), 13.0 of the hinge screw head
    #           (207.5 + 3.1), 9.9 of the screw at 228.4;
    #   cover - just right of the display opening; the painted border is no obstacle.
    # The hinge gateway must also clear the plate's 14 mm corner radius, whose tangent is at
    # x = 219.5: an 8 mm square centred here ends on that tangent, so no corner is shaved off.
    tx = 215.5
    fx, fy, fd = m.fan
    if cover:
        # The flat painted display border carries the same slate as the outer border, so the
        # cover reads as a frame round a screen without adding a second height.
        wx, wy, ww, wh, wr = m.well
        fr = m.frame
        p.path(p.rrect(wx - fr, wy - fr, ww + 2 * fr, wh + 2 * fr, wr + fr)
               + " " + p.rrect(wx, wy, ww, wh, wr), SLATE, rule="evenodd")
    # the trace runs the same length on both parts and ends in the same port ring, so the two
    # legs are a mirror image across the seam and read as one run when the case lies open
    end = 152.0
    p.line([(tx, 0.0), (tx, end)], AMBER, 3.0, cap="butt")
    p.circle(tx, end, 7.4, "none", stroke=AMBER, sw=2.6)
    # hinge gateway: one 8 mm square straddling the seam, identical on both parts, so when the
    # case is open the two halves make a single 16 mm port that the trace enters and leaves
    p.rect(tx - 4.0, 0.0, 8.0, 8.0, AMBER)

    if cover:
        brand_cover(p, m.cover_cap)
    else:
        brand_deck(p, "OFFLINE  LIBRARY", 10.5)


SCHEMES = [
    dict(
        slug="1_meridian", name="MERIDIAN", sub="a chart graticule ruled from the hinge",
        draw=scheme_meridian,
        palette=[(BASE, "graphite"), (AMBER, "amber rules"), (AMBER_L, "long ticks"),
                 (GREY_L, "short ticks"), (SLATE, "slate border")],
        steps=[
            "1  400-grit scuff, adhesion promoter, graphite base over the whole face",
            "2  tape the 0.5 mm graticule at 17.81 mm pitch, every fifth line  ->  ash",
            "3  re-mask the fifth lines and the two end rules  ->  amber",
            "4  mask the flat 7 mm cover border  ->  slate",
            "5  unmask, matte 2K clear over everything",
            "6  lay the two printed stickers last, on the plate the mask reserved",
        ],
        note="Continuity: the graticule is laid out from the hinge at L/10 = 17.81 mm pitch on both "
             "parts, so line n is the same distance from the seam on either half and the chart "
             "runs on across it. Every fifth line and the two end rules are amber, the rest ash. "
             "Each line is drawn only where there is plate: measured against the model, the grid "
             "meets the Pi opening, the fan, the keyboard well, the display opening and the screw "
             "heads, and stops dead at each. On the flat cover the graticule may cross the painted "
             "border; the later slate pass covers it there. Actual apertures and reserved type "
             "still stop every line. Nothing is touched up by hand, so the grid reads as one chart "
             "with holes punched through it rather than as a pattern that gives up.",
    ),
    dict(
        slug="2_strata", name="STRATA", sub="five bands in the rails, all the way past the seam",
        draw=scheme_strata,
        palette=[(BASE, "graphite"), (AMBER_D, "deep amber"), (SLATE, "slate"),
                 (AMBER, "amber"), (GREY, "ash")],
        steps=[
            "1  graphite base over the whole face",
            "2  mask both 32 mm rails; lay the five bands from the edge inwards",
            "3  0.6 mm hairline between amber and slate  ->  light amber",
            "4  latch band 2.6 mm at y 2.6, full width  ->  deep amber",
            "5  stencil wordmark and motto; matte 2K clear, lettering last",
        ],
        note="Continuity: the stack is keyed to x, not to y, so each rail runs dead straight from the "
             "cover into the deck and the U closes across the hinge. 32 mm of bands fills the deck's "
             "40.95 mm rail and extends inboard of the cover's 7 mm painted-border datum. That "
             "border is not a raised ring, so the flat cover bands are clipped only by real "
             "apertures. This is the selected scheme; its SVG and printable STL stencils use the "
             "same rectangular marks as this sheet.",
    ),
    dict(
        slug="3_bearing", name="BEARING", sub="a slate border and one amber trace through the seam",
        draw=scheme_bearing,
        palette=[(BASE, "graphite"), (SLATE, "slate border"), (AMBER, "trace"),
                 (AMBER_L, "wordmark"), (IVORY, "motto")],
        steps=[
            "1  mask the 30 mm border and spray slate; graphite centre last",
            "2  chart dots, 0.55 mm, on the 17.81 mm grid  ->  light grey",
            "3  mask trace, gateway square, port ring  ->  amber",
            "4  stencil KTEMATA and the motto",
            "5  matte 2K clear over everything except the lettering",
        ],
        note="Continuity: one lane at x = 215.5. The two panels share an x axis, so the trace is a "
             "single 3 mm line that runs from a port ring in the cover, through an 8 mm gateway "
             "square on the hinge, to a second port ring in the deck. The lane was chosen by "
             "measurement, not by eye: on the deck it clears the Pi opening (ends 203.4), the hinge "
             "screw head at 207.5 and the screw at 228.4; on the cover it runs just right of the "
             "display opening and straight across the flat painted border. The well also takes the "
             "border's hinge band on the cover, so the border there survives only in the two side "
             "margins: the trace, not the border, is what crosses the seam.",
    ),
]


# ---------------------------------------------------------------- printed features (overlay)
def deck_features(p: Surface) -> None:
    m = p.m
    kx, ky, kw, kh, kr = m.kb
    p.rect(kx, ky, kw, kh, INK, kr, layer="features", stroke="#48545f", sw=1.0)
    p.rect(kx + 2.0, ky + 2.0, kw - 4.0, kh - 4.0, "#0e141a", kr - 1.6,
           layer="features", stroke="#2b353e", sw=0.6)
    for i in range(5):
        p.rect(kx + 4.0, ky + 4.0 + i * 10.2, kw - 8.0, 7.4, "#1a222a", 1.1, layer="features")
    p.text("K06  ·  SUNK 11 mm", 2.6, kx + kw / 2, ky + kh / 2 + 1.0, LABEL,
           layer="features", track=1.4, anchor="middle")

    ox, oy, ow, oh = m.oled
    p.rect(ox, oy, ow, oh, INK, 0.8, layer="features", stroke="#48545f", sw=0.8)
    p.text("OLED", 2.0, ox + ow / 2, oy + oh / 2 + 0.7, LABEL, layer="features", anchor="middle")

    fx, fy, fd = m.fan
    p.circle(fx, fy, fd / 2, INK, layer="features", stroke="#48545f", sw=1.0)
    for b in range(m.fan_bars):
        off = (b - (m.fan_bars - 1) / 2) * (fd / (m.fan_bars + 0.5))
        half = math.sqrt(max(0.0, (fd / 2) ** 2 - off ** 2)) + 1.5
        p.rect(fx - half, fy + off - m.fan_bar / 2, 2 * half, m.fan_bar, "#232c34",
               layer="features")
    for dx in (-16, 16):
        for dy in (-16, 16):
            p.circle(fx + dx, fy + dy, 1.7, INK, layer="features", stroke="#43505b", sw=0.5)


    # the opening runs from the PLATE's hinge edge (negative), not the tray's y = 0
    x0, y0, x1, y1 = m.port
    p.rect(x0, y0, x1 - x0, y1 - y0, INK, layer="features")
    p.line([(x0, y1), (x1, y1)], "#48545f", 0.9, layer="features")
    p.line([(x0, y0), (x0, y1)], "#48545f", 0.9, layer="features")
    p.line([(x1, y0), (x1, y1)], "#48545f", 0.9, layer="features")
    p.text("PI  ·  USB-C  HDMI ×2  DSI", 2.1, (x0 + x1) / 2, 11.0, LABEL,
           layer="features", anchor="middle")

    for sx, sy in m.screws:
        p.circle(sx, sy, 3.1, "#151d25", layer="features", stroke="#48545f", sw=0.6)
        p.circle(sx, sy, 1.7, INK, layer="features")

    # 16 mm IP67 power button, moved off the lid when the panel grew to 7"
    bx, by, bd = m.btn
    p.circle(bx, by, bd / 2 + 3.4, "none", layer="features", stroke="#48545f", sw=0.8)
    p.circle(bx, by, bd / 2, "#111820", layer="features", stroke="#6a7784", sw=1.0)
    p.circle(bx, by, bd / 2 - 2.0, "none", layer="features", stroke=AMBER_D, sw=1.2)
    p.text("POWER", 1.9, bx, by + bd / 2 + 6.0, LABEL, layer="features",
           track=0.9, anchor="middle")

    # 8.4 V charge socket: the host is never drilled, so it sits on the deck's right rail
    cx, cy, cd, cnut = m.chg
    p.circle(cx, cy, cnut / 2, "none", layer="features", stroke="#48545f", sw=0.8)
    p.circle(cx, cy, cd / 2, "#111820", layer="features", stroke="#6a7784", sw=0.9)
    p.text("CHARGE  8.4 V", 1.9, cx, cy - cnut / 2 - 5.0, LABEL,
           layer="features", track=0.8, anchor="middle")



def cover_features(p: Surface) -> None:
    m = p.m
    wx, wy, ww, wh, wr = m.well
    p.rect(wx, wy, ww, wh, "#06090c", wr, layer="features", stroke="#48545f", sw=1.0)
    px, py, pw, ph, pr = m.panel
    p.rect(px, py, pw, ph, "#0a0f14", pr, layer="features", stroke="#333f4a", sw=0.9)
    aw, ah = m.active
    p.rect(px + (pw - aw) / 2, py + (ph - ah) / 2, aw, ah, "none", 0.8,
           layer="features", stroke="#2b353e", sw=0.6, dash="3 2")
    p.text("WAVESHARE  DSI  LCD  (C)  ·  7\"", 2.8, m.w / 2, py + ph / 2 - 3.4, LABEL,
           layer="features", track=1.5, anchor="middle")
    p.text(f"{f(pw)} × {f(ph)}  ·  image {f(aw)} × {f(ah)}", 2.1, m.w / 2,
           py + ph / 2 + 3.0, LABEL, layer="features", anchor="middle")
    # the panel line, inside the well: the one place on this part that is never painted
    p.text(f"WELL {f(ww)} × {f(wh)}   ·   BEZEL {f(m.frame)}   ·   POWER ON THE DECK",
           1.9, m.w / 2, py + ph / 2 + 9.0, LABEL, layer="features", track=0.5,
           anchor="middle")

    cx, cy, cw, ch = m.cable
    p.rect(cx, cy, cw, ch, INK, layer="features")
    p.line([(cx, cy + ch), (cx + cw, cy + ch)], "#48545f", 0.8, layer="features")
    p.text("DSI", 1.8, cx + 6.5, cy + ch / 2 + 0.7, LABEL, layer="features", anchor="middle")



# ---------------------------------------------------------------- sheet
M = 20.0
GAP = 40.0
TITLE = 54.0
NOTES = 112.0


def sheet(model: Model, sc: dict, path: Path, preview: bool) -> tuple[Path, Path | None]:
    w, l = model.w, model.l
    dw, dl = model.deck[2], model.deck[3]
    sw = 2 * M + max(w, dw)
    # the deck's plate is bigger than the cover's, and it is drawn in the cassette frame, so the
    # sheet has to hold the plate's own bottom edge (y0 + l below the cassette origin)
    deck_bottom = model.deck[1] + dl
    sh = M - 6 + TITLE + l + GAP + deck_bottom + NOTES + M

    cover, deck = Surface(model, flipped=True), Surface(model)
    sc["draw"](cover, True)
    sc["draw"](deck, False)
    cover_features(cover)
    deck_features(deck)

    elems: list[str] = [f'<rect x="0" y="0" width="{f(sw)}" height="{f(sh)}" fill="{PAPER}"/>']
    elems.append(tspan("KTEMATA  ·  r5   PAINT", 3.4, M, M + 4.0, PAPER_MUTED, track=2.4))
    elems.append(tspan(sc["name"], 11.5, M, M + 17.0, PAPER_INK, track=3.0))
    elems.append(tspan(sc["sub"], 3.6, M, M + 24.6, PAPER_MUTED, italic=True))
    elems.append(tspan("open flat: the lid cover above the hinge, the deck below   ·   both share "
                       "one x axis, both are measured from the hinge", 2.7, M, M + 31.4,
                       PAPER_MUTED, italic=True))
    elems.append(tspan("scale 1:1  ·  millimetres  ·  y = 0 at the hinge, on both parts", 2.7,
                       sw - M, M + 4.0, PAPER_MUTED, anchor="end"))
    elems.append(f'<line x1="{f(M)}" y1="{f(M + 37.0)}" x2="{f(sw - M)}" '
                 f'y2="{f(M + 37.0)}" stroke="{PAPER_INK}" stroke-width="0.4"/>')

    y_cover = M + TITLE
    y_deck = y_cover + l + GAP
    hinge_y = y_cover + l + GAP / 2
    clip_defs: list[str] = []

    def emit(surf: Surface, top: float, box: tuple[float, ...], ident: str,
             holes: list[str], flip: bool) -> None:
        # outer outline + every aperture, even-odd: this is the physical mask. A painted line
        # that runs into the fan or the power button stops there, the way tape would stop it.
        x0, y0, bw, bl, br = box
        clip_defs.append(f'<clipPath id="{ident}" clipPathUnits="userSpaceOnUse">'
                         f'<path d="{rrect_d(x0, y0, bw, bl, br)} {" ".join(holes)}" '
                         f'fill-rule="evenodd"/></clipPath>')
        # flipping is already in the coordinates (Surface.y), so this is a plain translation
        place = f'translate({f(M)} {f(top)})'
        assert flip == surf.flipped
        elems.append(f'<g transform="{place}">'
                     f'<g clip-path="url(#{ident})">' + "".join(surf.paint) + "</g>"
                     + "".join(surf.features)
                     + f'<path d="{rrect_d(x0, y0, bw, bl, br)}" fill="none" '
                       f'stroke="#3b4650" stroke-width="0.8"/></g>')

    emit(cover, y_cover, (0, 0, w, l, model.cover_r), "coverclip",
         cover_holes_d(model), True)
    emit(deck, y_deck, model.deck, "deckclip", deck_holes_d(model), False)
    elems.insert(1, "<defs>" + "".join(clip_defs) + "</defs>")

    # the hinge line: the continuity datum
    elems.append(f'<line x1="{f(M + min(0, model.deck[0]) - 9)}" y1="{f(hinge_y)}" '
                 f'x2="{f(M + max(w, dw) + 9)}" y2="{f(hinge_y)}" stroke="{PAPER_INK}" '
                 f'stroke-width="0.5" stroke-dasharray="6 3"/>')
    elems.append(tspan("HINGE  ·  the pattern crosses this line", 2.6, M + w / 2, hinge_y - 3.4,
                       PAPER_MUTED, track=1.3, anchor="middle"))

    elems.append(tspan("LID COVER  ·  front face", 3.0, M, y_cover - 5.0, PAPER_MUTED,
                       track=1.3))
    elems.append(tspan(f"{f(w)} × {f(l)} mm", 2.6, M + w, y_cover - 5.0, PAPER_MUTED,
                       anchor="end"))
    elems.append(tspan("DECK  ·  top face", 3.0, M, hinge_y + 9.0, PAPER_MUTED, track=1.3))
    elems.append(tspan(f"{f(dw)} × {f(dl)} mm", 2.6, M + dw + model.deck[0], hinge_y + 9.0,
                       PAPER_MUTED, anchor="end"))
    for top, (x0, y0, bw, bl, _r) in ((y_cover, (0, 0, w, l, model.cover_r)),
                                      (y_deck, model.deck)):
        for cx, cy, dx, dy in ((M + x0, top + y0, -1, -1), (M + x0 + bw, top + y0, 1, -1),
                               (M + x0, top + y0 + bl, -1, 1),
                               (M + x0 + bw, top + y0 + bl, 1, 1)):
            elems.append(f'<path d="M{f(cx + dx * 6)} {f(cy)} H{f(cx)} V{f(cy + dy * 6)}" '
                         f'fill="none" stroke="{PAPER_INK}" stroke-width="0.3" opacity="0.5"/>')

    # notes
    ny = y_deck + deck_bottom + 26.0
    elems.append(f'<line x1="{f(M)}" y1="{f(ny - 8)}" x2="{f(sw - M)}" y2="{f(ny - 8)}" '
                 f'stroke="{PAPER_INK}" stroke-width="0.35" opacity="0.5"/>')
    elems.append(tspan("PALETTE", 2.6, M, ny, PAPER_MUTED, track=1.8))
    cx = M
    for colour, name in sc["palette"]:
        elems.append(f'<rect x="{f(cx)}" y="{f(ny + 3.0)}" width="13" height="6.5" rx="1" '
                     f'fill="{colour}" stroke="{PAPER_INK}" stroke-width="0.25"/>')
        elems.append(tspan(name, 2.2, cx, ny + 14.0, PAPER_MUTED))
        elems.append(tspan(colour.upper(), 1.8, cx, ny + 17.4, PAPER_MUTED, opacity=0.7))
        cx += 29.0

    elems.append(tspan("MASK ORDER", 2.6, M, ny + 26.0, PAPER_MUTED, track=1.8))
    for i, step in enumerate(sc["steps"]):
        elems.append(tspan(step, 2.4, M, ny + 32.6 + i * 4.8, PAPER_INK))

    tx = M + 132.0
    col = sw - M - tx
    elems.append(tspan("ONE CONTINUOUS SURFACE", 2.6, tx, ny, PAPER_MUTED, track=1.8))
    lines = _wrap_mm(sc["note"], col, 2.4)
    for i, line in enumerate(lines):
        elems.append(tspan(line, 2.4, tx, ny + 6.6 + i * 4.6, PAPER_INK))
    elems.append(tspan("Grey labels name printed features; they are not painted.", 2.2,
                       tx, ny + 6.6 + len(lines) * 4.6 + 2.0, PAPER_MUTED, italic=True))
    # notes height is derived from the longest column, so a longer note can never be clipped
    need = ny + 6.6 + len(lines) * 4.6 + 8.0
    assert sh >= need + M, f"the sheet is {sh - M - need:.1f} mm too short for the notes"

    bx = sw - M - 50.0
    by = sh - M + 4.0
    for i in range(5):
        elems.append(f'<rect x="{f(bx + i * 10)}" y="{f(by - 2.2)}" width="10" height="2.2" '
                     f'fill="{PAPER_INK if i % 2 == 0 else PAPER}"/>')
    elems.append(f'<rect x="{f(bx)}" y="{f(by - 2.2)}" width="50" height="2.2" fill="none" '
                 f'stroke="{PAPER_INK}" stroke-width="0.3"/>')
    elems.append(tspan("50 mm", 2.4, bx + 25, by - 3.4, PAPER_MUTED, anchor="middle"))

    head = (f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{f(sw)}mm" height="{f(sh)}mm" '
            f'viewBox="0 0 {f(sw)} {f(sh)}">\n'
            f'<title>Ktemata r5 airbrush scheme - {sc["name"]}</title>\n'
            f'<desc>{_esc(sc["note"])}</desc>\n')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(head + "\n".join(elems) + "\n</svg>\n", encoding="utf-8")

    png = None
    if preview:
        png = path.with_suffix(".png")
        subprocess.run(["rsvg-convert", "-w", "1500", "-o", str(png), str(path)], check=True)
    return path, png


def _wrap_mm(text: str, width: float, cap: float) -> list[str]:
    """Wrap to a measured width in millimetres, so the notes fit their column exactly."""
    words, lines, cur = text.split(), [], ""
    for word in words:
        trial = f"{cur} {word}".strip()
        if cur and text_w(trial, cap) > width:
            lines.append(cur)
            cur = word
        else:
            cur = trial
    if cur:
        lines.append(cur)
    return lines


def _esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def contact(pngs: list[Path], path: Path) -> None:
    ims = [Image.open(p).convert("RGB") for p in pngs]
    gap = 22
    cw = max(i.width for i in ims)
    ch = max(i.height for i in ims)
    out = Image.new("RGB", (len(ims) * (cw + gap) + gap, ch + 2 * gap), "#efe9de")
    for i, im in enumerate(ims):
        out.paste(im, (gap + i * (cw + gap), gap))
    out.save(path)


# ---------------------------------------------------------------- stencils
# A mask is the inverse of the paint: you cut away what gets sprayed. So each stencil is the part
# outline with the marks of ONE pass removed, plus registration holes on a common datum so the
# passes stack up. The colour sheet and these cut files come from the same mark data.
MERIDIAN_STENCIL_PASSES = [
    ("ash", "ASH", "0.5 mm graticule, the short rules"),
    ("amber", "AMBER", "0.9 mm graticule, every fifth rule"),
    ("seam", "DEEP AMBER", "seam rule at the hinge, end stop at the latch edge"),
    ("bezel", "SLATE", "flat 7 mm painted border (lid cover only)"),
]
STRATA_STENCIL_PASSES = [
    ("deep_amber", "DEEP AMBER", "8 mm outer rails and 2.6 mm latch band"),
    ("slate", "SLATE", "5 mm rail bands"),
    ("amber", "AMBER", "12 mm rail bands"),
    ("ash", "ASH", "3 mm rail bands"),
    ("hairline", "LIGHT AMBER", "0.6 mm rail hairlines"),
    ("ink", "GRAPHITE SHADOW", "0.6 mm latch shadow"),
]
SELECTED_SCHEME = 2
STENCIL_SCHEMES = {
    1: ("MERIDIAN", meridian_marks, MERIDIAN_STENCIL_PASSES),
    2: ("STRATA", strata_marks, STRATA_STENCIL_PASSES),
}


def stencil_spec(scheme: int = SELECTED_SCHEME):
    """Display name, mark source and paint passes for one stencil-capable scheme."""
    if scheme not in STENCIL_SCHEMES:
        raise ValueError("stencils are available for Meridian (1) and Strata (2), not Bearing (3)")
    return STENCIL_SCHEMES[scheme]


def stencil(model: Model, cover: bool, group: str, path: Path, preview: bool,
            scheme: int = SELECTED_SCHEME) -> Path:
    """One cut file: the mask for ONE paint pass.

    Black is the material you keep and lay on the part; white is what the blade removes - the
    waste, the apertures, and the slots paint passes through.  One file per pass, because each
    colour is a separate masking: spray ash, lift, re-mask, cut amber, and so on.  Registration
    crosses sit in the handling margin so the passes stack on the same datum without putting a
    hole in the mask itself.
    """
    if cover:
        x0, y0, w, l, r = 0.0, 0.0, model.w, model.l, model.cover_r
    else:
        x0, y0, w, l, r = model.deck          # the deck's plate, larger than the cassette
    pad = 14.0
    sw, sh = 2 * pad + w, 2 * pad + l + 28.0

    scheme_name, mark_fn, passes = stencil_spec(scheme)
    marks = [mk for mk in mark_fn(model, cover) if mk.group == group]
    holes = cover_holes_d(model) if cover else deck_holes_d(model)
    # the cover is drawn mirrored y, exactly as on the colour sheet, so a mask cut from this file
    # lands the same way round
    fy = (lambda y: l - y) if cover else (lambda y: y)

    title, blurb = next((n, b) for g, n, b in passes if g == group)
    elems = [f'<rect x="0" y="0" width="{f(sw)}" height="{f(sh)}" fill="{PAPER}"/>']
    # Printed as black-on-white, which is how a stencil sheet is read and cut.  It is deliberately
    # NOT one boolean path: an even-odd union of an outline, a ring and its hole re-fills the ring
    # interior, because even-odd counts every subpath crossing.  Black is laid out first, the
    # cut-outs are painted over it, and the whole thing is clipped to the part outline so a mark
    # that runs past the edge cannot leak outside the mask.
    # the deck's outline sits at (x0, y0) in the cassette frame, so the whole group is shifted to
    # put it on the paper at (pad, pad); the cover's outline is already at the origin
    elems.append(f'<defs><clipPath id="part" clipPathUnits="userSpaceOnUse">'
                 f'<path d="{rrect_d(x0, y0, w, l, r)}"/></clipPath></defs>')
    elems.append(f'<g transform="translate({f(pad - x0)} {f(pad - y0)})">'
                 f'<path d="{rrect_d(x0, y0, w, l, r)}" fill="{PAPER_INK}"/>'
                 f'<g clip-path="url(#part)">'
                 + "".join(f'<path d="{mk.d(fy)}" fill="{PAPER}" fill-rule="evenodd"/>'
                           for mk in marks)
                 + "".join(f'<path d="{h}" fill="{PAPER}"/>' for h in holes)
                 + "</g></g>")

    # The part outline is the datum, so registration crosses sit in the margin beyond the top and
    # bottom edges where paper is plain - not on the mask, where they would be invisible against
    # black and a hole in the sheet besides.
    def cross(cx: float, cy: float) -> str:
        return (f'<path d="M{f(cx - 4.5)} {f(cy)} H{f(cx + 4.5)} M{f(cx)} {f(cy - 4.5)} '
                f'V{f(cy + 4.5)}" fill="none" stroke="{PAPER_INK}" stroke-width="0.3"/>')
    # in the left and right margins, at mid height: the top and bottom margins carry the title
    # and the caption, and a cross there collides with the type
    for cx in (pad / 2, sw - pad / 2):
        elems.append(cross(cx, pad + l / 2))

    elems.append(tspan(f"{scheme_name}  ·  STENCIL  {title}  ·  {'LID COVER' if cover else 'DECK'}",
                       3.2, pad, pad - 9.0, PAPER_INK, track=1.4))
    elems.append(tspan(f"{blurb}   ·   cut 1:1, {f(w)} × {f(l)} mm", 2.4, pad,
                       pad + l + 15.0, PAPER_MUTED))
    elems.append(tspan("black = lay on the part   ·   white = cut away", 2.4, pad,
                       pad + l + 19.4, PAPER_MUTED))
    elems.append(tspan("crosses = registration   ·   KTEMATA r5", 2.4, sw - pad,
                       pad + l + 15.0, PAPER_MUTED, anchor="end"))

    head = (f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{f(sw)}mm" height="{f(sh)}mm" '
            f'viewBox="0 0 {f(sw)} {f(sh)}">\n'
            f'<title>{scheme_name.title()} stencil - {"lid cover" if cover else "deck"} - {title}</title>\n')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(head + "\n".join(elems) + "\n</svg>\n", encoding="utf-8")
    if preview:
        subprocess.run(["rsvg-convert", "-w", "1100", "-o", str(path.with_suffix(".png")),
                        str(path)], check=True)
    return path


# ---------------------------------------------------------------- stickers
# The two type blocks are hand-stencilled elsewhere, and 2.4 mm lettering through a hand-cut mask
# is the hardest thing in the whole scheme: a 0.3 mm stroke will not survive a blade, and a
# slipped stencil cannot be touched up without showing. So they can instead be printed as two
# vinyl stickers, one per block, laid on the plate the mask already reserved - which is why
# sticker_trim() and the model's type_boxes come from the same spec.
#
# A file that reproduces the design AND can be die-cut is a rectangle: the tagline's 0.3 mm
# strokes are far below what a contour cut can hold, so the lettering needs a background patch to
# be handled. The patch is printed in the scheme's own graphite, so under matte laminate and the
# 2K clear it reads as a small brand plate rather than as a white label.


def sticker(model: Model, spec: dict, path: Path, preview: bool) -> tuple[Path, Path | None]:
    """One sticker file: 1:1 artwork with bleed, and deliberately no cut line.

    The printer uploads artwork only and adds the contour themselves - a cut line in the file is
    rejected. The trim size therefore lives in the file name, the <title> and PAINT.md, because
    that is what the order form asks for.
    """
    bx0, by0, bx1, by1 = _sticker_box(spec)
    tw, th = sticker_trim(spec["side"], spec["lines"][0][1])
    fw, fh = tw + 2 * STICKER_BLEED, th + 2 * STICKER_BLEED
    # block coords -> file coords: the ink is centred in the trim, so the margin is symmetric even
    # where the 0.1 mm round-up gives a little more than STICKER_MARGIN on one axis
    ox = STICKER_BLEED + (tw - (bx1 - bx0)) / 2 - bx0
    oy = STICKER_BLEED + (th - (by1 - by0)) / 2 - by0
    cx = fw / 2

    elems = [f'<rect x="0" y="0" width="{f(fw)}" height="{f(fh)}" fill="{BASE}"/>']
    for text, cap, track, italic, fill, dy in spec["lines"]:
        d, width = _text_path(text, cap, italic, track)
        elems.append(f'<path d="{d}" fill="{fill}" fill-rule="nonzero" '
                     f'transform="translate({f(cx - width / 2)} {f(oy + dy)})"/>')
    dy, half, fill, sw = spec["rule"]
    elems.append(f'<rect x="{f(cx - half)}" y="{f(oy + dy - sw / 2)}" '
                 f'width="{f(2 * half)}" height="{f(sw)}" fill="{fill}"/>')

    trim = f"{f(tw)} × {f(th)} mm"
    head = (f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{f(fw)}mm" height="{f(fh)}mm" '
            f'viewBox="0 0 {f(fw)} {f(fh)}">\n'
            f'<title>Ktemata r5 Meridian - {spec["note"]} sticker, trim {trim}, '
            f'bleed {f(STICKER_BLEED)} mm</title>\n'
            f'<desc>1:1 vector artwork, RGB, lettering already converted to outlines. '
            f'No cut line and no crop marks: contour-cut to {trim} centred, i.e. '
            f'{f(STICKER_BLEED)} mm inside the artwork on every side. Matte laminate.</desc>\n')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(head + "\n".join(elems) + "\n</svg>\n", encoding="utf-8")

    # PDF is what gets uploaded: vector, sharp at any size, and not the rejected PDF 1.4
    pdf = path.with_suffix(".pdf")
    subprocess.run(["rsvg-convert", "-f", "pdf1.7", "-o", str(pdf), str(path)], check=True)
    png = None
    if preview:
        png = path.with_suffix(".png")
        subprocess.run(["rsvg-convert", "-w", "1400", "--background-color", PAPER, "-o",
                        str(png), str(path)], check=True)
    return pdf, png


# ---------------------------------------------------------------- main
def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--scheme", type=int, choices=(1, 2, 3), help="only this scheme")
    ap.add_argument("--no-png", action="store_true", help="skip the raster previews")
    ap.add_argument("--stencils", action="store_true",
                    help="also cut the selected scheme (default STRATA) into one mask per paint pass")
    ap.add_argument("--stickers", action="store_true",
                    help="also write the two MERIDIAN type blocks as print-ready sticker files")
    args = ap.parse_args()

    model = Model(probe())
    chosen = [SCHEMES[args.scheme - 1]] if args.scheme else SCHEMES
    pngs: list[Path] = []
    for sc in chosen:
        svg = OUT / f"ktemata_paint_{sc['slug']}.svg"
        _, png = sheet(model, sc, svg, not args.no_png)
        print(f"{sc['name']:<9} {svg.relative_to(REPO)}" + (f"   +   {png.name}" if png else ""))
        if png:
            pngs.append(png)
    if len(pngs) > 1:
        contact(pngs, OUT / "ktemata_paint_all.png")
        print(f"{'contact':<9} {(OUT / 'ktemata_paint_all.png').relative_to(REPO)}")

    if args.stencils:
        scheme = args.scheme or SELECTED_SCHEME
        try:
            scheme_name, mark_fn, passes = stencil_spec(scheme)
        except ValueError as exc:
            ap.error(str(exc))
        for cover, side in ((False, "deck"), (True, "cover")):
            for group, name, _b in passes:
                if not any(mk.group == group for mk in mark_fn(model, cover)):
                    continue
                out = OUT / f"ktemata_stencil_{side}_{group}.svg"
                stencil(model, cover, group, out, not args.no_png, scheme)
                print(f"{'stencil':<9} {out.relative_to(REPO)}")

    if args.stickers:
        # one file per block, named with its trim size because the order form asks for it and a
        # file with a cut line in it is rejected outright
        for spec in sticker_specs(model.cover_cap):
            tw, th = sticker_trim(spec["side"], spec["lines"][0][1])
            stem = (f"ktemata_sticker_{spec['side']}_{spec['name']}"
                    f"_{f(tw)}x{f(th)}mm")
            out = OUT / f"{stem}_bleed.svg"
            pdf, png = sticker(model, spec, out, not args.no_png)
            print(f"{'sticker':<9} {pdf.relative_to(REPO)}   ({f(tw)} × {f(th)} mm trim)"
                  + (f"   +   {png.name}" if png else ""))


if __name__ == "__main__":
    main()

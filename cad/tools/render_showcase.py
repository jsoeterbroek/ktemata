#!/usr/bin/env python3
"""Render the open yellow r5 website showcase from the real CAD and Strata paint data."""

import argparse
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))
import paint  # noqa: E402


def mark_array(marks: list[paint.Mark]) -> str:
    return json.dumps([[m.x0, m.y0, m.x1, m.y1, m.fill] for m in marks])


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output", type=Path,
                    default=REPO / "renders" / "r5" / "site_r5_showcase.png")
    ap.add_argument("--camera", default="0,0,0,45,0,215,0")
    ap.add_argument("--imgsize", default="1800,1400")
    args = ap.parse_args()

    model = paint.Model(paint.probe())
    deck = mark_array(paint.strata_marks(model, False))
    cover = mark_array(paint.strata_marks(model, True))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        "openscad", "-o", str(args.output), "--render", f"--imgsize={args.imgsize}",
        "--colorscheme=Tomorrow", f"--camera={args.camera}", "--viewall", "--autocenter",
        "-D", "R5=true", "-D", f"STRATA_DECK={deck}", "-D", f"STRATA_COVER={cover}",
        str(REPO / "cad" / "r5_showcase.scad"),
    ]
    result = subprocess.run(cmd, cwd=REPO, capture_output=True, text=True)
    if result.returncode or not args.output.exists():
        sys.exit(result.stderr[-4000:] or result.stdout[-4000:] or "showcase render failed")
    print(f"{args.output.relative_to(REPO)}  {args.imgsize}")


if __name__ == "__main__":
    main()

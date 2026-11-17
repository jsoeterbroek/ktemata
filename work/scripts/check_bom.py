#!/usr/bin/env python3
"""Cross-check the schematic against the BOM.

The KiCad project is the netlist; docs/BOM.md is the purchasing list. They are different documents on
purpose - the BOM carries prices, suppliers, quantities, mechanical parts and "do not buy" notes that no
schematic has, and several schematic blocks stand for a connection or a source rather than one bought
part. What must not drift is the *link*: every block names its BOM item(s) in a `Part` field, and this
script fails if a block names an item the BOM does not have, or if two blocks claim the same item.

    kicad-cli sch export netlist --format kicadxml -o /tmp/kt.xml cad/kicad/r6/ktemata.kicad_sch
    python3 work/scripts/check_bom.py /tmp/kt.xml

Exit status 1 on a broken link; unclaimed BOM items are reported, not failed - they are the mechanical
and cable parts, which have no symbol.
"""
import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ITEM_RE = re.compile(r"^\|\s*([0-9]+[a-z]?)\s*\|")


def bom_items(path: Path) -> dict[str, str]:
    items = {}
    for line in path.read_text().splitlines():
        m = ITEM_RE.match(line)
        if not m:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        name = re.sub(r"[*`]", "", cells[1])[:60] if len(cells) > 1 else ""
        items[m.group(1)] = name
    return items


def schematic_parts(path: Path) -> list[tuple[str, str, list[str]]]:
    root = ET.parse(path).getroot()
    out = []
    for comp in root.iter("comp"):
        ref = comp.get("ref") or ""
        value = (comp.findtext("value") or "").strip()
        part = ""
        for field in comp.iter("field"):
            if field.get("name") == "Part":
                part = (field.text or "").strip()
        tokens = [t.strip() for t in re.split(r"[,;/\s]+", part) if t.strip() and t.strip() != "--"]
        out.append((ref, value, tokens))
    out.sort(key=lambda r: (len(r[0]), r[0]))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("netlist", help="kicadxml netlist exported from the project")
    ap.add_argument("--bom", default=str(ROOT / "docs" / "BOM.md"))
    args = ap.parse_args()

    items = bom_items(Path(args.bom))
    comps = schematic_parts(Path(args.netlist))
    if not items or not comps:
        sys.exit("nothing to compare: check the BOM path and the netlist export")

    problems = []
    claimed: dict[str, list[str]] = {}
    for ref, value, tokens in comps:
        for token in tokens:
            if token not in items:
                problems.append(f"{ref} ({value}) names BOM item {token}, which is not in {args.bom}")
            claimed.setdefault(token, []).append(ref)
        if not tokens:
            print(f"  note  {ref:4s} {value}: no Part field (a connection or a source, not a bought part)")

    for token, refs in sorted(claimed.items()):
        if len(refs) > 1:
            problems.append(f"BOM item {token} is claimed by {', '.join(refs)}")

    print(f"\n{len(comps)} schematic blocks, {len(claimed)} BOM items claimed of {len(items)} listed")
    for token in sorted(items):
        who = ", ".join(claimed.get(token, []))
        print(f"  {token:5s} {'-> ' + who if who else '(no symbol: mechanical, cable or optional)'}"
              f"  {items[token][:52]}")

    if problems:
        print("\nFAIL")
        for p in problems:
            print("  " + p)
        return 1
    print("\nOK: every Part field names a real BOM item, and no item is claimed twice")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Turn a KiCad netlist into a flat, spreadsheet-friendly table.

The KiCad project in docs/kicad/ is the wiring source of truth; this script only reads what it
exports, so the table can never drift from the schematic:

    kicad-cli sch export netlist --format kicadxml -o /tmp/kt.xml docs/kicad/ktemata.kicad_sch
    python3 work/scripts/kicad_netlist_csv.py /tmp/kt.xml -o docs/kicad/ktemata_r5_connections.csv

One row per pin on every net: Net, Ref, Part, Pin. No pairing is invented, so nothing implies a
connection that the schematic does not have.
"""
import argparse
import csv
import sys
import xml.etree.ElementTree as ET


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("netlist", help="kicadxml netlist exported by kicad-cli sch export netlist")
    ap.add_argument("-o", "--output", help="CSV to write (default: stdout)")
    args = ap.parse_args()

    try:
        root = ET.parse(args.netlist).getroot()
    except ET.ParseError as exc:
        sys.exit(f"{args.netlist}: {exc}")

    parts = {c.get("ref"): (c.findtext("value") or "").strip()
             for c in root.iter("comp")}

    rows = []
    for net in root.iter("net"):
        name = net.get("name") or ""
        for node in net.findall("node"):
            ref = node.get("ref") or ""
            pin = node.get("pin") or ""
            rows.append((name, ref, parts.get(ref, ""), pin))
    rows.sort(key=lambda r: (r[0], r[1], int(r[3]) if r[3].isdigit() else 0))

    out = sys.stdout if not args.output else open(args.output, "w", newline="")
    w = csv.writer(out, lineterminator="\n")
    w.writerow(["Net", "Ref", "Part", "Pin"])
    w.writerows(rows)
    if args.output:
        out.close()
        print(f"{args.output}: {len(rows)} pins on {len({r[0] for r in rows})} nets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

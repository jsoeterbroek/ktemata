#!/usr/bin/env python3
"""Turn a KiCad netlist into a flat, spreadsheet-friendly table.

The projects in cad/kicad/r5/ and cad/kicad/r6/ are the wiring sources of truth; this script only
reads their exports, so each table cannot drift from its schematic. Example for R6 (use r5 for R5):

    kicad-cli sch export netlist --format kicadxml -o /tmp/kt.xml cad/kicad/r6/ktemata.kicad_sch
    python3 work/scripts/kicad_netlist_csv.py /tmp/kt.xml -o cad/kicad/r6/ktemata_r6_connections.csv

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

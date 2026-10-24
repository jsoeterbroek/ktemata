#!/bin/bash
# Interference check of every printed part vs. every component/part.
#   bash work/scripts/check.sh        # r4 (default)
#   R4=0 bash work/scripts/check.sh   # previous r2/r3 hardware
#   R1=1 bash work/scripts/check.sh   # original r1 hardware
# A "HIT" whose bbox is flat in one axis (zero volume) is a tangent contact and expected.
cd "$(dirname "$0")/../../cad"
# private scratch dir: two concurrent runs must not overwrite each other's STLs
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
extra=""
if [ "$R1" = "1" ]; then
  extra='-D R2=false'
  parts="bottom face kbs pull button"
  comps="display pi battery keyboard uadp"
else
  [ "$R4" = "0" ] && extra='-D R4=false'
  parts="bottom face kbs"
  comps="display pi keyboard ups cells oled firebeetle sensor rtc mppt charge oledbtn"
fi
pairs=""
for p in $parts; do for c in $comps; do pairs="$pairs $p:$c"; done; done
pairs="$pairs bottom:face bottom:kbs face:kbs kbs:keyboard"
[ "$R1" = "1" ] && pairs="$pairs bottom:pull bottom:button kbs:battery"
[ "$R1" != "1" ] && pairs="$pairs pi:ups pi:cells ups:cells"
# stl_report.py lives next to this script; we have already cd'd into cad/
report="../work/scripts/stl_report.py"

for pr in $pairs; do
  f="$tmp/chk_${pr/:/_}.stl"
  out=$(timeout 300 openscad -o "$f" $extra -D "CHECK=\"$pr\"" assembly.scad 2>&1)
  if echo "$out" | grep -q "top level object is empty"; then echo "OK    $pr"
  elif [ ! -f "$f" ]; then echo "ERR   $pr  openscad produced no STL"
  else echo "HIT   $pr  $(python3 -I "$report" bbox "$f")"
  fi
done

# --- corner overmould tool ---------------------------------------------------------------
# corner_mould.scad is not part of assembly.scad, so it has its own harness. The plates and
# the cavity touch the rubber over large faces, so a bbox test would always report a hit.
# What matters here is the VOLUME of the intersection: exactly 0 is correct contact,
# anything above zero means the pieces intrude on each other (and the mould would not close).
if [ "$R1" != "1" ] && [ "$R4" != "0" ]; then
  for pair in cap:case cup:case plate:case lid:case cup:cap plate:cap lid:cup; do
    f="$tmp/chk_cm_${pair/:/_}.stl"
    out=$(timeout 300 openscad -o "$f" -D "CHECK=\"$pair\"" corner_mould_check.scad 2>&1)
    if echo "$out" | grep -q "top level object is empty"; then echo "OK    corner_$pair"
    elif [ ! -f "$f" ]; then echo "ERR   corner_$pair  openscad produced no STL"
    else r=$(python3 -I "$report" vol "$f")
      case "$r" in tangent*) echo "OK    corner_$pair - $r";; *) echo "HIT   corner_$pair - $r";; esac
    fi
  done
fi

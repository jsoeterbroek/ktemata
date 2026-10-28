#!/bin/bash
# r5 interference check: the cassette's printed parts against each other and the components.
#   bash work/scripts/check_r5.sh            # default host (1200)
#   HOST=1400 bash work/scripts/check_r5.sh  # bigger host interior
# A "HIT" whose bbox is flat in one axis is a zero-volume (tangent) contact and expected.
cd "$(dirname "$0")/../../cad"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
extra="-D R5=true"
[ -n "$HOST" ] && extra="$extra -D HOST=\"$HOST\""
pairs="tray:deck tray:pi tray:ups tray:cells tray:floor tray:keyboard tray:display
deck:pi deck:ups deck:cells deck:floor deck:keyboard deck:oled deck:display deck:lid
keyboard:display pi:display ups:display cells:display lid:pi lid:ups lid:cells lid:floor
ups:cells pi:ups"
report="../work/scripts/stl_report.py"
for pr in $pairs; do
  f="$tmp/chk_${pr/:/_}.stl"
  out=$(timeout 300 openscad -o "$f" $extra -D "CHECK=\"$pr\"" assembly_r5.scad 2>&1)
  if echo "$out" | grep -q "top level object is empty"; then echo "OK    $pr"
  elif [ ! -f "$f" ]; then echo "ERR   $pr  openscad produced no STL"
  else echo "HIT   $pr  $(python3 -I "$report" bbox "$f")"; fi
done

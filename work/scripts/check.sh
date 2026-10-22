#!/bin/bash
# Interference check of every printed part vs. every component/part.
#   bash work/scripts/check.sh        # r4 (default)
#   R4=0 bash work/scripts/check.sh   # previous r2/r3 hardware
#   R1=1 bash work/scripts/check.sh   # original r1 hardware
# A "HIT" whose bbox is flat in one axis (zero volume) is a tangent contact and expected.
cd "$(dirname "$0")/../../cad"
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
for pr in $pairs; do
  out=$(timeout 300 openscad -o /tmp/chk_${pr/:/_}.stl $extra -D "CHECK=\"$pr\"" assembly.scad 2>&1)
  if echo "$out" | grep -q "top level object is empty"; then echo "OK    $pr"; else
    echo "HIT   $pr  $(python3 -I -c "
import sys,struct
d=open('/tmp/chk_${pr/:/_}.stl').read().split()
v=[float(x) for i,x in enumerate(d) if i>0 and d[i-1] in('vertex',) or (i>1 and d[i-2]=='vertex') or (i>2 and d[i-3]=='vertex')]
xs=v[0::3];ys=v[1::3];zs=v[2::3]
print('degenerate/tangent (no triangles)' if not xs else 'bbox x %.1f..%.1f  y %.1f..%.1f  z %.1f..%.1f'%(min(xs),max(xs),max(ys),min(ys),min(zs),max(zs)))" 2>&1)"; fi
done

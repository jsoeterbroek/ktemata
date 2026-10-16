#!/bin/bash
cd "$(dirname "$0")/../../cad"
parts="bottom face kbs pull button"
comps="display pi battery keyboard uadp"
pairs=""
for p in $parts; do for c in $comps; do pairs="$pairs $p:$c"; done; done
pairs="$pairs bottom:face bottom:kbs bottom:pull bottom:button face:kbs face:pull kbs:battery"
for pr in $pairs; do
  out=$(timeout 300 openscad -o /tmp/chk_${pr/:/_}.stl -D "CHECK=\"$pr\"" assembly.scad 2>&1)
  if echo "$out" | grep -q "top level object is empty"; then echo "OK    $pr"; else
    echo "HIT   $pr  $(python3 -I -c "
import sys,struct
d=open('/tmp/chk_${pr/:/_}.stl').read().split()
v=[float(x) for i,x in enumerate(d) if i>0 and d[i-1] in('vertex',) or (i>1 and d[i-2]=='vertex') or (i>2 and d[i-3]=='vertex')]
xs=v[0::3];ys=v[1::3];zs=v[2::3]
print('bbox x %.1f..%.1f  y %.1f..%.1f  z %.1f..%.1f'%(min(xs),max(xs),183-max(ys),183-min(ys),min(zs),max(zs)))" 2>&1)"; fi
done

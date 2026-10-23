#!/usr/bin/env python3
"""Export parts to ../stl as binary STL, dropped onto z=0 and centred on x/y.

  python3 cad/tools/export.py                 # r4 parts (default: TD2 + UPS HAT (B) + K06)
  python3 cad/tools/export.py --r2            # previous r2/r3 set (DFR0550 + HAT (E) + Phistone)
  python3 cad/tools/export.py --r1            # original r1 set instead
  python3 cad/tools/export.py face bottom     # only some parts
"""
import subprocess, struct, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__)); CAD = os.path.dirname(HERE)
OUT = os.path.join(os.path.dirname(CAD), 'stl')
PARTS = {'bottom':'ktemata_bottom', 'face':'ktemata_face', 'keyboard_support':'ktemata_keyboard_support',
         'charge_plug':'ktemata_charge_plug',
         'pull_switch':'ktemata_pull_switch', 'power_button':'ktemata_power_button'}
LEGACY = {'pull_switch', 'power_button'}

def read_ascii(path):
    tris, cur = [], []
    for line in open(path):
        t = line.split()
        if t and t[0] == 'vertex':
            cur.append(tuple(map(float, t[1:4])))
            if len(cur) == 3: tris.append(cur); cur = []
    return tris

def write_bin(path, tris, name):
    with open(path, 'wb') as f:
        f.write(name.encode()[:80].ljust(80, b' ')); f.write(struct.pack('<I', len(tris)))
        for a, b, c in tris:
            u = [b[i]-a[i] for i in range(3)]; v = [c[i]-a[i] for i in range(3)]
            n = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
            l = sum(x*x for x in n) ** .5 or 1
            f.write(struct.pack('<12fH', *[x/l for x in n], *a, *b, *c, 0))

def check_manifold(tris):
    """Edges not shared by exactly one face in each direction (open or non-manifold, as slicers report)."""
    edges = {}
    for t in tris:
        for i in range(3):
            e = (t[i], t[(i+1) % 3])
            edges[e] = edges.get(e, 0) + 1
    return sum(1 for (a, b), n in edges.items() if n != 1 or edges.get((b, a), 0) != 1)

args = sys.argv[1:]
r1 = '--r1' in args
r2 = '--r2' in args
if r1 and r2:
    sys.exit('choose either --r1 or --r2')
args = [a for a in args if a not in ('--r1', '--r2')]
# r4 is the default; --r2 selects the previous r2/r3 mechanics, --r1 the original case
extra = ['-D', 'R2=false'] if r1 else (['-D', 'R4=false'] if r2 else [])

os.makedirs(OUT, exist_ok=True)
for part, fname in PARTS.items():
    if r1 is False and part in LEGACY: continue
    if args and part not in args: continue
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, 'p.stl')
        r = subprocess.run(['openscad', '-o', tmp, *extra, '-D', f'PART="{part}"', os.path.join(CAD, 'export.scad')],
                           capture_output=True, text=True)
        if r.returncode or not os.path.exists(tmp): print(r.stderr); sys.exit(1)
        tris = read_ascii(tmp)
    if not tris:
        print(f'{fname:28s} EMPTY (part not available in this mode)'); continue
    xs = [p[0] for t in tris for p in t]; ys = [p[1] for t in tris for p in t]; zs = [p[2] for t in tris for p in t]
    off = (-(min(xs)+max(xs))/2, -(min(ys)+max(ys))/2, -min(zs))
    tris = [[tuple(p[i]+off[i] for i in range(3)) for p in t] for t in tris]
    write_bin(os.path.join(OUT, fname + '.stl'), tris, fname)
    print(f'{fname:28s} {max(xs)-min(xs):6.1f} x {max(ys)-min(ys):6.1f} x {max(zs)-min(zs):5.1f} mm  '
          f'{len(tris):6d} tris  bad edges: {check_manifold(tris)}')

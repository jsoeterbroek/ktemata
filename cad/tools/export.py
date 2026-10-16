#!/usr/bin/env python3
"""Export all parts to ../stl as binary STL, dropped onto z=0 and centred on x/y."""
import subprocess, struct, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__)); CAD = os.path.dirname(HERE)
OUT = os.path.join(os.path.dirname(CAD), 'stl')
PARTS = {'bottom':'pi_fluks_bottom', 'face':'pi_fluks_face', 'keyboard_support':'pi_fluks_keyboard_support',
         'pull_switch':'pi_fluks_pull_switch', 'power_button':'pi_fluks_power_button'}

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
    edges = {}
    for t in tris:
        for i in range(3):
            e = (t[i], t[(i+1) % 3])
            edges[e] = edges.get(e, 0) + 1
    bad = sum(1 for (a, b), n in edges.items() if edges.get((b, a), 0) != n)
    return bad

os.makedirs(OUT, exist_ok=True)
for part, fname in PARTS.items():
    if len(sys.argv) > 1 and part not in sys.argv[1:]: continue
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, 'p.stl')
        r = subprocess.run(['openscad', '-o', tmp, '-D', f'PART="{part}"', os.path.join(CAD, 'export.scad')],
                           capture_output=True, text=True)
        if r.returncode or not os.path.exists(tmp): print(r.stderr); sys.exit(1)
        tris = read_ascii(tmp)
    xs = [p[0] for t in tris for p in t]; ys = [p[1] for t in tris for p in t]; zs = [p[2] for t in tris for p in t]
    off = (-(min(xs)+max(xs))/2, -(min(ys)+max(ys))/2, -min(zs))
    tris = [[tuple(p[i]+off[i] for i in range(3)) for p in t] for t in tris]
    write_bin(os.path.join(OUT, fname + '.stl'), tris, fname)
    print(f'{fname:28s} {max(xs)-min(xs):6.1f} x {max(ys)-min(ys):6.1f} x {max(zs)-min(zs):5.1f} mm  '
          f'{len(tris):6d} tris  open edges: {check_manifold(tris)}')

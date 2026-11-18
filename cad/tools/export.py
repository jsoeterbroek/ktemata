#!/usr/bin/env python3
"""Export R5 parts to ../stl/r5 and named R6 prototypes to ../stl/r6.

  python3 cad/tools/export.py                                  # the shipped R5 set
  python3 cad/tools/export.py r5_deck                          # only some R5 parts
  python3 cad/tools/export.py r5_lid_cover_test_dimensions     # an R5 alternative, by name
  python3 cad/tools/export.py r6_lid_plate                     # the R6 keyboard/OLED lid prototype
  python3 cad/tools/export.py r6_tray                          # the R6 cassette tray
  python3 cad/tools/export.py r6_lid_cover                     # the R6 display frame / lid cover
  python3 cad/tools/export.py r6_deck                          # the R6 cassette deck

The R5 fit template and 7" lid cover, and all R6 parts, are skipped unless named. Every export is
binary, centred on x/y, dropped to z=0 and checked for directed-edge manifoldness.
"""
import subprocess, struct, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__)); CAD = os.path.dirname(HERE)
OUT_R5 = os.path.join(os.path.dirname(CAD), 'stl', 'r5')
OUT_R6 = os.path.join(os.path.dirname(CAD), 'stl', 'r6')
PARTS = {'r5_tray':'ktemata_r5_tray', 'r5_deck':'ktemata_r5_deck',
         'r5_lid_plate':'ktemata_r5_lid_plate', 'r5_lid_cover':'ktemata_r5_lid_cover',
         'r5_lid_cover_test_dimensions':'ktemata_r5_lid_cover_test_dimensions',
         'r5_lid_cover_waveshare_7in':'ktemata_r5_lid_cover_waveshare_7in',
         'r6_lid_plate':'ktemata_r6_lid_plate',
         'r6_tray':'ktemata_r6_tray',
         'r6_lid_cover':'ktemata_r6_lid_cover',
         'r6_deck':'ktemata_r6_deck'}
# Alternatives are skipped unless named; R6 prototypes are never in the default R5 export.
ALTERNATIVES = {'r5_lid_cover_test_dimensions', 'r5_lid_cover_waveshare_7in', 'r6_lid_plate',
                'r6_tray', 'r6_lid_cover', 'r6_deck'}

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
unknown = [a for a in args if a not in PARTS]
if unknown:
    sys.exit(f'unknown part(s) {unknown}: choose from {sorted(PARTS)}')

for part, fname in PARTS.items():
    if not args and part in ALTERNATIVES: continue
    if args and part not in args: continue
    out_dir = OUT_R6 if part.startswith('r6_') else OUT_R5
    os.makedirs(out_dir, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, 'p.stl')
        r = subprocess.run(['openscad', '-o', tmp, '-D', f'PART="{part}"', os.path.join(CAD, 'export.scad')],
                           capture_output=True, text=True)
        if r.returncode or not os.path.exists(tmp): print(r.stderr); sys.exit(1)
        tris = read_ascii(tmp)
    if not tris:
        print(f'{fname:28s} EMPTY (part not available in this mode)'); continue
    xs = [p[0] for t in tris for p in t]; ys = [p[1] for t in tris for p in t]; zs = [p[2] for t in tris for p in t]
    off = (-(min(xs)+max(xs))/2, -(min(ys)+max(ys))/2, -min(zs))
    tris = [[tuple(p[i]+off[i] for i in range(3)) for p in t] for t in tris]
    write_bin(os.path.join(out_dir, fname + '.stl'), tris, fname)
    print(f'{fname:28s} {max(xs)-min(xs):6.1f} x {max(ys)-min(ys):6.1f} x {max(zs)-min(zs):5.1f} mm  '
          f'{len(tris):6d} tris  bad edges: {check_manifold(tris)}')

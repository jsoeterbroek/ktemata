#!/usr/bin/env python3
"""Export the hand crank generator parts to ../stl/crank as binary STL, centred on x/y and
dropped onto z=0 (print orientation as set in cad/export_crank.scad).

  python3 cad/tools/export_crank.py                 # all crank parts
  python3 cad/tools/export_crank.py base stator     # only some parts

Prints size, triangle count and the number of bad edges (0 = manifold, as slicers report).
"""
import subprocess, struct, sys, os, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CAD = os.path.dirname(HERE)
OUT = os.path.join(os.path.dirname(CAD), 'stl', 'crank')

PARTS = {
    'base':           'crank_base',
    'stator':         'crank_stator',
    'top':            'crank_top',
    'rotor':          'crank_rotor',
    'hub':            'crank_hub',
    'gear_big':       'crank_gear_big',
    'gear_small':     'crank_gear_small',
    'arm':            'crank_arm',
    'knob':           'crank_knob',
    'tray':           'crank_tray',
    'lid':            'crank_lid',
    'foot':           'crank_foot',
}
DEFAULT = ['base', 'stator', 'top', 'rotor', 'hub', 'gear_big', 'gear_small',
           'arm', 'knob', 'tray', 'lid', 'foot']


def read_ascii(path):
    """Read a (possibly binary) STL written by OpenSCAD into triangle tuples."""
    data = open(path, 'rb').read()
    if data[:5].lower() == b'solid' and b'vertex' in data[:2048]:
        tris, cur = [], []
        for line in data.decode('utf-8', 'replace').splitlines():
            t = line.split()
            if t and t[0] == 'vertex':
                cur.append(tuple(map(float, t[1:4])))
                if len(cur) == 3:
                    tris.append(cur)
                    cur = []
        return tris
    n = struct.unpack('<I', data[80:84])[0]
    tris = []
    for i in range(n):
        v = struct.unpack('<12f', data[84 + i*50: 84 + i*50 + 48])
        tris.append([v[3:6], v[6:9], v[9:12]])
    return tris


def write_bin(path, tris, name):
    with open(path, 'wb') as f:
        f.write(name.encode()[:80].ljust(80, b' '))
        f.write(struct.pack('<I', len(tris)))
        for a, b, c in tris:
            u = [b[i] - a[i] for i in range(3)]
            v = [c[i] - a[i] for i in range(3)]
            n = [u[1]*v[2] - u[2]*v[1], u[2]*v[0] - u[0]*v[2], u[0]*v[1] - u[1]*v[0]]
            l = sum(x*x for x in n) ** .5 or 1
            f.write(struct.pack('<12fH', *[x/l for x in n], *a, *b, *c, 0))


def check_manifold(tris):
    """Edges not shared by exactly one face in each direction (open or non-manifold)."""
    edges = {}
    for t in tris:
        for i in range(3):
            e = (t[i], t[(i + 1) % 3])
            edges[e] = edges.get(e, 0) + 1
    return sum(1 for (a, b), n in edges.items() if n != 1 or edges.get((b, a), 0) != 1)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('-')]
    names = args or DEFAULT
    os.makedirs(OUT, exist_ok=True)
    bad = 0
    for part in names:
        fname = PARTS[part]
        with tempfile.TemporaryDirectory() as td:
            tmp = os.path.join(td, 'p.stl')
            r = subprocess.run(['openscad', '-o', tmp,
                                '-D', f'PART="{part}"', os.path.join(CAD, 'export_crank.scad')],
                               capture_output=True, text=True)
            if r.returncode or not os.path.exists(tmp):
                print(f'{fname:22s} FAILED\n{r.stderr}')
                bad += 1
                continue
            tris = read_ascii(tmp)
        if not tris:
            print(f'{fname:22s} EMPTY')
            bad += 1
            continue
        xs = [p[0] for t in tris for p in t]
        ys = [p[1] for t in tris for p in t]
        zs = [p[2] for t in tris for p in t]
        off = (-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, -min(zs))
        tris = [[tuple(p[i] + off[i] for i in range(3)) for p in t] for t in tris]
        write_bin(os.path.join(OUT, fname + '.stl'), tris, fname)
        e = check_manifold(tris)
        bad += 1 if e else 0
        print(f'{fname:22s} {max(xs)-min(xs):6.1f} x {max(ys)-min(ys):6.1f} x {max(zs)-min(zs):5.1f} mm  '
              f'{len(tris):6d} tris  bad edges: {e}')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())

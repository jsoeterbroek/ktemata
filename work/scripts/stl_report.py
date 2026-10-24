#!/usr/bin/env python3
"""Describe an STL intersection exported by check.sh.

  python3 work/scripts/stl_report.py bbox  <file>   # bounding box of the overlap
  python3 work/scripts/stl_report.py vol   <file>   # intersection volume in cm3

`bbox` is the original rule: a bbox flat in one axis is a tangent contact, not a collision.
`vol` is for tools whose pieces meet over large faces (the corner mould): there only a
positive volume is an intrusion.
"""
import sys


def vertices(path):
    try:
        with open(path) as f:
            tok = f.read().split()
    except OSError:
        return None
    v = []
    for i in range(1, len(tok) - 3):
        if tok[i - 1] == 'vertex':
            v.extend((float(tok[i]), float(tok[i + 1]), float(tok[i + 2])))
    return v


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ('bbox', 'vol'):
        sys.exit(__doc__)
    mode, path = sys.argv[1], sys.argv[2]
    v = vertices(path)
    if v is None:
        print('no STL (openscad failed)')
        return
    if not v:
        # zero-area contact (no triangles survive): still contact, not a collision
        print('tangent (no triangles)')
        return
    if mode == 'bbox':
        x, y, z = v[0::3], v[1::3], v[2::3]
        print('bbox x %.1f..%.1f  y %.1f..%.1f  z %.1f..%.1f'
              % (min(x), max(x), min(y), max(y), min(z), max(z)))
        return
    vol = 0.0
    for i in range(0, len(v) - 8, 9):
        ax, ay, az, bx, by, bz, cx, cy, cz = v[i:i + 9]
        vol += (ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)) / 6.0
    vol = abs(vol) / 1000.0
    print('tangent (%.6f cm3)' % vol if vol < 1e-6 else 'intrudes %.4f cm3' % vol)


if __name__ == '__main__':
    main()

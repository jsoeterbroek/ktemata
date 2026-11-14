#!/usr/bin/env python3
"""Render the r5 previews to ../renders/r5 (run export.py first: the STL views read its output).

   python3 cad/tools/render.py              # everything
   python3 cad/tools/render.py cover        # only images whose name contains one of the arguments
   python3 cad/tools/render.py --list       # the names, nothing rendered

The hand crank generator is a separate project (github.com/jsoeterbroek/handcrank); its previews
are rendered by its own cad/tools/render.py."""
import subprocess, sys, os, tempfile
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__)); CAD = os.path.dirname(HERE); ROOT = os.path.dirname(CAD)
OUT_R5 = os.path.join(ROOT, 'renders', 'r5')
STL_R5 = os.path.join(ROOT, 'stl', 'r5')
ISO = '0,0,0,55,0,25,0'    # gimbal camera rotation used with --viewall

# name: (source, size, camera, extra args, full CGAL render?)
#   source = .scad file in cad/, or 'stl:<part>' for an exported STL (print orientation)
VIEWS = {
    'ktemata_r5_tray':          ('stl:r5_tray',      (1200, 950), ISO, [], True),
    'ktemata_r5_deck':          ('stl:r5_deck',      (1200, 950), ISO, [], True),
    'ktemata_r5_lid_plate':     ('stl:r5_lid_plate', (1200, 950), ISO, [], True),
    'ktemata_r5_lid_cover':     ('stl:r5_lid_cover', (1200, 950), ISO, [], True),
    'ktemata_r5_lid_cover_test_dimensions': ('stl:r5_lid_cover_test_dimensions', (1200, 950), ISO, [], True),
    'ktemata_r5_lid_cover_waveshare_7in': ('stl:r5_lid_cover_waveshare_7in', (1200, 950), ISO, [], True),
    'r5_assembly':  ('assembly_r5.scad', (1400, 1100), ISO, [], True),
    'r5_cassette':  ('assembly_r5.scad', (1400, 1100), ISO, ['-D', 'SHOW_HOST=false'], True),
    'r5_exploded':  ('assembly_r5.scad', (1400, 1100), '0,0,0,60,0,30,0',
                     ['-D', 'SHOW_HOST=false', '-D', 'EXPLODE=60'], True),
    # dark view for site/ (same geometry, Tomorrow Night instead of Tomorrow); build.sh copies it
    'site_r5_exploded': ('assembly_r5.scad', (1400, 1000), '0,0,0,60,0,30,0',
                         ['-D', 'SHOW_HOST=false', '-D', 'EXPLODE=60'], True),
}

# The site is dark; the default Tomorrow scheme renders on white and clashes with it.
DARK = {'site_r5_exploded'}


def render(name, td):
    src, (w, h), cam, extra, full = VIEWS[name]
    if src.startswith('stl:'):
        stl = os.path.join(STL_R5, "ktemata_" + src[4:] + ".stl")
        if not os.path.exists(stl):
            return name, 1, ['missing STL: run export.py first']
        src = os.path.join(td, name + '.scad')
        open(src, 'w').write(f'color("#4a72b0") import("{stl}");\n')
    else:
        src = os.path.join(CAD, src)
    view = ['--camera=' + cam] + (['--viewall', '--autocenter'] if cam.startswith('0,0,0,') else [])
    scheme = 'Tomorrow Night' if name in DARK else 'Tomorrow'
    cmd = ['openscad', '-o', os.path.join(OUT_R5, name + '.png'), f'--imgsize={w},{h}',
           f'--colorscheme={scheme}', *(['--render'] if full else []), *view, *extra, src]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return name, r.returncode, r.stderr.strip().splitlines()[-1:] if r.returncode else ''


if '--list' in sys.argv[1:]:
    print('\n'.join(VIEWS)); sys.exit(0)

args = sys.argv[1:]
names = [n for n in VIEWS if any(a in n for a in args)] if args else list(VIEWS)
if not names:
    sys.exit(f'no view matches {args}')
os.makedirs(OUT_R5, exist_ok=True)
with tempfile.TemporaryDirectory() as td, ThreadPoolExecutor(os.cpu_count() or 4) as ex:
    for name, rc, err in ex.map(lambda n: render(n, td), names):
        print(f'{"ok  " if rc == 0 else "FAIL"} {name}.png {err or ""}')
        if rc:
            sys.exit(1)

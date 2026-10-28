#!/usr/bin/env python3
"""Render the case preview images to ../renders. Run export.py first (the ktemata_* views use the STLs).
   python3 cad/tools/render.py            # everything (r4)
   python3 cad/tools/render.py --r5       # the r5 cassette views (after export.py --r5)
   python3 cad/tools/render.py asm_iso    # only images whose name contains one of the arguments

The hand crank generator is a separate project (github.com/jsoeterbroek/handcrank); its previews
are rendered by its own cad/tools/render.py."""
import subprocess, sys, os, tempfile
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__)); CAD = os.path.dirname(HERE); ROOT = os.path.dirname(CAD)
OUT = os.path.join(ROOT, 'renders'); STL = os.path.join(ROOT, 'stl')
ISO, BACK = '0,0,0,55,0,25,0', '0,0,0,125,0,205,0'   # gimbal camera rotations used with --viewall

# name: (source, size, camera, extra args, full CGAL render?)
#   source = .scad file in cad/, or 'stl:<part>' for an exported STL (print orientation)
VIEWS = {
    # viewall/autocenter: the assemblies are 183-237 mm long depending on the variant, so a
    # fixed camera distance would crop one of them (r4 is 32 mm longer than r2/r3).
    'asm_iso':     ('assembly.scad', (1400, 1100), '0,0,0,55,0,25,0', [], True),
    'asm_corner':  ('assembly.scad', (1200, 900), '0,0,0,55,0,25,0', ['-D', 'EXPLODE=0'], True),
    'asm_back':    ('assembly.scad', (1200, 900), '0,0,0,125,0,205,0', [], True),
    # looking along +x into the cut face; --viewall would include the sectioning cube
    'asm_sec':     ('assembly.scad', (1400, 1000), '-260,118,26,86,118,26', ['-D', 'SECTION=true'], False),
    'bottom_iso':  ('bottom.scad', (1400, 1100), ISO, [], True),
    'face_iso':    ('face.scad', (1400, 1100), ISO, [], True),
    'keyboard_support': ('keyboard_support.scad', (900, 700), ISO, [], False),
    'power_button':     ('power_button.scad', (900, 700), ISO, [], False),
    'pull_switch':      ('pull_switch.scad', (900, 700), ISO, [], False),
    'ktemata_bottom':           ('stl:bottom', (1200, 950), ISO, [], True),
    'ktemata_bottom_back':      ('stl:bottom', (1200, 950), BACK, [], True),
    'ktemata_face':             ('stl:face', (1200, 950), ISO, [], True),
    'ktemata_face_front':       ('stl:face', (1200, 950), BACK, [], True),
    'ktemata_keyboard_support': ('stl:keyboard_support', (1200, 950), ISO, [], True),
    'ktemata_charge_plug':      ('stl:charge_plug', (900, 700), ISO, [], True),
    'ktemata_power_button':     ('stl:power_button', (1200, 950), ISO, [], True),
    'ktemata_pull_switch':      ('stl:pull_switch', (1200, 950), ISO, [], True),
    'ktemata_corner_cap':       ('stl:corner_cap',   (900, 700), ISO, [], True),
    'ktemata_corner_cup':       ('stl:corner_cup',   (900, 700), ISO, [], True),
    'ktemata_corner_plate':     ('stl:corner_plate', (900, 700), ISO, [], True),
    'ktemata_r5_tray':          ('stl:r5_tray',      (1200, 950), ISO, [], True),
    'ktemata_r5_deck':          ('stl:r5_deck',      (1200, 950), ISO, [], True),
    'ktemata_r5_lid_plate':     ('stl:r5_lid_plate', (1200, 950), ISO, [], True),
    'ktemata_corner_lid':       ('stl:corner_lid',   (900, 700), ISO, [], True),
    # r5 internal cassette (needs `export.py --r5` first); render with --r5
    'r5_assembly':  ('assembly_r5.scad', (1400, 1100), '0,0,0,55,0,25,0', [], True),
    'r5_cassette':  ('assembly_r5.scad', (1400, 1100), '0,0,0,55,0,25,0', ['-D', 'SHOW_HOST=false'], True),
    'r5_exploded':  ('assembly_r5.scad', (1400, 1100), '0,0,0,60,0,30,0', ['-D', 'SHOW_HOST=false', '-D', 'EXPLODE=60'], True),
}

R5_ONLY = {'r5_assembly', 'r5_cassette', 'r5_exploded', 'ktemata_r5_tray', 'ktemata_r5_deck',
           'ktemata_r5_lid_plate'}

R1_ONLY = {'power_button', 'pull_switch', 'ktemata_power_button', 'ktemata_pull_switch'}

def render(name, td):
    src, (w, h), cam, extra, full = VIEWS[name]
    extra = list(extra)
    if name in R1_ONLY and not src.startswith('stl:'):
        extra += ['-D', 'R2=false']
    if '--r2' in sys.argv[1:]:
        extra += ['-D', 'R4=false']
    if name in R5_ONLY:
        extra += ['-D', 'R5=true']
    if src.startswith('stl:'):
        src = os.path.join(td, name + '.scad')
        open(src, 'w').write(f'color("#4a72b0") import("{os.path.join(STL, "ktemata_" + VIEWS[name][0][4:] + ".stl")}");\n')
    else:
        src = os.path.join(CAD, src)
    view = ['--camera=' + cam] + (['--viewall', '--autocenter'] if cam.count(',') == 6 and cam.startswith('0,0,0,') else [])
    cmd = ['openscad', '-o', os.path.join(OUT, name + '.png'), f'--imgsize={w},{h}', '--colorscheme=Tomorrow',
           *(['--render'] if full else []), *view, *extra, src]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return name, r.returncode, r.stderr.strip().splitlines()[-1:] if r.returncode else ''

args = [a for a in sys.argv[1:] if a not in ('--r1', '--r5')]
r5 = '--r5' in sys.argv[1:]
if args:
    names = [n for n in VIEWS if any(a in n for a in args)]
else:
    # no arguments: render this build's set only (r5 views need export.py --r5 first)
    skip = R5_ONLY if not r5 else set(VIEWS) - R5_ONLY
    names = [n for n in VIEWS if n not in skip and (n not in R1_ONLY or '--r1' in sys.argv[1:])]
with tempfile.TemporaryDirectory() as td, ThreadPoolExecutor(os.cpu_count() or 4) as ex:
    for name, rc, err in ex.map(lambda n: render(n, td), names):
        print(f'{"ok  " if rc == 0 else "FAIL"} {name}.png {err or ""}')
        if rc: sys.exit(1)

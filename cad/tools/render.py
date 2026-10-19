#!/usr/bin/env python3
"""Render all preview images to ../renders. Run export.py first (the pi_fluks_* views use the STLs).
   python3 cad/tools/render.py            # everything
   python3 cad/tools/render.py asm_iso    # only images whose name contains one of the arguments"""
import subprocess, sys, os, tempfile
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__)); CAD = os.path.dirname(HERE); ROOT = os.path.dirname(CAD)
OUT = os.path.join(ROOT, 'renders'); STL = os.path.join(ROOT, 'stl')
ISO, BACK = '0,0,0,55,0,25,0', '0,0,0,125,0,205,0'   # gimbal camera rotations used with --viewall

# name: (source, size, camera, extra args, full CGAL render?)
#   source = .scad file in cad/, or 'stl:<part>' for an exported STL (print orientation)
VIEWS = {
    'asm_iso':     ('assembly.scad', (1400, 1100), '75,90,17,60,0,35,430', [], True),
    'asm_corner':  ('assembly.scad', (1200, 900), '140,10,25,60,0,40,150', [], True),
    'asm_back':    ('assembly.scad', (1200, 900), '75,90,17,125,0,215,430', [], True),
    'asm_sec':     ('assembly.scad', (1400, 1000), '64,90,17,75,0,90,330', ['-D', 'SECTION=true'], False),
    'bottom_iso':  ('bottom.scad', (1400, 1100), ISO, [], True),
    'face_iso':    ('face.scad', (1400, 1100), ISO, [], True),
    'keyboard_support': ('keyboard_support.scad', (900, 700), ISO, [], False),
    'power_button':     ('power_button.scad', (900, 700), ISO, [], False),
    'pull_switch':      ('pull_switch.scad', (900, 700), ISO, [], False),
    'pi_fluks_bottom':           ('stl:bottom', (1200, 950), ISO, [], True),
    'pi_fluks_bottom_back':      ('stl:bottom', (1200, 950), BACK, [], True),
    'pi_fluks_face':             ('stl:face', (1200, 950), ISO, [], True),
    'pi_fluks_face_front':       ('stl:face', (1200, 950), BACK, [], True),
    'pi_fluks_keyboard_support': ('stl:keyboard_support', (1200, 950), ISO, [], True),
    'pi_fluks_charge_plug':      ('stl:charge_plug', (900, 700), ISO, [], True),
    'pi_fluks_power_button':     ('stl:power_button', (1200, 950), ISO, [], True),
    'pi_fluks_pull_switch':      ('stl:pull_switch', (1200, 950), ISO, [], True),
}

R1_ONLY = {'power_button', 'pull_switch', 'pi_fluks_power_button', 'pi_fluks_pull_switch'}

def render(name, td):
    src, (w, h), cam, extra, full = VIEWS[name]
    extra = list(extra)
    if name in R1_ONLY and not src.startswith('stl:'):
        extra += ['-D', 'R2=false']
    if src.startswith('stl:'):
        src = os.path.join(td, name + '.scad')
        open(src, 'w').write(f'color("#4a72b0") import("{os.path.join(STL, "pi_fluks_" + VIEWS[name][0][4:] + ".stl")}");\n')
    else:
        src = os.path.join(CAD, src)
    view = ['--camera=' + cam] + (['--viewall', '--autocenter'] if cam.count(',') == 6 and cam.startswith('0,0,0,') else [])
    cmd = ['openscad', '-o', os.path.join(OUT, name + '.png'), f'--imgsize={w},{h}', '--colorscheme=Tomorrow',
           *(['--render'] if full else []), *view, *extra, src]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return name, r.returncode, r.stderr.strip().splitlines()[-1:] if r.returncode else ''

args = [a for a in sys.argv[1:] if a != '--r1']
names = [n for n in VIEWS
         if (args and any(a in n for a in args)) or (not args and (n not in R1_ONLY or '--r1' in sys.argv[1:]))]
with tempfile.TemporaryDirectory() as td, ThreadPoolExecutor(os.cpu_count() or 4) as ex:
    for name, rc, err in ex.map(lambda n: render(n, td), names):
        print(f'{"ok  " if rc == 0 else "FAIL"} {name}.png {err or ""}')
        if rc: sys.exit(1)

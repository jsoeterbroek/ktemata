# AGENTS.md

This file provides guidance when working with code in this repository.

## Important

Be direct, ultra-concise, and straight to the point. Skip all pleasantries, introductory remarks, meta-commentary, and unnecessary explanations. Answer using bullet points where applicable.

## What this is

Parametric OpenSCAD case for the **Ktemata** handheld: a rugged offline library device — Wikipedia, maps, Gutenberg — that keeps its content when power and networking are gone. The name is Greek κτήματα, "possessions".

**R6 is the default build.** Two variants:
- **R6**: perfboard variant with DC5521 charge management
- **R6 PCH**: custom power/charge carrier board

Both keep Wikipedia, maps and Gutenberg when power and networking are gone. Github repository history tracks both variants.

## Hardware Architecture

### Target Platforms

- **Host Case**: Peli 1200 (rugged, IP67-rated)
- **Computer**: Raspberry Pi 5 (4 GB)
- **Display**: Waveshare 7" DSI LCD (C)
- **Keyboard**: Rii K06 Touch Keyboard
- **Storage**: NVMe SSD
- **Power**: Waveshare UPS Module 3S with three 18650 cells in 3S

### Build Strategy

Git repository tracks both variants. Earlier revisions are historical and available in the repo history — no need to maintain older builds separately. GitHub history preserves the evolution from prototyping through production-ready designs.

## Design Philosophy

**KISS principle**. Hardware, design and build stay simple.

- Core: Pi 5, 7" DSI display, K06 keyboard, NVMe SSD, UPS Module 3S
- R6 variant uses simple perfboard for cost-effectiveness and rapid iteration
- R6 PCH variant provides a power/charge carrier
- Charging managed by DC5521 (R6) or the PCH carrier
- Everything else is complexity. A nice-to-have is a point of failure.

## Tools

For development phase use:

- **FreeCAD / OpenSCAD**: CAD tools
- **Python 3**: Export scripts and automation
- **kicad-cli**: Schematic and board manipulation

## Commands

```bash
# Export R6 variants (perfboard or PCH)
python3 cad/tools/export.py --variant R6_PERFBOARD
python3 cad/tools/export.py --variant R6_PCH

# Export specific parts
python3 cad/tools/export.py r6_lid_plate        # keyboard lid prototype
python3 cad/tools/export.py r6_tray             # cassette tray with UPS 3S
python3 cad/tools/export.py r6_deck             # full-face deck with panel

# Render and validate
openscad -o out.png --render --imgsize=1400,1100 cad/assembly.scad
bash work/scripts/check_r6.sh                   # interference check (HOST defaults to 1200)
python3 cad/tools/paint.py --rev R6             # paint patterns and masks
```

## Architecture

### Parametric Design

- `cad/common.scad` holds all shared parameters. No switches or hardcoded values.
- **Coordinate convention**: x = left→right, y = top→bottom, z = 0 at back surface rising to screen. Use `at(x, y, z)` for placement.
- Component positions derive from each other through the parameter system.

### Part Structure

Each part file models itself in assembly position with pattern: `difference() { union() { solids } difference() { cuts } }`. Parts render only when `ASSEMBLY` is undefined. Assembly uses `EXPLODE`, `SECTION`, `CHECK` stand-ins for interference checks.

### KiCad Integration

- `cad/kicad/r6/` contains the current R6 KiCad project
- `cad/kicad/r6/PCH/` contains the power/charge carrier project
- Each is a self-contained KiCad project — `ktemata.kicad_pro` with indexed and sheet files
- One connector-shaped `Ktemata:` symbol per module. Global labels carry names across sheets.

### Tooling Usage

- **Parametric**: All dimensions are explicit variables at script top, never hardcoded internals
- **Z-fighting**: `difference()` uses `+0.02` offset or overlapping positions for clean booleans
- **CSG**: Symmetric features programmatic via loops; transformations respect `translate()` then `rotate()` order
- **Resolution**: `$fn = 60` globally for production parts; `$fn = 100` for precision curves only

## KISS Principles Applied

- The Pi 5 is the only computer; there is no separate status MCU
- Charging managed cleanly by DC5521 or PCH without parallel sources
- I²C carries the UPS gauge
- Both variants share the same rugged case envelope
- Neither variant adds unnecessary radios, sensors, or network stacks

## Git Strategy

Commit before large changes. `git push` to repository history preserves both R6 variants for future reference. Github is the source of truth — no local-only branches without commits. Older revisions remain in history for archival and debugging purposes.

## Audible ping

When a task is done, notify with an audible ping (afplay /System/Library/Sounds/Submarine.aiff -v 24)

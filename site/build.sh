#!/usr/bin/env bash
# Regenerate every generated image the site uses, then place it in site/img/.
# Every number comes from work/scripts/power_chart.py, the same source of truth as
# docs/POWER.md, so a chart and the prose cannot disagree. The 3D views are the same
# geometry as renders/, re-rendered on the site's dark scheme by cad/tools/render.py.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")

python3 "$root/work/scripts/power_chart.py" --site
python3 "$root/cad/tools/render.py" site_r5            # needs `export.py --r5` first
cp "$root/renders/site_r5_exploded.png" "$here/img/"

echo "site images rebuilt in $here/img"

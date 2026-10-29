#!/usr/bin/env bash
# Deploy the static site to ktemata.org (Transip web hosting) over scp.
# Usage: site/deploy.sh            # or: REMOTE=user@host:www/ site/deploy.sh
#
# Charts are regenerated first, so the published numbers are always the model's current
# output. Pass --no-build to deploy the files exactly as they are on disk.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
remote=${REMOTE:-ktemataorg@ktemat.ssh.transip.me:www/}

if [[ "${1:-}" != "--no-build" ]]; then
  "$here/build.sh"
fi

# scp only adds/overwrites; remove files on the host if you delete one here.
scp -q "$here"/*.html "$here/style.css" "$here/logo.svg" "$remote"
scp -qr "$here/img" "$remote"

echo "deployed to $remote"

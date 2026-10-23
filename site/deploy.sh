#!/usr/bin/env bash
# Deploy the static site to ktemata.org (Transip web hosting) over scp.
# Usage: site/deploy.sh            # or: REMOTE=user@host:www/ site/deploy.sh
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
remote=${REMOTE:-ktemataorg@ktemat.ssh.transip.me:www/}

# scp only adds/overwrites; remove files on the host if you delete one here.
scp -q "$here/index.html" "$here/style.css" "$here/logo.svg" "$remote"

echo "deployed to $remote"

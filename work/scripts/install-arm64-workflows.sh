#!/usr/bin/env bash
# Install the multi-arch (amd64 + arm64) build workflows into a Project NOMAD fork.
#
# Why this exists
# ---------------
# Upstream publishes amd64-only images, so `docker compose up` fails on a Raspberry Pi
# with "no matching manifest for linux/arm64". The images themselves are not the problem:
#
#   * the admin Dockerfile already switches on TARGETARCH and pins PMTILES_SHA256_ARM64
#   * both sidecars are FROM alpine:3.20 + apk packages, all multi-arch
#
# Only the CI never asked for arm64. These three files ask for it, on native runners, and
# push to the fork's own GHCR namespace (upstream hardcodes `crosstalk-solutions`).
#
# NOT included: build-translate-proxy.yml. Its Dockerfile says it is amd64-only by
# necessity - "Bergamot's intgemm backend is x86 specific and there is no aarch64 wheel".
# Translated Library is simply not installed on a Pi (every service defaults to
# `installed: false`).
#
# Usage, from the root of your fork:
#   bash install-arm64-workflows.sh            # copy the three workflows in
#   bash install-arm64-workflows.sh --dry-run  # show what would change
#   bash install-arm64-workflows.sh --check    # lint the local copies and exit
#
# Afterwards: commit, then Actions -> "Build Primary Docker Image" -> Run workflow.
# Build the two sidecars the same way, then point /opt/project-nomad/compose.yml at
# ghcr.io/<you>/project-nomad:1.35.1 (and the two sidecars).

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
src="$here/../patches/arm64-workflows"
files=(build-primary-image.yml build-sidecar-updater.yml build-disk-collector.yml)

mode=install
case ${1:-} in
    --dry-run) mode=dry ;;
    --check)   mode=check ;;
    "")        ;;
    *)         echo "usage: $0 [--dry-run|--check]" >&2; exit 2 ;;
esac

# --check works from anywhere: it only lints the shipped copies
if [ "$mode" = check ]; then
    command -v actionlint >/dev/null 2>&1 || { echo "actionlint not installed" >&2; exit 1; }
    actionlint "$src"/*.yml && echo "✓ actionlint clean"
    exit 0
fi

[ -d "$src" ] || { echo "✗ $src not found (are the patch files present?)" >&2; exit 1; }
wf="$PWD/.github/workflows"
[ -d "$wf" ] || { echo "✗ $wf not found - run this from the root of your fork" >&2; exit 1; }
for f in "${files[@]}"; do
    [ -f "$src/$f" ] || { echo "✗ missing patch $src/$f" >&2; exit 1; }
done

for f in "${files[@]}"; do
    if cmp -s "$src/$f" "$wf/$f"; then
        echo "· $f already up to date"
        continue
    fi
    if [ "$mode" = dry ]; then
        echo "would replace $wf/$f"
        diff -u "$wf/$f" "$src/$f" | head -40 || true
        continue
    fi
    # keep the pristine upstream copy once, so the change is easy to review or revert
    [ -f "$wf/$f.upstream" ] || cp "$wf/$f" "$wf/$f.upstream"
    cp "$src/$f" "$wf/$f"
    echo "✓ $f"
done

if [ "$mode" = install ]; then
    echo
    echo "Next:"
    echo "  1. git add .github/workflows && git commit -m 'ci: build amd64 + arm64 images'"
    echo "  2. git push, then Actions -> 'Build Primary Docker Image' -> Run workflow"
    echo "     (version = the NOMAD release you are matching, e.g. 1.35.1)"
    echo "  3. do the same for 'Build Sidecar Updater Image' and 'Build Disk Collector Image'"
    echo "  4. install NOMAD, then edit /opt/project-nomad/compose.yml to use"
    echo "     ghcr.io/<your-user>/project-nomad:1.35.1 and the two sidecars"
    if command -v actionlint >/dev/null 2>&1; then
        echo
        actionlint "$wf/${files[0]}" "$wf/${files[1]}" "$wf/${files[2]}" && echo "✓ actionlint clean"
    fi
fi

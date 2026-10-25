# arm64 build workflows for a Project NOMAD fork

Three drop-in replacements for Project NOMAD's CI, so the images build for
**linux/amd64 + linux/arm64** and publish to your own GHCR namespace.

## Why this is needed

Upstream publishes amd64-only images, so on a Pi:

```
docker compose up -d
no matching manifest for linux/arm64/v8 in the manifest list entries
```

The **images** are not the obstacle:

| Image | Note |
|---|---|
| `project-nomad` (admin) | its Dockerfile already switches on `TARGETARCH` and pins `PMTILES_SHA256_ARM64` |
| `project-nomad-sidecar-updater` | `FROM alpine:3.20` + `apk` packages (multi-arch) |
| `project-nomad-disk-collector` | `FROM alpine:3.20` + `apk` packages (multi-arch) |
| `project-nomad-translate` | **cannot work** — Bergamot's intgemm backend is x86-only, no aarch64 wheel |

Only the CI never asked for arm64. And translate is opt-in (`installed: false`), so it is
simply not installed.

## Install

From the root of your fork:

```bash
bash work/scripts/install-arm64-workflows.sh --dry-run   # preview
bash work/scripts/install-arm64-workflows.sh             # apply
git add .github/workflows && git commit -m 'ci: build amd64 + arm64 images'
git push
```

Then **Actions → Build Primary Docker Image → Run workflow** with the NOMAD version you are
matching (e.g. `1.35.1`), and the same for the two sidecars. Pushes to
`ghcr.io/<your-user>/project-nomad:<version>`.

## After building

Point the installed compose at your images:

```yaml
# /opt/project-nomad/compose.yml
admin:          image: ghcr.io/<you>/project-nomad:1.35.1
updater:        image: ghcr.io/<you>/project-nomad-sidecar-updater:1.35.1
disk-collector: image: ghcr.io/<you>/project-nomad-disk-collector:1.35.1
```

Also note the upstream installer's `check_is_x86_64` only **warns for 10 s** and continues,
so it runs on a Pi unchanged.

## What changed, and why

| Change | Reason |
|---|---|
| `platforms: ${{ matrix.platform }}` + matrix | builds amd64 on `ubuntu-latest`, arm64 on `ubuntu-24.04-arm`, then merges with `imagetools create` |
| per-digest push, then manifest merge | one multi-arch tag serving both architectures |
| `IMAGE: ghcr.io/${{ github.repository }}` | upstream hardcodes `crosstalk-solutions`, which a fork cannot push to |
| authorization gate falls open when the secret is unset | the upstream gate reads `DEPLOYMENT_AUTHORIZED_USERS`, absent in a fork, so every build would be skipped |
| `--tag` flags, built in bash | `imagetools create` treats positional arguments as SOURCES; passing tags positionally fails with `can't push with no tags specified`. Building the list in bash also avoids an empty `:latest` argv entry |

## Caveats

- **`ubuntu-24.04-arm` is free for public repositories.** On a private fork, set the arm64
  matrix row to `runner: ubuntu-latest` and add `docker/setup-qemu-action@v3` before the
  build step — same result, much slower.
- **`sharp` and `better-sqlite3`** are the native modules in the admin image. Both ship
  arm64 prebuilds, but a QEMU build can occasionally fetch the wrong one; if the image builds
  and then crashes on start, look there first.
- **`release.yml`** still rewrites the repo through upstream's `COSMISTACKBOT_ACCESS_TOKEN`
  and references upstream's image names. Do not run it in a fork.
- This is a **fork-local workaround**. Upstream has said ARM64 is being built in-house with
  Pi 5 test hardware (PR #419, Oct 2026); when that ships, drop these files and resync.

## Verified

- `actionlint` clean on all three files.
- Installed into a clean clone of the fork; `git diff` is only the intended change.
- The manifest-merge shell was executed with 1 and 2 digest files, with `tag_latest` both
  false and true: correct `--tag` list every time, no empty argument, junk files in the
  digests directory ignored.
- The exact merge command was dry-run against real alpine amd64 + arm64 digests and
  produced a correct two-platform index.

### Fixed after the first real run

The first build on the fork failed at the merge step with:

```
ERROR: can't push with no tags specified, please set --tag or --dry-run
```

The tags were passed positionally, which `imagetools create` reads as SOURCES. Only the two
platform builds had succeeded - they pushed untagged digests, so the package had no tags at
all and `tags: null` in the registry. That is why pulling the index gave an amd64-only
attestation index.

**Not verified:** an actual `docker buildx` run on GitHub runners. The workflow logic and
shell are tested; the arm64 build itself has not been executed.

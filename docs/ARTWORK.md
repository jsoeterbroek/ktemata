# Desktop artwork: wallpaper and boot splash

[`work/scripts/desktop-artwork.sh`](../work/scripts/desktop-artwork.sh) installs the Ktemata
wallpaper and the early boot logo. It is a **separate step after**
[`post-install.sh`](POST_INSTALL.md) and runs at **runlevel 5** — `graphical.target`:

```bash
sudo ./work/scripts/desktop-artwork.sh                  # logo + splash, now
sudo ./work/scripts/desktop-artwork.sh --no-splash      # wallpaper only
sudo ./work/scripts/desktop-artwork.sh --no-wallpaper   # splash only
sudo ./work/scripts/desktop-artwork.sh --user ktemata   # other desktop account
sudo ./work/scripts/desktop-artwork.sh --wait 120       # wait for the session bus
./work/scripts/desktop-artwork.sh --dry-run             # print, change nothing
```

`post-install.sh` installs the script as `/usr/local/lib/ktemata/desktop-artwork.sh`, copies
its assets to `/usr/local/share/ktemata/src/`, and enables
**`ktemata-artwork.service`** (`Type=oneshot`, `WantedBy=graphical.target`,
`ExecStart=… --user ktemata --wait 120`). It is **enabled, not started**, so the install cannot
block on the desktop session. The first run happens at the next boot; the unit is conditioned on
the marker `/usr/local/share/ktemata/.artwork-applied`, which the script writes only after a
complete run, so the TGA is not re-rendered on every boot. A manual `--no-splash` or
`--no-wallpaper` run does not write it, so the unit still finishes the other step; a missing
render tool or a failed conversion also leaves it absent and the unit retries at the next boot.

To apply a changed logo later:

```bash
sudo rm /usr/local/share/ktemata/.artwork-applied
sudo systemctl start ktemata-artwork      # or run the script directly, which ignores the marker
```

Why it is not in `post-install.sh`: applying the wallpaper goes through the desktop user's
D-Bus session. Post-install is often run over SSH in a text console, where that `gsettings` call
can block — which is how it hung. The script therefore:

- refuses to apply the wallpaper without a session bus instead of waiting on one; `--wait N`
  polls the bus first, which is what the unit uses because autologin can lag `graphical.target`
  by a few seconds;
- wraps every external command in `timeout` (30 s, 180 s for the initramfs, 300 s for the
  package install);
- writes the desktop configuration either way, so the next login still picks the image up.

Run it as root (`sudo`); it determines the desktop account from `$SUDO_USER`, falling back to
the logged-in user and then `ktemata`, and can be overridden with `--user`.

## Wallpaper

The Ktemata mark on black, from [`docs/ktemata-wallpaper.svg`](../docs/ktemata-wallpaper.svg) —
a plain 1920×1080 black field, the open-book mark at 18 % opacity, the `KTEMATA` wordmark and
`κτῆμα ἐς ἀεί`.

It is rendered to `/usr/local/share/ktemata/ktemata-wallpaper.png` and copied to
`~/.local/share/ktemata/`, then applied through whichever stack the desktop uses:

| Desktop | Mechanism |
|---|---|
| Raspberry Pi OS (labwc/pcmanfm) | `~/.config/pcmanfm/LXDE-pi/desktop-items-0.conf` (`wallpaper=`, `wallpaper_mode=crop`, `desktop_bg=#000000`) + `pcmanfm --set-wallpaper` for the live session |
| GNOME | `gsettings org.gnome.desktop.background picture-uri` **and** `picture-uri-dark` (a dark theme otherwise keeps its own image), `picture-options=scaled` |
| minimal X11 | `feh --bg-fill` from an autostart entry |

On GNOME the live apply uses the real session bus
(`unix:path=/run/user/<uid>/bus`), not a private `dbus-run-session`; a private bus is what made
the old step hang. If the account has no session (SSH only, no login), the step logs
`no session bus … re-run from the desktop` and stops there.

## Boot splash

Raspberry Pi OS shows two splashes; this replaces the **early firmware one**. The supported
mechanism is Raspberry Pi's
[rpi-splash-screen-support](https://github.com/raspberrypi/rpi-splash-screen-support), and its
constraints are strict: a **24-bit TGA**, at most **1920 × 1080**, at most **224 colours**.

The script renders [`docs/ktemata-splash.svg`](../docs/ktemata-splash.svg) at run time —
`rsvg-convert` then ImageMagick (7's `magick` on Debian, 6's `convert` on Ubuntu) — quantises to
224 colours, and writes a 24-bit RGB TGA, so an updated logo propagates without committing a
6 MB bitmap. It then:

1. copies the TGA to `/lib/firmware/logo.tga` and installs the initramfs hook, rebuilding the
   initramfs
2. adds `fullscreen_logo=1 fullscreen_logo_name=logo.tga vt.global_cursor_default=0` to
   `cmdline.txt` (idempotent, single line, `.ktemata.bak` kept once)
3. uses `/usr/bin/configure-splash` directly when that package is installed

The script installs `librsvg2-bin`, `imagemagick` and `file` when they are missing (apt, root
only); with both steps disabled it installs nothing.

**Orientation.** `configure-splash` rejects either axis above 1080, so a portrait splash cannot
be 1080×1920; portrait renders at **608×1080** from
[`docs/ktemata-splash-portrait.svg`](../docs/ktemata-splash-portrait.svg), a separate file with
an upright layout (rotating the landscape artwork leaves the text sideways). The Touch Display 2
is natively 720×1280, so if the splash appears rotated relative to the case, use
`--splash-orientation portrait`.

Notes:

- The **rainbow square** before the firmware logo is separate: add `disable_splash=1` to
  `/boot/firmware/config.txt` to hide it (the script only hints at this).
- **Plymouth** draws the second splash and keeps its own theme background.
- Only the early splash is a static image; the console rotation from `post-install.sh --rotate`
  applies after it.
- Nothing changes on a machine with no `/boot/firmware/cmdline.txt`. `CMDLINE_FILE` overrides
  the path for tests.

## Options and environment

```text
-y, --yes                 accepted; nothing is interactive
-n, --dry-run             print commands, run nothing (no root needed)
    --user NAME           desktop account for the wallpaper (default: sudo user)
    --wallpaper [FILE]    set the background (default), optionally from FILE
    --no-wallpaper        leave the desktop background alone
    --splash [FILE]       install the boot splash (default), optionally from a 24-bit TGA
    --no-splash           leave the boot splash alone
    --splash-orientation  landscape (default) or portrait (608x1080)
    --wait SECONDS        wait for the desktop user's session bus before applying
-h, --help / -V, --version
```

`WALLPAPER_SRC`, `SPLASH_SRC`, `SPLASH_ORIENTATION`, `CMDLINE_FILE` and `NO_COLOR` can be set in
the environment.

## Verified

The code was exercised before the split, from a clean `debian:trixie` container: both artwork
steps completed, the wallpaper rendered at 1920×1080 and the splash came out as
`Targa image data - RGB 1920 x 1080 x 24` with 102 colours. Package selection was checked for
each flag combination; after the split the script itself installs the missing tools, and
`--dry-run` shows the same commands without touching anything.

Both orientations were run through the real renderer: landscape `RGB 1920 x 1080 x 24` (104
colours), portrait `RGB 608 x 1080 x 24` (102 colours); a bad value is rejected before any work
starts. The rendered TGA was converted back to PNG and inspected — the artwork is centred with
upright text in both.

The wallpaper and splash steps were run end-to-end on **Debian 13** and **Ubuntu 24.04**
containers: the pcmanfm config points at the per-user PNG with `desktop_bg=#000000`, and
`cmdline.txt` stays one line and holds both the rotation and the splash parameters after two
consecutive runs with no duplicates.

After the split, both paths were exercised against a sandboxed `HOME`/`PATH` (shimmed `getent`,
`timeout`, `sudo`, `pcmanfm`, ImageMagick and `file`): the wallpaper was installed to the
per-user path and the pcmanfm config written with `wallpaper_mode=crop` and
`desktop_bg=#000000`; `cmdline.txt` gained the three parameters once, stayed one line, and a
second run reported "already enables the splash" while keeping a single `.ktemata.bak`. The
installed layout was run the same way with only `/usr/local/share/ktemata/src` available, so the
asset lookup fell back to the installed copy, and the completion marker was written. A
`--no-splash` run and a run without ImageMagick both left the marker absent, as intended. The
generated unit was inspected: it is a `graphical.target` oneshot with the marker condition, the
autologin user and `--wait 120`. It has not been started by systemd on real hardware yet.

The **session-bus path** (the reason for the split) is the one part not exercised on real
hardware: the container runs used a written pcmanfm config. The live `gsettings`/`pcmanfm` apply
still needs a run on the Touch Display 2 with the `ktemata` desktop logged in.

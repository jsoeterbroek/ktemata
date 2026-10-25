# Post-install (Ubuntu / Raspberry Pi OS)

[`work/scripts/post-install.sh`](../work/scripts/post-install.sh) prepares a fresh **Raspberry Pi OS (Debian 13
trixie)** install for the Ktemata build. Ubuntu 24.04 and plain Debian 13 are also supported, and each step
degrades to a SKIP where the platform differs.

The reference target is the image as flashed: **Raspberry Pi OS Lite or Desktop, trixie, user `ktemata`,
password `ktemata`, ssh-server enabled**. Nothing here needs a second account, and the script does not touch an
existing user's password.

```bash
sudo ./work/scripts/post-install.sh                  # update, install Kiwix, enable the service
sudo ./work/scripts/post-install.sh --rotate left    # + turn the Touch Display 2 90° left
sudo ./work/scripts/post-install.sh --sample         # + fetch one small ZIM to test with
./work/scripts/post-install.sh --dry-run             # show the commands, change nothing
```

Inspired by [`after-effects`](https://github.com/tprasadtp/ubuntu-post-install) but deliberately small: one
file, no YAML config, no whiptail menu. Idempotent — safe to re-run.

## What it does, in order

| Step | Action | Flag |
|---|---|---|
| 1 | Platform check: Debian/Ubuntu derivative, warns on untested arch | — |
| 2 | **Hardware checks** — see below; runs *before* anything is changed | `--no-hwtest`, `--hwtest-only`, `--strict` |
| 3 | **System update**: `apt-get update` then a non-interactive `full-upgrade` (keeps existing conffiles) | `--no-update` |
| 4 | Install `kiwix-tools`, `curl`, `ca-certificates`, the `kiwix` desktop app; `librsvg2-bin` + `imagemagick` for the artwork, `i2c-tools` for the hardware report | `--no-gui`, `--no-splash`/`--no-wallpaper` |
| 5 | Create `/srv/kiwix/zim` and the `kiwix` system user | — |
| 6 | Write and enable `kiwix.service` (`kiwix-serve` on :8080) | `--no-service` |
| 7 | Set the display rotation | `--rotate left\|right\|inverted\|normal` |
| 8 | Optionally install the kiosk launcher + autostart | `--kiosk` |
| 9 | Enable GDM automatic login for the `ktemata` account | `--no-autologin`, `--autologin-user` |
| 11 | Replaces the early boot splash with the logo | `--no-splash`, `--splash [FILE]` |
| 12 | Optionally download a sample ZIM and confirm the server answers | `--sample` |

The update runs **first** so the later package install needs no second upgrade pass, and a fresh image does
not get a Kiwix build that is already superseded.

## Display rotation

The Touch Display 2 is **720 × 1280 natively (portrait)**; the r4 case mounts it in landscape, so a new
install usually needs a rotation.

`--rotate left` means **90° counter-clockwise** (what "turn the screen left" means to a person). The kernel
takes clockwise degrees, so the script maps it:

| You ask for | Kernel value | Screen result |
|---|---|---|
| `left` | `rotate=270` | 90° counter-clockwise |
| `right` | `rotate=90` | 90° clockwise |
| `inverted` | `rotate=180` | upside down |
| `normal` | `rotate=0` | native portrait |

Two separate things are rotated, because on Raspberry Pi OS they are separate:

1. **Console / kiosk** — one line in `/boot/firmware/cmdline.txt`:

   ```
   video=DSI-1:720x1280@60,rotate=270
   ```

   The script appends it, or rewrites an existing `video=DSI-1:…` entry in place, and keeps a
   `cmdline.txt.ktemata.bak`. Running it again is a no-op.
2. **Desktop session** — `wlr-randr --output <DSI-1> --transform <90|180|270|normal>`. This is per session,
   so after a reboot use *Preferences → Screen Configuration → DSI-1 → Orientation*, or re-run with
   `--rotate`.

Notes:

* Only the **text console** follows `rotate=`; apps that write straight to DRM (VLC, libcamera) need their
  own rotation option.
* With **multiple displays**, `cmdline.txt` rotates all of them — use the desktop tool instead.
* On a non-Pi Ubuntu box there is no `/boot/firmware/cmdline.txt`; the step logs and moves on.
* Rotation is per display, not per case: if you print a different face the display sits in, change it.

## Hardware checks

They run **first**, so the report describes the machine as it arrived rather than after an upgrade.

```bash
sudo ./work/scripts/post-install.sh --hwtest-only   # report only, change nothing, no root needed
sudo ./work/scripts/post-install.sh --no-hwtest     # skip them
sudo ./work/scripts/post-install.sh --strict        # exit 1 if any check failed
```

| Check | PASS / FAIL / SKIP | Notes |
|---|---|---|
| **Pi model** | model string from `/proc/device-tree/model` | SKIP on non-Pi hardware |
| **SoC temperature** | 5 samples + actual CPU busy %; PASS < 80 °C | **WARN** ≥ 80/85 °C under load. **FAIL** if ≥ 85 °C while the CPU is idle — that is not the missing cooler |
| **Throttle flags** | `vcgencmd get_throttled` = `0x0` | **FAIL only on undervoltage** (bits 0/16) — a supply fault. Thermal/clock bits are WARN |
| **DSI display** | a `card*-DSI-*` connector with `status=connected` | reports the connector (`DSI-1`) and active mode (720×1280 for the TD2) |
| **I2C devices** | one line naming the build's chips: `0x3c (OLED), 0x42 (UPS INA219), 0x68 (DS3231)` | unknown addresses are only **counted**, not listed; SKIP when nothing replies (the **FireBeetle** is the I2C master). Buses that answer for nearly every address are **ignored** and named |
| **UPS gauge** | INA219 at 0x42 visible | SKIP on the Pi itself; the gauge is read by the ESP32 |
| **Pi RTC** | `/dev/rtc0` with a sane epoch | FAIL if the cell is flat/unset; hints at `dtparam=rtc_bbat_vchg=3000000` |
| **Storage** | ≥ 2 GB free on `/`, and the ZIM library not empty | FAIL on an empty library, because `kiwix-serve` will not start |
| **Network** | any interface `up` | SKIP when none — normal, Wi-Fi/LAN are off |
| **Port** | 8080 listening | informational only |

Checks never block the install: findings are counted and reported. `--strict` fails the run on a **fault**
(undervoltage), not on a **warning** (heat). `--hwtest-only` prints the report and exits without touching the
system.

### Heat is expected here

There is **no cooler in this build** — the UPS HAT (B) occupies the Pi's component side, so neither the Active
Cooler nor a heatsink fits (see `R4.md`). The Pi 5's soft limit is 80 °C and its hard limit 85 °C, so a bare
board under load sits at 85 °C and throttles. That is the design, not a defect: the check reports it as a
warning with the load average, and only treats **undervoltage** as a fault.

The check measures **actual CPU busy time** (two `/proc/stat` samples), not load average, so it can tell the
two causes apart:

| Reading | Verdict |
|---|---|
| ≥ 85 °C, CPU busy | **WARN** — expected: no cooler, it throttles instead of failing |
| ≥ 85 °C, CPU idle | **FAIL** — a bare Pi 5 idles 55–70 °C, so the heat is not from load |
| 80–85 °C, idle | **WARN** — warm for idle |
| < 80 °C | **PASS** |

On a FAIL or WARN it lists the processes using ≥ 10 % CPU, so "something is pegged" is visible rather than
implied. If an idle board is hot with nothing running, look for clearance under the board, a heat trap
(case, desk, insulation), or a process that is busy in short bursts the sample missed.

### Power path

The Pi **cannot detect the UPS HAT (B)**: its INA219 gauge is on the FireBeetle's I²C bus, so nothing on the
Pi side reports it. Tell the script which supply you are using:

```bash
sudo ./work/scripts/post-install.sh --hwtest-only --power usbc   # default: bench, USB-C only
sudo ./work/scripts/post-install.sh --hwtest-only --power hat    # in the case, on the HAT
```

It only changes the wording of an undervoltage hint — USB-C points at the 27 W supply and cable, `hat` points
at the pogo pins and the 8.4 V input. On the 27 W supply an undervoltage flag should never appear; if it does,
suspect the cable or the connector rather than the PSU.

## Desktop background

The Ktemata mark on black, from [`docs/ktemata-wallpaper.svg`](../docs/ktemata-wallpaper.svg) — a plain
1920×1080 black field, the open-book mark at 18 % opacity, the `KTEMATA` wordmark and `κτῆμα ἐς ἀεί`.

It is installed to `/usr/local/share/ktemata/ktemata-wallpaper.png` and a per-user copy under
`~/.local/share/ktemata/`, then applied through whichever stack the desktop uses:

| Desktop | Mechanism |
|---|---|
| Raspberry Pi OS (labwc/pcmanfm) | `~/.config/pcmanfm/LXDE-pi/desktop-items-0.conf` (`wallpaper=`, `wallpaper_mode=crop`, `desktop_bg=#000000`) + `pcmanfm --set-wallpaper` for the live session |
| GNOME | `gsettings org.gnome.desktop.background picture-uri` **and** `picture-uri-dark` (a dark theme otherwise keeps its own image), `picture-options=scaled` |
| minimal X11 | `feh --bg-fill` from an autostart entry |

```bash
sudo ./work/scripts/post-install.sh --wallpaper            # default logo
sudo ./work/scripts/post-install.sh --wallpaper mine.png   # your own image
sudo ./work/scripts/post-install.sh --no-wallpaper
```

## Boot splash

Raspberry Pi OS shows two splashes; this replaces the **early firmware one**. The supported mechanism is
Raspberry Pi's [rpi-splash-screen-support](https://github.com/raspberrypi/rpi-splash-screen-support), and its
constraints are strict: a **24-bit TGA**, at most **1920 × 1080**, at most **224 colours**.

The script renders [`docs/ktemata-splash.svg`](../docs/ktemata-splash.svg) at install time — `rsvg-convert`
then ImageMagick (7's `magick` on Debian, 6's `convert` on Ubuntu) — quantises to 224 colours, and writes a
24-bit RGB TGA, so an updated logo propagates without committing a 6 MB bitmap.

Both packages are installed by the script when either artwork step is enabled (`librsvg2-bin`,
`imagemagick`, plus `file` to verify the TGA); with `--no-splash --no-wallpaper` they are not pulled in at all.
It then:

1. copies the TGA to `/lib/firmware/logo.tga` and installs the initramfs hook, rebuilding the initramfs
2. adds `fullscreen_logo=1 fullscreen_logo_name=logo.tga vt.global_cursor_default=0` to `cmdline.txt`
   (idempotent, single line, `.ktemata.bak` kept once)
3. uses `/usr/bin/configure-splash` directly when that package is installed

```bash
sudo ./work/scripts/post-install.sh --splash                         # default logo (landscape)
sudo ./work/scripts/post-install.sh --splash --splash-orientation portrait
sudo ./work/scripts/post-install.sh --splash logo.tga                # your own TGA
sudo ./work/scripts/post-install.sh --no-splash
```

**Orientation.** `configure-splash` rejects either axis above 1080, so a portrait splash cannot be
1080×1920; portrait renders at **608×1080** from
[`docs/ktemata-splash-portrait.svg`](../docs/ktemata-splash-portrait.svg), a separate file with an upright
layout (rotating the landscape artwork leaves the text sideways). The Touch Display 2 is natively 720×1280,
so if the splash appears rotated relative to the case, switch to `--splash-orientation portrait`.

Notes:

- The **rainbow square** before the firmware logo is separate: add `disable_splash=1` to
  `/boot/firmware/config.txt` to hide it (the script only hints at this).
- **Plymouth** draws the second splash and keeps its own theme background.
- Only the early splash is a static image; the console rotation from `--rotate` applies after it.
- Nothing changes on a machine with no `/boot/firmware/cmdline.txt`.

## Autologin

The device is a single-purpose appliance: it should come up in the library without a password prompt.

**The display manager decides how**, and Raspberry Pi OS and Ubuntu use different ones — writing the wrong
file looks successful and does nothing:

| Platform | Display manager | Setting |
|---|---|---|
| **Raspberry Pi OS (trixie)** | **LightDM** | `autologin-user=ktemata` in `/etc/lightdm/lightdm.conf` `[Seat:*]` |
| Ubuntu (GNOME) | GDM | `AutomaticLoginEnable=true` + `AutomaticLogin=ktemata` in `/etc/gdm3/custom.conf` |

The script detects which is present and uses the matching mechanism; LightDM also wins if both are
installed, which is the Pi OS case. The LightDM edit is the same one `raspi-config`'s **B4 Desktop Autologin**
performs, so a manual `sudo raspi-config` afterwards agrees with it rather than fighting it.

Details:

- **Only the keys it owns are touched.** The LightDM file is largely commented defaults
  (`#autologin-user=`), which are enabled in place; everything else (`greeter-session`,
  `xserver-command`, …) is left alone. A `.ktemata.bak` copy is kept once.
- **An existing account is never modified.** On the flashed Pi OS image `ktemata` already exists with a
  password; the script only creates the user when it is missing (and then warns to set a password). It does
  **not** lock the account, because you log in with it over ssh.
- The **kiosk autostart follows this account** — `--kiosk` defaults `KIOSK_USER` to the autologin user, so
  the two cannot drift apart.
- A missing desktop environment is called out, since autologin without one just opens a text console.
- No LightDM or GDM at all (Lite image): the step skips and points at console autologin instead.

```bash
sudo ./work/scripts/post-install.sh --autologin-user ktemata   # default
sudo ./work/scripts/post-install.sh --no-autologin             # leave the login screen
```

If you already log in as another user and want the kiosk there instead, pass `--kiosk-user` and
`--autologin-user` the same name.

## Kiosk

`--kiosk` installs [`kiwix-kiosk.sh`](../work/scripts/kiwix-kiosk.sh) as `/usr/local/bin/kiwix-kiosk` and
adds `~/.config/autostart/kiwix-kiosk.desktop` for the desktop user (`--kiosk-user`, or the user who ran
`sudo`). On login the device comes up straight in the library.

```bash
kiwix-kiosk                 # start now
kiwix-kiosk --selftest      # what will it use? exit 0 = ready, 1 = not
kiwix-kiosk --app kiwix     # native kiwix-desktop instead of a browser
kiwix-kiosk --url URL       # show something else
kiwix-kiosk --stop
```

### Chromium needs a HOME and writable XDG dirs

An autostart entry (or `su -c`, or a systemd user unit) can run the kiosk with **`HOME` unset**. Chromium then
resolves every helper path to the empty string and dies before the first window:

```
chrome_crashpad_handler: --database is required
... mkdir : No such file or directory (2)
... FATAL:base/path_service.cc Failed to get the path for 1001
```

The launcher now:

- recovers `HOME` from the account database (`getent passwd $(id -u)`) before anything else
- exports and creates `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`
- gives Chromium a **private profile** (`--user-data-dir=$XDG_DATA_HOME/ktemata/kiosk-profile`) so it never
  fights the default profile, and an explicit, pre-created **crash directory**
  (`--crash-dumps-dir=$XDG_CACHE_HOME/ktemata/crash --disable-crash-reporter`)
- the autostart entry runs it through a login shell (`/bin/sh -lc`) so the session environment is complete

`--selftest` prints the user, `HOME`, and whether each XDG directory is writable, so this class of failure is
visible before the screen goes black.

What it does on start:

1. refuses to run without `DISPLAY`/`WAYLAND_DISPLAY` (a browser with no session is a black screen)
2. turns off blanking — `xset s off`, `-dpms`, `s noblank` on X11; `wlopm --on` on Wayland, noting that
   the reliable Wayland switch is the compositor's own idle setting
3. optionally rotates the output with `wlr-randr --transform DEG` (post-install passes the same angle as
   `--rotate`)
4. waits up to `KIOSK_WAIT` s for `kiwix-serve`, then starts the browser:
   `chromium --kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble --no-first-run
   --start-fullscreen --app=URL`, falling back to `chromium-browser`, `firefox --kiosk`, or
   `epiphany-browser --application-mode`
5. logs to `${XDG_STATE_HOME:-~/.local/state}/ktemata/kiosk.log`, so a black screen has a paper trail

A missing server is **not** fatal: the browser shows an error page and the log says why, which beats a
window that never appears.

## kiwix-serve

The unit runs as the unprivileged `kiwix` user and is hardened (`NoNewPrivileges`, `ProtectSystem=strict`,
read-only library). It carries

```
ConditionPathExistsGlob=/srv/kiwix/zim/*.zim
```

so on a fresh install with an empty library it stays inactive instead of failing in a restart loop. Drop ZIMs
in and `systemctl restart kiwix`.

The service user must be able to read the archives, so the script sets the library group to `kiwix` with
`g+rX` — and repeats that after the `--sample` download, which otherwise lands `root:root` and is invisible
to the service.

```bash
systemctl status kiwix
journalctl -u kiwix -f
curl -sI http://localhost:8080/ | head -1
```

Override the location with `--zim-dir` and the port with `--port`; both are also honoured in the unit.

## Where the ZIMs come from

<https://download.kiwix.org/zim/> — the same library the device itself carries (see [`../zim/zim.md`](../zim/zim.md)).
The `--sample` download is `wikiciv_en_all_maxi_2025-11.zim` (4.4 MB, civil-defence wiki), small enough to
fetch on a metered link. Override with `SAMPLE_ZIM=…`.

Mind the disk: the full English Wikipedia `maxi` archive is ~119 GB, Gutenberg `mul_all` ~254 GB.

## Options and environment

```text
-y, --yes              no confirmation prompt
-n, --dry-run          print commands, run nothing (no root needed)
    --sample           download one small ZIM
    --zim-dir DIR      library directory (default /srv/kiwix/zim)
    --port PORT        kiwix-serve port (default 8080)
    --no-service       packages only
    --no-gui           skip the desktop app
    --no-update        skip the system upgrade
    --rotate WHAT      normal | left | right | inverted (or 0|90|180|270 clockwise)
    --kiosk            install the kiosk launcher + autostart
    --kiosk-user NAME  desktop user to autostart it for (default: the sudo user)
    --no-hwtest        skip the hardware checks
    --hwtest-only      run the hardware checks and exit
    --strict           non-zero exit when a hardware check fails (not on warnings)
    --power usbc|hat   supply in use, for the diagnostic hints (default usbc)
    --no-wallpaper     leave the desktop background alone
    --wallpaper [FILE] set it (default), optionally from FILE
    --no-splash        leave the boot splash alone
    --splash [FILE]    replace the boot splash, optionally from a 24-bit TGA
    --no-autologin     leave the GDM login screen
    --autologin-user N account to log in automatically (default ktemata)
-h, --help / -V, --version
```

`ZIM_DIR`, `SERVICE_PORT`, `SERVICE_USER`, `SAMPLE_ZIM`, `ROTATE`, `NO_COLOR` and `CMDLINE_FILE` (test hook)
can be set in the environment.

## Verified

Run inside `ubuntu:24.04` (amd64): dry run, then a real install with `--yes --sample --no-gui`. `kiwix-tools
3.5.0` installed, the sample ZIM downloaded, and a throwaway `kiwix-serve` answered on :9080. On the host
(Arch) the platform check correctly refuses. A re-run is idempotent ("already exists", "already the newest
version"), the generated unit was inspected, and the service user was confirmed able to read the archive
(`head -c4` returns the `ZIM\x04` magic).

Rotation was exercised against synthetic `cmdline.txt` copies: append to a file without a trailing newline,
replace an existing `rotate=0`, and a repeat run reporting "already set".

The hardware report was tested inside the same container (correct SKIPs for a non-Pi machine) and with the
Pi-only branches forced in a harness: a fake Pi model PASSes, a missing `vcgencmd` SKIPs, an unset RTC FAILs
("cell flat or unset"), a sane `/dev/rtc0` PASSes, an empty ZIM library FAILs and a populated one reports
`1 archive(s), 4.5M`. Step order was confirmed from the `==>` lines: Platform → Hardware → System update →
Packages → Library → Service → Rotation → Kiosk.

Autologin was tested against real-shaped configs in a container. **LightDM** (the Pi OS path): the commented
`#autologin-user=` in a stock `[Seat:*]` block is enabled in place, `greeter-session` and
`xserver-command` survive, and when both a LightDM and a GDM file exist LightDM is chosen and the GDM file is
left untouched. **GDM** (Ubuntu): insert into a stock `custom.conf`, replace an existing
`AutomaticLoginEnable=false` / `AutomaticLogin=pi`, append a missing `[daemon]` section to a config that only
had `[security]`, and the Debian layout where only `daemon.conf` exists. Each case leaves the other sections
intact and keeps a backup identical to the original.

Both orientations were run through the real script: landscape gives `RGB 1920 x 1080 x 24` (104 colours),
portrait `RGB 608 x 1080 x 24` (102 colours), and a bad value is rejected before any work starts. The rendered
TGA was converted back to PNG and inspected — the artwork is centred with upright text in both.

From a clean `debian:trixie` container the script installs its own dependencies and completes both artwork
steps: wallpaper rendered at 1920×1080, splash `RGB 1920 x 1080 x 24`. Package selection was checked for each
flag combination — default pulls librsvg2-bin/imagemagick/file, `--no-splash` still pulls them for the
wallpaper, `--no-splash --no-wallpaper` pulls neither.

The wallpaper and splash steps were run end-to-end on both **Debian 13** and **Ubuntu 24.04** containers: the
pcmanfm config points at the per-user PNG with `desktop_bg=#000000`; the splash comes out as
`Targa image data - RGB 1920 x 1080 x 24` with 102 colours; `cmdline.txt` stays one line and holds both the
rotation and the splash parameters after two consecutive runs with no duplicates.

The Chromium start was reproduced with `HOME` unset in a Debian container: after the fix the profile and
crash directories are created and Chromium launches (the only remaining complaint there is the container's
missing `chromium-sandbox`, which is unrelated).

The kiosk path was tested the same way: `/usr/local/bin/kiwix-kiosk` installed, the autostart entry written
with `Exec=/usr/local/bin/kiwix-kiosk --transform 270`, and the launcher's `--selftest` returning 0 against a
live server and 1 without one.

**On real hardware** (Debian 13 trixie, Pi 5 Rev 1.1): model, serial, display `DSI-1 (720x1280)`, RTC
holding a sane time, microSD storage and network all PASS; SoC 58–60 °C at idle with the 27 W supply and no
throttle flags.

Not covered: arm64 was checked only at the package level (Ubuntu publishes `kiwix`, `kiwix-tools` and
`zim-tools` for arm64 in noble), and the desktop `wlr-randr` path has not been run on real Wayland hardware.

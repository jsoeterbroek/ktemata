# Post-install (Ubuntu / Raspberry Pi OS)

[`work/scripts/post-install.sh`](../work/scripts/post-install.sh) prepares a fresh Ubuntu or Raspberry Pi OS
install for the Ktemata build.

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
| 4 | Install `kiwix-tools`, `curl`, `ca-certificates`, the `kiwix` desktop app | `--no-gui` |
| 5 | Create `/srv/kiwix/zim` and the `kiwix` system user | — |
| 6 | Write and enable `kiwix.service` (`kiwix-serve` on :8080) | `--no-service` |
| 7 | Set the display rotation | `--rotate left\|right\|inverted\|normal` |
| 8 | Optionally install the kiosk launcher + autostart | `--kiosk` |
| 9 | Optionally download a sample ZIM and confirm the server answers | `--sample` |

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
| **Throttling** | `vcgencmd get_throttled` = `0x0` | FAIL names undervoltage/thermal events; needs `libraspberrypi-bin` |
| **SoC temperature** | `vcgencmd measure_temp` < 80 °C | FAIL above, which is where the Pi starts throttling |
| **DSI display** | a `card*-DSI-*` connector with `status=connected` | reports the active mode (720×1280 for the TD2) |
| **I2C buses** | lists what each bus answers | SKIP when no device replies — expected, the **FireBeetle** is the I2C master in this build |
| **Expected addresses** | 0x42 UPS INA219, 0x3C/0x3D OLED, 0x68 DS3231, 0x76/0x77 BME688 | only PASS lines for addresses actually seen |
| **UPS gauge** | INA219 at 0x42 visible | SKIP on the Pi itself; the gauge is read by the ESP32 |
| **Pi RTC** | `/dev/rtc0` with a sane epoch | FAIL if the cell is flat/unset; hints at `dtparam=rtc_bbat_vchg=3000000` |
| **Storage** | ≥ 2 GB free on `/`, and the ZIM library not empty | FAIL on an empty library, because `kiwix-serve` will not start |
| **Network** | any interface `up` | SKIP when none — normal, Wi-Fi/LAN are off |
| **Port** | 8080 listening | informational only |

Checks never block the install: findings are counted and reported, and only `--strict` turns them into a
non-zero exit. `--hwtest-only` prints the report and exits without touching the system.

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
    --strict           non-zero exit when a hardware check fails
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

The kiosk path was tested the same way: `/usr/local/bin/kiwix-kiosk` installed, the autostart entry written
with `Exec=/usr/local/bin/kiwix-kiosk --transform 270`, and the launcher's `--selftest` returning 0 against a
live server and 1 without one.

Not covered: arm64 was checked only at the package level (Ubuntu publishes `kiwix`, `kiwix-tools` and
`zim-tools` for arm64 in noble), and the desktop `wlr-randr` path has not been run on real Wayland hardware.

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

## Library hotspot

The Pi 5 has a dual-band 2.4/5 GHz radio on board, so serving the library to a room is a
configuration choice, not hardware. This is the same function the commercial Prepper Disk ships
with; it costs about **0.4 W** (estimated), which is why it is worth having.

```bash
sudo ./work/scripts/post-install.sh --hotspot --hotspot-pass 'somepassphrase'
sudo ./work/scripts/post-install.sh --hotspot --hotspot-open --hotspot-ssid Ktemata
sudo ./work/scripts/post-install.sh --hotspot --hotspot-band 2.4   # older e-readers
```

Clients join the network and browse `http://10.10.10.1:8080/` (or any hostname — DNS answers
everything with the box's address). Defaults: SSID `Ktemata`, **open network**, `10.10.10.1/24`,
dual-band.

| Flag | Meaning |
|---|---|
| `--hotspot` | create the AP (default: off, so a fresh image keeps the old behaviour) |
| `--no-hotspot` | explicitly do not create one |
| `--no-radio` | disable the on-board radios in the firmware — the real off switch; see below |
| `--hotspot-ssid N` | network name (default `Ktemata`) |
| `--hotspot-pass P` | WPA2 passphrase, **8+ characters**; the script refuses shorter ones |
| `--hotspot-open` | leave it open even if a password was configured |
| `--hotspot-band auto\|2.4\|5` | pin the band; `2.4` also serves devices with no 5 GHz radio |
| `--hotspot-addr A` | AP address (default `10.10.10.1`) |

How it is implemented:

- **NetworkManager first.** Present on Raspberry Pi OS Bookworm+ and Ubuntu desktop, so the
  installer creates a self-contained `nmcli` profile (`802-11-wireless.mode ap`,
  `ipv4.method shared`). DHCP and DNS come from NetworkManager's own dnsmasq; nothing else is
  installed, and the profile survives reboots and `apt` upgrades.
- **hostapd + dnsmasq otherwise.** For images without NetworkManager, it writes
  `/etc/hostapd/hostapd.conf` (mode 0600) and `/etc/dnsmasq.d/ktemata-hotspot.conf` and enables
  both units.
- **No routing.** `ipv4.ip-forward 0` stops `method shared` from NATing clients onto whatever
  uplink is present. The AP serves this box and nothing beyond it — an appliance that silently
  becomes a router on a hotel or office LAN is a worse failure than not routing.
- **Idempotent.** An existing profile with the same SSID is left untouched, so re-running the
  installer never resets a password.
- **Verified, not assumed.** The step brings the AP up and then fetches
  `http://<addr>:8080/` to prove the library answers over that interface.

Turning it off again:

```bash
sudo nmcli connection delete Ktemata        # NetworkManager path
sudo systemctl disable --now hostapd dnsmasq   # hostapd path
```

## Radio silence: `--no-radio`

Deleting the AP is not the same as being silent. Without `--hotspot` the installer simply declines
to create an access point: the radio is still enabled, `wlan0` exists, and if the box has ever been
joined to a network it will associate with it again. `kiwix-serve` also runs with no `--address`, so
it binds `0.0.0.0:8080` on every interface that comes up.

`--no-radio` is the real off switch. It disables the on-board Wi-Fi and Bluetooth **in the
firmware**, which is persistent and applies before the kernel probes the hardware:

```bash
sudo ./work/scripts/post-install.sh --no-radio
```

What it writes to `/boot/firmware/config.txt` (after a `.ktemata.bak` backup):

| Device | Line |
|---|---|
| Pi 5 / 500 / CM5 (BCM2712) | `dtoverlay=disable-wifi-pi5`, `dtoverlay=disable-bt-pi5` |
| Pi 4 and earlier | `dtoverlay=disable-wifi`, `dtoverlay=disable-bt` |

The SoC is read from `/proc/device-tree/compatible` (falling back to the `Model` line in
`/proc/cpuinfo`), because the Pi 5 overlays target `&sdio2` and `&bluetooth` rather than the
`&mmc`/`&mmcnr` nodes of earlier boards. The firmware would select the `-pi5` variant automatically
when given the unsuffixed name, but this writes the explicit one: a silent boot should not depend on
a fallback rule.

- **Mutually exclusive with `--hotspot`** — a disabled radio cannot host an AP, so the script
  refuses the combination instead of installing both and failing at boot with `no wlan0`.
- **Takes effect on the next boot.** The interfaces stay up in the running system until then; the
  step says so.
- **Bluetooth is included.** There is no reason to leave a second radio alive.
- **What it does not cover:** a USB Wi-Fi dongle or an Ethernet link that is up. The library server
  still binds all interfaces, so if a cable is connected the content is reachable — this flag stops
  the device *transmitting*, not every possible path to it. `--no-service` plus a USB-only workflow,
  or unplugging Ethernet, is the rest of that answer.

Verify after a reboot:

```bash
ip -brief link | grep -c wlan0     # 0
rfkill list                        # no phy entries for the onboard radio
hciconfig -a 2>/dev/null           # nothing
```

## What it does, in order

| Step | Action | Flag |
|---|---|---|
| 1 | Platform check: Debian/Ubuntu derivative, warns on untested arch | — |
| 2 | **Hardware checks** — see below; runs *before* anything is changed | `--no-hwtest`, `--hwtest-only`, `--strict` |
| 3 | **System update**: `apt-get update` then a non-interactive `full-upgrade` (keeps existing conffiles) | `--no-update` |
| 4 | Install `kiwix-tools`, `curl`, `ca-certificates`, the `kiwix` desktop app, `i2c-tools` for the hardware report and `util-linux-extra` (provides `hwclock` on Debian 12+) | `--no-gui`; `--library nomad` skips the Kiwix packages |
| 5 | Create `/srv/kiwix/zim` and the `kiwix` system user | `--library nomad` skips this |
| 6 | Write and enable `kiwix.service` (`kiwix-serve` on :8080) | `--no-service`; `--library nomad` skips it |
| 6b | **Write and enable `ktemata-status-oled.service`**: UTC + library free space + the Wi-Fi state to the FireBeetle over USB serial — see below | `--no-oled`, `--oled-port DEV` |
| 6c | **Write and enable `ktemata-artwork.service`**: wallpaper + boot splash at `graphical.target` — see [ARTWORK.md](ARTWORK.md) | `--no-artwork` |
| 6d | **Add the Waveshare 7inch DSI LCD (C) overlay** (`vc4-kms-dsi-waveshare-panel,7_0_inchC,i2c1`) and ensure `vc4-kms-v3d` | `--no-display-overlay` (r4 / Touch Display 2) |
| 6e | **Install Waveshare's Brightness app** and the Qt5 libs it needs | `--no-brightness`, `--no-gui` |
| 7 | Set the display rotation | `--rotate left\|right\|inverted\|normal` |
| 8 | Optionally install the kiosk launcher + autostart | `--kiosk` |
| 9 | Enable GDM automatic login for the `ktemata` account | `--no-autologin`, `--autologin-user` |
| 12 | Optionally sets `camera_auto_detect=0` in `config.txt` | `--no-camera-autodetect` |
| 12c | **Enables the Pi RTC trickle charge** (`dtparam=rtc_bbat_vchg=3000000`) for the rechargeable ML-2020 | `--no-rtc-charge` (required with a non-rechargeable CR2032) |
| 12b | **Optionally disables the Wi-Fi and Bluetooth radios in the firmware** — see below | `--no-radio` |
| 13 | **Optionally serves the library over its own Wi-Fi AP** — see below | `--hotspot` |
| 14 | Optionally download a sample ZIM and confirm the server answers | `--sample` |

The wallpaper and the early boot splash are installed as a **one-shot unit at `graphical.target`**
(runlevel 5), not executed here: applying the wallpaper needs the desktop user's session bus, and doing that
from a text console is what used to hang this script. `ktemata-artwork.service` runs at the next boot and
waits for the session, or apply it immediately from the desktop with
[`work/scripts/desktop-artwork.sh`](../work/scripts/desktop-artwork.sh) — see [ARTWORK.md](ARTWORK.md).

With **`--library nomad`** the Kiwix packages, `/srv/kiwix/zim`, `kiwix.service` and `--sample` are
skipped: the library belongs to the Project NOMAD stack. The OLED sender and the hardware report
follow the active library directory (`${NOMAD_STORAGE_PATH}/zim` in that mode). See
[Host Kiwix or NOMAD](#host-kiwix-or-nomad).

The update runs **first** so the later package install needs no second upgrade pass, and a fresh image does
not get a Kiwix build that is already superseded.

## Display rotation

The r5 Waveshare 7inch DSI LCD (C) is **1024 × 600 natively (landscape)** and needs no rotation when
mounted landscape. The r4 Touch Display 2 is 720 × 1280 (portrait); a new r4 install usually needs a
rotation. `--no-display-overlay` is for that r4 build.

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
   video=DSI-1:1024x600M@60,rotate=270
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
| **DSI display** | a `card*-DSI-*` connector with `status=connected` | reports the connector (`DSI-1`) and active mode (`1024x600` for the r5 Waveshare, `720x1280` for the TD2) |
| **I2C devices** | one line naming the build's chips: `0x3c (OLED), 0x42 (UPS INA219), 0x68 (DS3231)` | unknown addresses are only **counted**, not listed; SKIP when nothing replies (the **FireBeetle** is the I2C master). Buses that answer for nearly every address are **ignored** and named |
| **UPS gauge** | INA219 at 0x42 visible | SKIP on the Pi itself; the gauge is read by the ESP32 |
| **Pi RTC** | `/dev/rtc0` with a sane epoch | FAIL if the cell is flat/unset; the install step enables `dtparam=rtc_bbat_vchg=3000000` for the ML-2020 |
| **Storage** | ≥ 2 GB free on `/`, and the active ZIM library not empty | `$ZIM_DIR` with `--library host`, `${NOMAD_STORAGE_PATH}/zim` with `nomad` |
| **Status OLED** | the FireBeetle's CH340 found on `/dev/serial/by-id` or `/dev/ttyUSB*` | SKIP when the board is not connected; `ttyACM*` is accepted too (a native-USB ESP32) |
| **Network** | any interface `up` | SKIP when none — normal, Wi-Fi/LAN are off |
| **Port** | 8080 listening | informational only. It is not listening on a fresh install because there is no `library.xml` until a ZIM exists |

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

## Display overlay and backlight

The r5 panel is not auto-detected on the Pi 5: the step adds

```
dtoverlay=vc4-kms-v3d
dtoverlay=vc4-kms-dsi-waveshare-panel,7_0_inchC,i2c1
```

to `config.txt` (idempotent, one live line each, `.ktemata.bak` once), then reboots. `i2c1` is the
Pi's touch bus; it is separate from the FireBeetle's I²C bus. The panel is 1024 × 600 and gets the
mode from the overlay; `--rotate` only writes `video=DSI-1:1024x600M@60,rotate=…` for the console.

The Brightness step mirrors Waveshare's `install.sh`: it downloads
<https://files.waveshare.com/wiki/common/Brightness.zip>, copies the matching ARM64/ARMHF Qt
binary, desktop file and icon into `/usr/share/applications`, and adds the Qt5 Core/Gui/Widgets
and libGL packages when the archive has them. The app then appears under *Start Menu → Accessories
→ Brightness*. It is skipped with `--no-gui`; the terminal equivalent always works:

```bash
echo 100 | sudo tee /sys/class/backlight/*/brightness   # 0..255
```

The app is a precompiled vendor binary, not built from source; it is optional.

## Desktop artwork

The wallpaper and the early boot splash live in
[`work/scripts/desktop-artwork.sh`](../work/scripts/desktop-artwork.sh). The step installs the
script and its assets under `/usr/local/` and enables `ktemata-artwork.service` at
`graphical.target`; it does **not** run it, so a text-console install cannot hang on the
desktop's D-Bus session.

- Runs once, at the next boot, after the desktop user's session bus appears (`--wait 120`).
- A completion marker (`/usr/local/share/ktemata/.artwork-applied`) stops it re-rendering every
  boot. Delete the marker or run the script by hand to apply a changed logo.
- The splash takes effect on the following boot; the wallpaper applies in the running session.

```bash
sudo systemctl start ktemata-artwork        # apply now, after the desktop is up
sudo ./work/scripts/desktop-artwork.sh      # or straight from the checkout
```

Details, options and what was verified: [ARTWORK.md](ARTWORK.md).

## Project NOMAD images

Upstream publishes the NOMAD management images for **amd64 only**, so `docker compose up` on a Pi fails with
`no matching manifest for linux/arm64`. The step pulls the multi-arch fork **before** NOMAD's own installer
runs, so that installer's `docker compose up` finds the images already present.

```bash
sudo ./work/scripts/post-install.sh --nomad-version 1.35.1
sudo ./work/scripts/post-install.sh --nomad-registry ghcr.io/you
sudo ./work/scripts/post-install.sh --no-nomad
```

Three images: `project-nomad`, `-sidecar-updater`, `-disk-collector`.

**It verifies rather than assumes.** `docker image inspect .Architecture` is empty on the containerd image
store, so the check reads the manifest:

- multi-arch index → lists every platform
- single-platform manifest → `docker manifest inspect --verbose`, whose `Descriptor.platform.architecture`
  names it (the architecture is in the config blob, not the manifest)

An image without a manifest for the host architecture is an **error**, with `upstream publishes amd64 only` as
the hint on ARM. Pulls use `docker pull --platform linux/<arch>`.

It also rewrites an existing `/opt/project-nomad/compose.yml`: upstream's compose pins
`ghcr.io/crosstalk-solutions/...` with `pull_policy: always`, which would drag the amd64 image back in on the
next `compose up`. Image references are repointed at the configured registry and version, other services
(`mysql`, `redis`, …) are untouched, and `compose.yml.ktemata.bak` is kept.

Skips cleanly when Docker is absent or the daemon is unreachable.

## config.txt (opt-in)

Only one `config.txt` change is offered, and only when asked for, because a bad edit there can make the board
unbootable:

```bash
sudo ./work/scripts/post-install.sh --no-camera-autodetect
```

That sets `camera_auto_detect=0` — the build has no CSI camera, so the firmware's camera scan is pure boot
time. The edit handles the enabled, commented (`#camera_auto_detect=1`) and absent forms, never leaves two live
lines, keeps `config.txt.ktemata.bak` once, and is a no-op when already disabled.

**Deliberately not touched:**

| Setting | Why |
|---|---|
| `display_auto_detect=1` | it loads overlays for recognised DSI displays — `0` would stop the Touch Display 2 being detected |
| `display_rotate` | firmware-legacy, deprecated, ignored by the KMS driver on Pi 5; rotation belongs in `cmdline.txt` (`--rotate`) |
| `dtparam=audio=on` | stock and harmless; the build does not need it changed |
| `dtoverlay=nospi10` | Pi 5 stock; it disables `spi10`, which shares pins with the DSI touch path |

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

## Host Kiwix or NOMAD

Choose **one** library front end:

| `--library` | What runs | Library path | Ports |
|---|---|---|---|
| `host` (default) | `kiwix.service` on the Pi; `kiwix-tools` + desktop app installed | `/srv/kiwix/zim` | `8080` |
| `nomad` | nothing on the host; the NOMAD stack serves it | `${NOMAD_STORAGE_PATH}/zim` (default `/opt/project-nomad/storage/zim`) | NOMAD admin `8080`, Kiwix `8090` |

Facts about the NOMAD side (checked against the fork's service seeder): `nomad_admin` publishes
**:8080**; NOMAD's Kiwix service is the container `ghcr.io/kiwix/kiwix-serve:3.8.1`, publishes
**:8090**, binds `${NOMAD_STORAGE_PATH}/zim` as `/data`, and serves `/data/kiwix-library.xml` with
`--monitorLibrary`. The NOMAD **installer** installs only the Command Center; Kiwix is added from
the Command Center after setup.

Consequences:

- The host `kiwix-serve` must not run together with NOMAD: both want **:8080**. `--library nomad`
  avoids the clash by not installing the host stack at all.
- The two ZIM directories are different. `--library nomad` makes the hardware check and the
  status OLED report `${NOMAD_STORAGE_PATH}/zim`, not `/srv/kiwix/zim`.
- `--sample` is skipped in `nomad` mode; add content in the NOMAD Command Center.
- The kiosk still opens `http://localhost:8080`, which is the NOMAD admin in this mode (the
  Information Library is a page inside it; the raw Kiwix UI is on :8090).

```bash
sudo ./work/scripts/post-install.sh --library nomad
```

## kiwix-serve

Only installed with `--library host` (the default). The unit runs as the unprivileged `kiwix` user
and is hardened (`NoNewPrivileges`, `ProtectSystem=strict`, read-only library).

It serves through a **library XML**, not a glob:

```ini
ConditionPathExists=/srv/kiwix/zim
ExecStartPre=/usr/local/bin/kiwix-library
ExecStart=/bin/sh -c 'if [ -f "$ZIM_DIR/library.xml" ]; then exec kiwix-serve --library …; fi; exit 0'
```

Why: **systemd does not run `ExecStart` through a shell**, so a bare `/srv/kiwix/zim/*.zim` arrives at
kiwix-serve as the literal string and it exits 1:

```
Unable to add the ZIM file '/srv/kiwix/zim/*.zim' to the internal library.
```

`--library` takes an XML listing instead. `kiwix-library` (installed to `/usr/local/bin`) rebuilds that XML
from the `*.zim` files on every start, so dropping in an archive and restarting is enough. `kiwix-manage`
does the listing.

The condition is on the **directory**, not the XML: a `ConditionPathExists` on the XML would also suppress
`ExecStartPre`, so the library could never be created. With no archives at all the start command prints
`no ZIM files yet` and exits 0, so an idle card produces an idle unit rather than a restart loop.

The service user must be able to read the archives, so the script sets the library group to `kiwix` with
`g+rX` — and repeats that after the `--sample` download, which otherwise lands `root:root` and is invisible
to the service.

```bash
systemctl status kiwix
journalctl -u kiwix -f
curl -sI http://localhost:8080/ | head -1
```

Override the location with `--zim-dir` and the port with `--port`; both are also honoured in the unit.

## Status OLED sender

The FireBeetle 2 in `firmware/` drives the 1.3" panel and has no clock of its own unless a
DS3231 is fitted, so the Pi pushes UTC and the free space of the library filesystem over the
USB serial link. This step installs `work/scripts/status-oled.py` to `/usr/local/lib/ktemata/`
and enables `ktemata-status-oled.service`. It runs as root only to open the serial device and
writes nothing but the board's JSON.

- Autodetects the CH340 on its stable `/dev/serial/by-id` name, else `ttyUSB*` / `ttyACM*`;
  `--oled-port` pins the device (the CH340 has no serial number, so with several attached the
  autodetect can only take the first).
- Sends `{"cmd":"time","epoch":…}` at start and hourly, and again whenever the board announces
  a boot. The epoch is **UTC**; the firmware applies `TIMEZONE` when it renders. Opening the
  port can reset the board, so the first line waits two seconds, and an unconfirmed send is
  repeated every 5 s until the board logs `time synced` (six tries, then hourly).
- Sends `{"cmd":"storage","used_pct":…,"free_gb":…}` at start and every 60 s, computed with
  `df` semantics (`f_bavail`) for `--zim-dir`.
- Sends `{"cmd":"wifi","state":…}` at start, after a board boot and every 15 s, for the OLED's
  `WIFI` screen. The board has no radio, so this is the Pi's own state: `nmcli` on `wlan0` plus
  the active profile's `802-11-wireless.mode` gives `ap` (the `--hotspot` profile) or `client`;
  without NetworkManager an active `hostapd` means `ap` and `iw dev wlan0 link` means `client`;
  otherwise `off`. Read-only, so the service needs no extra rights.
- Reads the board's telemetry back and logs alert and Wi-Fi transitions and rejected commands to
  the journal. Lines that are not JSON (the ESP32 boot ROM) are ignored unless `-v` is given; the
  firmware silences its own core logger so the stream stays JSON.
- Retries when the board is absent or unplugged, so the unit is harmless on a box without one.
  `--no-oled` skips the step entirely.

```bash
systemctl status ktemata-status-oled
journalctl -u ktemata-status-oled -f
sudo systemctl stop ktemata-status-oled
sudo python3 work/scripts/status-oled.py --once -v   # one manual sync, echo the board's lines
sudo systemctl start ktemata-status-oled
```

Opening a CH340 port can pulse the ESP32 reset line; expect the OLED to restart once per service
start, after which the sender sees the boot banner and re-syncs. The sender holds an exclusive lock:
running it by hand while the service runs is refused, because two readers on one tty split the
board's replies (one of them then never sees `time synced`).

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
    --library WHAT     host (default) or nomad
    --no-service       packages only
    --no-oled          skip the status OLED sender
    --oled-port DEV    FireBeetle serial device (default: autodetect)
    --no-artwork       skip the graphical.target wallpaper/splash unit
    --no-display-overlay
                       skip the Waveshare DSI overlay (for the r4 Touch Display 2)
    --no-brightness    skip the Waveshare Brightness app
    --no-gui           skip the desktop app
    --no-update        skip the system upgrade
    --rotate WHAT      normal | left | right | inverted (or 0|90|180|270 clockwise)
    --kiosk            install the kiosk launcher + autostart
    --kiosk-user NAME  desktop user to autostart it for (default: the sudo user)
    --no-hwtest        skip the hardware checks
    --hwtest-only      run the hardware checks and exit
    --strict           non-zero exit when a hardware check fails (not on warnings)
    --power usbc|hat   supply in use, for the diagnostic hints (default usbc)
    --no-nomad         do not pull the NOMAD images
    --nomad-version V  NOMAD tag to pull (default 1.35.1)
    --nomad-registry R registry/namespace (default ghcr.io/jsoeterbroek)
    --no-camera-autodetect
                       set camera_auto_detect=0 in config.txt (opt-in)
    --no-rtc-charge    do not enable the ML-2020 RTC trickle charge
    --no-autologin     leave the GDM login screen
    --autologin-user N account to log in automatically (default ktemata)
-h, --help / -V, --version
```

`ZIM_DIR`, `SERVICE_PORT`, `SERVICE_USER`, `LIBRARY`, `NOMAD_STORAGE_PATH`, `SAMPLE_ZIM`, `ROTATE`,
`DISPLAY_MODE`, `NO_COLOR`, `OLED_PORT` and `CMDLINE_FILE` (test hook) can be set in the environment.

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
Packages → Library → Service → Status OLED → Rotation → Kiosk.

Autologin was tested against real-shaped configs in a container. **LightDM** (the Pi OS path): the commented
`#autologin-user=` in a stock `[Seat:*]` block is enabled in place, `greeter-session` and
`xserver-command` survive, and when both a LightDM and a GDM file exist LightDM is chosen and the GDM file is
left untouched. **GDM** (Ubuntu): insert into a stock `custom.conf`, replace an existing
`AutomaticLoginEnable=false` / `AutomaticLogin=pi`, append a missing `[daemon]` section to a config that only
had `[security]`, and the Debian layout where only `daemon.conf` exists. Each case leaves the other sections
intact and keeps a backup identical to the original.

The NOMAD step was tested against the real registry with the host architecture forced:
the fork (`ghcr.io/jsoeterbroek`) reports `arm64 amd64` and pulls; **upstream reports `amd64` only and is
refused on arm64** with the "build the fork's arm64 images" hint; upstream passes on amd64. A realistic
upstream `compose.yml` was rewritten to the fork's registry and version with `mysql:8.0` untouched and a
backup kept. The step skips cleanly when Docker is absent or the daemon is unreachable.

The `config.txt` edit was tested against the actual Pi 5 file: the diff is exactly one line
(`camera_auto_detect=1` → `0`), `dtparam=audio=on` and `display_auto_detect=1` are untouched, a
second run reports "already disabled", the commented and absent forms both end with one live line, a
dry run changes nothing, and a default (no-flag) run leaves the file byte-identical.

The RTC trickle edit was exercised against synthetic `config.txt` copies: a commented line is
replaced, a different value is rewritten, an absent line is appended once, a second run reports
"already enabled", and a dry run leaves the file untouched. It is opt-out only; a CR2032 must not be
used with it.

The display overlay edit was tested on synthetic `config.txt` files: a commented `vc4-kms-v3d`
with `,cma-256` is uncommented in place, a missing one is inserted before the panel overlay, an
existing `dsi0` panel line is rewritten, and a second run is a no-op. The Brightness installer was
exercised against the real Waveshare zip with a stubbed `dpkg`; it copies the ARM64 binary, desktop
file and icon. Neither has been run on the Pi with the panel attached yet.

The artwork steps now live in `desktop-artwork.sh`; their verification is recorded in
[ARTWORK.md](ARTWORK.md), including the container runs that produced the PNG and TGA.

`--library nomad` was exercised function by function: the package list drops `kiwix-tools` and the
desktop app, the library and service steps report "skipped", the status OLED unit is written with
`--storage ${NOMAD_STORAGE_PATH}/zim`, and the hardware storage check reads that directory. The
verify step reports the NOMAD container state instead of probing `kiwix-serve`. It has not been run
against a live NOMAD install on the Pi.

The Chromium start was reproduced with `HOME` unset in a Debian container: after the fix the profile and
crash directories are created and Chromium launches (the only remaining complaint there is the container's
missing `chromium-sandbox`, which is unrelated).

The kiosk path was tested the same way: `/usr/local/bin/kiwix-kiosk` installed, the autostart entry written
with `Exec=/usr/local/bin/kiwix-kiosk --transform 270`, and the launcher's `--selftest` returning 0 against a
live server and 1 without one.

The status OLED sender was exercised against a pseudo-terminal standing in for the board: nothing is written
during the two-second reset window, the boot banner and an unconfirmed send both trigger a re-sync, a `bad
json` reply triggers a retry, `time synced` stops the 5 s retries, non-JSON lines stay out of the journal
unless `-v` is given, an unplug is logged and recovered from, and SIGTERM stops it with status 0. The generated
unit was inspected with and without `--oled-port` and with a space in the ZIM path. The serial check reports
SKIP on a host with no FireBeetle; on the Pi the board enumerates as
`/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0`, which is the name the check and the sender prefer. The firmware change (silenced core
logger) builds for the DFR1140 (`pio run`), but has not been flashed and rechecked on the board yet.

**On real hardware** (Debian 13 trixie, Pi 5 Rev 1.1): model, serial, display `DSI-1 (720x1280)`, RTC
holding a sane time, microSD storage and network all PASS; SoC 58–60 °C at idle with the 27 W supply and no
throttle flags.

Not covered: arm64 was checked only at the package level (Ubuntu publishes `kiwix`, `kiwix-tools` and
`zim-tools` for arm64 in noble), and the desktop `wlr-randr` path has not been run on real Wayland hardware.

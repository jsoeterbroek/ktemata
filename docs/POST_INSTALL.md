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
file, no YAML config, no whiptail menu. Idempotent — safe to re-run. The install confirmation is skipped when
an existing host installation is detected; a fresh installation still asks before changing the system.

## Library admin (port 8081)

Kiwix is a reader, not a file manager. The installer adds a small admin page for the part you
cannot do from the kiosk: putting archives in, taking them out, and kicking the index.

```
http://<device>:8081/          # e.g. http://10.10.10.1:8081/ on the hotspot
```

The installer also adds a **Ktemata Admin** desktop shortcut, like the library and Wi-Fi icons. It
opens `http://127.0.0.1:8081/` in a new Firefox window (or the default browser via `xdg-open`);
sign in with the credentials from `/etc/ktemata/admin.conf`.

It lists every `*.zim` with its size, mtime and whether the current `library.xml` knows it, shows
filesystem use and the space taken by ZIM files, and can:

- **upload** archives by drag-and-drop. Transfers are chunked (8 MiB) and resumable: an interrupted
  upload leaves `<name>.zim.part`, and dropping the same file again continues where it stopped.
  The archive is renamed into place only after the last chunk, so a half file is never served.
  The first bytes must be a ZIM header, and the free-space check runs before any data is written.
- **delete** an archive, or discard an interrupted upload.
- **start, stop and restart** `kiwix.service`, with its state in the header.
- **rebuild the index**: runs `/usr/local/bin/kiwix-library` (the same helper `kiwix.service`
  uses as `ExecStartPre`) and restarts `kiwix-serve`. The page flags a stale index — archives on
  disk that are not in `library.xml`, or entries whose files are gone — and offers the rebuild.

Uploading or deleting a file does **not** publish it by itself: kiwix-serve reads `library.xml`
at start, so use *Rebuild index & restart*. That is deliberate — a large upload should not
restart the library while someone is reading.

### Credentials and exposure

The page can destroy the library, so it is not anonymous:

```bash
sudo cat /etc/ktemata/admin.conf     # KTEMATA_ADMIN_USER=ktemata, KTEMATA_ADMIN_PASSWORD=...
```

The password is generated once on first install (36 hex characters) and kept on re-runs. HTTP
Basic auth protects every route. The unit runs as root because it writes `/srv/kiwix/zim` and
rebuilds `/var/lib/kiwix/library.xml`; `ProtectSystem=strict` leaves everything else read-only,
and the password file is mode 0600.

There is **no TLS**. A password and ZIM payload cross the network in the clear. Keep the admin
page on the hotspot or a trusted LAN, or bind it to loopback and use an SSH tunnel:

```bash
sudo ss -ltnp | grep 8081                                   # what is listening
sudo ./work/scripts/post-install.sh --admin-bind 127.0.0.1  # loopback only
# then, on a laptop: ssh -L 8081:127.0.0.1:8081 ktemata@<device>
# and open http://127.0.0.1:8081/
```

`--no-admin` skips the page entirely; `--admin-user` and `--admin-pass` set the login (8+
characters). To rotate the password, edit `/etc/ktemata/admin.conf` and
`sudo systemctl restart ktemata-admin`.

The server is [`work/scripts/ktemata-admin.py`](../work/scripts/ktemata-admin.py), standard
library only, no framework:

```bash
python3 work/scripts/ktemata-admin.py --zim-dir /srv/kiwix/zim \
    --state-dir /var/lib/kiwix --auth-file /etc/ktemata/admin.conf   # foreground, :8081
```

Without a credentials file it refuses to bind beyond `127.0.0.1`.

If the optional [offline AI](OFFLINE_AI.md) is installed and indexed, the page also has an
**Ask the library** box that answers from the documents under `/var/lib/kiwix` and the library
directories.

## Offline AI (optional)

The local assistant is a separate install because it downloads models and changes the memory and
thermal profile. See [OFFLINE_AI.md](OFFLINE_AI.md) for models, limits and the ZIM caveat.

```bash
sudo ./work/scripts/post-install-ai.sh --yes
# or let the main installer delegate to it
sudo ./work/scripts/post-install.sh --ai
```

It indexes `/var/lib/kiwix` and `/srv/kiwix/zim` by default (text, Markdown, HTML, XML, PDF, EPUB,
DOCX, ODT), answers with `ktemata-ai ask "..."`, and adds **Ask the library**, **Ask ZIM**, and the
**AI index** column to the admin page. ZIM archives are skipped by the normal document ingest.
KiwixRAG is installed for them: build a vector index with
`sudo ktemata-ai zim-index --zim FILE`, or use the **AI index** column in the admin archive table.
Ask with `ktemata-ai zim-ask --zim FILE "..."` or the admin **Ask ZIM** form. KiwixRAG is by
[brunuff](https://github.com/brunuff/KiwixRAG); see [OFFLINE_AI.md](OFFLINE_AI.md).

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
- **No NAT.** NetworkManager has no per-connection switch to keep `ipv4.method shared` from
  masquerading clients onto whatever uplink is present (`ipv4.ip-forward` is not a property and
  fails with `invalid property 'ip-forward'`). The installer writes
  `/etc/NetworkManager/conf.d/90-ktemata-no-nat.conf` with `firewall-backend=none`: dnsmasq still
  provides DHCP and DNS, but no NAT rule is added. Clients reach the box without being
  masqueraded onto the uplink — an appliance that silently becomes a router on a hotel or office
  LAN is a worse failure than not routing. The setting is global, so every shared connection on
  this box is NAT-less.
- **Idempotent.** An existing working profile with the same SSID is left untouched, so re-running
  the installer never resets a password. A profile left half-configured by an interrupted run
  (or the old `ip-forward` failure) is repaired.
- **Verified, not assumed.** The step brings the AP up and then fetches
  `http://<addr>:8080/` to prove the library answers over that interface.

Turning it off again:

```bash
sudo nmcli connection delete Ktemata        # NetworkManager path
sudo systemctl disable --now hostapd dnsmasq   # hostapd path
```

## Wi-Fi mode switch

The desktop gets a **Ktemata Wi-Fi** launcher that switches the radio between three modes at
runtime — no reinstall and no reboot:

| Mode | What it does |
|---|---|
| **Client** | Radio on, access point down. NetworkManager joins a saved client network. |
| **Access point** | Radio on, brings up the `Ktemata` AP profile at `10.10.10.1/24`; DHCP/DNS come from NetworkManager. |
| **Off** | `nmcli radio wifi off`. NetworkManager keeps the radio disabled across reboots. |

From a terminal:

```bash
wifi-mode status      # one line: off / client - connected to X / access point
wifi-mode client
wifi-mode ap
wifi-mode off
wifi-mode menu        # same chooser the desktop entry opens
```

How it is put together:

- **One root-owned helper**, `wifi-mode.sh` → `/usr/local/bin/wifi-mode`. It only drives
  `nmcli`; there is no hostapd path, because the switch needs a live NetworkManager to change
  modes without a reboot. On an image without NetworkManager the step is skipped.
- **AP settings live in `/etc/ktemata/wifi.conf`**, mode 0600:

  | Key | Meaning |
  |---|---|
  | `AP_NAME` | NetworkManager connection/profile name (internal), default `Ktemata` |
  | `AP_WELCOME` | SSID clients see when connecting; empty falls back to `Ktemata` |
  | `AP_PASSWORD` | WPA2 passphrase, 8–63 characters; empty leaves a new profile open |
  | `AP_ADDR`, `AP_CIDR` | AP address and prefix, default `10.10.10.1`/`24` |
  | `AP_BAND` | `auto`, `2.4` or `5`, default `auto` |

  The installer writes this file from `--hotspot-ssid`, `--hotspot-pass`, `--hotspot-addr` and
  `--hotspot-band` only when it does not exist; an existing file is never overwritten. An
  installation from the old helper migrates `/etc/ktemata/wifi-mode.conf` once. The helper reads
  the old file as a fallback if the new one is absent. Because the file is sourced as root, the
  helper refuses to run if it is not root-owned or is group/other-writable.
- **The config is applied on every `wifi-mode ap`.** An existing profile whose SSID matches
  `AP_WELCOME` is adopted and renamed to `AP_NAME`; the mode, SSID, address and password are then
  written from the file. The AP is brought down and up so a changed SSID or PSK actually takes
  effect. Editing `wifi.conf` is enough — no profile deletion. If the file is missing, AP mode
  refuses to create a profile instead of falling back to open defaults.
- **The active AP is found by mode, not by name.** `status` and `client` inspect
  `802-11-wireless.mode` on the active connection, so a profile called `ktemata-ap` is reported
  as an access point even when `AP_NAME=ktemata`. Set `AP_NAME=ktemata-ap` to keep that profile
  name; otherwise the next `wifi-mode ap` adopts and renames it to `AP_NAME`.
- **Client mode cannot fall back into AP mode.** It disables autoconnect on every AP-mode
  profile, brings down the active AP, then joins a saved client profile. If NetworkManager's
  `device connect` picks the local AP anyway, the helper takes it down and activates a client
  profile explicitly. With no saved client network it leaves the radio on and the AP down.
- **No password prompt.** `NetworkManager` connection changes are root operations on a stock
  image, so the installer writes `/etc/sudoers.d/ktemata-wifi`, which allows the desktop account
  to run exactly `wifi-mode client`, `wifi-mode ap` and `wifi-mode off` without a password. The
  helper is root-owned; the rule cannot run arbitrary arguments.
- **AP mode is NAT-less.** The helper writes the same
  `/etc/NetworkManager/conf.d/90-ktemata-no-nat.conf` drop-in as `--hotspot`, so
  `ipv4.method shared` supplies DHCP/DNS without masquerading clients onto an uplink. It reloads
  NetworkManager's configuration after writing it.
- **The chooser is zenity** (`--no-gui` skips the desktop entry). Without zenity the command
  prints a terminal menu, so it still works over ssh.
- **Radio off is not firmware off.** It stops NetworkManager scanning and associating and it
  survives a reboot, but it can be undone from the same launcher. The permanent switch remains
  [`--no-radio`](#radio-silence---no-radio); with that flag the installer skips the switcher,
  because a disabled radio cannot host an AP or join a network.

```bash
sudo ./work/scripts/post-install.sh --no-wifi-switch   # do not install it
```

## Desktop icons

All Ktemata desktop icons (Library, Wi-Fi, Admin) are executable `.desktop` entries. PCManFM/libfm
still shows **Execute / Execute in Terminal / Open** unless `quick_exec=1` is set, so the installer
writes it under `[config]` in the desktop user's `~/.config/libfm/libfm.conf`. Other keys are
preserved, and the change is idempotent.

Apply it to a running session by restarting the desktop manager, or simply log out and back in:

```bash
pcmanfm --desktop-off
pcmanfm --desktop &
```

On older Pi OS releases the same key may live in `~/.config/pcmanfm/LXDE-pi/pcmanfm.conf`.

## Radio silence: `--no-radio`

Deleting the AP is not the same as being silent. Without `--hotspot` the installer simply declines
to create an access point: the radio is still enabled, `wlan0` exists, and if the box has ever been
joined to a network it will associate with it again. `kiwix-serve` also runs with no `--address`, so
it binds every available interface (IPv4 and IPv6) on :8080.

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
| 6a | Write and enable `ktemata-admin.service` — the library admin on :8081, plus a **Ktemata Admin** desktop shortcut — see above | `--no-admin`; `--library nomad` and `--no-service` skip it |
| 6b | Add **Ktemata Library** to the desktop; opens Firefox in full-screen kiosk mode on `http://127.0.0.1:8080/` | `--no-gui`, `--no-service`; `--library nomad` skips it |
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
| 13b | **Install the desktop Wi-Fi mode switch** (`wifi-mode`: client / access point / off) — see above | `--no-wifi-switch`, `--no-gui`, `--no-radio`; skipped without NetworkManager |
| 14 | Optionally download a sample ZIM and confirm the server answers | `--sample` |

The wallpaper and the early boot splash are installed as a **one-shot unit at `graphical.target`**
(runlevel 5), not executed here: applying the wallpaper needs the desktop user's session bus, and doing that
from a text console is what used to hang this script. `ktemata-artwork.service` runs at the next boot and
waits for the session, or apply it immediately from the desktop with
[`work/scripts/desktop-artwork.sh`](../work/scripts/desktop-artwork.sh) — see [ARTWORK.md](ARTWORK.md).

With **`--library nomad`** the Kiwix packages, `/srv/kiwix/zim`, `kiwix.service` and `--sample` are
skipped: the library belongs to the Project NOMAD stack. The hardware report follows the active
library directory (`${NOMAD_STORAGE_PATH}/zim` in that mode). See
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
| **I2C devices** | names the UPS Module 3S INA219 at `0x41` | Unknown addresses are only **counted**, not listed. Buses that answer for nearly every address are **ignored** and named |
| **UPS gauge** | INA219 at `0x41` on bus `1`, a unique auto-detected bus, or bus `2` with `--ups-i2c-alt-pins` | FAIL when no gauge answers or several buses are ambiguous; SKIP when tools or an explicitly required bus are unavailable |
| **Pi RTC** | `/dev/rtc0` with a sane epoch | FAIL if the cell is flat/unset; the install step enables `dtparam=rtc_bbat_vchg=3000000` for the ML-2020 |
| **Storage** | ≥ 2 GB free on `/`, and the active ZIM library not empty | `$ZIM_DIR` with `--library host`, `${NOMAD_STORAGE_PATH}/zim` with `nomad` |
| **Network** | any interface `up` | SKIP when none — normal, Wi-Fi/LAN are off |
| **Port** | 8080 listening | informational only. It is not listening on a fresh install because there is no `library.xml` until a ZIM exists |

Checks never block the install: findings are counted and reported. `--strict` fails the run on a **fault**
(undervoltage), not on a **warning** (heat). `--hwtest-only` prints the report and exits without touching the
system.

### Thermal warnings

The Pi 5's soft limit is 80 °C and its hard limit is 85 °C. Thermal and clock throttling are reported as
warnings with actual CPU load; **undervoltage** is treated as a supply fault. A reading of at least 85 °C while
idle is a failure because the heat is not explained by CPU load.

The check measures **actual CPU busy time** (two `/proc/stat` samples), not load average, so it can tell the
two causes apart:

| Reading | Verdict |
|---|---|
| ≥ 85 °C, CPU busy | **WARN** — load-related throttling; inspect cooling and airflow |
| ≥ 85 °C, CPU idle | **FAIL** — a bare Pi 5 idles 55–70 °C, so the heat is not from load |
| 80–85 °C, idle | **WARN** — warm for idle |
| < 80 °C | **PASS** |

On a FAIL or WARN it lists the processes using ≥ 10 % CPU, so "something is pegged" is visible rather than
implied. If an idle board is hot with nothing running, look for clearance under the board, a heat trap
(case, desk, insulation), or a process that is busy in short bursts the sample missed.

### Power path

The Pi reads the UPS Module 3S's INA219 directly at `0x41`. Select the supply used for undervoltage
diagnostic hints:

```bash
./work/scripts/post-install.sh --hwtest-only --power usbc   # default: direct USB-C supply
./work/scripts/post-install.sh --hwtest-only --power ups3s  # UPS Module 3S 5 V output
```

This option only changes the hint wording. USB-C points at the 27 W supply and cable; `ups3s` points at the
cells, output switch and 5 V Type-C lead. The UPS gauge itself is detected by the I²C check above.

## Display overlay and backlight

The r5 panel is not auto-detected on the Pi 5: the step adds

```
dtoverlay=vc4-kms-v3d
dtoverlay=vc4-kms-dsi-waveshare-panel,7_0_inchC,i2c1
```

to `config.txt` (idempotent, one live line each, `.ktemata.bak` once), then reboots. `i2c1` is the
Pi's touch bus; it is separate from the UPS Module 3S I²C bus. The panel is 1024 × 600 and gets the
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

## UPS alternate I²C pins

For the Pi 5 PCH wiring on GPIO12/GPIO13 (physical pins 32/33), opt in to the UPS bus overlay:

```bash
sudo ./work/scripts/post-install.sh --ups-i2c-alt-pins
```

This adds `dtoverlay=i2c2-pi5,pins_12_13` to `/boot/firmware/config.txt`, keeps the usual one-time
`.ktemata.bak`, and takes effect after reboot. The UPS INA219 is then at `0x41` on Linux bus `2`;
verify with `sudo i2cdetect -y 2`. An existing, differently configured `i2c2-pi5` overlay is left
unchanged rather than loading a conflicting second instance. Standard GPIO2/GPIO3 wiring needs
neither this flag nor the overlay. The tray app and its bus selection are documented in
[`work/scripts/UPS_3S/README.md`](../work/scripts/UPS_3S/README.md).

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

## Project NOMAD (optional)

NOMAD is a separate stack and is **not** installed here. Run the Raspberry Pi 5 fork's installer
(`install/install_nomad.sh` from `broy55/project-nomad-rpi5`) on a fresh box first, then:

```bash
sudo ./work/scripts/post-install.sh --library nomad
```

It cannot be folded into this script:

- it is an interactive wizard (whiptail, `read` fallbacks) and refuses to run when
  `/opt/project-nomad/compose.yml` already exists, so it cannot be re-run from here;
- on arm64 it **builds** the three images locally from its own source tarball, so pulling or
  repointing images beforehand has no effect — it never consumes a pre-built tag;
- its preflight hard-fails on the stock Pi 5 16K-page kernel; set `[pi5] kernel=kernel8.img` in
  `config.txt` and reboot before running it (it only stages that itself when an NVIDIA eGPU is
  present);
- its own update and hotspot/firewall scripts are stubs (`update_nomad.sh` exits 1, the hotspot
  scripts are preview-only and refuse to write to `/`).

`--library nomad` only changes what this script does: no host `kiwix-serve`, and the hardware
storage check reads `${NOMAD_STORAGE_PATH}/zim`.

## Camera auto-detect (opt-in)

This camera-specific `config.txt` change is only made when asked, because a bad boot edit can make the board
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

Install NOMAD with its own installer first — see [Project NOMAD](#project-nomad-optional). This
script never writes to `/opt/project-nomad`.

Consequences:

- The host `kiwix-serve` must not run together with NOMAD: both want **:8080**. `--library nomad`
  avoids the clash by not installing the host stack at all.
- The two ZIM directories are different. `--library nomad` makes the hardware check read
  `${NOMAD_STORAGE_PATH}/zim`, not `/srv/kiwix/zim`.
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
StateDirectory=kiwix
TimeoutStartSec=1800
ExecStartPre=/usr/local/bin/kiwix-library "/srv/kiwix/zim" "/var/lib/kiwix/library.xml"
ExecStart=/bin/sh -c 'if [ -f "/var/lib/kiwix/library.xml" ]; then exec kiwix-serve --library …; fi; exit 0'
```

Why: **systemd does not run `ExecStart` through a shell**, so a bare `/srv/kiwix/zim/*.zim` arrives at
kiwix-serve as the literal string and it exits 1:

```
Unable to add the ZIM file '/srv/kiwix/zim/*.zim' to the internal library.
```

`--library` takes an XML listing instead. `kiwix-library` (installed to `/usr/local/bin`) rebuilds that XML
when needed; dropping in an archive and restarting is enough. It stores a SHA-256 fingerprint of every
ZIM's path, size and modification time in `/var/lib/kiwix/library.xml.inputs.sha256`. If that fingerprint
and the existing XML are intact, the service skips re-indexing. Full content hashes are deliberately not
used because they would read every multi-gigabyte archive on each start. Removing all ZIMs clears the XML.

`kiwix-manage` does the listing when the inputs change. The XML is written to `/var/lib/kiwix/library.xml`;
systemd's `StateDirectory=kiwix` keeps that path writable while `/srv/kiwix/zim` remains read-only to the
service. Indexing hundreds of archives can take several minutes; `TimeoutStartSec=1800` prevents systemd
from repeatedly killing and restarting that work. While the unit is `activating (start-pre)`, port 8080 is
not expected to be listening.

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
The service listens on every available address because `kiwix-serve` gets no `--address`. Do not add
`--address=0.0.0.0`: kiwix-serve treats it as a literal interface address and exits with
`ERROR: IP address is not available on this system: 0.0.0.0` (reproduced with 3.7.0). Omitting the option
is the wildcard. Local shortcuts use `http://127.0.0.1:8080/` because `localhost` may resolve to IPv6 `::1`
and older builds served IPv4 only. If the connection still fails, check that at least one ZIM is installed
and inspect `systemctl status kiwix`; the service intentionally exits when `library.xml` cannot be created.

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
    --no-artwork       skip the graphical.target wallpaper/splash unit
    --no-display-overlay
                       skip the Waveshare DSI overlay (for the r4 Touch Display 2)
    --no-brightness    skip the Waveshare Brightness app
    --no-gui           skip the desktop app
    --no-wifi-switch   skip the desktop Wi-Fi mode switcher (client / AP / off)
    --no-update        skip the system upgrade
    --rotate WHAT      normal | left | right | inverted (or 0|90|180|270 clockwise)
    --kiosk            install the kiosk launcher + autostart
    --kiosk-user NAME  desktop user to autostart it for (default: the sudo user)
    --ai               install the offline AI (Ollama + ktemata-ai + KiwixRAG);
                       see OFFLINE_AI.md
    --no-hwtest        skip the hardware checks
    --hwtest-only      run the hardware checks and exit
    --strict           non-zero exit when a hardware check fails (not on warnings)
    --power usbc|ups3s supply in use, for undervoltage hints (default usbc)
    --no-camera-autodetect
                       set camera_auto_detect=0 in config.txt (opt-in)
    --no-rtc-charge    do not enable the ML-2020 RTC trickle charge
    --no-autologin     leave the GDM login screen
    --autologin-user N account to log in automatically (default ktemata)
-h, --help / -V, --version
```

`ZIM_DIR`, `SERVICE_PORT`, `SERVICE_USER`, `LIBRARY`, `NOMAD_STORAGE_PATH`, `SAMPLE_ZIM`, `ROTATE`,
`DISPLAY_MODE`, `NO_COLOR`, `POWER_SOURCE`, `UPS_I2C_ALT_PINS` and `CMDLINE_FILE` (test hook) can be set in the environment.

## Verified

Run inside `ubuntu:24.04` (amd64): dry run, then a real install with `--yes --sample --no-gui`. `kiwix-tools
3.5.0` installed, the sample ZIM downloaded, and a throwaway `kiwix-serve` answered on :9080. On the host
(Arch) the platform check correctly refuses. A re-run is idempotent ("already exists", "already the newest
version"), the generated unit was inspected, and the service user was confirmed able to read the archive
(`head -c4` returns the `ZIM\x04` magic).

The service bind was rechecked in Debian 13 with **kiwix-tools 3.7.0**: `--address=0.0.0.0` fails after loading
the library with `ERROR: IP address is not available on this system: 0.0.0.0`, while the same unit without
`--address` starts and answers HTTP 200 on `127.0.0.1`. The unit no longer passes an address.

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
desktop app, the library and service steps report "skipped", and the hardware storage check reads
`${NOMAD_STORAGE_PATH}/zim`. The
verify step reports the NOMAD container state instead of probing `kiwix-serve`. It has not been run
against a live NOMAD install on the Pi.

The Chromium start was reproduced with `HOME` unset in a Debian container: after the fix the profile and
crash directories are created and Chromium launches (the only remaining complaint there is the container's
missing `chromium-sandbox`, which is unrelated).

The kiosk path was tested the same way: `/usr/local/bin/kiwix-kiosk` installed, the autostart entry written
with `Exec=/usr/local/bin/kiwix-kiosk --transform 270`, and the launcher's `--selftest` returning 0 against a
live server and 1 without one.

The Wi-Fi mode switch was exercised against a fake `nmcli` in Debian 13, both as root and as an
unprivileged desktop user through the generated sudoers rule: `off` disables the radio, `ap` creates the
profile with `mode ap`/`ipv4.method shared` and activates it, `client` turns the AP's
autoconnect off and joins a saved client profile, and `status` reports all three states. The sudoers file
parses with `visudo -cf`, the three mode words run without a password, and an arbitrary argument is refused.
`install_wifi_switch` was dry-run in Debian 13 with user `ktemata`: helper, mode-0600 config, sudoers rule and
`~/Desktop/ktemata-wifi.desktop` were all reported. The zenity chooser was driven with a stub; the terminal
chooser was driven over a pty against the fake `nmcli`. A real radio and NetworkManager were not available in
the containers.

The profile property set was checked against real `nmcli` 1.52.1 with `nmcli --offline connection add`:
`ipv4.ip-forward` is rejected (`invalid property 'ip-forward'`), while the current set (`mode ap`,
`ipv4.method shared`, `ipv4.addresses`, `ipv6.method disabled`) is accepted. `NetworkManager --print-config`
shows `firewall-backend=none` from the drop-in. With a fake `nmcli`, a half-configured `Ktemata` profile
(`mode=infrastructure`) was repaired on the first `ap` run and left alone on the second, and the drop-in
writer produced a mode-0644 file. A real AP/NAT path was not exercised.

`/etc/ktemata/wifi.conf` was driven through a fake `nmcli`: `AP_NAME`, `AP_WELCOME` and `AP_PASSWORD` created
the profile, editing the file changed the SSID and PSK on the next `ap`, an empty `AP_WELCOME` fell back to
`Ktemata`, and a 6-character password was refused. A legacy `wifi-mode.conf` was read as a fallback, an
existing profile with the matching SSID was adopted and renamed, and the installer preserved an existing
`wifi.conf`, migrated a legacy file, and created a fresh one from the hotspot flags. A real radio was not
available in the container.

The libfm quick-exec writer was tested against empty, existing, and sectioned `libfm.conf` files: it creates
`[config]`/`quick_exec=1`, replaces an existing `quick_exec=0`, inserts into an existing `[config]`, leaves
other sections and keys alone, is idempotent, and changes nothing in a dry run.

An active AP named `ktemata-ap` with `AP_NAME=ktemata` was also exercised: `status` reported the access point
(from `802-11-wireless.mode`) rather than a client, `client` disabled and brought down `ktemata-ap`, and the
next `ap` adopted and renamed it to `ktemata`. Changing `AP_PASSWORD` on an already-active profile wrote the
new PSK and reactivated the AP instead of leaving the old password in the running hostapd. With two AP
profiles (`Ktemata`, `ktemata-ap`) both autoconnecting, `client` set both to `autoconnect no`; with a fake
`device connect` forced to pick the AP, it was taken down and the saved `HomeNet` profile was activated.

**On real hardware** (Debian 13 trixie, Pi 5 Rev 1.1): model, serial, display `DSI-1 (720x1280)`, RTC
holding a sane time, microSD storage and network all PASS; SoC 58–60 °C at idle with the 27 W supply and no
throttle flags.

Not covered: arm64 was checked only at the package level (Ubuntu publishes `kiwix`, `kiwix-tools` and
`zim-tools` for arm64 in noble), and the desktop `wlr-randr` path has not been run on real Wayland hardware.

#!/usr/bin/env bash
# Ktemata post-install for Ubuntu / Debian derivatives.
#
# Installs Kiwix (the offline library reader the device is built around), sets up the ZIM
# library directory, and enables kiwix-serve as a systemd service so the library is reachable
# from a browser on the device or over USB tethering. --library nomad skips that stack and
# leaves the library to Project NOMAD. Hardware checks target the Pi 5 and its directly attached
# Waveshare UPS Module 3S on the simplified PCH.
#
#   sudo ./work/scripts/post-install.sh                 # update, install, enable the service
#   sudo ./work/scripts/post-install.sh --sample        # also fetch one small ZIM to test with
#   sudo ./work/scripts/post-install.sh --rotate left   # + turn the Touch Display 2 90 deg left
#   sudo ./work/scripts/post-install.sh --kiosk         # + boot straight into the library
#   sudo ./work/scripts/post-install.sh --hwtest-only   # just the hardware checks, change nothing
#   ./work/scripts/post-install.sh --dry-run            # show what would happen (no root)
#   sudo ./work/scripts/post-install.sh --no-service    # packages only
#   sudo ./work/scripts/post-install.sh --no-update     # skip the system upgrade
#
# Idempotent: re-running is safe, already-installed packages are skipped.
# Tested on Ubuntu 24.04 (noble), amd64 and arm64.
#
# Inspired by tprasadtp/ubuntu-post-install (after-effects), kept much smaller on purpose.

set -euo pipefail

readonly SCRIPT=$(basename "$0")
readonly SCRIPT_VERSION="0.1.0"

# ---------------- defaults (override with flags or environment) ----------------
ZIM_DIR=${ZIM_DIR:-/srv/kiwix/zim}
SERVICE_PORT=${SERVICE_PORT:-8080}
SERVICE_NAME=kiwix
SERVICE_USER=${SERVICE_USER:-kiwix}
STATE_DIR=/var/lib/$SERVICE_NAME
LIBRARY_XML=$STATE_DIR/library.xml
# Which library front end: "host" installs kiwix-serve here; "nomad" leaves the library to
# the Project NOMAD stack (admin on :8080, its Kiwix container on :8090, ZIMs under
# $NOMAD_STORAGE_PATH/zim). The two cannot share :8080, so choose one.
LIBRARY=${LIBRARY:-host}                    # host | nomad
NOMAD_STORAGE_PATH=${NOMAD_STORAGE_PATH:-/opt/project-nomad/storage}
HOST_LIBRARY=true                           # derived from LIBRARY after argument parsing
LIBRARY_DIR=$ZIM_DIR                        # active library path, including NOMAD mode

# a small, genuinely useful ZIM for the smoke test (4.4 MB, wikiHow-style civil defence)
SAMPLE_ZIM=${SAMPLE_ZIM:-wikiciv_en_all_maxi_2025-11.zim}
SAMPLE_URL="https://download.kiwix.org/zim/other/$SAMPLE_ZIM"

# Display rotation. The kernel takes degrees CLOCKWISE; 'left' means 90 deg counter-clockwise
# (what "rotate the screen left" means to a user), so it maps to 270 clockwise.
ROTATE=${ROTATE:-}          # "", normal|left|right|inverted, or 0|90|180|270 (clockwise)

DRY_RUN=false
ASSUME_YES=false
WITH_SAMPLE=false
WITH_SERVICE=true
WITH_GUI=true
# The wallpaper and early boot splash run once at graphical.target (runlevel 5), after the
# desktop user's session bus exists. --no-artwork skips the unit; the script still works
# when run by hand from the desktop.
WITH_ARTWORK=true
ARTWORK_SERVICE=ktemata-artwork
# r5 uses the Waveshare 7inch DSI LCD (C); its overlay must be in config.txt or the panel stays
# dark. --no-display-overlay is for the r4 Touch Display 2 build (auto-detected).
WITH_DISPLAY_OVERLAY=true
DISPLAY_OVERLAY="dtoverlay=vc4-kms-dsi-waveshare-panel,7_0_inchC,i2c1"
# Optional Pi 5 UPS wiring on GPIO12/13 (physical pins 32/33), exposed as Linux I2C bus 2.
UPS_I2C_ALT_PINS=${UPS_I2C_ALT_PINS:-false}
UPS_I2C_OVERLAY="dtoverlay=i2c2-pi5,pins_12_13"
DISPLAY_MODE=${DISPLAY_MODE:-1024x600M}
# The vendor Brightness app is a Qt5 GUI; --no-brightness or --no-gui skips it.
WITH_BRIGHTNESS=true
BRIGHTNESS_URL="https://files.waveshare.com/wiki/common/Brightness.zip"
WITH_UPDATE=true
WITH_KIOSK=false
WITH_AI=false
WITH_HWTEST=true
HWTEST_ONLY=false
STRICT=false
HW_FAILS=0          # faults (e.g. undervoltage): --strict fails on these
HW_WARNS=0          # degraded conditions (e.g. thermal throttling): --strict ignores
HW_CHECKS=0
KIOSK_USER=${KIOSK_USER:-${SUDO_USER:-}}   # whose session autostarts the kiosk
# The account the kiosk runs as, and the one GDM logs in automatically. "ktemata" keeps the
# desktop session separate from the admin user you ssh in as.
AUTOLOGIN_USER=${AUTOLOGIN_USER:-ktemata}
WITH_AUTOLOGIN=true
WITH_NOCAMERA=false     # opt-in: only edit config.txt when asked
# The Pi 5 RTC cell is a rechargeable ML-2020 on J5. Enable the PMIC trickle charge so it
# stays topped up; --no-rtc-charge skips this (and must be used with a non-rechargeable cell).
WITH_RTC_CHARGE=true
# The handheld is also a library hotspot. The Pi 5's radio is on board; serving the ZIM files
# over a private AP is a configuration choice, not extra hardware. Off by default so a fresh
# image keeps the old no-networking behaviour until someone asks for it.
WITH_HOTSPOT=false
HOTSPOT_SSID=${HOTSPOT_SSID:-Ktemata}
HOTSPOT_PASS=${HOTSPOT_PASS:-}          # empty: open network (no password)
HOTSPOT_ADDR=${HOTSPOT_ADDR:-10.10.10.1}
HOTSPOT_CIDR=${HOTSPOT_CIDR:-24}
HOTSPOT_BAND=${HOTSPOT_BAND:-auto}      # auto (2.4+5 GHz) | 2.4 | 5
# The desktop switcher between client, AP and radio-off. It is a root-owned helper plus a
# one-line sudoers rule, because NetworkManager connection changes need root on a stock image
# and an appliance should not ask for a password. --no-wifi-switch skips it.
WITH_WIFI_SWITCH=true
WIFI_SWITCH_BIN=/usr/local/bin/wifi-mode
WIFI_SWITCH_CONF=/etc/ktemata/wifi.conf
WIFI_SWITCH_LEGACY_CONF=/etc/ktemata/wifi-mode.conf
WIFI_SWITCH_SUDOERS=/etc/sudoers.d/ktemata-wifi
WIFI_SWITCH_STATE="not installed"
# NetworkManager has no per-connection switch to keep ipv4.method shared from NATing clients
# (`ipv4.ip-forward` is not a property). The firewall backend is global, so a drop-in turns
# masquerading off while dnsmasq still provides DHCP and DNS for the AP.
NM_NO_NAT_CONF=/etc/NetworkManager/conf.d/90-ktemata-no-nat.conf
NM_NO_NAT_READY=false
# Browser-based library admin: list, upload and delete ZIM files, drive kiwix-serve and rebuild
# its index. It writes the library, so it runs as root behind HTTP Basic auth on its own port;
# --no-admin skips it. The password lives in a root-only file, generated once.
WITH_ADMIN=true
ADMIN_PORT=${ADMIN_PORT:-8081}
ADMIN_BIND=${ADMIN_BIND:-0.0.0.0}       # 127.0.0.1 + an SSH tunnel, or one management address
ADMIN_USER=${ADMIN_USER:-ktemata}
ADMIN_PASS=${ADMIN_PASS:-}              # empty: keep an existing password, or generate one
ADMIN_CONFIG=/etc/ktemata/admin.conf
ADMIN_ASSETS=/usr/share/ktemata/admin
ADMIN_SERVICE=ktemata-admin
ADMIN_STATE="not installed"
# --no-radio turns the radios off in the firmware, so the device is silent at boot and stays
# silent: no AP, no client association, no Bluetooth. Unlike --no-hotspot (which only declines
# to create an AP) this is a real off switch, and it is persistent. Mutually exclusive with
# --hotspot, because a disabled radio cannot host an access point.
WITH_NO_RADIO=false
RADIO_STATE="unchanged"                 # what the config.txt step actually did

# ---------------- output ----------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
    C_BLUE=$'\e[36m'; C_BOLD=$'\e[1m'; C_OFF=$'\e[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""; C_OFF=""
fi

log_info()    { printf '%s•%s %s\n' "$C_BLUE" "$C_OFF" "$*"; }
log_ok()      { printf '%s✓%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
log_warn()    { printf '%s!%s %s\n' "$C_YELLOW" "$C_OFF" "$*" >&2; }
log_error()   { printf '%s✗%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; }
log_stage()   { printf '\n%s%s==>%s %s%s\n' "$C_BOLD" "$C_BLUE" "$C_OFF" "$*" "$C_OFF"; }
die()         { log_error "$*"; exit 1; }

usage() {
    cat <<EOF
${C_BOLD}$SCRIPT $SCRIPT_VERSION${C_OFF} — Ktemata post-install (Ubuntu / Debian derivatives)

${C_BOLD}USAGE${C_OFF}
  [sudo] ./$SCRIPT [OPTION]...

${C_BOLD}OPTIONS${C_OFF}
  -y, --yes              Do not ask for confirmation.
  -n, --dry-run          Print the commands instead of running them (no root needed).
      --sample           Download one small ZIM so the host Kiwix has something to serve
                         (host library only).
      --zim-dir DIR      Library directory (default: $ZIM_DIR).
      --port PORT        kiwix-serve port (default: $SERVICE_PORT).
      --library WHAT     host (default) installs kiwix-serve here; nomad leaves the
                         library to Project NOMAD (admin :8080, Kiwix :8090, ZIMs in
                         $NOMAD_STORAGE_PATH/zim) and installs no host Kiwix.
      --no-service       Install the packages only; do not create/enable the service.
      --no-artwork       Do not install the wallpaper/boot-splash unit at graphical.target.
      --no-display-overlay
                         Do not add the Waveshare 7inch DSI LCD (C) overlay to config.txt
                         (for the r4 Touch Display 2 build, which is auto-detected).
      --ups-i2c-alt-pins Add dtoverlay=i2c2-pi5,pins_12_13 for the UPS on Pi 5 GPIO12/13
                         (physical pins 32/33, Linux bus 2). Opt-in; reboot to apply.
      --no-brightness    Do not install the Waveshare Brightness app (Qt5 GUI).
      --no-gui           Skip the desktop Kiwix app (headless / server installs).
      --no-update        Skip the system upgrade (apt full-upgrade).
      --rotate WHAT      Rotate the display: normal | left | right | inverted,
                         or 0|90|180|270 (degrees clockwise, as the kernel takes them).
                         'left' = 90 deg counter-clockwise.
      --kiosk            Install the kiosk launcher and autostart it in the desktop session.
      --kiosk-user NAME  Whose session autostarts it (default: the user running sudo).
      --ai               Install the offline AI (Ollama + ktemata-ai + llm-tools-kiwix) after
                         the base install. Downloads models and is opt-in; see docs/OFFLINE_AI.md.
      --no-hwtest        Skip the hardware checks.
      --hwtest-only      Run the hardware checks and exit (implies --dry-run).
      --strict           Exit non-zero if a hardware check fails.
      --power usbc|ups3s How the Pi is powered, for undervoltage hints (default: usbc).
      --no-autologin     Do not enable GDM automatic login.
      --no-camera-autodetect
                         Set camera_auto_detect=0 in config.txt (no CSI camera in this
                         build). Touches config.txt, so it is opt-in.
      --no-rtc-charge    Do not enable the Pi RTC trickle charge (default: enable it for
                         the rechargeable ML-2020; never use it with a CR2032).
      --hotspot          Serve the library over its own Wi-Fi access point (wlan0).
                         Uses NetworkManager when present, else hostapd + dnsmasq.
      --no-hotspot       Do not create an access point (default).
      --no-radio         Turn the Wi-Fi and Bluetooth radios OFF in the firmware
                         (dtoverlay=disable-wifi/disable-bt, plus disable-wifi-pi5/
                         disable-bt-pi5 on a Pi 5). No AP, no client association, no
                         Bluetooth: the device cannot transmit at all. Persistent, and
                         takes effect on the next boot. Cannot be combined with --hotspot.
                         Note that the library front end still binds all interfaces, so a
                         USB or Ethernet link that is up can still reach it.
      --hotspot-ssid N   Network name (default: Ktemata).
      --hotspot-pass P   WPA2 password, 8+ characters (default: open network).
      --hotspot-open     Explicitly leave the network open, even if a password was set.
      --hotspot-band B   auto (default) | 2.4 | 5. Only 2.4 GHz reaches older e-readers.
      --hotspot-addr A   AP address (default: 10.10.10.1, matching the Prepper Disk's habit).
      --no-wifi-switch   Do not install the desktop Wi-Fi mode switcher (client / access
                         point / radio off). Skipped automatically with --no-radio, and when
                         NetworkManager is absent.
      --no-admin         Do not install the browser library admin on :$ADMIN_PORT.
      --admin-port N     Port for the library admin (default 8081).
      --admin-bind A     Address the admin listens on (default 0.0.0.0). Use 127.0.0.1 and
                         an SSH tunnel when the LAN is not trusted.
      --admin-user N     Login name for the library admin (default ktemata).
      --admin-pass P     Password for the library admin (8+ characters). Default: keep the
                         existing one, or generate a random password on first install.
      --autologin-user N Account to log in automatically (default: ktemata).
  -h, --help             This message.
  -V, --version          Print the version.

${C_BOLD}ENVIRONMENT${C_OFF}
  ZIM_DIR, SERVICE_PORT, SERVICE_USER, LIBRARY, NOMAD_STORAGE_PATH, DISPLAY_MODE, NO_COLOR,
  UPS_I2C_ALT_PINS, POWER_SOURCE,
  HOTSPOT_SSID, HOTSPOT_PASS, HOTSPOT_ADDR, HOTSPOT_CIDR, HOTSPOT_BAND,
  ADMIN_PORT, ADMIN_BIND, ADMIN_USER, ADMIN_PASS

${C_BOLD}WHAT IT DOES${C_OFF}
  1. checks it is running as root on a Debian derivative
  2. checks the Pi, display, UPS Module 3S gauge, RTC, storage and network
  3. updates the system (apt update + full-upgrade) unless --no-update
  4. installs kiwix-tools (+ kiwix desktop app unless --no-gui)   [--library host]
  5. creates the ZIM library directory                            [--library host]
  6. writes and enables $SERVICE_NAME.service (kiwix-serve on :$SERVICE_PORT)  [--library host]
     and adds a Firefox full-screen library icon to the desktop unless --no-gui
  6a. writes and enables $ADMIN_SERVICE.service: the library admin on :$ADMIN_PORT,
      for uploading and deleting ZIM files and controlling kiwix-serve unless --no-admin
  7. writes and enables $ARTWORK_SERVICE.service: wallpaper + boot splash at graphical.target
  8. adds the Waveshare 7inch DSI LCD (C) overlay unless --no-display-overlay
  9. optionally enables UPS I2C on Pi 5 GPIO12/13 (--ups-i2c-alt-pins)
 10. installs the Waveshare Brightness app unless --no-brightness / --no-gui
 11. optionally sets display rotation, autologin, kiosk, RTC charging and networking
     (including the desktop Wi-Fi mode switcher unless --no-wifi-switch)
 12. optionally installs the offline AI (--ai) — see OFFLINE_AI.md
 13. optionally downloads a sample ZIM (--sample)
 14. verifies the server answers (or the NOMAD containers with --library nomad)

The artwork itself runs in $ARTWORK_SERVICE.service at the next boot, once the desktop user's
session bus exists; to apply it immediately, run ./desktop-artwork.sh from the desktop.
EOF
}

# ---------------- helpers ----------------
run() {
    if $DRY_RUN; then
        printf '%s  [dry-run]%s %s\n' "$C_YELLOW" "$C_OFF" "$*"
        return 0
    fi
    "$@"
}

# run a shell fragment (for redirections / pipes that cannot be argv)
run_sh() {
    if $DRY_RUN; then
        printf '%s  [dry-run]%s %s\n' "$C_YELLOW" "$C_OFF" "$*"
        return 0
    fi
    bash -c "$*"
}

has_command() { command -v "$1" >/dev/null 2>&1; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "must run as root: sudo ./$SCRIPT ${*:-}"
    fi
}

confirm() {
    $ASSUME_YES && return 0
    [ -t 0 ] || die "not a terminal; pass --yes to run unattended"
    local reply
    read -r -p "$1 [y/N] " reply
    [[ $reply =~ ^[Yy]$ ]]
}

have_systemd() { [ -d /run/systemd/system ]; }

# ---------------- steps ----------------
check_platform() {
    log_stage "Platform"

    [ -r /etc/os-release ] || die "/etc/os-release missing; cannot identify the distribution"
    # Read os-release in a subshell: Ubuntu defines VERSION there, and sourcing it into this
    # shell would clash with variables we already own.
    local ID ID_LIKE PRETTY_NAME
    eval "$( ( . /etc/os-release; printf 'ID=%q ID_LIKE=%q PRETTY_NAME=%q\n' \
        "${ID:-}" "${ID_LIKE:-}" "${PRETTY_NAME:-}" ) )"
    local id_like=" ${ID_LIKE:-} "
    case "${ID:-}${id_like}" in
        *debian*|*ubuntu*) ;;
        *) die "this script targets Debian/Ubuntu derivatives; found ID=${ID:-?}" ;;
    esac

    local arch; arch=$(uname -m)
    case $arch in
        x86_64|aarch64|armv7l) ;;
        *) log_warn "untested architecture: $arch" ;;
    esac

    log_ok "${PRETTY_NAME:-$ID} ($arch)"

    if $WITH_SERVICE && $HOST_LIBRARY && ! have_systemd; then
        log_warn "systemd not running (container?); the service will be written but not enabled"
    fi
}

# ============================ hardware checks ============================
# Everything the software depends on but cannot test: the Pi itself, the directly attached UPS
# gauge, RTC, storage and display. Each check prints PASS, FAIL or SKIP (not applicable here), so
# the report is readable on a fresh box.
#
# These are diagnostics, not gates: a missing sensor does not stop Kiwix from working, so
# failures are collected and only affect the exit status with --strict.

hw_pass() { HW_CHECKS=$((HW_CHECKS + 1)); printf '  %sPASS%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
hw_fail() { HW_CHECKS=$((HW_CHECKS + 1)); HW_FAILS=$((HW_FAILS + 1)); printf '  %sFAIL%s %s\n' "$C_RED" "$C_OFF" "$*"; }
hw_skip() { HW_CHECKS=$((HW_CHECKS + 1)); printf '  %sSKIP%s %s\n' "$C_YELLOW" "$C_OFF" "$*"; }
hw_warn() { HW_CHECKS=$((HW_CHECKS + 1)); HW_WARNS=$((HW_WARNS + 1)); printf '  %sWARN%s %s\n' "$C_YELLOW" "$C_OFF" "$*"; }
# kept as an alias so thermal findings read naturally in this file
hw_fail_soft() { hw_warn "$@"; }
hw_note() { printf '        %s\n' "$*"; }

is_pi() {
    [ -r /proc/device-tree/model ] || return 1
    grep -qi 'raspberry pi' /proc/device-tree/model 2>/dev/null
}

pi_model() { tr -d '\0' </proc/device-tree/model 2>/dev/null || echo "unknown"; }

# Select the undervoltage hint with --power ups3s / POWER_SOURCE=ups3s when the Pi is powered by
# the UPS Module 3S. The default remains the bench case (a direct USB-C supply).
power_hint() {
    if [ "${POWER_SOURCE:-usbc}" = ups3s ]; then
        printf '%s\n' "on the UPS Module 3S: check the cells, output switch and 5 V Type-C lead"
    else
        printf '%s' "on USB-C: use the 27 W (5 V/5 A) supply - a 3 A charger gives exactly"
        printf '%s\n' " this under load; check the cable too"
    fi
}


# CPU busy percentage over a short interval, from two /proc/stat samples.
cpu_busy_percent() {
    local a b
    a=$(awk '/^cpu / {print $2+$3+$4, $5}' /proc/stat 2>/dev/null) || return 0
    sleep 1
    b=$(awk '/^cpu / {print $2+$3+$4, $5}' /proc/stat 2>/dev/null) || return 0
    awk -v a="$a" -v b="$b" 'BEGIN {
        split(a, x, " "); split(b, y, " ");
        busy = y[1] - x[1]; idle = y[2] - x[2]; total = busy + idle;
        print (total > 0) ? int(busy * 100 / total) : 0
    }'
}

# The short list that usually explains a hot idle board.
report_hot_processes() {
    command -v ps >/dev/null 2>&1 || return 0
    local top
    top=$(ps -eo pcpu=,comm= --sort=-pcpu 2>/dev/null \
          | awk '$1 >= 10 {printf "%s %s%%, ", $2, $1}' | cut -d, -f1-3 | sed 's/, $//')
    [ -n "$top" ] && hw_note "top CPU: $top"
    return 0
}

# Pi 5 thermal limits (Raspberry Pi documentation): 80 C soft limit -> clock is reduced,
# 85 C hard limit -> hard throttling. Report heat and clock throttling as warnings with load
# context; undervoltage is a supply fault.
hw_thermal() {
    if ! has_command vcgencmd; then
        hw_skip "thermals (install libraspberrypi-bin for throttle/temperature)"
        return
    fi

    # --- temperature: sample, because a single reading may catch a transient -------------
    local t tmin="" tmax="" i
    for i in 1 2 3 4 5; do
        t=$(vcgencmd measure_temp 2>/dev/null | sed -n "s/^temp=\([0-9.]*\)'C$/\1/p")
        if [ -n "$t" ]; then
            awk -v a="$t" -v b="${tmin:-$t}" 'BEGIN {exit !(a < b)}' && tmin=$t
            awk -v a="$t" -v b="${tmax:-$t}" 'BEGIN {exit !(a > b)}' && tmax=$t
            [ -n "$tmin" ] || tmin=$t
            [ -n "$tmax" ] || tmax=$t
        fi
        sleep 0.4
    done

    # --- how busy is it, really? ------------------------------------------------------------
    # Load average counts uninterruptible sleep too, so use actual CPU busy time. Without this
    # A single hot reading cannot distinguish "working hard" from "idle and still 85 C", where
    # the heat is not coming from the CPU.
    local busy_pct cores
    busy_pct=$(cpu_busy_percent)
    cores=$(nproc 2>/dev/null || echo 4)
    local state=idle
    [ "${busy_pct:-0}" -ge 20 ] 2>/dev/null && state=light
    [ "${busy_pct:-0}" -ge 60 ] 2>/dev/null && state=busy

    if [ -z "$tmax" ]; then
        hw_skip "SoC temperature (vcgencmd gave no answer)"
    else
        local hot=${tmax%%.*}        # integer part for the comparison
        local ctx="cpu ${busy_pct:-?}% busy, ${cores} cores"
        if [ "$hot" -ge 85 ]; then
            if [ "$state" = idle ]; then
                # 85 C while doing nothing is not the missing cooler: something else heats it
                hw_fail "SoC ${tmax} C at idle ($ctx) - not load related"
                hw_note "a bare Pi 5 idles around 55-70 C; at ${busy_pct:-?}% CPU this is a fault:"
                hw_note "clearance under the board, a heat trap (case/desk/insulation), or a"
                hw_note "process pegged in the background"
                report_hot_processes
            else
                hw_warn "SoC ${tmax} C - at the 85 C hard limit (throttling); $ctx"
                hw_note "load-related throttling; check the cooler, vents and case airflow"
                report_hot_processes
            fi
        elif [ "$hot" -ge 80 ]; then
            if [ "$state" = idle ]; then
                hw_warn "SoC ${tmax} C at idle ($ctx) - warm for idle"
                report_hot_processes
            else
                hw_warn "SoC ${tmax} C - over the 80 C soft limit (clock reduced); $ctx"
            fi
        else
            hw_pass "SoC ${tmax} C (${tmin}-${tmax} C), $ctx"
        fi
    fi

    # --- throttle flags: the authoritative signal -------------------------------------------
    local thr
    thr=$(vcgencmd get_throttled 2>/dev/null | sed -n 's/.*throttled=0x\([0-9a-fA-F]*\).*/\1/p')
    if [ -z "$thr" ]; then
        hw_skip "throttle flags (vcgencmd gave no answer)"
        return
    fi
    local flags=$((16#$thr))
    local now="" past=""
    (( flags & 0x1 ))  && now="$now undervoltage"
    (( flags & 0x2 ))  && now="$now arm-frequency-capped"
    (( flags & 0x4 ))  && now="$now throttled"
    (( flags & 0x8 ))  && now="$now soft-temp-limit"
    (( flags & 0x10 )) && past="$past undervoltage"
    (( flags & 0x20 )) && past="$past arm-frequency-capped"
    (( flags & 0x40 )) && past="$past throttled"
    (( flags & 0x80 )) && past="$past soft-temp-limit"

    if [ "$flags" -eq 0 ]; then
        hw_pass "no throttle flags since boot (0x0)"
    else
        # undervoltage is the one that means the hardware is being supplied badly
        if (( flags & 0x1 )) || (( flags & 0x10 )); then
            hw_fail "undervoltage flag set (0x$thr)${now:+ now:$now}${past:+ past:$past}"
            hw_note "$(power_hint)"
        else
            hw_fail_soft "throttle flags 0x$thr${now:+ now:$now}${past:+ past:$past}"
        fi
    fi
}


hw_pi() {
    if ! is_pi; then
        hw_skip "Raspberry Pi model (not a Pi: $(uname -m), $(uname -r))"
        return
    fi
    hw_pass "model: $(pi_model)"

    hw_thermal

    if [ -r /proc/device-tree/serial-number ]; then
        hw_pass "serial: $(tr -d '\0' </proc/device-tree/serial-number)"
    fi
}

hw_display() {
    # DSI panel: the Touch Display 2 is autodetected, so it shows up as a DRM connector
    if [ -d /sys/class/drm ]; then
        local dsi
        dsi=$(ls -d /sys/class/drm/card*-DSI-* 2>/dev/null | head -1 || true)
        if [ -n "$dsi" ]; then
            if [ "$(cat "$dsi/status" 2>/dev/null)" = connected ]; then
                local modes
                modes=$(head -1 "$dsi/modes" 2>/dev/null || true)
                local conn=${dsi##*/}
                conn=${conn#card[0-9]*-}          # card1-DSI-1 -> DSI-1
                hw_pass "display connected: $conn (${modes:-no mode})"
            else
                hw_fail "DSI output present but status=$(cat "$dsi/status" 2>/dev/null)"
            fi
        else
            hw_skip "DSI display (no DSI connector in /sys/class/drm)"
        fi
    else
        hw_skip "display (no DRM)"
    fi
}

# i2cdetect is in /usr/sbin, which is not on a user PATH; always call it by path.
i2c_tool() {
    local tool=$1; shift
    for t in "$(command -v "$tool" 2>/dev/null)" "/usr/sbin/$tool" "/usr/bin/$tool"; do
        [ -n "$t" ] && [ -x "$t" ] && { "$t" "$@"; return $?; }
    done
    return 127
}

# Scan once and cache: the UPS check uses the same data, and i2cdetect over every bus is slow.
# Sets I2C_BUSES, I2C_FOUND ("bus:addr ...") and I2C_ALL (unique lowercase addresses).
I2C_SCANNED=false
I2C_BUSES=""
I2C_FOUND=""
I2C_ALL=""
I2C_BOGUS=""      # buses that answer for nearly every address (not real buses)

i2c_scan() {
    $I2C_SCANNED && return 0
    I2C_SCANNED=true
    i2c_tool i2cdetect -l >/dev/null 2>&1 || return 1
    I2C_BUSES=$(i2c_tool i2cdetect -l 2>/dev/null | awk '$1 ~ /^i2c-/ {print $1}' | sort -uV)
    [ -n "$I2C_BUSES" ] || return 1

    local bus map addrs a n
    for bus in $I2C_BUSES; do
        map=$(i2c_tool i2cdetect -y "${bus#i2c-}" 2>/dev/null || true)
        [ -n "$map" ] || continue
        addrs=$(echo "$map" | grep -E '^[0-9a-f]{2}:' \
                | sed 's/^[0-9a-f][0-9a-f]://' \
                | grep -oE '\b[0-9a-f]{2}\b' | grep -v '^--$')
        n=$(printf '%s\n' $addrs | grep -c . || true)

        # A bus that answers for (nearly) every address is not a bus: it is an adapter that
        # ACKs regardless (the vc4-hdmi DDC line is the usual culprit on a Pi). Counting it
        # turns one bad adapter into dozens of "devices" and can make it look as though two
        # strapped addresses of the same chip coexist (0x3c and 0x3d), which is impossible.
        if [ "$n" -gt 0 ] && [ "$n" -ge 32 ]; then
            I2C_BOGUS="$I2C_BOGUS $bus($n)"
            continue
        fi
        for a in $addrs; do I2C_FOUND="$I2C_FOUND $bus:$a"; done
    done
    I2C_FOUND=${I2C_FOUND# }
    I2C_BOGUS=${I2C_BOGUS# }
    I2C_ALL=$(printf '%s\n' $I2C_FOUND | cut -d: -f2 | sort -u | tr '\n' ' ')
    return 0
}

# Label devices used by the current build instead of dumping raw addresses.
i2c_label() {
    case $1 in
        41) echo "UPS Module 3S INA219" ;;
        *)  return 1 ;;
    esac
}

hw_i2c_bus() {
    # The Pi is the I2C master for the UPS Module 3S. Display touch uses its own bus.
    if ! i2c_tool i2cdetect -l >/dev/null 2>&1; then
        hw_skip "I2C (i2c-tools not installed: sudo apt install i2c-tools)"
        return
    fi
    if ! i2c_scan || [ -z "${I2C_BUSES// /}" ]; then
        hw_skip "I2C (no bus exposed; enable I2C in raspi-config)"
        return
    fi

    local nbus; nbus=$(echo $I2C_BUSES | wc -w)

    if [ -z "${I2C_FOUND// /}" ]; then
        hw_skip "I2C: no devices detected on ${nbus} bus(es)"
        return
    fi

    local known="" unknown="" addr label
    for addr in $I2C_ALL; do
        if label=$(i2c_label "$addr"); then
            known="${known:+$known, }0x$addr ($label)"
        else
            unknown="$unknown $addr"
        fi
    done
    [ -n "$known" ] && hw_pass "I2C: $known"

    # Display/camera bridges and unrelated devices are counted, not identified.
    if [ -n "${unknown// /}" ]; then
        local n; n=$(echo $unknown | wc -w)
        hw_note "I2C: $n other address(es) present (not part of this build)"
    fi
    if [ -n "${I2C_BOGUS// /}" ]; then
        hw_note "I2C: ignoring ${I2C_BOGUS// /, } - answers on nearly every address (adapter, not a bus)"
    fi
    [ "$nbus" -gt 2 ] && hw_note "I2C: $nbus buses exposed"
    return 0
}

hw_ups() {
    i2c_tool i2cdetect -l >/dev/null 2>&1 \
        || { hw_skip "UPS Module 3S gauge (i2c-tools not installed)"; return; }
    i2c_scan || { hw_skip "UPS Module 3S gauge (no I2C bus)"; return; }

    if $UPS_I2C_ALT_PINS; then
        if ! printf '%s\n' $I2C_BUSES | grep -qx "i2c-2"; then
            hw_skip "UPS Module 3S gauge (i2c-2 unavailable)"
            hw_note "the GPIO12/13 overlay requires a reboot before i2c-2 appears"
            return
        fi
        if printf '%s\n' $I2C_FOUND | grep -qx "i2c-2:41"; then
            hw_pass "UPS Module 3S INA219 answering at 0x41 on i2c-2"
        else
            hw_fail "UPS Module 3S INA219 not detected at 0x41 on i2c-2"
            hw_note "check UPS SDA/SCL/GND on physical pins 32/33 and the shared ground"
        fi
        return
    fi

    # Default wiring uses bus 1, but board revisions and other overlays can expose a different
    # bus number. A single 0x41 elsewhere is still the UPS; bogus adapters were filtered out.
    if printf '%s\n' $I2C_FOUND | grep -qx "i2c-1:41"; then
        hw_pass "UPS Module 3S INA219 answering at 0x41 on i2c-1"
        return
    fi

    local matches bus
    matches=$(printf '%s\n' $I2C_FOUND | grep ':41$' || true)
    case $(printf '%s\n' $matches | grep -c . || true) in
        0)
            hw_fail "UPS Module 3S INA219 not detected at 0x41 on any available I2C bus"
            hw_note "check UPS SDA/SCL/GND and enable the matching Pi I2C bus"
            ;;
        1)
            bus=${matches%:41}
            hw_pass "UPS Module 3S INA219 answering at 0x41 on $bus (auto-detected)"
            hw_note "for the tray, use: ktemata-ups-tray --i2c-bus ${bus#i2c-} --once"
            ;;
        *)
            hw_fail "UPS Module 3S INA219 is ambiguous: $matches"
            hw_note "use --ups-i2c-alt-pins only for the GPIO12/13 wiring on bus 2"
            ;;
    esac
}

hw_rtc() {
    # The Pi 5 RTC needs the ML-2020 on J5 and the trickle-charge dtparam; both are checkable.
    local rtc
    rtc=$(ls /dev/rtc* 2>/dev/null | head -1 || true)
    if [ -z "$rtc" ]; then
        if is_pi; then
            hw_fail "no /dev/rtc* (RTC cell missing or the interface is disabled)"
        else
            hw_skip "no /dev/rtc* (no RTC on this machine)"
        fi
        return
    fi
    local since
    since=$(cat /sys/class/rtc/rtc0/since_epoch 2>/dev/null || echo "")
    if [ -n "$since" ] && [ "$since" -gt 1600000000 ] 2>/dev/null; then
        hw_pass "RTC $rtc holds $(date -u -d "@$since" '+%F %T UTC' 2>/dev/null || echo "$since")"
    else
        # an epoch near 1970 means the cell is flat or never set
        hw_fail "RTC $rtc reads $(date -u -d "@${since:-0}" '+%F %T UTC' 2>/dev/null || echo "${since:-?}") - cell flat or unset"
    fi
    if grep -qs 'rtc_bbat_vchg' /boot/firmware/config.txt; then
        hw_pass "RTC trickle charging configured"
    else
        hw_note "without dtparam=rtc_bbat_vchg=3000000 the cell is not recharged by the Pi"
    fi
}

hw_storage() {
    local target=${1:-/}
    local avail used
    avail=$(df -Pk "$target" 2>/dev/null | awk 'NR==2 {print int($4/1024)}')
    used=$(df -P "$target" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')
    if [ -z "$avail" ]; then
        hw_fail "cannot stat $target"
        return
    fi
    local kind="microSD"
    local dev root_src
    root_src=$(findmnt -n -o SOURCE / 2>/dev/null || true)
    case $root_src in
        /dev/mmcblk*) kind="microSD ($root_src)" ;;
        /dev/nvme*)   kind="NVMe ($root_src)" ;;
        /dev/sd*)     kind="USB/SATA ($root_src)" ;;
        "")           kind="root" ;;
        *)            kind="$root_src" ;;
    esac
    if [ "$avail" -lt 2048 ]; then
        hw_fail "$target: $avail MB free ($used % used) on $kind - too little for the desktop"
    else
        hw_pass "$target: $avail MB free ($used % used) on $kind"
    fi

    # the ZIM library wants its own space; report it when it exists
    if [ -d "$LIBRARY_DIR" ]; then
        local zims
        zims=$(find "$LIBRARY_DIR" -maxdepth 1 -name '*.zim' | wc -l)
        local zsize
        zsize=$(du -sh "$LIBRARY_DIR" 2>/dev/null | awk '{print $1}')
        if [ "$zims" -eq 0 ]; then
            hw_fail "ZIM library $LIBRARY_DIR is empty (the library will have no content)"
        else
            hw_pass "ZIM library: $zims archive(s), $zsize"
        fi
    fi
}

hw_network() {
    local up
    up=$(find /sys/class/net -mindepth 1 -maxdepth 1 ! -name lo -exec cat '{}/operstate' \; 2>/dev/null \
         | grep -c up || true)
    if [ "${up:-0}" -gt 0 ]; then
        hw_pass "$up network interface(s) up"
    else
        hw_skip "no network link (expected: Wi-Fi/LAN are off in this build)"
    fi

    # the kiosk only needs loopback, so this is informational
    if ss -ltn 2>/dev/null | grep -q ":$SERVICE_PORT "; then
        if $HOST_LIBRARY; then
            hw_pass "port $SERVICE_PORT listening"
        else
            hw_pass "port $SERVICE_PORT listening (NOMAD admin)"
        fi
    else
        if $HOST_LIBRARY; then
            hw_note "hint: port $SERVICE_PORT not listening yet (service starts once a ZIM exists)"
        else
            hw_note "hint: NOMAD not started yet (admin :8080, Kiwix :8090)"
        fi
    fi
}

hw_audio() {
    # no sound in this build; only report if a card is unexpectedly present
    if [ -e /proc/asound/cards ] && grep -qv '^\s*$' /proc/asound/cards 2>/dev/null; then
        hw_note "audio card detected (not used by this build)"
    fi
}

run_hw_tests() {
    if ! $WITH_HWTEST; then
        log_stage "Hardware"
        log_info "skipped (--no-hwtest)"
        return 0
    fi
    log_stage "Hardware"

    hw_pi
    hw_display
    hw_i2c_bus
    hw_ups
    hw_rtc
    hw_storage /
    hw_network
    hw_audio

    printf '\n  %d checks, %d failed, %d warning(s)\n' "$HW_CHECKS" "$HW_FAILS" "$HW_WARNS"
    if [ "$HW_FAILS" -gt 0 ]; then
        log_warn "$HW_FAILS hardware check(s) failed; the software is installed regardless"
    fi
}


update_system() {
    if ! $WITH_UPDATE; then
        log_stage "System update"
        log_info "skipped (--no-update)"
        return 0
    fi
    log_stage "System update"

    # Do this first: packages installed later then need no second upgrade pass, and a fresh
    # image does not get a Kiwix build that is hours away from being superseded.
    run env DEBIAN_FRONTEND=noninteractive apt-get update -qq
    log_ok "package lists refreshed"

    run env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold full-upgrade -qq
    log_ok "system up to date"
}

# "left" is 90 deg counter-clockwise; the kernel wants clockwise degrees.
rotation_degrees() {
    case "${1,,}" in
        ""|none|off)  return 1 ;;
        normal|0)     printf 0 ;;
        left|270)     printf 270 ;;
        right|90)     printf 90 ;;
        inverted|180) printf 180 ;;
        *)            die "--rotate takes normal|left|right|inverted (or 0|90|180|270), not '$1'" ;;
    esac
}

setup_rotation() {
    log_stage "Display rotation"

    local deg
    if ! deg=$(rotation_degrees "$ROTATE"); then
        log_info "skipped (pass --rotate left|right|inverted to enable)"
        return 0
    fi

    # Only Raspberry Pi OS has this file; on a generic Ubuntu box there is nothing to rotate.
    local cmdline="${CMDLINE_FILE:-/boot/firmware/cmdline.txt}"
    if [ ! -f "$cmdline" ]; then
        log_warn "$cmdline not found: not a Raspberry Pi OS boot partition, skipping"
        return 0
    fi

    # The Waveshare panel is 1024x600 natively; rotate= is clockwise degrees, console only.
    local want="video=DSI-1:$DISPLAY_MODE@60,rotate=$deg"
    if grep -q 'video=DSI-1:' "$cmdline"; then
        if grep -q "video=DSI-1:$DISPLAY_MODE@60,rotate=$deg\b" "$cmdline"; then
            log_ok "already set to $deg deg clockwise"
            return 0
        fi
        log_info "replacing the existing DSI-1 rotation with $deg deg clockwise"
        if $DRY_RUN; then
            printf '%s  [dry-run]%s sed -i -E update DSI-1 line in %s\n' "$C_YELLOW" "$C_OFF" "$cmdline"
        else
            cp -a "$cmdline" "$cmdline.ktemata.bak"
            sed -i -E "s#video=DSI-1:[^ ]*#${want}#" "$cmdline"
        fi
    else
        log_info "adding '$want' to $cmdline"
        if $DRY_RUN; then
            printf '%s  [dry-run]%s append %s\n' "$C_YELLOW" "$C_OFF" "$want"
        else
            cp -a "$cmdline" "$cmdline.ktemata.bak"
            # cmdline.txt MUST stay a single line: the firmware reads one line and ignores the
            # rest, so join onto the existing line and keep exactly one trailing newline.
            if [ -n "$(tail -c1 "$cmdline")" ]; then
                printf ' %s\n' "$want" >>"$cmdline"      # no trailing newline to start with
            else
                sed -i -e '$ s/$/ '"$want"'/' "$cmdline"  # replace the final newline
            fi
        fi
    fi

    # The kernel rotate= only covers the text console. On a desktop session, rotate the
    # compositor output too, now if possible and persistently via the user's profile.
    rotate_desktop "$deg"
}

rotate_desktop() {
    local deg=$1 out
    if ! has_command wlr-randr; then
        log_info "wlr-randr not installed: desktop rotation not applied (console only)"
        log_info "  with the desktop: Preferences > Screen Configuration > DSI-1 > Orientation"
        return 0
    fi
    out=$(wlr-randr 2>/dev/null | awk '/^[A-Za-z]/ {print $1}' | head -1)
    if [ -z "$out" ]; then
        log_info "no Wayland output found (headless?); console rotation stands"
        return 0
    fi
    local transform
    case $deg in
        0)   transform=normal ;;
        90)  transform=90 ;;
        180) transform=180 ;;
        270) transform=270 ;;
    esac
    log_info "wlr-randr --output $out --transform $transform (per user session)"
    run wlr-randr --output "$out" --transform "$transform"
}

install_packages() {
    log_stage "Packages"

    local pkgs=(curl ca-certificates)
    $HOST_LIBRARY && pkgs+=(kiwix-tools)
    if $WITH_GUI && $HOST_LIBRARY; then
        pkgs+=(kiwix)
    fi
    # The desktop shortcut opens the host library in Firefox's full-screen kiosk mode.
    if $WITH_GUI && $HOST_LIBRARY && $WITH_SERVICE && ! has_command firefox; then
        if apt-cache show firefox >/dev/null 2>&1; then
            pkgs+=(firefox)
        else
            log_warn "Firefox is not available from this system's package sources"
        fi
    fi
    # The Waveshare Brightness app is a Qt5 GUI; add the libs it links when the archive has
    # them (t64 names on Debian 13, plain names on Ubuntu 24.04).
    if $WITH_GUI && $WITH_BRIGHTNESS; then
        pkgs+=(python3)  # unpacks the vendor archive with python3 -m zipfile
        local pkg
        for pkg in libqt5core5t64 libqt5core5a; do
            if apt-cache show "$pkg" >/dev/null 2>&1; then pkgs+=("$pkg"); break; fi
        done
        for pkg in libqt5gui5t64 libqt5gui5; do
            if apt-cache show "$pkg" >/dev/null 2>&1; then pkgs+=("$pkg"); break; fi
        done
        for pkg in libqt5widgets5t64 libqt5widgets5; do
            if apt-cache show "$pkg" >/dev/null 2>&1; then pkgs+=("$pkg"); break; fi
        done
        if apt-cache show libgl1 >/dev/null 2>&1; then pkgs+=(libgl1); fi
    fi
    # desktop rotation is done with wlr-randr; only needed when a rotation was requested
    if [ -n "$ROTATE" ] && $WITH_GUI; then
        pkgs+=(wlr-randr)
    fi
    # the Wi-Fi switcher's chooser is zenity; the CLI works without it
    if $WITH_GUI && $WITH_WIFI_SWITCH && ! $WITH_NO_RADIO; then
        if apt-cache show zenity >/dev/null 2>&1; then
            pkgs+=(zenity)
        fi
    fi
    # The kiosk needs a browser. Debian ships `chromium`; Ubuntu only has `chromium-browser`,
    # which is a snap transition, and Raspberry Pi OS has `chromium`. Ask apt which exists
    # instead of guessing, and never let this fail the install.
    if $WITH_KIOSK; then
        if apt-cache show chromium >/dev/null 2>&1; then
            pkgs+=(chromium)
        elif apt-cache show chromium-browser >/dev/null 2>&1; then
            pkgs+=(chromium-browser)
        else
            log_warn "no chromium package in this archive; the kiosk will need another browser"
        fi
    fi
    # the hardware report uses i2cdetect/vcgencmd; harmless if a package is unavailable
    $WITH_HWTEST && pkgs+=(i2c-tools)
    # hwclock moved to util-linux-extra on Debian 12+ (still in util-linux on older releases)
    if apt-cache show util-linux-extra >/dev/null 2>&1; then
        pkgs+=(util-linux-extra)
    fi

    log_info "installing: ${pkgs[*]}"
    # with --no-update the package lists were not refreshed yet
    $WITH_UPDATE || run env DEBIAN_FRONTEND=noninteractive apt-get update -qq
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"

    if $HOST_LIBRARY && ! $DRY_RUN; then
        has_command kiwix-serve || die "kiwix-serve is still missing after install"
        log_ok "$(kiwix-serve --version 2>&1 | head -1)"
    fi
}

setup_library() {
    if ! $HOST_LIBRARY; then
        log_stage "Library"
        log_info "skipped (--library nomad; NOMAD serves $LIBRARY_DIR)"
        return 0
    fi
    log_stage "Library"
    log_info "ZIM directory: $ZIM_DIR"

    if [ -d "$ZIM_DIR" ]; then
        log_ok "already exists"
    else
        run install -d -m 0755 -o root -g root "$ZIM_DIR"
        log_ok "created"
    fi

    if ! $WITH_SERVICE; then
        return 0
    fi

    if id -u "$SERVICE_USER" >/dev/null 2>&1; then
        log_ok "service user $SERVICE_USER exists"
    else
        run useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"
        log_ok "created service user $SERVICE_USER"
    fi
    # the unit runs as this user, so it must be able to read the archives
    grant_library_access
}

# Install the kiosk launcher and an autostart entry for the desktop session.
# Ensure the account exists, then enable GDM automatic login for it.
#
# GDM reads /etc/gdm3/custom.conf on Ubuntu and /etc/gdm3/daemon.conf on Debian; the same
# [daemon] keys work in both. Only touch the two keys we own: the file carries a lot of
# commented defaults and users may have set others.
install_autologin() {
    $WITH_AUTOLOGIN || { log_stage "Autologin"; log_info "skipped (--no-autologin)"; return 0; }
    log_stage "Autologin"

    # 1. the account. On Raspberry Pi OS the first-boot wizard already created it (with the
    # password you chose), so only create one when it is missing — and never lock an account
    # the user can currently log in with over ssh.
    if id -u "$AUTOLOGIN_USER" >/dev/null 2>&1; then
        log_ok "user $AUTOLOGIN_USER exists"
    else
        run useradd --create-home --shell /bin/bash "$AUTOLOGIN_USER"
        $DRY_RUN || log_ok "created $AUTOLOGIN_USER (no password set)"
        log_warn "set a password: passwd $AUTOLOGIN_USER"
    fi

    # 2. which display manager is in charge? Raspberry Pi OS uses LightDM, Ubuntu GNOME uses
    # GDM, and they do not read the same file — writing the wrong one silently does nothing.
    if [ -f "${LIGHTDM_CONF:-/etc/lightdm/lightdm.conf}" ] || has_command lightdm; then
        autologin_lightdm
    elif [ -f /etc/gdm3/custom.conf ] || [ -f /etc/gdm3/daemon.conf ] || has_command gdm3; then
        autologin_gdm
    else
        log_warn "neither LightDM nor GDM found; skipping autologin"
        log_info "  console autologin instead: systemctl edit getty@tty1"
        return 0
    fi

    # 3. autologin is pointless without a session to log in to
    if ! dpkg -l 2>/dev/null | awk '$1=="ii"{print $2}' | grep -qE 'task-.*-desktop|ubuntu-desktop|gnome-shell|labwc|lxde|raspberrypi-ui-mods'; then
        log_warn "no desktop environment found: autologin would start a text console"
    fi
}

# Raspberry Pi OS: [Seat:*] autologin-user in /etc/lightdm/lightdm.conf, which is exactly
# what raspi-config's "B4 Desktop Autologin" writes. The file is largely commented defaults.
autologin_lightdm() {
    # overridable for testing; nothing in normal operation sets it
    local conf=${LIGHTDM_CONF:-/etc/lightdm/lightdm.conf}
    if [ ! -f "$conf" ]; then
        log_warn "$conf not found; install lightdm or use raspi-config B4"
        return 0
    fi
    log_info "display manager: LightDM"

    if $DRY_RUN; then
        printf '%s  [dry-run]%s set autologin-user=%s in %s\n' "$C_YELLOW" "$C_OFF" "$AUTOLOGIN_USER" "$conf"
        return 0
    fi

    [ -f "$conf.ktemata.bak" ] || cp -a "$conf" "$conf.ktemata.bak"

    if grep -qE '^[#;]?[[:space:]]*autologin-user[[:space:]]*=' "$conf"; then
        sed -i -E "s|^[#;]?[[:space:]]*autologin-user[[:space:]]*=.*|autologin-user=$AUTOLOGIN_USER|" "$conf"
    elif grep -q '^\[Seat:\*\]' "$conf"; then
        sed -i "/^\[Seat:\*\]/a autologin-user=$AUTOLOGIN_USER" "$conf"
    else
        printf '\n[Seat:*]\nautologin-user=%s\n' "$AUTOLOGIN_USER" >>"$conf"
    fi

    # pam needs to allow the nopasswd login for the greeter to auto-session
    if [ -f /etc/pam.d/lightdm-autologin ] && ! grep -q "nopasswdlogin" /etc/group 2>/dev/null; then
        log_info "note: LightDM autologin uses /etc/pam.d/lightdm-autologin"
    fi

    local got
    got=$(sed -n 's/^autologin-user=//p' "$conf" | head -1)
    if [ "$got" = "$AUTOLOGIN_USER" ]; then
        log_ok "autologin-user=$got ($conf)"
    else
        log_error "could not set autologin-user in $conf (reads '$got')"
    fi
}

# Ubuntu / GNOME. Only the two keys we own are touched.
autologin_gdm() {
    local conf=""
    for c in /etc/gdm3/custom.conf /etc/gdm3/daemon.conf; do
        [ -f "$c" ] && { conf=$c; break; }
    done
    if [ -z "$conf" ]; then
        conf=/etc/gdm3/custom.conf
        $DRY_RUN || { install -d -m 0755 /etc/gdm3; : >"$conf"; }
    fi
    log_info "display manager: GDM ($conf)"

    if $DRY_RUN; then
        printf '%s  [dry-run]%s set [daemon] AutomaticLoginEnable=true, AutomaticLogin=%s\n' \
            "$C_YELLOW" "$C_OFF" "$AUTOLOGIN_USER"
        return 0
    fi

    [ -f "$conf.ktemata.bak" ] || cp -a "$conf" "$conf.ktemata.bak"
    grep -q '^\[daemon\]' "$conf" || printf '\n[daemon]\n' >>"$conf"

    set_daemon_key() {
        local key=$1 value=$2
        # allow "Key=value", "Key = value" and the commented "#  Key = value" default
        if grep -qE "^[#;]?[[:space:]]*${key}[[:space:]]*=" "$conf"; then
            sed -i -E "s|^[#;]?[[:space:]]*${key}[[:space:]]*=.*|${key}=${value}|" "$conf"
        else
            sed -i -E "/^\[daemon\]/a ${key}=${value}" "$conf"
        fi
    }
    set_daemon_key AutomaticLoginEnable true
    set_daemon_key AutomaticLogin "$AUTOLOGIN_USER"

    local readback
    readback=$(awk -F= '/^\[daemon\]/{d=1;next} /^\[/{d=0} d && /^(AutomaticLoginEnable|AutomaticLogin)=/{print}' "$conf" | tr '\n' ' ')
    case $readback in
        *AutomaticLoginEnable=true*AutomaticLogin="$AUTOLOGIN_USER"*|*AutomaticLogin="$AUTOLOGIN_USER"*AutomaticLoginEnable=true*)
            log_ok "[daemon] $readback" ;;
        *)  log_error "could not set autologin; $conf reads: $readback" ;;
    esac
}


# Enable the PMIC's trickle charge for the Pi 5's RTC cell. The build uses a rechargeable
# ML-2020 on J5; a non-rechargeable CR2032 must NOT be trickle-charged, hence the opt-out.
setup_rtc_charge() {
    $WITH_RTC_CHARGE || { log_stage "RTC trickle"; log_info "skipped (--no-rtc-charge)"; return 0; }
    log_stage "RTC trickle"

    local cfg="${CONFIG_TXT:-/boot/firmware/config.txt}"
    if [ ! -f "$cfg" ]; then
        log_info "no $cfg: not a Raspberry Pi boot partition, skipping"
        return 0
    fi

    if grep -qx 'dtparam=rtc_bbat_vchg=3000000' "$cfg"; then
        log_ok "already enabled for the ML-2020"
        return 0
    fi

    if $DRY_RUN; then
        printf '%s  [dry-run]%s set dtparam=rtc_bbat_vchg=3000000 in %s\n' "$C_YELLOW" "$C_OFF" "$cfg"
        return 0
    fi

    [ -f "$cfg.ktemata.bak" ] || cp -a "$cfg" "$cfg.ktemata.bak"

    # A commented or different-value line is replaced in place; otherwise append.
    if grep -qE '^[#[:space:]]*dtparam=rtc_bbat_vchg[[:space:]]*=' "$cfg"; then
        sed -i -E 's|^[#[:space:]]*dtparam=rtc_bbat_vchg[[:space:]]*=.*|dtparam=rtc_bbat_vchg=3000000|' "$cfg"
    else
        printf '\ndtparam=rtc_bbat_vchg=3000000\n' >>"$cfg"
    fi

    local n
    n=$(grep -c '^dtparam=rtc_bbat_vchg=3000000$' "$cfg")
    if [ "$n" = 1 ]; then
        log_ok "enabled (reboot to apply; ML-2020 only)"
    else
        log_error "RTC trickle edit looks wrong: $n live line(s)"
        log_warn "restore with: sudo cp $cfg.ktemata.bak $cfg"
    fi
}

# Turn off the firmware's CSI-camera probe. The build has no camera, so this only removes
# a boot-time scan. Opt-in: config.txt can make the board unbootable, so nothing here runs
# unless asked for, and the edit is the narrowest possible.
#
# Deliberately NOT touched:
#   display_auto_detect=1  - it loads overlays for the DSI display; 0 breaks the TD2
#   display_rotate         - firmware-legacy, ignored by the KMS driver on Pi 5
#   dtparam=audio=on       - stock, and the build does not need it changed
set_camera_autodetect_off() {
    $WITH_NOCAMERA || return 0
    log_stage "Camera autodetect"

    local cfg="${CONFIG_TXT:-/boot/firmware/config.txt}"
    if [ ! -f "$cfg" ]; then
        log_info "no $cfg: not a Raspberry Pi boot partition, skipping"
        return 0
    fi

    if grep -qE '^[[:space:]]*camera_auto_detect=0' "$cfg"; then
        log_ok "already disabled"
        return 0
    fi

    if $DRY_RUN; then
        printf '%s  [dry-run]%s set camera_auto_detect=0 in %s\n' "$C_YELLOW" "$C_OFF" "$cfg"
        return 0
    fi

    [ -f "$cfg.ktemata.bak" ] || cp -a "$cfg" "$cfg.ktemata.bak"

    # commented ("#camera_auto_detect=1"), enabled, or absent: handle all three, and never
    # leave two live copies
    if grep -qE '^[#[:space:]]*camera_auto_detect[[:space:]]*=' "$cfg"; then
        sed -i -E 's|^[#[:space:]]*camera_auto_detect[[:space:]]*=.*|camera_auto_detect=0|' "$cfg"
    else
        printf 'camera_auto_detect=0\n' >>"$cfg"
    fi

    local n
    n=$(grep -c '^camera_auto_detect=' "$cfg")
    if [ "$n" = 1 ] && grep -qx 'camera_auto_detect=0' "$cfg"; then
        log_ok "camera_auto_detect=0 ($cfg)"
    else
        log_error "camera_auto_detect edit looks wrong: $n live line(s)"
        log_warn "restore with: sudo cp $cfg.ktemata.bak $cfg"
    fi
}

# ---------------------------------------------------------------------------------------
# --no-radio: turn the radios off in the firmware
# ---------------------------------------------------------------------------------------
# This is the real off switch, as opposed to --no-hotspot, which only declines to create an
# access point: without this, wlan0 is still enabled and associates with any saved network,
# and kiwix-serve still binds 0.0.0.0:8080.
#
# dtoverlay=disable-wifi / disable-bt load a .dtbo that sets the WLAN SDIO controller and the
# Bluetooth node to "disabled", so the kernel never probes them. The Pi 5 (BCM2712) has its
# own variants that target &sdio2 and &bluetooth instead of &mmc/&mmcnr; the firmware picks
# them automatically, but this writes the explicit name as well, because a silent boot should
# not depend on a fallback rule.
#
# What it does NOT do: unload an already-loaded radio in the running system (only a reboot
# removes the interface), and it does not stop a USB Wi-Fi dongle or an Ethernet link. It is
# the on-board radios, which is what the device ships with.
set_radio_off() {
    $WITH_NO_RADIO || return 0
    log_stage "Radios off"

    local cfg="${CONFIG_TXT:-/boot/firmware/config.txt}"
    if [ ! -f "$cfg" ]; then
        log_info "no $cfg: not a Raspberry Pi boot partition, skipping"
        RADIO_STATE="no $cfg"
        return 0
    fi

    # BCM2712 = Pi 5 / 500 / CM5, which need the -pi5 overlay variants. Read the SoC from the
    # device tree when it is there; fall back to the model line in /proc/cpuinfo.
    # KTEMATA_DEVICE_TREE and KTEMATA_CPUINFO exist so the choice can be exercised in a test
    # without a Pi 5; both default to the real paths.
    local soc="" overlays
    local dt="${KTEMATA_DEVICE_TREE:-/proc/device-tree}"
    local cpuinfo="${KTEMATA_CPUINFO:-/proc/cpuinfo}"
    if [ -r "$dt/compatible" ]; then
        soc=$(tr -d '\0' <"$dt/compatible" 2>/dev/null || true)
    fi
    if [ -z "$soc" ] && [ -r "$cpuinfo" ]; then
        soc=$(sed -n 's/^Model.*: //p' "$cpuinfo" 2>/dev/null | head -1 || true)
    fi
    case "$soc" in
        *bcm2712*|*"Raspberry Pi 5"*|*"Raspberry Pi 500"*|*"Compute Module 5"*)
            overlays="disable-wifi-pi5 disable-bt-pi5" ;;
        *)
            overlays="disable-wifi disable-bt" ;;
    esac

    local ov lines=() missing=()
    for ov in $overlays; do
        lines+=("dtoverlay=$ov")
    done

    if $DRY_RUN; then
        printf '%s  [dry-run]%s add %s to %s (next boot)\n' \
            "$C_YELLOW" "$C_OFF" "${lines[*]}" "$cfg"
        RADIO_STATE="would be off (${overlays})"
        return 0
    fi

    [ -f "$cfg.ktemata.bak" ] || cp -a "$cfg" "$cfg.ktemata.bak"

    local line
    for line in "${lines[@]}"; do
        # already live, commented out, or absent: end up with exactly one live line
        if grep -qx -- "$line" "$cfg"; then
            continue
        fi
        if grep -qE "^[#[:space:]]*dtoverlay=${line#dtoverlay=}[[:space:]]*$" "$cfg"; then
            # uncomment in place; keep the file's own ordering
            sed -i -E "s|^[#[:space:]]*(dtoverlay=${line#dtoverlay=})[[:space:]]*\$|\1|" "$cfg"
        else
            printf '%s\n' "$line" >>"$cfg"
        fi
    done

    # verify each one ended up live exactly once; a duplicated dtoverlay is harmless but a
    # missing one is the whole point of the flag
    local n
    for line in "${lines[@]}"; do
        n=$(grep -cx -- "$line" "$cfg")
        if [ "$n" = 1 ]; then
            log_ok "$line"
        else
            log_error "$line appears $n times in $cfg"
            missing+=("$line")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log_warn "restore with: sudo cp $cfg.ktemata.bak $cfg"
        RADIO_STATE="FAILED"
        return 0          # do not abort the install over this; the summary reports it
    fi

    RADIO_STATE="off (${overlays}), next boot"
    log_info "the radios stay up until the next reboot"
}

# ---------------------------------------------------------------------------------------
# Library hotspot (access point for phones / laptops / e-readers)
# ---------------------------------------------------------------------------------------
# The Pi 5 has a dual-band 2.4/5 GHz radio on board. Nothing has to be added to serve the library
# to a room: hostapd makes it an AP, dnsmasq hands out addresses and resolves every name to the
# box, and kiwix-serve (:8080) is what they browse. Roughly 0.4 W, estimated.
#
# NetworkManager is used when it is present (Raspberry Pi OS Bookworm+ and Ubuntu desktop both
# ship it) because `nmcli` writes a self-contained profile that survives reboots; otherwise the
# step falls back to hostapd + dnsmasq units. Either way the wired/uplink interface is untouched,
# so the machine can still be updated over Ethernet while it serves.
#
# Deliberately NOT done here:
#   - no NAT to the internet. `ipv4.method shared` normally masquerades clients onto whatever
#     uplink is up, and NetworkManager has no per-connection switch for it (`ipv4.ip-forward` is
#     not a property). A conf.d drop-in sets firewall-backend=none: DHCP and DNS still come from
#     NetworkManager's own dnsmasq, but no masquerade rule is added. An appliance that silently
#     NATs a room onto a hotel/office LAN is worse than one that does not.
#   - no rfkill unblock by default: if the radio is hard-blocked by a switch, the step reports it.
#   - no hostname change: `kiwix.local` and the IP both work, and mDNS is already on the image.

# One drop-in, shared by the --hotspot step and the desktop switcher. Idempotent; reloads
# NetworkManager's configuration when it had to write the file.
write_nm_no_nat() {
    $NM_NO_NAT_READY && return 0
    if $DRY_RUN; then
        printf '%s  [dry-run]%s write %s (firewall-backend=none; no NAT for shared connections)\n' \
            "$C_YELLOW" "$C_OFF" "$NM_NO_NAT_CONF"
        NM_NO_NAT_READY=true
        return 0
    fi

    if [ -r "$NM_NO_NAT_CONF" ] && grep -qx 'firewall-backend=none' "$NM_NO_NAT_CONF"; then
        log_ok "$NM_NO_NAT_CONF already disables NAT for shared connections"
        NM_NO_NAT_READY=true
        if has_command nmcli; then
            run nmcli general reload conf >/dev/null 2>&1 || true
        fi
        return 0
    fi

    install -d -m 0755 "$(dirname "$NM_NO_NAT_CONF")"
    {
        printf '[main]\n'
        printf '# Ktemata: the library AP serves DHCP/DNS but must not NAT clients onto the uplink.\n'
        printf 'firewall-backend=none\n'
    } >"$NM_NO_NAT_CONF"
    chmod 0644 "$NM_NO_NAT_CONF"
    NM_NO_NAT_READY=true
    log_ok "$NM_NO_NAT_CONF (no NAT for shared connections)"
    if has_command nmcli; then
        run nmcli general reload conf >/dev/null 2>&1 || \
            run systemctl reload NetworkManager >/dev/null 2>&1 || \
            log_warn "reload NetworkManager to apply the no-NAT setting"
    fi
}

setup_hotspot() {
    $WITH_HOTSPOT || return 0
    log_stage "Library hotspot"

    if [ ! -d /sys/class/net/wlan0 ]; then
        log_warn "no wlan0 interface: this board has no usable Wi-Fi radio, skipping"
        return 0
    fi

    # Also on the "profile already exists" path below: an older profile may have been created
    # while NAT was still on, and this drop-in is what keeps it off.
    if has_command nmcli; then
        write_nm_no_nat
    fi

    # An existing, working AP profile must not be overwritten by re-running the installer.
    # A half-configured one (for example from the old ipv4.ip-forward failure) is repaired below.
    if has_command nmcli && nmcli -t -f NAME connection show 2>/dev/null | grep -qx "$HOTSPOT_SSID"; then
        local mode
        mode=$(nmcli -g 802-11-wireless.mode connection show "$HOTSPOT_SSID" 2>/dev/null || true)
        if [ "$mode" = ap ]; then
            log_ok "NetworkManager profile '$HOTSPOT_SSID' already exists, leaving it alone"
            verify_hotspot
            return 0
        fi
        log_warn "profile '$HOTSPOT_SSID' exists but is not an access point; repairing it"
    fi

    if has_command nmcli; then
        install_hotspot_nm
    else
        install_hotspot_hostapd
    fi
    verify_hotspot
}

# NetworkManager's band property: 'bg' = 2.4 GHz only, 'a' = 5 GHz only, unset = either.
hotspot_nm_band() {
    case $HOTSPOT_BAND in
        2.4) echo bg ;;
        5)   echo a ;;
        *)   echo "" ;;   # auto: leave it to the driver
    esac
}

install_hotspot_nm() {
    log_info "NetworkManager is present: creating a shared AP profile"
    write_nm_no_nat
    $DRY_RUN || {
        # 802-11-wireless mode ap = real access point (not ad-hoc), so phones connect normally.
        # Only add when missing: setup_hotspot routes a half-configured profile here for repair.
        if ! nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$HOTSPOT_SSID"; then
            nmcli connection add type wifi ifname wlan0 con-name "$HOTSPOT_SSID" \
                autoconnect yes ssid "$HOTSPOT_SSID" >/dev/null
        fi
        # band is only set when pinned: an empty value is an nmcli error, and leaving it unset
        # lets the driver pick, which is what "auto" should mean
        local nm_args=(
            802-11-wireless.mode ap
            ipv4.method shared
            ipv4.addresses "$HOTSPOT_ADDR/$HOTSPOT_CIDR"
            ipv6.method disabled
        )
        local band; band=$(hotspot_nm_band)
        [ -n "$band" ] && nm_args+=(802-11-wireless.band "$band")
        nmcli connection modify "$HOTSPOT_SSID" "${nm_args[@]}" >/dev/null
        if [ -n "$HOTSPOT_PASS" ]; then
            nmcli connection modify "$HOTSPOT_SSID" \
                802-11-wireless-security.key-mgmt wpa-psk \
                802-11-wireless-security.psk "$HOTSPOT_PASS" >/dev/null
        else
            log_warn "no password: the library is readable by anyone in radio range"
        fi
        log_ok "profile '$HOTSPOT_SSID' configured on wlan0 ($HOTSPOT_ADDR/$HOTSPOT_CIDR)"
    }
    $DRY_RUN && printf '%s  [dry-run]%s nmcli connection add ... ssid %s\n' \
        "$C_YELLOW" "$C_OFF" "$HOTSPOT_SSID"

    # ipv4.method shared gives DHCP + DNS via NetworkManager's own dnsmasq instance, so no
    # separate dnsmasq/hostapd unit is needed. The no-NAT drop-in keeps it from masquerading
    # clients onto the uplink. Bring it up now rather than at the next boot.
    run nmcli connection up "$HOTSPOT_SSID" || log_warn "could not bring the AP up yet"
}

install_hotspot_hostapd() {
    log_info "no NetworkManager: falling back to hostapd + dnsmasq"
    local pkgs=(hostapd dnsmasq)
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"

    if $DRY_RUN; then
        printf '%s  [dry-run]%s write /etc/hostapd/hostapd.conf and /etc/dnsmasq.d/ktemata-hotspot.conf\n' \
            "$C_YELLOW" "$C_OFF"
        return 0
    fi

    local hw
    hw=$(grep -q '^country=' /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null && \
         sed -n 's/^country=\(..\).*/\1/p' /etc/wpa_supplicant/wpa_supplicant.conf | head -1)
    hw=${hw:-NL}

    # hw_mode/ieee80211ac follow --hotspot-band; 2.4 GHz is the safe default because older
    # e-readers and cheap phones have no 5 GHz radio at all
    local hw_mode=g ac_line=""
    case $HOTSPOT_BAND in
        5) hw_mode=a; ac_line="ieee80211ac=1" ;;
    esac

    cat >/etc/hostapd/hostapd.conf <<APCONF
# Ktemata library hotspot (written by post-install.sh)
interface=wlan0
driver=nl80211
ssid=$HOTSPOT_SSID
hw_mode=$hw_mode
channel=$([ "$hw_mode" = a ] && echo 36 || echo 6)
country_code=$hw
ieee80211n=1
$ac_line
wmm_enabled=1
APCONF
    if [ -n "$HOTSPOT_PASS" ]; then
        cat >>/etc/hostapd/hostapd.conf <<APCONF
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_passphrase=$HOTSPOT_PASS
rsn_pairwise=CCMP
APCONF
    else
        log_warn "no password: the library is readable by anyone in radio range"
    fi
    chmod 0600 /etc/hostapd/hostapd.conf
    sed -i 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd 2>/dev/null || true

    # dnsmasq: DHCP on wlan0 only, and answer every name with this box so any URL works
    cat >/etc/dnsmasq.d/ktemata-hotspot.conf <<DNSCONF
# Ktemata library hotspot (written by post-install.sh)
interface=wlan0
bind-interfaces
dhcp-range=${HOTSPOT_ADDR%.*}.10,${HOTSPOT_ADDR%.*}.200,12h
address=/#/$HOTSPOT_ADDR
DNSCONF

    run systemctl unmask hostapd || true
    run systemctl enable --now hostapd
    run systemctl enable --now dnsmasq
    run systemctl restart dnsmasq
    log_ok "hostapd + dnsmasq enabled on wlan0 ($HOTSPOT_ADDR/$HOTSPOT_CIDR)"
}

verify_hotspot() {
    $DRY_RUN && return 0
    if has_command nmcli; then
        if nmcli -t -f NAME connection show --active 2>/dev/null | grep -qx "$HOTSPOT_SSID"; then
            log_ok "AP '$HOTSPOT_SSID' is up on wlan0"
        else
            log_warn "AP '$HOTSPOT_SSID' is not up yet; it will start on the next boot"
        fi
    else
        systemctl is-active --quiet hostapd && log_ok "hostapd active" \
            || log_warn "hostapd is not active"
    fi
    # the library must answer over the AP address, not just loopback
    if has_command curl; then
        if curl -fsS -m 4 -o /dev/null "http://$HOTSPOT_ADDR:$SERVICE_PORT/" 2>/dev/null; then
            log_ok "library answers on http://$HOTSPOT_ADDR:$SERVICE_PORT/ over the AP"
        else
            log_warn "library did not answer on http://$HOTSPOT_ADDR:$SERVICE_PORT/ (no ZIM yet?)"
        fi
    fi
}

# Desktop switch between client, access point and radio off, through NetworkManager.
#
# The helper is root-owned and the desktop entry runs it as the user. NetworkManager connection
# changes need root on a stock Pi OS / Ubuntu image, and an appliance should not show a password
# prompt, so a one-line sudoers rule allows exactly the three mode words. The AP profile itself
# is created lazily by the helper from the values written here, which means the switch also works
# on an image installed without --hotspot.
install_wifi_switch() {
    log_stage "Wi-Fi mode switch"
    if ! $WITH_WIFI_SWITCH; then
        WIFI_SWITCH_STATE="skipped"
        log_info "skipped (--no-wifi-switch)"
        return 0
    fi
    if $WITH_NO_RADIO; then
        WIFI_SWITCH_STATE="skipped (radio off)"
        log_info "skipped (--no-radio: the radio is disabled in firmware)"
        return 0
    fi
    if ! $DRY_RUN && ! has_command nmcli; then
        WIFI_SWITCH_STATE="skipped (no NetworkManager)"
        log_warn "NetworkManager (nmcli) not found: no Wi-Fi switcher"
        log_info "  use --hotspot for the hostapd path, or --no-radio for a silent device"
        return 0
    fi

    # AP mode uses ipv4.method shared; the drop-in keeps it from NATing clients onto the uplink.
    write_nm_no_nat

    local dir src
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    src="$dir/wifi-mode.sh"
    [ -f "$src" ] || die "cannot find wifi-mode.sh next to this script"
    run install -m 0755 -o root -g root "$src" "$WIFI_SWITCH_BIN"
    WIFI_SWITCH_STATE="CLI installed"
    log_ok "$WIFI_SWITCH_BIN"

    # AP settings for the helper. An existing wifi.conf is the user's source of truth and is
    # never overwritten. A fresh install writes AP_NAME/AP_WELCOME/AP_PASSWORD; an install from
    # the old helper migrates the legacy wifi-mode.conf values. %q keeps passphrases sourceable.
    if $DRY_RUN; then
        printf '%s  [dry-run]%s write %s (if absent) and %s\n' \
            "$C_YELLOW" "$C_OFF" "$WIFI_SWITCH_CONF" "$WIFI_SWITCH_SUDOERS"
    else
        install -d -m 0755 -o root -g root /etc/ktemata
        if [ -r "$WIFI_SWITCH_CONF" ]; then
            log_ok "$WIFI_SWITCH_CONF exists, leaving your AP settings alone"
        else
            (
                umask 077
                {
                    printf '# Ktemata AP settings (post-install.sh)\n'
                    printf '# AP_NAME is the NetworkManager profile; AP_WELCOME is the SSID clients see.\n'
                    if [ -r "$WIFI_SWITCH_LEGACY_CONF" ]; then
                        # It is about to be sourced as root; tighten it first.
                        chown root:root "$WIFI_SWITCH_LEGACY_CONF"
                        chmod 0600 "$WIFI_SWITCH_LEGACY_CONF"
                        # shellcheck disable=SC1090
                        . "$WIFI_SWITCH_LEGACY_CONF"
                        printf 'AP_NAME=%q\n' "${AP_PROFILE:-Ktemata}"
                        printf 'AP_WELCOME=%q\n' "${AP_PROFILE:-Ktemata}"
                        printf 'AP_PASSWORD=%q\n' "${AP_PASS:-}"
                        printf 'AP_ADDR=%q\n' "${AP_ADDR:-10.10.10.1}"
                        printf 'AP_CIDR=%q\n' "${AP_CIDR:-24}"
                        printf 'AP_BAND=%q\n' "${AP_BAND:-auto}"
                    else
                        printf 'AP_NAME=%q\n' "$HOTSPOT_SSID"
                        printf 'AP_WELCOME=%q\n' "$HOTSPOT_SSID"
                        printf 'AP_PASSWORD=%q\n' "$HOTSPOT_PASS"
                        printf 'AP_ADDR=%q\n' "$HOTSPOT_ADDR"
                        printf 'AP_CIDR=%q\n' "$HOTSPOT_CIDR"
                        printf 'AP_BAND=%q\n' "$HOTSPOT_BAND"
                        [ -n "$HOTSPOT_PASS" ] || \
                            log_warn "no --hotspot-pass: AP mode will be an open network"
                    fi
                } >"$WIFI_SWITCH_CONF"
            )
            log_ok "$WIFI_SWITCH_CONF (new)"
        fi
        chown root:root "$WIFI_SWITCH_CONF"
        chmod 0600 "$WIFI_SWITCH_CONF"
        log_ok "$WIFI_SWITCH_CONF (mode 0600)"
    fi

    # The desktop entry and the passwordless rule belong to the account whose session owns
    # the screen, same rule as the kiosk and the library icon.
    local user=${KIOSK_USER:-$AUTOLOGIN_USER}
    if ! id -u "$user" >/dev/null 2>&1; then
        log_warn "no desktop user '$user': installed the CLI, not the desktop entry"
        return 0
    fi
    local home group
    home=$(getent passwd "$user" | cut -d: -f6)
    group=$(id -gn "$user")
    if [ ! -d "$home" ]; then
        log_warn "home directory not found for $user: no desktop entry"
        return 0
    fi
    if $DRY_RUN; then
        printf '%s  [dry-run]%s allow %s to run %s client|ap|off without a password\n' \
            "$C_YELLOW" "$C_OFF" "$user" "$WIFI_SWITCH_BIN"
        if $WITH_GUI; then
            printf '%s  [dry-run]%s write %s/Desktop/ktemata-wifi.desktop\n' \
                "$C_YELLOW" "$C_OFF" "$home"
            enable_desktop_quick_exec "$user" "$home"
        fi
        return 0
    fi

    local tmp
    tmp=$(mktemp)
    {
        printf '# Ktemata Wi-Fi mode switch (post-install.sh)\n'
        printf '# The helper is root-owned and accepts only client, ap and off.\n'
        printf '%s ALL=(root) NOPASSWD: %s client, %s ap, %s off\n' \
            "$user" "$WIFI_SWITCH_BIN" "$WIFI_SWITCH_BIN" "$WIFI_SWITCH_BIN"
    } >"$tmp"
    if has_command visudo && visudo -cf "$tmp" >/dev/null 2>&1; then
        install -m 0440 -o root -g root "$tmp" "$WIFI_SWITCH_SUDOERS"
        WIFI_SWITCH_STATE="installed"
        log_ok "$WIFI_SWITCH_SUDOERS"
    else
        log_warn "could not install the sudoers rule; use sudo $WIFI_SWITCH_BIN"
    fi
    rm -f "$tmp"

    $WITH_GUI || { log_info "no desktop entry (--no-gui)"; return 0; }

    local entry="$home/Desktop/ktemata-wifi.desktop"
    install -d -m 0755 -o "$user" -g "$group" "$home/Desktop"
    cat >"$entry" <<EOF
[Desktop Entry]
Type=Application
Name=Ktemata Wi-Fi
Comment=Switch between client, access point and radio off
Exec=$WIFI_SWITCH_BIN menu
Icon=network-wireless
Terminal=false
Categories=Network;Settings;
EOF
    chown "$user":"$group" "$entry"
    chmod 0755 "$entry"
    enable_desktop_quick_exec "$user" "$home"
    WIFI_SWITCH_STATE="installed (desktop + sudoers)"
    log_ok "$entry"
}

# The offline AI is a separate installer: it downloads models and has its own config. Keep it
# opt-in so a plain post-install does not turn a Pi into a slow model host.
install_offline_ai() {
    $WITH_AI || return 0
    log_stage "Offline AI"
    local dir script shell_user
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    script="$dir/post-install-ai.sh"
    shell_user=${KIOSK_USER:-$AUTOLOGIN_USER}
    [ -x "$script" ] || die "cannot find post-install-ai.sh next to this script"
    if $DRY_RUN; then
        printf '%s  [dry-run]%s %s --yes --dry-run --zim-home %s --shell-user %s\n' \
            "$C_YELLOW" "$C_OFF" "$script" "$LIBRARY_DIR" "$shell_user"
        return 0
    fi
    "$script" --yes --zim-home "$LIBRARY_DIR" --shell-user "$shell_user"
}

install_kiosk() {
    $WITH_KIOSK || { log_stage "Kiosk"; log_info "skipped (pass --kiosk to enable)"; return 0; }
    log_stage "Kiosk"

    # default to the autologin account: the kiosk belongs in the session GDM opens
    [ -n "$KIOSK_USER" ] || KIOSK_USER=$AUTOLOGIN_USER
    [ -n "$KIOSK_USER" ] || die "--kiosk needs a desktop user; run it via sudo, or pass --kiosk-user NAME"
    id -u "$KIOSK_USER" >/dev/null 2>&1 || die "no such user: $KIOSK_USER"
    local home
    home=$(getent passwd "$KIOSK_USER" | cut -d: -f6)
    [ -d "$home" ] || die "home directory not found for $KIOSK_USER"

    # 1. the launcher itself
    local src dir
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    src="$dir/kiwix-kiosk.sh"
    [ -f "$src" ] || die "cannot find kiwix-kiosk.sh next to this script"
    run install -m 0755 -o root -g root "$src" /usr/local/bin/kiwix-kiosk
    log_ok "/usr/local/bin/kiwix-kiosk"

    # 2. autostart inside the desktop session (XDG autostart: labwc, LXDE, GNOME all honour it)
    local autostart="$home/.config/autostart"
    if $DRY_RUN; then
        printf '%s  [dry-run]%s write %s/kiwix-kiosk.desktop\n' "$C_YELLOW" "$C_OFF" "$autostart"
    else
        install -d -m 0755 -o "$KIOSK_USER" -g "$(id -gn "$KIOSK_USER")" "$autostart"
        cat >"$autostart/kiwix-kiosk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ktemata kiosk
Comment=Boot straight into the offline library
Exec=/bin/sh -lc /usr/local/bin/kiwix-kiosk
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
        chown "$KIOSK_USER":"$(id -gn "$KIOSK_USER")" "$autostart/kiwix-kiosk.desktop"
        chmod 0644 "$autostart/kiwix-kiosk.desktop"
        log_ok "$autostart/kiwix-kiosk.desktop"
    fi

    # 3. rotation must reach the compositor, so hand it to the kiosk as well
    if [ -n "$ROTATE" ] && deg=$(rotation_degrees "$ROTATE"); then
        if $DRY_RUN; then
            printf '%s  [dry-run]%s set KIOSK_DISPLAY_TRANSFORM=%s in the autostart entry\n' "$C_YELLOW" "$C_OFF" "$deg"
        else
            sed -i "s#^Exec=.*#Exec=/bin/sh -lc \"/usr/local/bin/kiwix-kiosk --transform $deg\"#" \
                "$autostart/kiwix-kiosk.desktop"
            log_ok "kiosk rotates the output to $deg"
        fi
    fi

    if $DRY_RUN; then
        printf '%s  [dry-run]%s /usr/local/bin/kiwix-kiosk --selftest\n' "$C_YELLOW" "$C_OFF"
    else
        # selftest wants a session, so run it as the user in a clean environment
        if sudo -u "$KIOSK_USER" -H env -u DISPLAY -u WAYLAND_DISPLAY \
                /usr/local/bin/kiwix-kiosk --selftest >/dev/null 2>&1; then
            log_ok "kiosk launcher selftest passed"
        else
            log_warn "kiosk launcher selftest reported not-ready (no session yet is normal)"
        fi
    fi
}

install_admin() {
    if ! $HOST_LIBRARY || ! $WITH_SERVICE; then
        log_stage "Library admin"
        log_info "skipped (needs the host library and its $SERVICE_NAME service)"
        ADMIN_STATE="skipped"
        return 0
    fi
    if ! $WITH_ADMIN; then
        log_stage "Library admin"
        log_info "skipped (--no-admin)"
        ADMIN_STATE="skipped"
        return 0
    fi
    log_stage "Library admin"

    local dir src assets unit
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    src="$dir/ktemata-admin.py"
    assets="$dir/ktemata-admin"
    unit="/etc/systemd/system/$ADMIN_SERVICE.service"
    [ -r "$src" ] || die "cannot find ktemata-admin.py next to this script"
    [ -r "$assets/index.html" ] || die "cannot find the ktemata-admin assets next to this script"

    run install -d -m 0755 "$ADMIN_ASSETS"
    local f
    for f in index.html style.css app.js favicon.svg; do
        run install -m 0644 "$assets/$f" "$ADMIN_ASSETS/$f"
    done
    run install -m 0755 -o root -g root "$src" /usr/local/bin/ktemata-admin
    # library.xml lives here. kiwix.service creates it via StateDirectory, but the admin unit
    # may be started first and needs a writable directory straight away.
    run install -d -m 0755 -o "$SERVICE_USER" -g "$SERVICE_USER" "$STATE_DIR"
    log_ok "/usr/local/bin/ktemata-admin + $ADMIN_ASSETS"

    # Credentials: generated once and then left alone, so re-running the installer never resets
    # a password someone wrote down. --admin-pass or ADMIN_PASS overrides it deliberately.
    if [ -z "$ADMIN_PASS" ] && [ -s "$ADMIN_CONFIG" ]; then
        log_ok "credentials kept in $ADMIN_CONFIG"
    else
        if [ -z "$ADMIN_PASS" ]; then
            ADMIN_PASS=$(od -An -N18 -tx1 /dev/urandom | tr -d ' \n')
        fi
        run install -d -m 0755 /etc/ktemata
        if $DRY_RUN; then
            printf '%s  [dry-run]%s write %s (user %s, generated password)\n' \
                "$C_YELLOW" "$C_OFF" "$ADMIN_CONFIG" "$ADMIN_USER"
        else
            local tmp
            tmp=$(mktemp)
            chmod 0600 "$tmp"
            {
                printf '# Ktemata library admin credentials. Root-only: the service writes the library.\n'
                printf '# Change the password here and restart %s.service to apply.\n' "$ADMIN_SERVICE"
                printf 'KTEMATA_ADMIN_USER=%s\n' "$ADMIN_USER"
                printf 'KTEMATA_ADMIN_PASSWORD=%s\n' "$ADMIN_PASS"
            } >"$tmp"
            install -m 0600 -o root -g root "$tmp" "$ADMIN_CONFIG"
            rm -f "$tmp"
            log_ok "credentials written to $ADMIN_CONFIG (user $ADMIN_USER)"
        fi
    fi

    log_info "writing $unit"
    if $DRY_RUN; then
        printf '%s  [dry-run]%s write %s (admin on :%s)\n' \
            "$C_YELLOW" "$C_OFF" "$unit" "$ADMIN_PORT"
    else
        cat >"$unit" <<EOF
[Unit]
Description=Ktemata library admin (ZIM uploads and Kiwix control)
Documentation=file:$ADMIN_ASSETS
After=network.target
ConditionPathExists=$ZIM_DIR

[Service]
Type=simple
# The page deletes and writes ZIM files and rebuilds library.xml. Basic auth and a root-only
# password file are the gate; ProtectSystem keeps the rest of the disk read-only.
User=root
ExecStart=/usr/local/bin/ktemata-admin --zim-dir $ZIM_DIR --state-dir $STATE_DIR \
    --bind $ADMIN_BIND --port $ADMIN_PORT --library-port $SERVICE_PORT --service $SERVICE_NAME \
    --auth-file $ADMIN_CONFIG --assets $ADMIN_ASSETS
Restart=on-failure
RestartSec=3
# A chunk is 8 MiB; do not kill the unit mid-write on a restart.
TimeoutStopSec=20
ProtectSystem=strict
ReadWritePaths=$ZIM_DIR $STATE_DIR
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true

[Install]
WantedBy=multi-user.target
EOF
        chmod 0644 "$unit"
        log_ok "unit written"
    fi

    if have_systemd; then
        run systemctl daemon-reload
        run systemctl enable --now "$ADMIN_SERVICE.service"
        ADMIN_STATE="enabled"
        if ! $DRY_RUN; then
            local check_user check_pass i
            check_user=$(sed -n 's/^KTEMATA_ADMIN_USER=//p' "$ADMIN_CONFIG" 2>/dev/null | head -1)
            check_pass=$(sed -n 's/^KTEMATA_ADMIN_PASSWORD=//p' "$ADMIN_CONFIG" 2>/dev/null | head -1)
            for i in $(seq 1 20); do
                if curl -fsS -o /dev/null --max-time 2 -u "$check_user:$check_pass" \
                        "http://127.0.0.1:$ADMIN_PORT/healthz" 2>/dev/null; then
                    ADMIN_STATE="active"
                    break
                fi
                sleep 0.5
            done
            if [ "$ADMIN_STATE" = active ]; then
                log_ok "answering on http://$ADMIN_BIND:$ADMIN_PORT"
            else
                log_warn "$ADMIN_SERVICE.service is not answering yet: journalctl -u $ADMIN_SERVICE"
                ADMIN_STATE="installed (not answering)"
            fi
        fi
    else
        log_warn "systemd not running here: start it later with"
        log_warn "  sudo systemctl enable --now $ADMIN_SERVICE.service"
        ADMIN_STATE="written (systemd not running)"
    fi
}

# PCManFM/libfm shows "Execute / Execute in Terminal / Open" for an executable .desktop file
# unless quick_exec is set. The Ktemata icons are meant to launch on a double-click.
DESKTOP_QUICK_EXEC_USER=""
enable_desktop_quick_exec() {
    local user=$1 home=$2 group dir conf tmp
    [ "$DESKTOP_QUICK_EXEC_USER" = "$user" ] && return 0
    group=$(id -gn "$user")
    dir="$home/.config/libfm"
    conf="$dir/libfm.conf"
    if $DRY_RUN; then
        printf '%s  [dry-run]%s set quick_exec=1 in %s\n' \
            "$C_YELLOW" "$C_OFF" "$conf"
        DESKTOP_QUICK_EXEC_USER=$user
        return 0
    fi

    [ -d "$home/.config" ] || \
        install -d -m 0755 -o "$user" -g "$group" "$home/.config"
    install -d -m 0755 -o "$user" -g "$group" "$dir"

    if [ ! -e "$conf" ]; then
        printf '[config]\nquick_exec=1\n' >"$conf"
    else
        tmp=$(mktemp "$dir/.libfm.conf.XXXXXX")
        awk '
            BEGIN { in_config=0; seen_config=0; done=0 }
            /^\[/ {
                if (in_config && !done) { print "quick_exec=1"; done=1 }
                in_config = ($0 ~ /^\[config\][[:space:]]*$/)
                if (in_config) seen_config=1
                print
                next
            }
            in_config && /^[[:space:]]*quick_exec[[:space:]]*=/ {
                if (!done) { print "quick_exec=1"; done=1 }
                next
            }
            { print }
            END {
                if (in_config && !done) print "quick_exec=1"
                if (!seen_config) { print ""; print "[config]"; print "quick_exec=1" }
            }
        ' "$conf" >"$tmp"
        mv "$tmp" "$conf"
    fi
    chown "$user":"$group" "$dir" "$conf"
    chmod 0755 "$dir"
    chmod 0644 "$conf"
    DESKTOP_QUICK_EXEC_USER=$user
    log_ok "$conf (quick_exec=1)"
}

install_library_icon() {
    if ! $WITH_GUI || ! $HOST_LIBRARY || ! $WITH_SERVICE; then
        log_stage "Library desktop icon"
        log_info "skipped (requires the host service and a desktop)"
        return 0
    fi
    log_stage "Library desktop icon"
    if ! $DRY_RUN && ! has_command firefox; then
        log_warn "Firefox is not installed; no library icon created"
        return 0
    fi

    local user=${KIOSK_USER:-$AUTOLOGIN_USER}
    id -u "$user" >/dev/null 2>&1 || die "no desktop user: $user"
    local home
    home=$(getent passwd "$user" | cut -d: -f6)
    [ -d "$home" ] || die "home directory not found for $user"

    local desktop="$home/Desktop"
    local entry="$desktop/ktemata-library.desktop"
    if $DRY_RUN; then
        printf '%s  [dry-run]%s write %s (Firefox kiosk on 127.0.0.1:%s)\n' \
            "$C_YELLOW" "$C_OFF" "$entry" "$SERVICE_PORT"
        enable_desktop_quick_exec "$user" "$home"
        return 0
    fi

    install -d -m 0755 -o "$user" -g "$(id -gn "$user")" "$desktop"
    cat >"$entry" <<EOF
[Desktop Entry]
Type=Application
Name=Ktemata Library
Comment=Open the offline library full screen in Firefox
Exec=/usr/bin/firefox --kiosk http://127.0.0.1:$SERVICE_PORT/
Icon=firefox
Terminal=false
Categories=Education;Network;
EOF
    chown "$user":"$(id -gn "$user")" "$entry"
    chmod 0755 "$entry"
    enable_desktop_quick_exec "$user" "$home"
    log_ok "$entry"
}

# The service runs as SERVICE_USER; every archive must be group-readable by it. Called again
# after a download, because a freshly written ZIM is owned by root.
grant_library_access() {
    $WITH_SERVICE || return 0
    run_sh "chgrp -R '$SERVICE_USER' '$ZIM_DIR' && chmod -R g+rX '$ZIM_DIR'"
}

# Build $LIBRARY_XML only when the ZIM paths, sizes or mtimes change. The installed helper is
# shared with ExecStartPre, so post-install and systemd use exactly the same cache and error paths.
rebuild_library() {
    $DRY_RUN && { printf '%s  [dry-run]%s build %s\n' "$C_YELLOW" "$C_OFF" "$LIBRARY_XML"; return 0; }
    install -d -m 0755 -o "$SERVICE_USER" -g "$SERVICE_USER" "$STATE_DIR"
    /usr/local/bin/kiwix-library "$ZIM_DIR" "$LIBRARY_XML"
}

install_service() {
    if ! $HOST_LIBRARY; then
        log_stage "Service"
        log_info "skipped (--library nomad; NOMAD's Kiwix container serves the library)"
        return 0
    fi
    $WITH_SERVICE || { log_stage "Service"; log_info "skipped (--no-service)"; return 0; }
    log_stage "Service"

    local dir helper_src
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    helper_src="$dir/kiwix-library.sh"
    [ -r "$helper_src" ] || die "cannot find kiwix-library.sh next to this script"
    local unit="/etc/systemd/system/$SERVICE_NAME.service"
    log_info "writing $unit"

    if $DRY_RUN; then
        printf '%s  [dry-run]%s write %s (kiwix-serve on :%s)\n' "$C_YELLOW" "$C_OFF" "$unit" "$SERVICE_PORT"
    else
        cat >"$unit" <<EOF
[Unit]
Description=Kiwix offline library server
Documentation=https://wiki.kiwix.org/wiki/Kiwix-serve
After=network.target
# Gate on the directory, not the XML: ExecStartPre rebuilds the XML from the ZIM files, and
# a Condition on the XML would suppress ExecStartPre as well, so the library could never be
# created. An empty directory still leaves nothing to serve, but that is a normal idle unit.
ConditionPathExists=$ZIM_DIR

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
# StateDirectory gives ExecStartPre a writable /var/lib/kiwix while the ZIMs stay read-only.
StateDirectory=$SERVICE_NAME
StateDirectoryMode=0755
# Hundreds of ZIMs can take several minutes to index; do not kill and restart start-pre every 90 s.
TimeoutStartSec=1800
# Regenerate the XML on every start so dropping in a new ZIM and restarting is enough.
ExecStartPre=/usr/local/bin/kiwix-library "$ZIM_DIR" "$LIBRARY_XML"
# No ZIMs -> the XML is absent -> would exit 1 and restart. sh -c lets us exit 0 instead and
# wait for a restart, so an idle card does not produce a restart loop.
# No --address: kiwix-serve then listens on every available address. Do not pass 0.0.0.0 —
# it treats that as a literal interface address and exits with "IP address is not available".
# Local launchers use 127.0.0.1 explicitly, so they do not depend on the IPv6/IPv4 choice.
ExecStart=/bin/sh -c 'if [ -f "$LIBRARY_XML" ]; then exec /usr/bin/kiwix-serve --port=$SERVICE_PORT --library "$LIBRARY_XML"; fi; echo "no ZIM files yet in $ZIM_DIR"; exit 0'
Restart=on-failure
RestartSec=3
# the library is read-only; keep the service boxed in
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=$ZIM_DIR

[Install]
WantedBy=multi-user.target
EOF
        chmod 0644 "$unit"
        log_ok "unit written"
    fi

    if $DRY_RUN; then
        printf '%s  [dry-run]%s install %s -> /usr/local/bin/kiwix-library\n' \
            "$C_YELLOW" "$C_OFF" "$helper_src"
    else
        install -m 0755 "$helper_src" /usr/local/bin/kiwix-library
        log_ok "/usr/local/bin/kiwix-library"
    fi

    rebuild_library

    if have_systemd; then
        run systemctl daemon-reload
        run systemctl enable --now "$SERVICE_NAME.service"
        log_ok "enabled; serving locally on http://127.0.0.1:$SERVICE_PORT"
    else
        log_warn "systemd not running here: start it later with"
        log_warn "  sudo systemctl enable --now $SERVICE_NAME.service"
    fi
}

install_artwork_unit() {
    $WITH_ARTWORK || { log_stage "Artwork unit"; log_info "skipped (--no-artwork)"; return 0; }
    log_stage "Artwork unit"

    local dir dest share unit
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    dest=/usr/local/lib/ktemata/desktop-artwork.sh
    share=/usr/local/share/ktemata
    unit="/etc/systemd/system/$ARTWORK_SERVICE.service"

    if [ ! -r "$dir/desktop-artwork.sh" ]; then
        log_warn "$dir/desktop-artwork.sh not found; skipping the artwork unit"
        return 0
    fi
    if ! id -u "$AUTOLOGIN_USER" >/dev/null 2>&1; then
        log_warn "no user $AUTOLOGIN_USER (AUTOLOGIN_USER); skipping the artwork unit"
        return 0
    fi

    local asset missing=0
    for asset in \
        "$dir/../../docs/ktemata-wallpaper.svg" \
        "$dir/../../docs/ktemata-splash.svg" \
        "$dir/../../docs/ktemata-splash-portrait.svg" \
        "$dir/ktemata-wallpaper.png" \
        "$dir/ktemata-splash.png"; do
        [ -r "$asset" ] || { log_warn "missing artwork asset: $asset"; missing=1; }
    done
    [ "$missing" -eq 0 ] || log_warn "the unit will fall back to whatever is installed in $share/src"

    log_info "artwork for $AUTOLOGIN_USER at graphical.target (next boot)"

    if $DRY_RUN; then
        printf '%s  [dry-run]%s install %s -> %s (+ assets in %s/src)\n' "$C_YELLOW" "$C_OFF" "$dir/desktop-artwork.sh" "$dest" "$share"
        printf '%s  [dry-run]%s write %s\n' "$C_YELLOW" "$C_OFF" "$unit"
        printf '%s  [dry-run]%s systemctl enable %s.service\n' "$C_YELLOW" "$C_OFF" "$ARTWORK_SERVICE"
        return 0
    fi

    install -d -m 0755 /usr/local/lib/ktemata "$share/src"
    install -m 0755 "$dir/desktop-artwork.sh" "$dest"
    for asset in \
        "$dir/../../docs/ktemata-wallpaper.svg" \
        "$dir/../../docs/ktemata-splash.svg" \
        "$dir/../../docs/ktemata-splash-portrait.svg" \
        "$dir/ktemata-wallpaper.png" \
        "$dir/ktemata-splash.png"; do
        [ -r "$asset" ] && install -m 0644 "$asset" "$share/src/"
    done
    log_ok "$dest and assets in $share/src"

    cat >"$unit" <<EOF
[Unit]
Description=Ktemata wallpaper and boot splash
Documentation=file:$dest
After=systemd-user-sessions.service
# One successful run is enough: the wallpaper config persists and the splash is a boot file.
# The script writes this marker; remove it to let the unit run again at the next boot.
ConditionPathExists=!$share/.artwork-applied

[Service]
Type=oneshot
RemainAfterExit=yes
# At graphical.target the display manager is up, but autologin and its session bus can lag.
ExecStart=$dest --user $AUTOLOGIN_USER --wait 120
TimeoutStartSec=900
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=graphical.target
EOF
    chmod 0644 "$unit"
    log_ok "unit written"

    if have_systemd; then
        run systemctl daemon-reload
        run systemctl enable "$ARTWORK_SERVICE.service"
        log_ok "enabled for graphical.target; runs at the next boot"
    else
        log_warn "systemd not running here: enable it later with"
        log_warn "  sudo systemctl enable $ARTWORK_SERVICE.service"
    fi
}

# Enable the optional Pi 5 UPS I2C bus on GPIO12/13. Keep a differently configured i2c2-pi5
# overlay untouched: loading two instances can fail or move the expected /dev/i2c-2 device.
setup_ups_i2c() {
    $UPS_I2C_ALT_PINS || return 0
    log_stage "UPS I2C (alternate pins)"

    local cfg="${CONFIG_TXT:-/boot/firmware/config.txt}"
    if [ ! -f "$cfg" ]; then
        log_info "no $cfg: not a Raspberry Pi boot partition, skipping"
        return 0
    fi
    if grep -qE "^[[:space:]]*$UPS_I2C_OVERLAY[[:space:]]*$" "$cfg"; then
        log_ok "already enabled on GPIO12/13 (Linux bus 2)"
        return 0
    fi
    if grep -qE '^[[:space:]]*dtoverlay=i2c2-pi5([,[:space:]]|$)' "$cfg"; then
        log_warn "i2c2-pi5 is already configured differently; leaving it unchanged"
        return 0
    fi
    if $DRY_RUN; then
        printf '%s  [dry-run]%s add %s to %s\n' "$C_YELLOW" "$C_OFF" "$UPS_I2C_OVERLAY" "$cfg"
        return 0
    fi

    [ -f "$cfg.ktemata.bak" ] || cp -a "$cfg" "$cfg.ktemata.bak"
    if grep -qE "^[[:space:]]*#[[:space:]]*$UPS_I2C_OVERLAY" "$cfg"; then
        sed -i -E "s|^[[:space:]]*#[[:space:]]*$UPS_I2C_OVERLAY.*|$UPS_I2C_OVERLAY|" "$cfg"
    else
        printf '%s\n' "$UPS_I2C_OVERLAY" >>"$cfg"
    fi

    local n
    n=$(grep -cE "^[[:space:]]*$UPS_I2C_OVERLAY[[:space:]]*$" "$cfg")
    if [ "$n" = 1 ]; then
        log_ok "added GPIO12/13 as I2C bus 2 (reboot, then use --i2c-bus 2)"
    else
        log_error "UPS I2C overlay edit looks wrong: $n live line(s)"
        log_warn "restore with: sudo cp $cfg.ktemata.bak $cfg"
    fi
}

# Add the Waveshare DSI overlay to config.txt. The panel is not auto-detected on the Pi 5, so
# without this it stays dark. Idempotent, one live line, backup kept once.
setup_display_overlay() {
    $WITH_DISPLAY_OVERLAY || { log_stage "Display overlay"; log_info "skipped (--no-display-overlay)"; return 0; }
    log_stage "Display overlay"

    local cfg="${CONFIG_TXT:-/boot/firmware/config.txt}"
    if [ ! -f "$cfg" ]; then
        log_info "no $cfg: not a Raspberry Pi boot partition, skipping"
        return 0
    fi

    local line="$DISPLAY_OVERLAY" need_vc4=false need_line=false
    grep -qE '^dtoverlay=vc4-kms-v3d' "$cfg" || need_vc4=true
    grep -qxF "$line" "$cfg" || need_line=true

    if ! $need_vc4 && ! $need_line; then
        log_ok "already enabled"
        return 0
    fi

    if $DRY_RUN; then
        printf '%s  [dry-run]%s add %s and %s to %s\n' "$C_YELLOW" "$C_OFF" "dtoverlay=vc4-kms-v3d" "$line" "$cfg"
        return 0
    fi

    [ -f "$cfg.ktemata.bak" ] || cp -a "$cfg" "$cfg.ktemata.bak"

    # vc4-kms-v3d is stock on Pi OS but may be commented out. Keep any options on an existing
    # line, and put it before the panel overlay if it has to be inserted.
    if $need_vc4; then
        if grep -qE '^[[:space:]]*#[[:space:]]*dtoverlay=vc4-kms-v3d' "$cfg"; then
            sed -i -E 's|^[[:space:]]*#[[:space:]]*dtoverlay=vc4-kms-v3d|dtoverlay=vc4-kms-v3d|' "$cfg"
        elif grep -qE '^[#[:space:]]*dtoverlay=vc4-kms-dsi-waveshare-panel' "$cfg"; then
            awk '/^[#[:space:]]*dtoverlay=vc4-kms-dsi-waveshare-panel/ && !done {
                     print "dtoverlay=vc4-kms-v3d"; done=1
                 }
                 { print }' "$cfg" >"$cfg.tmp" && mv "$cfg.tmp" "$cfg"
        else
            printf 'dtoverlay=vc4-kms-v3d\n' >>"$cfg"
        fi
    fi

    if $need_line; then
        if grep -qE '^[#[:space:]]*dtoverlay=vc4-kms-dsi-waveshare-panel' "$cfg"; then
            sed -i -E "s|^[#[:space:]]*dtoverlay=vc4-kms-dsi-waveshare-panel.*|$line|" "$cfg"
        else
            printf '%s\n' "$line" >>"$cfg"
        fi
    fi

    local n
    n=$(grep -cF "$line" "$cfg")
    if [ "$n" = 1 ]; then
        log_ok "added (reboot to apply)"
    else
        log_error "display overlay edit looks wrong: $n live line(s)"
        log_warn "restore with: sudo cp $cfg.ktemata.bak $cfg"
    fi
}

# Install Waveshare's Brightness app exactly as their install.sh does: copy the Qt binary,
# desktop file and icon into /usr/share/applications. The display's backlight appears as
# /sys/class/backlight/*/brightness once the DSI overlay is loaded.
install_brightness() {
    $WITH_BRIGHTNESS || { log_stage "Brightness app"; log_info "skipped (--no-brightness)"; return 0; }
    if ! $WITH_GUI; then
        log_stage "Brightness app"
        log_info "skipped (--no-gui; it is a desktop app)"
        return 0
    fi
    log_stage "Brightness app"

    local arch
    arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
    case $arch in
        arm64)  local bits=64 ;;
        armhf)  local bits=32 ;;
        *)      log_warn "no ARM Brightness binary for $arch; skipping"; return 0 ;;
    esac

    local bin="/usr/share/applications/brightness${bits}bit"
    if [ -x "$bin" ]; then
        log_ok "already installed"
        return 0
    fi

    if $DRY_RUN; then
        printf '%s  [dry-run]%s download %s and install brightness%sbit\n' "$C_YELLOW" "$C_OFF" "$BRIGHTNESS_URL" "$bits"
        return 0
    fi

    local tmp
    tmp=$(mktemp -d)
    if ! curl -fL --retry 3 -sS -o "$tmp/Brightness.zip" "$BRIGHTNESS_URL"; then
        log_warn "could not download $BRIGHTNESS_URL; skipping the Brightness app"
        rm -rf "$tmp"
        return 0
    fi
    if ! python3 -m zipfile -e "$tmp/Brightness.zip" "$tmp"; then
        log_warn "could not extract Brightness.zip; skipping"
        rm -rf "$tmp"
        return 0
    fi

    install -d -m 0755 /usr/share/applications
    install -m 0755 "$tmp/Brightness/brightness${bits}bit" "$bin"
    install -m 0644 "$tmp/Brightness/brightness${bits}bit.desktop" /usr/share/applications/
    install -m 0644 "$tmp/Brightness/brightness.png" /usr/share/applications/
    rm -rf "$tmp"
    log_ok "installed (Start Menu -> Accessories -> Brightness)"
}

download_sample() {
    if ! $HOST_LIBRARY; then
        log_stage "Sample ZIM"
        log_info "skipped (--library nomad; add content in the NOMAD Command Center)"
        return 0
    fi
    log_stage "Sample ZIM"
    local dest="$ZIM_DIR/$SAMPLE_ZIM"

    if [ -e "$dest" ]; then
        log_ok "$SAMPLE_ZIM already present"
        return 0
    fi

    log_info "$SAMPLE_ZIM (~4 MB) -> $dest"
    # progress bar only on a terminal; otherwise keep the log clean
    local progress=(--progress-bar)
    [ -t 2 ] || progress=(-sS)
    run curl -fL --retry 3 "${progress[@]}" -o "$dest.part" "$SAMPLE_URL"
    run mv "$dest.part" "$dest"
    run_sh "chmod 0644 '$dest'"
    grant_library_access          # the file is root-owned; the service user must read it
    log_ok "downloaded"
}

verify() {
    log_stage "Verify"

    if $DRY_RUN; then
        log_info "dry run: nothing to verify"
        return 0
    fi

    if $HOST_LIBRARY; then
        has_command kiwix-serve || die "kiwix-serve missing"
        log_ok "$(kiwix-serve --version 2>&1 | head -1)"

        # a served ZIM is the only proof the whole chain works; do it without touching the service
        local zim
        zim=$(find "$ZIM_DIR" -maxdepth 1 -name '*.zim' -print -quit 2>/dev/null || true)
        if [ -n "$zim" ]; then
            local port=$((SERVICE_PORT + 1000))
            if has_command curl; then
                if ! $WITH_SERVICE || ! have_systemd; then
                    log_info "starting a throwaway kiwix-serve on :$port"
                    kiwix-serve --port="$port" "$zim" >/dev/null 2>&1 &
                    local pid=$!
                    local ok=false
                    for _ in 1 2 3 4 5 6 7 8 9 10; do
                        if curl -fsS -o /dev/null "http://127.0.0.1:$port/" 2>/dev/null; then ok=true; break; fi
                        sleep 0.4
                    done
                    kill "$pid" 2>/dev/null || true
                    wait "$pid" 2>/dev/null || true
                    $ok && log_ok "kiwix-serve answered on :$port" \
                        || log_warn "kiwix-serve did not answer on :$port"
                fi
            fi
        else
            log_warn "no ZIM in $ZIM_DIR yet; drop some in and the service will start"
        fi

        if $WITH_SERVICE && have_systemd; then
            local state
            state=$(systemctl is-active "$SERVICE_NAME.service" 2>/dev/null || true)
            case $state in
                active) log_ok "$SERVICE_NAME.service active" ;;
                inactive) log_warn "$SERVICE_NAME.service inactive (add a ZIM to $ZIM_DIR, then systemctl restart $SERVICE_NAME)" ;;
                *) log_warn "$SERVICE_NAME.service: ${state:-unknown}" ;;
            esac
        fi
    else
        log_info "library: NOMAD (admin :8080, Kiwix :8090, $LIBRARY_DIR)"
        if has_command docker && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx nomad_admin; then
            log_ok "NOMAD admin container running"
        else
            log_warn "NOMAD is not running yet; install it with its own installer, then add content in the Command Center"
        fi
    fi

}

summary() {
    log_stage "Done"
    if $HOST_LIBRARY; then
        printf '  library   %s\n' "$ZIM_DIR"
        if $WITH_SERVICE; then
            printf '  service   %s.service (port %s)\n' "$SERVICE_NAME" "$SERVICE_PORT"
            printf '  check     systemctl status %s\n' "$SERVICE_NAME"
            if $WITH_ADMIN; then
                local admin_user=$ADMIN_USER
                if [ -r "$ADMIN_CONFIG" ]; then
                    admin_user=$(sed -n 's/^KTEMATA_ADMIN_USER=//p' "$ADMIN_CONFIG" | head -1)
                    [ -n "$admin_user" ] || admin_user=$ADMIN_USER
                fi
                local admin_host=$ADMIN_BIND
                [ "$admin_host" = 0.0.0.0 ] && admin_host="<device>"
                printf '  admin     http://%s:%s (user %s, password in %s)\n' \
                    "$admin_host" "$ADMIN_PORT" "$admin_user" "$ADMIN_CONFIG"
                printf '            %s\n' "$ADMIN_STATE"
            fi
        fi
    else
        printf '  library   NOMAD (%s)\n' "$LIBRARY_DIR"
        printf '  service   NOMAD containers (admin :8080, Kiwix :8090)\n'
    fi
    if $HOST_LIBRARY; then
        printf '  next      drop *.zim files into %s, then: sudo systemctl restart %s\n' "$ZIM_DIR" "$SERVICE_NAME"
    else
        printf '  next      add content in the NOMAD Command Center (%s)\n' "$LIBRARY_DIR"
    fi
    if [ -n "$ROTATE" ]; then
        printf '  display   rotated (%s); reboot to apply console rotation\n' "$ROTATE"
    fi
    if $WITH_AUTOLOGIN; then
        printf '  autologin %s (GDM)\n' "$AUTOLOGIN_USER"
    fi
    if $WITH_ARTWORK; then
        printf '  artwork   %s.service (graphical.target; next boot)\n' "$ARTWORK_SERVICE"
        printf '  now       sudo ./work/scripts/desktop-artwork.sh  (from the desktop)\n'
    fi
    if $WITH_KIOSK; then
        printf '  kiosk     %s autostarts kiwix-kiosk on login\n' "$KIOSK_USER"
    fi
    if $WITH_AI; then
        printf '  ai        ktemata-ai ask "..." (see docs/OFFLINE_AI.md)\n'
    fi
    if $WITH_NO_RADIO; then
        printf '  radios    %s\n' "$RADIO_STATE"
    elif $WITH_WIFI_SWITCH; then
        printf '  wifi      %s (%s)\n' "$WIFI_SWITCH_BIN" "$WIFI_SWITCH_STATE"
    fi
    if $WITH_HWTEST; then
        printf '  hardware  %d checks, %d failed, %d warning(s)\n' "$HW_CHECKS" "$HW_FAILS" "$HW_WARNS"
    fi
    if $HOST_LIBRARY; then
        printf '  desktop   kiwix (or "kiwix-desktop" if your release names it that way)\n'
        printf '  list      %s\n' "${SAMPLE_URL%/*}/"
    fi
}

# An existing host installation needs no repeated install confirmation. Accept a disabled unit too:
# its disabled state is a user choice, not a reason to treat the installation as new.
host_install_present() {
    $HOST_LIBRARY || return 1
    has_command kiwix-serve || return 1
    [ -d "$LIBRARY_DIR" ] || return 1
    $WITH_SERVICE || return 0
    if have_systemd; then
        systemctl cat "$SERVICE_NAME.service" >/dev/null 2>&1
    else
        [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]
    fi
}

# ---------------- arguments ----------------
main() {
    while [ $# -gt 0 ]; do
        case $1 in
            -y|--yes)        ASSUME_YES=true ;;
            -n|--dry-run)    DRY_RUN=true ;;
            --sample)        WITH_SAMPLE=true ;;
            --no-service)    WITH_SERVICE=false ;;
            --library)       LIBRARY=${2:?--library takes host or nomad}; shift ;;
            --no-artwork)    WITH_ARTWORK=false ;;
            --no-display-overlay) WITH_DISPLAY_OVERLAY=false ;;
            --ups-i2c-alt-pins) UPS_I2C_ALT_PINS=true ;;
            --no-brightness) WITH_BRIGHTNESS=false ;;
            --no-gui)        WITH_GUI=false ;;
            --no-update)     WITH_UPDATE=false ;;
            --kiosk)         WITH_KIOSK=true ;;
            --ai)            WITH_AI=true ;;
            --no-hwtest)     WITH_HWTEST=false ;;
            --hwtest-only)   HWTEST_ONLY=true; DRY_RUN=true; WITH_HWTEST=true ;;
            --strict)        STRICT=true ;;
            --power)         POWER_SOURCE=${2:?--power takes usbc or ups3s}; shift ;;
            --no-autologin)  WITH_AUTOLOGIN=false ;;
            --no-camera-autodetect) WITH_NOCAMERA=true ;;
            --no-rtc-charge) WITH_RTC_CHARGE=false ;;
            --hotspot)       WITH_HOTSPOT=true ;;
            --no-hotspot)    WITH_HOTSPOT=false ;;
            --no-radio)      WITH_NO_RADIO=true ;;
            --hotspot-ssid)  HOTSPOT_SSID=${2:?--hotspot-ssid needs a name}; shift ;;
            --hotspot-pass)  HOTSPOT_PASS=${2:?--hotspot-pass needs a password}; shift ;;
            --hotspot-open)  HOTSPOT_PASS="" ;;
            --hotspot-band)  HOTSPOT_BAND=${2:?--hotspot-band takes auto, 2.4 or 5}; shift ;;
            --hotspot-addr)  HOTSPOT_ADDR=${2:?--hotspot-addr needs an address}; shift ;;
            --no-wifi-switch) WITH_WIFI_SWITCH=false ;;
            --no-admin)      WITH_ADMIN=false ;;
            --admin-port)    ADMIN_PORT=${2:?--admin-port needs a number}; shift ;;
            --admin-bind)    ADMIN_BIND=${2:?--admin-bind needs an address}; shift ;;
            --admin-user)    ADMIN_USER=${2:?--admin-user needs a name}; shift ;;
            --admin-pass)    ADMIN_PASS=${2:?--admin-pass needs a password}; shift ;;
            --autologin-user) AUTOLOGIN_USER=${2:?--autologin-user needs a name}; shift ;;
            --kiosk-user)    KIOSK_USER=${2:?--kiosk-user needs a name}; shift ;;
            --rotate)        ROTATE=${2:?--rotate needs normal|left|right|inverted}; shift ;;
            --zim-dir)       ZIM_DIR=${2:?--zim-dir needs a path}; shift ;;
            --port)          SERVICE_PORT=${2:?--port needs a number}; shift ;;
            -h|--help)       usage; exit 0 ;;
            -V|--version)    printf '%s %s\n' "$SCRIPT" "$SCRIPT_VERSION"; exit 0 ;;
            *)               log_error "unknown option: $1"; usage; exit 2 ;;
        esac
        shift
    done

    case $ZIM_DIR in /*) ;; *) die "--zim-dir must be an absolute path" ;; esac
    case $LIBRARY in host|nomad) ;; *) die "--library takes host or nomad" ;; esac
    if [ "$LIBRARY" = nomad ]; then
        HOST_LIBRARY=false
        case $NOMAD_STORAGE_PATH in /*) ;; *) die "NOMAD_STORAGE_PATH must be an absolute path" ;; esac
        LIBRARY_DIR="$NOMAD_STORAGE_PATH/zim"
    else
        HOST_LIBRARY=true
        LIBRARY_DIR=$ZIM_DIR
    fi
    if ! $HOST_LIBRARY && [ "$ZIM_DIR" != /srv/kiwix/zim ]; then
        log_warn "--zim-dir is ignored with --library nomad; NOMAD uses $LIBRARY_DIR"
    fi
    case $SERVICE_PORT in ''|*[!0-9]*) die "--port must be a number" ;; esac
    case $ADMIN_PORT in ''|*[!0-9]*) die "--admin-port must be a number" ;; esac
    [ "$ADMIN_PORT" != "$SERVICE_PORT" ] || die "--admin-port must differ from --port ($SERVICE_PORT)"
    case $ADMIN_BIND in ''|*[!0-9A-Za-z.:_-]*) die "--admin-bind must be an IP address or hostname" ;; esac
    case $ADMIN_USER in ''|*[!A-Za-z0-9._-]*) die "--admin-user takes letters, digits, dot, dash or underscore" ;; esac
    if [ -n "$ADMIN_PASS" ]; then
        [ ${#ADMIN_PASS} -ge 8 ] || die "--admin-pass needs at least 8 characters"
        case $ADMIN_PASS in *$'\n'*|*$'\r'*) die "--admin-pass must be a single line" ;; esac
    fi
    # fail fast on a bad --rotate instead of halfway through the install
    [ -z "$ROTATE" ] || rotation_degrees "$ROTATE" >/dev/null
    case ${POWER_SOURCE:-usbc} in usbc|ups3s) ;; *) die "--power takes usbc or ups3s" ;; esac
    case $HOTSPOT_BAND in auto|2.4|5) ;; *) die "--hotspot-band takes auto, 2.4 or 5" ;; esac
    # a disabled radio cannot host an access point: refuse rather than install both and have
    # the AP fail at boot with "no wlan0"
    if $WITH_NO_RADIO && $WITH_HOTSPOT; then
        die "--no-radio and --hotspot are mutually exclusive: a disabled radio cannot serve an AP"
    fi
    # WPA2-PSK needs 8..63 printable characters; anything else silently fails at connect time
    if [ -n "$HOTSPOT_PASS" ] && [ ${#HOTSPOT_PASS} -lt 8 ]; then
        die "--hotspot-pass needs at least 8 characters (WPA2 minimum), or use --hotspot-open"
    fi
    case $HOTSPOT_ADDR in
        *[!0-9.]*|'') die "--hotspot-addr must be an IPv4 address" ;;
    esac

    $DRY_RUN || require_root "$@"

    if ! $DRY_RUN && ! $ASSUME_YES && ! $HWTEST_ONLY && ! host_install_present; then
        confirm "Install Kiwix into $ZIM_DIR and enable $SERVICE_NAME.service on port $SERVICE_PORT?" \
            || { log_info "aborted"; exit 0; }
    fi

    check_platform
    run_hw_tests            # before anything is installed: reports the box as it arrived
    if $HWTEST_ONLY; then
        # a diagnostic run: report and leave without touching the system
        log_stage "Summary"
        printf '  %d hardware checks, %d failed\n' "$HW_CHECKS" "$HW_FAILS"
        [ "$HW_FAILS" -gt 0 ] && exit 1
        exit 0
    fi
    update_system
    install_packages
    setup_library
    install_service
    install_admin
    install_library_icon
    install_artwork_unit
    setup_display_overlay
    setup_ups_i2c
    install_brightness
    setup_rotation
    install_autologin
    set_camera_autodetect_off
    setup_rtc_charge
    set_radio_off
    setup_hotspot
    install_wifi_switch
    install_kiosk
    install_offline_ai
    $WITH_SAMPLE && download_sample
    verify
    summary

    if $STRICT && [ "$HW_FAILS" -gt 0 ]; then
        log_error "$HW_FAILS hardware check(s) failed (--strict)"
        exit 1
    fi
}

main "$@"

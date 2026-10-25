#!/usr/bin/env bash
# Ktemata post-install for Ubuntu / Debian derivatives.
#
# Installs Kiwix (the offline library reader the device is built around), sets up the ZIM
# library directory, and enables kiwix-serve as a systemd service so the library is reachable
# from a browser on the device or over USB tethering.
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
WITH_UPDATE=true
WITH_KIOSK=false
WITH_HWTEST=true
HWTEST_ONLY=false
STRICT=false
HW_FAILS=0          # faults (e.g. undervoltage): --strict fails on these
HW_WARNS=0          # expected-or-degraded conditions (heat without a cooler): --strict ignores
HW_CHECKS=0
HW_WARNS_NOTE=false
KIOSK_USER=${KIOSK_USER:-${SUDO_USER:-}}   # whose session autostarts the kiosk
# The account the kiosk runs as, and the one GDM logs in automatically. "ktemata" keeps the
# desktop session separate from the admin user you ssh in as.
AUTOLOGIN_USER=${AUTOLOGIN_USER:-ktemata}
WITH_AUTOLOGIN=true
WITH_WALLPAPER=true
WITH_SPLASH=true
SPLASH_ORIENTATION=${SPLASH_ORIENTATION:-landscape}
WALLPAPER_SRC=${WALLPAPER_SRC:-}       # optional override; default installs the repo artwork

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
      --sample           Download one small ZIM so kiwix-serve has something to serve.
      --zim-dir DIR      Library directory (default: $ZIM_DIR).
      --port PORT        kiwix-serve port (default: $SERVICE_PORT).
      --no-service       Install the packages only; do not create/enable the service.
      --no-gui           Skip the desktop Kiwix app (headless / server installs).
      --no-update        Skip the system upgrade (apt full-upgrade).
      --rotate WHAT      Rotate the display: normal | left | right | inverted,
                         or 0|90|180|270 (degrees clockwise, as the kernel takes them).
                         'left' = 90 deg counter-clockwise.
      --kiosk            Install the kiosk launcher and autostart it in the desktop session.
      --kiosk-user NAME  Whose session autostarts it (default: the user running sudo).
      --no-hwtest        Skip the hardware checks.
      --hwtest-only      Run the hardware checks and exit (implies --dry-run).
      --strict           Exit non-zero if a hardware check fails.
      --power usbc|hat   How the Pi is powered, for the diagnostic hints (default: usbc).
      --no-autologin     Do not enable GDM automatic login.
      --no-wallpaper     Do not set the desktop background.
      --wallpaper [FILE] Set the background (default), or use this image instead of the logo.
      --no-splash        Do not change the boot splash screen.
      --splash [FILE]    Enable the boot splash (default), or use this 24-bit TGA
                         (<=1920x1080, <=224 colours).
      --splash-orientation WHAT
                         landscape (default) or portrait. The Touch Display 2 is natively
                         720x1280, so the firmware may draw the splash rotated relative to
                         the case; try portrait if that happens.
      --autologin-user N Account to log in automatically (default: ktemata).
  -h, --help             This message.
  -V, --version          Print the version.

${C_BOLD}ENVIRONMENT${C_OFF}
  ZIM_DIR, SERVICE_PORT, SERVICE_USER, NO_COLOR

${C_BOLD}WHAT IT DOES${C_OFF}
  1. checks it is running as root on a Debian derivative
  2. runs the hardware checks (Pi model, display, I2C, UPS gauge, RTC, storage, network)
  3. updates the system (apt update + full-upgrade) unless --no-update
  4. installs kiwix-tools (+ kiwix desktop app unless --no-gui)
  5. creates the ZIM library directory
  6. writes and enables $SERVICE_NAME.service (kiwix-serve on :$SERVICE_PORT)
  7. optionally sets the display rotation (--rotate) and downloads a sample ZIM (--sample)
  8. optionally installs the kiosk autostart (--kiosk)
  9. enables GDM automatic login (unless --no-autologin)
 10. sets the Ktemata logo as the desktop background (unless --no-wallpaper)
 11. replaces the early boot splash with the logo (unless --no-splash)
 12. verifies the server answers
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

    if $WITH_SERVICE && ! have_systemd; then
        log_warn "systemd not running (container?); the service will be written but not enabled"
    fi
}

# ============================ hardware checks ============================
# Everything the software depends on but cannot test: the Pi itself, the I2C devices on the
# FireBeetle bus, the UPS gauge, the RTCs, storage and the display. Each check prints PASS,
# FAIL or SKIP (not applicable here), so the report is readable on a fresh box.
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

# How the board is powered. The Pi cannot detect the UPS HAT (B): its INA219 sits on the
# FireBeetle's I2C bus, so there is nothing on the Pi side to query. Declare it instead, with
# --power hat / POWER_SOURCE=hat, and default to the bench case (USB-C only).
power_hint() {
    if [ "${POWER_SOURCE:-usbc}" = hat ]; then
        printf '%s\n' "on the UPS HAT: re-seat the pogo pins, then check the 8.4 V input"
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
# 85 C hard limit -> hard throttling. A reading above 85 is therefore "at the ceiling", not
# necessarily a fault, and this build deliberately runs without a cooler (the UPS HAT (B)
# occupies the Pi's component side, so neither the Active Cooler nor a heatsink fits).
# So: FAIL only on undervoltage, which *is* a fault. Heat is reported as a warning with the
# context needed to judge it.
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
    # a single hot reading cannot distinguish "working hard, no cooler, expected" from
    # "idle and still 85 C", which means the heat is not coming from the CPU.
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
                hw_note "expected without a cooler (the UPS HAT (B) takes the component side);"
                hw_note "it throttles here under load rather than failing"
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

# Scan once and cache: hw_ups needs the same data, and i2cdetect over every bus is slow.
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

# Label our own devices so the report names them instead of dumping raw addresses.
i2c_label() {
    case $1 in
        42) echo "UPS INA219" ;;
        3c|3d) echo "OLED" ;;
        68) echo "DS3231" ;;
        76|77) echo "BME688" ;;
        *)  return 1 ;;
    esac
}

hw_i2c_bus() {
    # The FireBeetle, not the Pi, is the I2C master (the Pi has no 40-pin header in this
    # build), so a bare Pi shows nothing useful. Report our devices, not every address.
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
        hw_skip "I2C: nothing on ${nbus} bus(es) — the FireBeetle is the I2C master in this build"
        return
    fi

    # one line for our devices: "0x42 (UPS INA219), 0x68 (DS3231)"
    local known="" unknown="" addr label
    for addr in $I2C_ALL; do
        if label=$(i2c_label "$addr"); then
            known="${known:+$known, }0x$addr ($label)"
        else
            unknown="$unknown $addr"
        fi
    done
    [ -n "$known" ] && hw_pass "I2C: $known"

    # 0x3c/0x3d (OLED) and 0x76/0x77 (BME688) are strap options of one chip: a real bus
    # cannot show both, so the addresses are coming from somewhere that is not a device.
    has_addr() { printf '%s\n' $I2C_ALL | grep -qx "$1"; }
    if has_addr 3c && has_addr 3d; then
        hw_warn "I2C: 0x3c and 0x3d cannot both exist - one OLED, two strap options"
    fi
    if has_addr 76 && has_addr 77; then
        hw_warn "I2C: 0x76 and 0x77 cannot both exist - one BME688, two strap options"
    fi

    # anything else is only counted: display/camera bridges and HATs are not our business
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
    # The HAT (B) reports through the INA219 at 0x42 on the FireBeetle bus, so on the Pi itself
    # this only reports whether 0x42 appeared in the scan above.
    i2c_tool i2cdetect -l >/dev/null 2>&1 || { hw_skip "UPS gauge (i2c-tools not installed)"; return; }
    i2c_scan || { hw_skip "UPS gauge (no I2C bus)"; return; }

    if printf '%s\n' $I2C_ALL | grep -qx 42; then
        hw_pass "UPS HAT (B) INA219 answering at 0x42"
    else
        hw_skip "UPS HAT (B) gauge at 0x42 not visible from the Pi (the FireBeetle reads it)"
    fi
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
    if [ -d "$ZIM_DIR" ]; then
        local zims
        zims=$(find "$ZIM_DIR" -maxdepth 1 -name '*.zim' | wc -l)
        local zsize
        zsize=$(du -sh "$ZIM_DIR" 2>/dev/null | awk '{print $1}')
        if [ "$zims" -eq 0 ]; then
            hw_fail "ZIM library $ZIM_DIR is empty (kiwix-serve will not start)"
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
        hw_pass "port $SERVICE_PORT listening"
    else
        hw_note "hint: port $SERVICE_PORT not listening yet (service starts once a ZIM exists)"
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
    if [ "$HW_WARNS" -gt 0 ] && ! $HW_WARNS_NOTE; then
        log_warn "$HW_WARNS warning(s): this build runs without a cooler, so the SoC sits at"
        log_warn "its thermal limit under load. That is expected, not a fault."
    fi
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

    # Touch Display 2 is 720x1280 native (portrait). rotate= is clockwise degrees, console only.
    local want="video=DSI-1:720x1280@60,rotate=$deg"
    if grep -q 'video=DSI-1:' "$cmdline"; then
        if grep -q "video=DSI-1:720x1280@60,rotate=$deg\b" "$cmdline"; then
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

    local pkgs=(kiwix-tools curl ca-certificates)
    $WITH_GUI && pkgs+=(kiwix)
    # desktop rotation is done with wlr-randr; only needed when a rotation was requested
    if [ -n "$ROTATE" ] && $WITH_GUI; then
        pkgs+=(wlr-randr)
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

    log_info "installing: ${pkgs[*]}"
    # with --no-update the package lists were not refreshed yet
    $WITH_UPDATE || run env DEBIAN_FRONTEND=noninteractive apt-get update -qq
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"

    if ! $DRY_RUN; then
        has_command kiwix-serve || die "kiwix-serve is still missing after install"
        log_ok "$(kiwix-serve --version 2>&1 | head -1)"
    fi
}

setup_library() {
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


install_wallpaper() {
    $WITH_WALLPAPER || { log_stage "Wallpaper"; log_info "skipped (--no-wallpaper)"; return 0; }
    log_stage "Wallpaper"

    local dir home user_img
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    # target user: the autologin account is the one whose desktop is actually shown
    local owner=${KIOSK_USER:-$AUTOLOGIN_USER}
    id -u "$owner" >/dev/null 2>&1 || { log_warn "no user $owner; skipping wallpaper"; return 0; }
    home=$(getent passwd "$owner" | cut -d: -f6)
    [ -d "$home" ] || { log_warn "no home for $owner; skipping wallpaper"; return 0; }

    install -d -m 0755 /usr/local/share/ktemata
    user_img="$home/.local/share/ktemata/ktemata-wallpaper.png"

    if $DRY_RUN; then
        printf '%s  [dry-run]%s render/install wallpaper to /usr/local/share/ktemata\n' "$C_YELLOW" "$C_OFF"
    else
        if [ -n "$WALLPAPER_SRC" ]; then
            [ -r "$WALLPAPER_SRC" ] || die "cannot read --wallpaper $WALLPAPER_SRC"
            install -m 0644 "$WALLPAPER_SRC" /usr/local/share/ktemata/ktemata-wallpaper.png
            log_ok "using $WALLPAPER_SRC"
        elif has_command rsvg-convert && [ -r "$dir/../../docs/ktemata-wallpaper.svg" ]; then
            # render at 1920x1080: larger than any panel we support, scaled to fit anyway
            rsvg-convert -w 1920 -h 1080 "$dir/../../docs/ktemata-wallpaper.svg" \
                -o /usr/local/share/ktemata/ktemata-wallpaper.png
            chmod 0644 /usr/local/share/ktemata/ktemata-wallpaper.png
            log_ok "rendered from docs/ktemata-wallpaper.svg"
        elif [ -r "$dir/ktemata-wallpaper.png" ]; then
            install -m 0644 "$dir/ktemata-wallpaper.png" /usr/local/share/ktemata/ktemata-wallpaper.png
            log_ok "installed the pre-rendered PNG"
        else
            log_warn "no wallpaper source (need rsvg-convert, or --wallpaper FILE); skipping"
            return 0
        fi
    fi

    local img=/usr/local/share/ktemata/ktemata-wallpaper.png
    install -d -m 0755 "$(dirname "$user_img")"
    $DRY_RUN || install -m 0644 "$img" "$user_img"
    chown -R "$owner":"$(id -gn "$owner")" "$(dirname "$user_img")" 2>/dev/null || true

    # 1. GNOME
    if has_command gsettings && gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.desktop.background'; then
        if $DRY_RUN; then
            printf '%s  [dry-run]%s gsettings set org.gnome.desktop.background picture-uri\n' "$C_YELLOW" "$C_OFF"
        else
            sudo -u "$owner" -H dbus-run-session -- gsettings set org.gnome.desktop.background picture-uri \
                "file://$user_img" 2>/dev/null \
            || sudo -u "$owner" -H gsettings set org.gnome.desktop.background picture-uri \
                "file://$user_img" 2>/dev/null || true
            # GNOME 42+ needs the dark variant too, or a dark theme keeps its own image
            sudo -u "$owner" -H dbus-run-session -- gsettings set org.gnome.desktop.background picture-uri-dark \
                "file://$user_img" 2>/dev/null || true
            sudo -u "$owner" -H dbus-run-session -- gsettings set org.gnome.desktop.background picture-options \
                'scaled' 2>/dev/null || true
            log_ok "GNOME background set for $owner"
        fi
    fi

    # 2. Raspberry Pi OS: pcmanfm desktop preferences + the live apply command
    local pcdir="$home/.config/pcmanfm/LXDE-pi"
    local pcfile="$pcdir/desktop-items-0.conf"
    if has_command pcmanfm || has_command labwc; then
        if $DRY_RUN; then
            printf '%s  [dry-run]%s write %s (wallpaper=%s)\n' "$C_YELLOW" "$C_OFF" "$pcfile" "$user_img"
        else
            install -d -m 0755 -o "$owner" -g "$(id -gn "$owner")" "$pcdir"
            if [ -f "$pcfile" ] && grep -q '^wallpaper=' "$pcfile"; then
                sed -i "s#^wallpaper=.*#wallpaper=$user_img#" "$pcfile"
            elif [ -f "$pcfile" ]; then
                sed -i "/^\[Desktop\]/a wallpaper=$user_img" "$pcfile"
            else
                # pcmanfm's own defaults; only the keys it needs are written
                cat >"$pcfile" <<EOF
[*]
wallpaper_mode=crop
wallpaper_common=1
wallpaper=$user_img
desktop_bg=#000000
desktop_shadow=none
desktop_font=PibotoLt 12
show_wm_menu=0
show_documents=0
show_trash=0
show_mounts=0
EOF
            fi
            # 'crop' keeps the logo centred; stretch would distort on an odd panel
            sed -i "s#^wallpaper_mode=.*#wallpaper_mode=crop#" "$pcfile" 2>/dev/null || true
            chown "$owner":"$(id -gn "$owner")" "$pcfile"
            # apply now if a session is running; harmless (and silent) if not
            sudo -u "$owner" -H DISPLAY=${DISPLAY:-:0} pcmanfm --set-wallpaper="$user_img" \
                >/dev/null 2>&1 || true
            log_ok "pcmanfm desktop set for $owner ($pcfile)"
        fi
    fi

    # 3. minimal X11 (no pcmanfm, no GNOME): feh at session start
    if ! has_command pcmanfm && ! has_command labwc; then
        local autostart="$home/.config/autostart"
        if $DRY_RUN; then
            printf '%s  [dry-run]%s write %s/ktemata-wallpaper.desktop\n' "$C_YELLOW" "$C_OFF" "$autostart"
        else
            install -d -m 0755 -o "$owner" -g "$(id -gn "$owner")" "$autostart"
            cat >"$autostart/ktemata-wallpaper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ktemata wallpaper
Exec=/bin/sh -c "command -v feh >/dev/null && feh --no-fehbg --bg-fill $user_img"
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
            chown "$owner":"$(id -gn "$owner")" "$autostart/ktemata-wallpaper.desktop"
            log_ok "feh autostart entry for $owner"
        fi
    fi

    log_info "image: $img"
}

# Replace the early boot splash (the firmware/Plymouth logo) with the Ktemata mark.
#
# Raspberry Pi OS shows two splashes: the firmware's early logo, then Plymouth. The supported
# way to change the first is Raspberry Pi's own rpi-splash-screen-support: a 24-bit TGA,
# at most 1920x1080, at most 224 colours, installed as /lib/firmware/logo.tga with a hook
# that copies it into the initramfs, plus three cmdline.txt parameters.
#
# The image is derived from the repo SVG at install time (ImageMagick), so an updated logo
# propagates without committing a 6 MB bitmap.
install_splash() {
    $WITH_SPLASH || { log_stage "Boot splash"; log_info "skipped (--no-splash)"; return 0; }
    log_stage "Boot splash"

    local cmdline="${CMDLINE_FILE:-/boot/firmware/cmdline.txt}"
    if [ ! -f "$cmdline" ]; then
        log_info "no $cmdline: not a Raspberry Pi boot partition, skipping"
        return 0
    fi

    local dir tga
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    tga=/usr/local/share/ktemata/ktemata-splash.tga

    if $DRY_RUN; then
        printf '%s  [dry-run]%s build %s and run configure-splash\n' "$C_YELLOW" "$C_OFF" "$tga"
        printf '%s  [dry-run]%s set fullscreen_logo=1, fullscreen_logo_name=logo.tga, vt.global_cursor_default=0\n' "$C_YELLOW" "$C_OFF"
        return 0
    fi

    install -d -m 0755 /usr/local/share/ktemata

    if [ -n "${SPLASH_SRC:-}" ]; then
        [ -r "$SPLASH_SRC" ] || die "cannot read --splash $SPLASH_SRC"
        install -m 0644 "$SPLASH_SRC" "$tga"
        log_ok "using $SPLASH_SRC"
    else
        # ImageMagick 7 is `magick`, 6 (Ubuntu 24.04) is `convert`; both take the same args.
        local im=""
        if has_command magick; then im=magick
        elif has_command convert; then im=convert
        fi
        if [ -z "$im" ]; then
            log_warn "need ImageMagick to build the TGA; skipping splash"
            log_info "  apt install imagemagick librsvg2-bin"
            return 0
        fi
        local src
        # configure-splash rejects anything larger than 1920x1080 in EITHER axis, so a
        # portrait splash has to fit in 1080 height: 608x1080 is the 9:16 equivalent.
        local w h
        case $SPLASH_ORIENTATION in
            portrait) w=608;  h=1080 ;;
            *)        w=1920; h=1080 ;;
        esac
        # There are two source SVGs rather than one rotated at build time: rotating the
        # landscape artwork leaves the text sideways. The portrait file lays the same content
        # out upright for a 9:16 panel.
        local svg="$dir/../../docs/ktemata-splash.svg"
        [ "$SPLASH_ORIENTATION" = portrait ] && svg="$dir/../../docs/ktemata-splash-portrait.svg"
        if has_command rsvg-convert && [ -r "$svg" ]; then
            src="$tga.png"
            rsvg-convert -w "$w" -h "$h" "$svg" -o "$src"
            log_ok "rendered from $(basename "$svg") ($SPLASH_ORIENTATION ${w}x${h})"
        elif [ -r "$dir/ktemata-splash.png" ]; then
            src="$dir/ktemata-splash.png"
            log_ok "using the bundled splash PNG"
        else
            log_warn "no splash source; skipping"
            return 0
        fi
        # 224 colours is the firmware palette limit; 24-bit RGB is the required TGA depth
        "$im" "$src" -strip -colors 224 -type TrueColor -depth 8 \
            -define tga:compression=none "$tga" || {
            log_warn "could not build the TGA; skipping splash"; return 0; }
        [ "$src" = "$tga.png" ] && rm -f "$src"
        chmod 0644 "$tga"
    fi

    # the firmware only accepts TGA, 24-bit, <=1920x1080
    local dims
    dims=$(file -b "$tga")
    case $dims in
        *"Targa image data - RGB"*"x 24"*)
            # configure-splash also rejects >1920x1080, so check rather than find out at boot
            local pw ph
            pw=$(echo "$dims" | sed -n 's/.*[[:space:]]\([0-9][0-9]*\) x \([0-9][0-9]*\) x 24.*/\1/p')
            ph=$(echo "$dims" | sed -n 's/.*[[:space:]]\([0-9][0-9]*\) x \([0-9][0-9]*\) x 24.*/\2/p')
            if [ -n "$pw" ] && { [ "$pw" -gt 1920 ] || [ "$ph" -gt 1080 ]; }; then
                log_warn "splash is ${pw}x${ph}; the firmware accepts at most 1920x1080"
                log_warn "use --splash-orientation portrait (608x1080) for a portrait panel"
                return 0
            fi
            ;;
        *) log_warn "generated splash is not a 24-bit RGB TGA: $dims"
           log_warn "leaving cmdline.txt alone"; return 0 ;;
    esac

    # Use Raspberry Pi's supported path when it is installed
    if [ -x /usr/bin/configure-splash ]; then
        configure-splash "$tga" >/dev/null 2>&1 && log_ok "configure-splash applied" \
            || log_warn "configure-splash failed; falling back to the manual steps"
    fi

    # Ensure the kernel parameters are present (idempotent; also covers the manual case)
    local want="fullscreen_logo=1 fullscreen_logo_name=logo.tga vt.global_cursor_default=0"
    local cur
    cur=$(tr -d '\n' <"$cmdline")
    local param missing=""
    for param in $want; do
        case " $cur " in *" $param "*) ;; *) missing="$missing $param" ;; esac
    done

    if [ -z "$missing" ]; then
        log_ok "cmdline.txt already enables the splash"
    else
        [ -f "$cmdline.ktemata.bak" ] || cp -a "$cmdline" "$cmdline.ktemata.bak"
        # cmdline.txt must stay a single line
        printf '%s%s\n' "$cur" "$missing" >"$cmdline"
        log_ok "added:$missing"
    fi

    # install the logo + initramfs hook if configure-splash did not do it
    if [ -d /etc/initramfs-tools/hooks ] && [ ! -f /lib/firmware/logo.tga ]; then
        install -m 0644 "$tga" /lib/firmware/logo.tga
        if [ -r /usr/share/rpi-splash-screen-support/default-hook.sh ]; then
            install -m 0755 /usr/share/rpi-splash-screen-support/default-hook.sh \
                /etc/initramfs-tools/hooks/splash-screen-hook.sh
            sed -i "s|splash-image-path|logo.tga|" /etc/initramfs-tools/hooks/splash-screen-hook.sh
        fi
        has_command update-initramfs && update-initramfs -k all -u >/dev/null 2>&1 \
            && log_ok "initramfs rebuilt" || log_warn "initramfs not rebuilt"
    fi

    # Plymouth draws the second splash; give it our colour so there is no white flash
    local ptheme=/usr/share/plymouth/themes/pix/pix.script
    if [ -f "$ptheme" ]; then
        log_info "Plymouth theme found; it keeps its own background"
    fi

    # the firmware rainbow square shows before anything else; optional to remove
    if [ -f /boot/firmware/config.txt ] && ! grep -q '^disable_splash=1' /boot/firmware/config.txt; then
        log_info "hint: add disable_splash=1 to /boot/firmware/config.txt to also hide the rainbow"
    fi

    log_info "splash: $tga (takes effect on the next boot)"
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

# The service runs as SERVICE_USER; every archive must be group-readable by it. Called again
# after a download, because a freshly written ZIM is owned by root.
grant_library_access() {
    $WITH_SERVICE || return 0
    run_sh "chgrp -R '$SERVICE_USER' '$ZIM_DIR' && chmod -R g+rX '$ZIM_DIR'"
}

install_service() {
    $WITH_SERVICE || { log_stage "Service"; log_info "skipped (--no-service)"; return 0; }
    log_stage "Service"

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
# no archives yet -> nothing to serve; start once a ZIM is present
ConditionPathExistsGlob=$ZIM_DIR/*.zim

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
ExecStart=/usr/bin/kiwix-serve --port=$SERVICE_PORT $ZIM_DIR/*.zim
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

    if have_systemd; then
        run systemctl daemon-reload
        run systemctl enable --now "$SERVICE_NAME.service"
        log_ok "enabled; serving on http://localhost:$SERVICE_PORT"
    else
        log_warn "systemd not running here: start it later with"
        log_warn "  sudo systemctl enable --now $SERVICE_NAME.service"
    fi
}

download_sample() {
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
}

summary() {
    log_stage "Done"
    printf '  library   %s\n' "$ZIM_DIR"
    if $WITH_SERVICE; then
        printf '  service   %s.service (port %s)\n' "$SERVICE_NAME" "$SERVICE_PORT"
        printf '  check     systemctl status %s\n' "$SERVICE_NAME"
    fi
    printf '  next      drop *.zim files into %s, then: sudo systemctl restart %s\n' "$ZIM_DIR" "$SERVICE_NAME"
    if [ -n "$ROTATE" ]; then
        printf '  display   rotated (%s); reboot to apply console rotation\n' "$ROTATE"
    fi
    if $WITH_AUTOLOGIN; then
        printf '  autologin %s (GDM)\n' "$AUTOLOGIN_USER"
    fi
    if $WITH_WALLPAPER; then
        printf '  wallpaper /usr/local/share/ktemata/ktemata-wallpaper.png\n'
    fi
    if $WITH_SPLASH; then
        printf '  splash    /usr/local/share/ktemata/ktemata-splash.tga (next boot)\n'
    fi
    if $WITH_KIOSK; then
        printf '  kiosk     %s autostarts kiwix-kiosk on login\n' "$KIOSK_USER"
    fi
    if $WITH_HWTEST; then
        printf '  hardware  %d checks, %d failed, %d warning(s)\n' "$HW_CHECKS" "$HW_FAILS" "$HW_WARNS"
    fi
    printf '  desktop   kiwix (or "kiwix-desktop" if your release names it that way)\n'
    printf '  list      %s\n' "${SAMPLE_URL%/*}/"
}

# ---------------- arguments ----------------
main() {
    while [ $# -gt 0 ]; do
        case $1 in
            -y|--yes)        ASSUME_YES=true ;;
            -n|--dry-run)    DRY_RUN=true ;;
            --sample)        WITH_SAMPLE=true ;;
            --no-service)    WITH_SERVICE=false ;;
            --no-gui)        WITH_GUI=false ;;
            --no-update)     WITH_UPDATE=false ;;
            --kiosk)         WITH_KIOSK=true ;;
            --no-hwtest)     WITH_HWTEST=false ;;
            --hwtest-only)   HWTEST_ONLY=true; DRY_RUN=true; WITH_HWTEST=true ;;
            --strict)        STRICT=true ;;
            --power)         POWER_SOURCE=${2:?--power takes usbc or hat}; shift ;;
            --no-autologin)  WITH_AUTOLOGIN=false ;;
            --no-wallpaper)  WITH_WALLPAPER=false ;;
            --wallpaper)
                if [ $# -ge 2 ] && [ -f "$2" ]; then WALLPAPER_SRC=$2; shift; else WALLPAPER_SRC=""; fi
                WITH_WALLPAPER=true ;;
            --no-splash)     WITH_SPLASH=false ;;
            --splash-orientation)
                SPLASH_ORIENTATION=${2:?--splash-orientation takes landscape or portrait}; shift ;;
            # bare --splash just means "enable it" (the default image); a path is an override
            --splash)
                if [ $# -ge 2 ] && [ -f "$2" ]; then SPLASH_SRC=$2; shift; else SPLASH_SRC=""; fi
                WITH_SPLASH=true
SPLASH_ORIENTATION=${SPLASH_ORIENTATION:-landscape} ;;
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
    case $SERVICE_PORT in ''|*[!0-9]*) die "--port must be a number" ;; esac
    # fail fast on a bad --rotate instead of halfway through the install
    [ -z "$ROTATE" ] || rotation_degrees "$ROTATE" >/dev/null
    case ${POWER_SOURCE:-usbc} in usbc|hat) ;; *) die "--power takes usbc or hat" ;; esac
    case $SPLASH_ORIENTATION in landscape|portrait) ;;
        *) die "--splash-orientation takes landscape or portrait" ;; esac

    $DRY_RUN || require_root "$@"

    if ! $DRY_RUN && ! $ASSUME_YES && ! $HWTEST_ONLY; then
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
    setup_rotation
    install_autologin
    install_wallpaper
    install_splash
    install_kiosk
    $WITH_SAMPLE && download_sample
    verify
    summary

    if $STRICT && [ "$HW_FAILS" -gt 0 ]; then
        log_error "$HW_FAILS hardware check(s) failed (--strict)"
        exit 1
    fi
}

main "$@"

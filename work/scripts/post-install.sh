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
KIOSK_USER=${KIOSK_USER:-${SUDO_USER:-}}   # whose session autostarts the kiosk

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
  -h, --help             This message.
  -V, --version          Print the version.

${C_BOLD}ENVIRONMENT${C_OFF}
  ZIM_DIR, SERVICE_PORT, SERVICE_USER, NO_COLOR

${C_BOLD}WHAT IT DOES${C_OFF}
  1. checks it is running as root on a Debian derivative
  2. updates the system (apt update + full-upgrade) unless --no-update
  3. installs kiwix-tools (+ kiwix desktop app unless --no-gui)
  4. creates the ZIM library directory
  5. writes and enables $SERVICE_NAME.service (kiwix-serve on :$SERVICE_PORT)
  6. optionally sets the display rotation (--rotate) and downloads a sample ZIM (--sample)
  7. optionally installs the kiosk autostart (--kiosk)
  8. verifies the server answers
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
    # the kiosk needs a browser; chromium is the Pi OS default. On Ubuntu this package is a
    # snap transition, so only warn rather than fail if it cannot be installed.
    $WITH_KIOSK && pkgs+=(chromium-browser)

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
install_kiosk() {
    $WITH_KIOSK || { log_stage "Kiosk"; log_info "skipped (pass --kiosk to enable)"; return 0; }
    log_stage "Kiosk"

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
Exec=/usr/local/bin/kiwix-kiosk
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
            sed -i "s#^Exec=.*#Exec=/usr/local/bin/kiwix-kiosk --transform $deg#" \
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
    if $WITH_KIOSK; then
        printf '  kiosk     %s autostarts kiwix-kiosk on login\n' "$KIOSK_USER"
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

    $DRY_RUN || require_root "$@"

    if ! $DRY_RUN && ! $ASSUME_YES; then
        confirm "Install Kiwix into $ZIM_DIR and enable $SERVICE_NAME.service on port $SERVICE_PORT?" \
            || { log_info "aborted"; exit 0; }
    fi

    check_platform
    update_system
    install_packages
    setup_library
    install_service
    setup_rotation
    install_kiosk
    $WITH_SAMPLE && download_sample
    verify
    summary
}

main "$@"

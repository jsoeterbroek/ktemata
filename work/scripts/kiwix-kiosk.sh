#!/usr/bin/env bash
# Ktemata kiosk launcher.
#
# Boots straight into the offline library: waits for kiwix-serve, turns off screen blanking
# and starts a borderless full-screen browser on http://127.0.0.1:<port>/.
#
#   kiwix-kiosk                  # start the kiosk (normally via the autostart entry)
#   kiwix-kiosk --url URL        # show something else, e.g. a menu page
#   kiwix-kiosk --app kiwix      # native kiwix-desktop instead of a browser
#   kiwix-kiosk --selftest       # check the environment and exit (used by post-install)
#   kiwix-kiosk --stop           # stop a running kiosk
#
# Installed by work/scripts/post-install.sh --kiosk, which also writes the autostart entry.
# Works on X11 and on Wayland (Raspberry Pi OS Bookworm+ runs labwc/wlroots).

set -euo pipefail

readonly SCRIPT=$(basename "$0")

KIOSK_PORT=${KIOSK_PORT:-8080}
KIOSK_URL=${KIOSK_URL:-http://127.0.0.1:$KIOSK_PORT/}
KIOSK_LOG=${KIOSK_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/ktemata/kiosk.log}
KIOSK_WAIT=${KIOSK_WAIT:-60}          # seconds to wait for kiwix-serve
KIOSK_APP=${KIOSK_APP:-browser}       # browser | kiwix
KIOSK_DISPLAY_TRANSFORM=${KIOSK_DISPLAY_TRANSFORM:-}   # e.g. 270; empty = leave the output alone

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$KIOSK_LOG" 2>/dev/null || true; }
say() { printf '%s\n' "$*"; log "$*"; }
die() { printf '✗ %s\n' "$*" >&2; log "ERROR $*"; exit 1; }

usage() {
    cat <<EOF
$SCRIPT — Ktemata kiosk launcher

USAGE
  $SCRIPT [OPTION]...

OPTIONS
  --url URL           page to show (default $KIOSK_URL)
  --app browser|kiwix which front end (default $KIOSK_APP)
  --port PORT         kiwix-serve port to wait for (default $KIOSK_PORT)
  --transform DEG     rotate the Wayland output before starting (90|180|270)
  --selftest          report what would be used, then exit
  --stop              stop a running kiosk started by this script
  -h, --help          this message

FILES
  $KIOSK_LOG
EOF
}

# ---------------- session detection ----------------
is_wayland() { [ -n "${WAYLAND_DISPLAY:-}" ]; }
is_x11()     { [ -n "${DISPLAY:-}" ] && ! is_wayland; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------- screen blanking ----------------
# X11 and Wayland need different incantations; both are best-effort.
disable_blanking() {
    if is_x11 && have xset; then
        xset s off 2>/dev/null || true          # no screensaver
        xset -dpms 2>/dev/null || true          # no energy-saving blank
        xset s noblank 2>/dev/null || true
        say "blanking off (X11: xset)"
    elif is_wayland; then
        # wlroots compositors honour the idle-inhibit protocol only per client; the reliable
        # system-wide switch on Pi OS is the compositor's own idle setting.
        if have wlopm; then
            wlopm --on '*' 2>/dev/null && say "blanking off (Wayland: wlopm --on)" \
                || say "wlopm found but refused; leaving the compositor setting"
        else
            say "Wayland: no wlopm; screen idle is the compositor's setting (labwc: <idle/> disabled)"
        fi
    else
        say "no display session detected (DISPLAY/WAYLAND_DISPLAY unset)"
    fi
}

# Optional rotation for Wayland; cmdline.txt rotation only covers the text console.
apply_transform() {
    [ -n "$KIOSK_DISPLAY_TRANSFORM" ] || return 0
    if ! have wlr-randr; then
        say "transform requested but wlr-randr is missing; skipping"
        return 0
    fi
    local out
    out=$(wlr-randr 2>/dev/null | awk '/^[A-Za-z]/ {print $1}' | head -1)
    [ -n "$out" ] || { say "no Wayland output found; skipping transform"; return 0; }
    wlr-randr --output "$out" --transform "$KIOSK_DISPLAY_TRANSFORM" 2>/dev/null \
        && say "output $out rotated to $KIOSK_DISPLAY_TRANSFORM" \
        || say "wlr-randr refused to set transform $KIOSK_DISPLAY_TRANSFORM"
}

# ---------------- server ----------------
# One non-blocking check: is anything listening on the kiosk port?
probe_server() {
    # any HTTP answer means it is up; curl -f rejects 4xx, and kiwix-serve may answer 404 or a
    # redirect, so accept a status code instead of a zero exit.
    if have curl; then
        local code
        code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 2 \
            "http://127.0.0.1:$KIOSK_PORT/" 2>/dev/null || true)
        [ -n "$code" ] && [ "$code" != "000" ] && return 0
    fi
    have nc && nc -z 127.0.0.1 "$KIOSK_PORT" 2>/dev/null
}

wait_for_server() {
    local deadline=$(( $(date +%s) + KIOSK_WAIT ))
    say "waiting for kiwix-serve on port $KIOSK_PORT (up to ${KIOSK_WAIT}s)"
    while [ "$(date +%s)" -lt "$deadline" ]; do
        probe_server && { say "kiwix-serve is answering"; return 0; }
        sleep 1
    done
    return 1
}

# ---------------- front ends ----------------
# Pick the first browser that can actually run. `$1` is the URL.
browser_cmd() {
    local url=$1
    # Raspberry Pi OS ships chromium; some images only have the browser under another name.
    if have chromium; then
        printf '%s\t%s\n' chromium "--kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble --no-first-run --start-fullscreen --app=$url"
    elif have chromium-browser; then
        printf '%s\t%s\n' chromium-browser "--kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble --no-first-run --start-fullscreen --app=$url"
    elif have firefox; then
        printf '%s\t%s\n' firefox "--kiosk $url"
    elif have epiphany-browser; then
        printf '%s\t%s\n' epiphany-browser "--application-mode $url"
    else
        return 1
    fi
}

start_browser() {
    local spec bin args
    spec=$(browser_cmd "$KIOSK_URL") || die "no browser found (chromium, chromium-browser, firefox or epiphany-browser)"
    bin=${spec%%$'\t'*}
    args=${spec#*$'\t'}
    say "starting $bin"
    # shellcheck disable=SC2086  # word splitting of the flag string is intended
    exec "$bin" $args
}

start_kiwix_desktop() {
    have kiwix-desktop || die "kiwix-desktop not installed (apt install kiwix)"
    say "starting kiwix-desktop in full screen"
    # Qt app: full screen via the window manager hint; the kiosk compositor has no decorations
    exec kiwix-desktop --fullscreen 2>/dev/null || exec kiwix-desktop
}

selftest() {
    local rc=0
    say "session: $(is_wayland && echo wayland || (is_x11 && echo x11 || echo none))"
    say "server:  http://127.0.0.1:$KIOSK_PORT/"
    for c in xset wlopm wlr-randr curl nc; do
        if have "$c"; then say "  $c: $(command -v "$c")"; else say "  $c: missing (optional)"; fi
    done
    if spec=$(browser_cmd "$KIOSK_URL"); then
        say "  browser: ${spec%%$'\t'*}"
    else
        say "  browser: NONE (install chromium or firefox)"
        rc=1
    fi
    if have kiwix-desktop; then say "  kiwix-desktop: present"; else say "  kiwix-desktop: missing (optional)"; fi
    # a single probe: a selftest must not sit for KIOSK_WAIT
    if probe_server; then say "  kiwix-serve: answering"
    else say "  kiwix-serve: not answering"; rc=1
    fi
    say "result: $([ $rc -eq 0 ] && echo ready || echo 'not ready')"
    exit "$rc"
}

stop_kiosk() {
    local pids
    pids=$(pgrep -f 'kiosk|chromium.*--kiosk|kiwix-desktop' 2>/dev/null | grep -v "^$$\$" || true)
    if [ -z "$pids" ]; then say "nothing to stop"; return 0; fi
    # shellcheck disable=SC2086
    kill $pids 2>/dev/null || true
    say "stopped: $pids"
}

# ---------------- main ----------------
main() {
    mkdir -p "$(dirname "$KIOSK_LOG")"

    while [ $# -gt 0 ]; do
        case $1 in
            --url)        KIOSK_URL=${2:?--url needs a value}; shift ;;
            --port)       KIOSK_PORT=${2:?--port needs a value}; shift ;;
            --app)        KIOSK_APP=${2:?--app needs browser or kiwix}; shift ;;
            --transform)  KIOSK_DISPLAY_TRANSFORM=${2:?--transform needs a value}; shift ;;
            --selftest)   selftest ;;
            --stop)       stop_kiosk; exit 0 ;;
            -h|--help)    usage; exit 0 ;;
            *)            die "unknown option: $1 (see --help)" ;;
        esac
        shift
    done

    say "kiosk start: app=$KIOSK_APP url=$KIOSK_URL"

    # The kiosk is useless without a session; fail loudly rather than starting a browser
    # that cannot connect.
    if ! is_wayland && ! is_x11; then
        die "no graphical session (DISPLAY/WAYLAND_DISPLAY unset)"
    fi

    disable_blanking
    apply_transform

    # A missing server is not fatal: the browser still shows an error page, and kiwix-serve
    # may come up later. Log it so a black tablet is diagnosable.
    wait_for_server || say "kiwix-serve did not answer within ${KIOSK_WAIT}s; starting anyway"

    case $KIOSK_APP in
        browser) start_browser ;;
        kiwix)   start_kiwix_desktop ;;
        *)       die "--app takes browser or kiwix" ;;
    esac
}

main "$@"

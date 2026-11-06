#!/usr/bin/env bash
# Ktemata desktop artwork: the wallpaper and the early boot splash.
#
# Split out of post-install.sh because applying the wallpaper needs the desktop user's
# session bus; post-install is often run over SSH from a text console, where gsettings can
# block for a long time. Run this afterwards from the running desktop (runlevel 5 /
# graphical.target):
#
#   sudo ./work/scripts/desktop-artwork.sh                  # logo + splash
#   sudo ./work/scripts/desktop-artwork.sh --no-splash       # wallpaper only
#   sudo ./work/scripts/desktop-artwork.sh --no-wallpaper    # splash only
#   sudo ./work/scripts/desktop-artwork.sh --wallpaper mine.png
#   sudo ./work/scripts/desktop-artwork.sh --user ktemata    # other desktop account
#   ./work/scripts/desktop-artwork.sh --dry-run              # no root needed
#
# Idempotent: re-running is safe. The splash takes effect on the next boot; the wallpaper
# applies immediately when the session bus is reachable.

set -euo pipefail

readonly SCRIPT=$(basename "$0")
readonly SCRIPT_VERSION="0.1.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

WITH_WALLPAPER=true
WITH_SPLASH=true
DRY_RUN=false
OWNER=${SUDO_USER:-}
WALLPAPER_SRC=${WALLPAPER_SRC:-}
SPLASH_SRC=${SPLASH_SRC:-}
SPLASH_ORIENTATION=${SPLASH_ORIENTATION:-landscape}
WAIT=0

SHARE=/usr/local/share/ktemata
# Written after a run; the graphical.target unit is conditioned on it, so it applies the
# artwork once rather than re-rendering the TGA on every boot. Manual runs ignore it;
# delete it to let the unit run again.
DONE_MARKER="$SHARE/.artwork-applied"
# Every external call is bounded: a dead session bus or a stalled initramfs must not hang
# the operator, which is exactly why this step left post-install.
TIMEOUT=30

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
    C_BLUE=$'\e[36m'; C_BOLD=$'\e[1m'; C_OFF=$'\e[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""; C_OFF=""
fi

log_info()  { printf '%s•%s %s\n' "$C_BLUE" "$C_OFF" "$*"; }
log_ok()    { printf '%s✓%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
log_warn()  { printf '%s!%s %s\n' "$C_YELLOW" "$C_OFF" "$*" >&2; }
log_stage() { printf '\n%s%s==>%s %s%s\n' "$C_BOLD" "$C_BLUE" "$C_OFF" "$*" "$C_OFF"; }
die()       { log_warn "$*"; exit 1; }

has_command() { command -v "$1" >/dev/null 2>&1; }

# Assets live beside the checkout (docs/ or work/scripts/) during development and in
# $SHARE/src on the installed system; look in both.
find_asset() {
    local name=$1 candidate
    for candidate in "$SCRIPT_DIR/../../docs/$name" "$SCRIPT_DIR/$name" "$SHARE/src/$name"; do
        [ -r "$candidate" ] && { printf '%s' "$candidate"; return 0; }
    done
    return 1
}

usage() {
    cat <<EOF
${C_BOLD}$SCRIPT $SCRIPT_VERSION${C_OFF} — Ktemata wallpaper and boot splash

${C_BOLD}USAGE${C_OFF}
  [sudo] ./$SCRIPT [OPTION]...

Run this after post-install.sh, from the desktop session (runlevel 5), so the wallpaper
can be applied through the live session bus.

${C_BOLD}OPTIONS${C_OFF}
  -y, --yes              Accepted for symmetry with post-install.sh; nothing to confirm.
  -n, --dry-run          Print the commands instead of running them (no root needed).
      --user NAME        Desktop account to set the wallpaper for (default: \$SUDO_USER,
                         else the logged-in user, else ktemata).
      --wallpaper [FILE] Set the wallpaper (default), optionally from FILE.
      --no-wallpaper     Leave the desktop background alone.
      --splash [FILE]    Install the boot splash (default), optionally from a 24-bit TGA.
      --no-splash        Leave the boot splash alone.
      --splash-orientation WHAT
                         landscape (default) or portrait (608x1080).
      --wait SECONDS     Wait up to this long for the desktop user's session bus before
                         applying the wallpaper (the installed unit uses 120).
  -h, --help             This message.
  -V, --version          Print the version.

${C_BOLD}WHAT IT DOES${C_OFF}
  1. renders docs/ktemata-wallpaper.svg to a 1920x1080 PNG and sets it for the desktop
     (GNOME gsettings, Raspberry Pi OS pcmanfm, or a feh autostart on minimal X11)
  2. renders docs/ktemata-splash.svg to a 24-bit, <=224-colour, <=1920x1080 TGA, installs
     it as the firmware logo (configure-splash, /lib/firmware/logo.tga, cmdline.txt)
  3. installs librsvg2-bin/imagemagick/file when missing (apt, root only)

post-install.sh installs this script as /usr/local/lib/ktemata/desktop-artwork.sh and enables
ktemata-artwork.service at graphical.target (runlevel 5); the unit passes --wait and is
conditioned on /usr/local/share/ktemata/.artwork-applied, so it runs once. The splash takes
effect on the next boot. The wallpaper needs the desktop session: if the user has no session
bus, the configuration is still written and the script says so instead of blocking.
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

# Print the apt packages still needed for the enabled steps; return 1 when any is missing.
missing_tools() {
    local missing=()
    if $WITH_WALLPAPER || $WITH_SPLASH; then
        has_command rsvg-convert || missing+=(librsvg2-bin)
    fi
    if $WITH_SPLASH; then
        if ! has_command magick && ! has_command convert; then missing+=(imagemagick); fi
        has_command file || missing+=(file)
    fi
    [ ${#missing[@]} -eq 0 ] && return 0
    printf '%s' "${missing[*]}"
    return 1
}

ensure_tools() {
    local missing=""
    missing=$(missing_tools) || true
    [ -z "$missing" ] && return 0

    if $DRY_RUN; then
        printf '%s  [dry-run]%s apt-get install %s\n' "$C_YELLOW" "$C_OFF" "$missing"
        return 0
    fi
    if ! has_command apt-get; then
        log_warn "missing $missing; install them to render the artwork"
        return 1
    fi
    log_info "installing $missing"
    DEBIAN_FRONTEND=noninteractive timeout 300 apt-get install -y --no-install-recommends $missing \
        || log_warn "could not install $missing"
    missing=$(missing_tools) || true
    [ -z "$missing" ] && return 0
    log_warn "still missing: $missing"
    return 1
}

# Run a command in the desktop user's session, with a bounded wait. sudo resets the
# environment, so the bus address is rebuilt from the systemd runtime directory unless it
# was preserved explicitly.
run_as_owner() {
    local uid
    uid=$(id -u "$OWNER")
    timeout "$TIMEOUT" sudo -u "$OWNER" -H env \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$uid/bus}" \
        DISPLAY="${DISPLAY:-:0}" \
        "$@"
}

have_session_bus() {
    local uid
    uid=$(id -u "$OWNER")
    [ -S "/run/user/$uid/bus" ] || [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]
}

# At graphical.target the display manager is up but autologin has not necessarily finished,
# so the user's bus appears a little later. Poll it; the unit passes --wait 120.
wait_for_bus() {
    [ "$WAIT" -gt 0 ] || return 0
    local uid deadline
    uid=$(id -u "$OWNER")
    deadline=$((SECONDS + WAIT))
    log_info "waiting up to ${WAIT}s for $OWNER's session bus"
    while ! have_session_bus; do
        if [ "$SECONDS" -ge "$deadline" ]; then
            log_warn "no session bus after ${WAIT}s; the config applies at the next login"
            return 1
        fi
        sleep 2
    done
    return 0
}

# ---------------- wallpaper ----------------
install_wallpaper() {
    $WITH_WALLPAPER || { log_stage "Wallpaper"; log_info "skipped (--no-wallpaper)"; return 0; }
    log_stage "Wallpaper"

    local home user_img svg png
    home=$(getent passwd "$OWNER" | cut -d: -f6)
    [ -d "$home" ] || die "no home directory for $OWNER"

    $DRY_RUN || install -d -m 0755 "$SHARE"
    user_img="$home/.local/share/ktemata/ktemata-wallpaper.png"

    if $DRY_RUN; then
        printf '%s  [dry-run]%s render/install wallpaper to %s\n' "$C_YELLOW" "$C_OFF" "$SHARE"
    elif [ -n "$WALLPAPER_SRC" ]; then
        [ -r "$WALLPAPER_SRC" ] || die "cannot read --wallpaper $WALLPAPER_SRC"
        install -m 0644 "$WALLPAPER_SRC" "$SHARE/ktemata-wallpaper.png"
        log_ok "using $WALLPAPER_SRC"
    elif svg=$(find_asset ktemata-wallpaper.svg) && has_command rsvg-convert; then
        # render at 1920x1080: larger than any panel we support, scaled to fit anyway
        timeout "$TIMEOUT" rsvg-convert -w 1920 -h 1080 \
            "$svg" -o "$SHARE/ktemata-wallpaper.png"
        chmod 0644 "$SHARE/ktemata-wallpaper.png"
        log_ok "rendered from $(basename "$svg")"
    elif png=$(find_asset ktemata-wallpaper.png); then
        install -m 0644 "$png" "$SHARE/ktemata-wallpaper.png"
        log_ok "installed the pre-rendered PNG"
    else
        log_warn "no wallpaper source (need rsvg-convert, or --wallpaper FILE)"
        return 1
    fi

    local img="$SHARE/ktemata-wallpaper.png"
    if [ "$WAIT" -gt 0 ] && ! have_session_bus; then
        wait_for_bus || true
    fi
    if $DRY_RUN; then
        printf '%s  [dry-run]%s install %s -> %s\n' "$C_YELLOW" "$C_OFF" "$img" "$user_img"
    else
        install -d -m 0755 "$(dirname "$user_img")"
        install -m 0644 "$img" "$user_img"
        chown -R "$OWNER":"$(id -gn "$OWNER")" "$(dirname "$user_img")" 2>/dev/null || true
    fi

    # 1. GNOME
    if has_command gsettings && gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.desktop.background'; then
        if $DRY_RUN; then
            printf '%s  [dry-run]%s gsettings set org.gnome.desktop.background picture-uri\n' "$C_YELLOW" "$C_OFF"
        elif ! have_session_bus; then
            log_warn "no session bus for $OWNER: GNOME background written on the next run from the desktop"
        else
            run_as_owner gsettings set org.gnome.desktop.background picture-uri \
                "file://$user_img" 2>/dev/null || log_warn "gsettings picture-uri failed"
            # GNOME 42+ needs the dark variant too, or a dark theme keeps its own image
            run_as_owner gsettings set org.gnome.desktop.background picture-uri-dark \
                "file://$user_img" 2>/dev/null || true
            run_as_owner gsettings set org.gnome.desktop.background picture-options \
                'scaled' 2>/dev/null || true
            log_ok "GNOME background set for $OWNER"
        fi
    fi

    # 2. Raspberry Pi OS: pcmanfm desktop preferences + the live apply command
    local pcdir="$home/.config/pcmanfm/LXDE-pi"
    local pcfile="$pcdir/desktop-items-0.conf"
    if has_command pcmanfm || has_command labwc; then
        if $DRY_RUN; then
            printf '%s  [dry-run]%s write %s (wallpaper=%s)\n' "$C_YELLOW" "$C_OFF" "$pcfile" "$user_img"
        else
            install -d -m 0755 -o "$OWNER" -g "$(id -gn "$OWNER")" "$pcdir"
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
            chown "$OWNER":"$(id -gn "$OWNER")" "$pcfile"
            # apply now if a session is running; harmless (and bounded) if not
            if have_session_bus && has_command pcmanfm; then
                run_as_owner pcmanfm --set-wallpaper="$user_img" >/dev/null 2>&1 \
                    || log_warn "pcmanfm --set-wallpaper failed; the config applies at next login"
            fi
            log_ok "pcmanfm desktop set for $OWNER ($pcfile)"
        fi
    fi

    # 3. minimal X11 (no pcmanfm, no GNOME): feh at session start
    if ! has_command pcmanfm && ! has_command labwc; then
        local autostart="$home/.config/autostart"
        if $DRY_RUN; then
            printf '%s  [dry-run]%s write %s/ktemata-wallpaper.desktop\n' "$C_YELLOW" "$C_OFF" "$autostart"
        else
            install -d -m 0755 -o "$OWNER" -g "$(id -gn "$OWNER")" "$autostart"
            cat >"$autostart/ktemata-wallpaper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ktemata wallpaper
Exec=/bin/sh -c "command -v feh >/dev/null && feh --no-fehbg --bg-fill $user_img"
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
            chown "$OWNER":"$(id -gn "$OWNER")" "$autostart/ktemata-wallpaper.desktop"
            log_ok "feh autostart entry for $OWNER"
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
# The image is derived from the repo SVG at run time (ImageMagick), so an updated logo
# propagates without committing a 6 MB bitmap.
install_splash() {
    $WITH_SPLASH || { log_stage "Boot splash"; log_info "skipped (--no-splash)"; return 0; }
    log_stage "Boot splash"

    local cmdline="${CMDLINE_FILE:-/boot/firmware/cmdline.txt}"
    if [ ! -f "$cmdline" ]; then
        log_info "no $cmdline: not a Raspberry Pi boot partition, skipping"
        return 0
    fi

    local tga="$SHARE/ktemata-splash.tga"

    if $DRY_RUN; then
        printf '%s  [dry-run]%s build %s and run configure-splash\n' "$C_YELLOW" "$C_OFF" "$tga"
        printf '%s  [dry-run]%s set fullscreen_logo=1, fullscreen_logo_name=logo.tga, vt.global_cursor_default=0\n' "$C_YELLOW" "$C_OFF"
        return 0
    fi

    install -d -m 0755 "$SHARE"

    if [ -n "$SPLASH_SRC" ]; then
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
            log_warn "need ImageMagick to build the TGA"
            log_info "  apt install imagemagick librsvg2-bin"
            return 1
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
        local svg=""
        if [ "$SPLASH_ORIENTATION" = portrait ]; then
            svg=$(find_asset ktemata-splash-portrait.svg) || true
        else
            svg=$(find_asset ktemata-splash.svg) || true
        fi
        if [ -n "$svg" ] && has_command rsvg-convert; then
            src="$tga.png"
            timeout "$TIMEOUT" rsvg-convert -w "$w" -h "$h" "$svg" -o "$src"
            log_ok "rendered from $(basename "$svg") ($SPLASH_ORIENTATION ${w}x${h})"
        elif src=$(find_asset ktemata-splash.png); then
            log_ok "using the bundled splash PNG"
        else
            log_warn "no splash source"
            return 1
        fi
        # 224 colours is the firmware palette limit; 24-bit RGB is the required TGA depth
        timeout "$TIMEOUT" "$im" "$src" -strip -colors 224 -type TrueColor -depth 8 \
            -define tga:compression=none "$tga" || {
            log_warn "could not build the TGA (timed out?)"; return 1; }
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
                return 1
            fi
            ;;
        *) log_warn "generated splash is not a 24-bit RGB TGA: $dims"
           log_warn "leaving cmdline.txt alone"; return 1 ;;
    esac

    # Use Raspberry Pi's supported path when it is installed
    if [ -x /usr/bin/configure-splash ]; then
        timeout "$TIMEOUT" configure-splash "$tga" >/dev/null 2>&1 && log_ok "configure-splash applied" \
            || log_warn "configure-splash failed or timed out; falling back to the manual steps"
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
        if has_command update-initramfs; then
            timeout 180 update-initramfs -k all -u >/dev/null 2>&1 \
                && log_ok "initramfs rebuilt" || log_warn "initramfs not rebuilt (timed out?)"
        fi
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

# ---------------- arguments ----------------
main() {
    while [ $# -gt 0 ]; do
        case $1 in
            -y|--yes)        ;;          # nothing is interactive
            -n|--dry-run)    DRY_RUN=true ;;
            --user)          OWNER=${2:?--user needs a name}; shift ;;
            --no-wallpaper)  WITH_WALLPAPER=false ;;
            --wallpaper)
                if [ $# -ge 2 ] && [ -f "$2" ]; then WALLPAPER_SRC=$2; shift; else WALLPAPER_SRC=""; fi
                WITH_WALLPAPER=true ;;
            --no-splash)     WITH_SPLASH=false ;;
            --splash)
                if [ $# -ge 2 ] && [ -f "$2" ]; then SPLASH_SRC=$2; shift; else SPLASH_SRC=""; fi
                WITH_SPLASH=true ;;
            --splash-orientation)
                SPLASH_ORIENTATION=${2:?--splash-orientation takes landscape or portrait}; shift ;;
            --wait)
                WAIT=${2:?--wait needs a number of seconds}; shift ;;
            -h|--help)       usage; exit 0 ;;
            -V|--version)    printf '%s %s\n' "$SCRIPT" "$SCRIPT_VERSION"; exit 0 ;;
            *)               log_warn "unknown option: $1"; usage; exit 2 ;;
        esac
        shift
    done

    case $SPLASH_ORIENTATION in landscape|portrait) ;;
        *) die "--splash-orientation takes landscape or portrait" ;; esac
    case $WAIT in ''|*[!0-9]*) die "--wait takes a number of seconds" ;; esac
    $WITH_WALLPAPER || $WITH_SPLASH || { log_info "nothing to do"; exit 0; }

    # the default account, when sudo does not name the caller (root shell on the console)
    if [ -z "$OWNER" ]; then
        OWNER=$(logname 2>/dev/null || true)
    fi
    [ -n "$OWNER" ] || OWNER=ktemata
    id -u "$OWNER" >/dev/null 2>&1 || die "no such user: $OWNER"

    if ! $DRY_RUN && [ "$(id -u)" -ne 0 ]; then
        die "run this with sudo (it writes $SHARE and the boot files)"
    fi

    if $WITH_WALLPAPER && ! $DRY_RUN && has_command systemctl \
       && ! systemctl is-active --quiet graphical.target; then
        log_warn "graphical.target is not active: run this from the desktop (runlevel 5),"
        log_warn "or the wallpaper will only be written, not applied"
    fi

    log_stage "Tools"
    if ! ensure_tools; then
        log_warn "artwork tools are missing; not marking this run done (the unit retries next boot)"
        return 0
    fi

    local ok=true wp_ok=true sp_ok=true
    install_wallpaper || { wp_ok=false; ok=false; }
    install_splash || { sp_ok=false; ok=false; }

    # The graphical.target unit asks for both steps; only a complete run counts as done, so a
    # manual --no-splash/--no-wallpaper (or a failed render) leaves the marker absent and the
    # unit retries at the next boot.
    if $ok && $WITH_WALLPAPER && $WITH_SPLASH && ! $DRY_RUN; then
        install -d -m 0755 "$SHARE"
        : >"$DONE_MARKER"
    fi

    log_stage "Done"
    if $WITH_WALLPAPER; then
        $wp_ok && printf '  wallpaper %s\n' "$OWNER" \
            || printf '  wallpaper not applied (see above)\n'
    fi
    if $WITH_SPLASH; then
        $sp_ok && printf '  splash    %s (next boot)\n' "$SHARE/ktemata-splash.tga" \
            || printf '  splash    not installed (see above)\n'
    fi
    $WITH_WALLPAPER && ! have_session_bus && printf '  session   no bus for %s; re-run from the desktop\n' "$OWNER"
    return 0
}

main "$@"

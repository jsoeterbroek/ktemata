#!/usr/bin/env bash
# Ktemata Wi-Fi mode switch, installed as /usr/local/bin/wifi-mode by post-install.sh.
#
# The desktop entry runs "wifi-mode menu": pick client, access point, or radio off. The same
# choices are available from a terminal, which is what the installer verifies.
#
#   wifi-mode              chooser (GUI, else terminal)
#   wifi-mode menu         same
#   wifi-mode status       current mode, one line
#   wifi-mode client       radio on; leave the AP, join a known network
#   wifi-mode ap           radio on; bring up the Ktemata access point
#   wifi-mode off          radio off (NetworkManager remembers it across reboots)
#
# NetworkManager is the only backend: the AP is an ordinary nmcli profile (mode ap, ipv4.method
# shared), so DHCP/DNS come from NM's own dnsmasq and nothing else is installed. A drop-in sets
# NM's firewall backend to none, because ipv4.method shared would otherwise NAT clients onto
# whatever uplink is present. hostapd is not touched; images without NetworkManager are out of
# scope.
#
# The AP profile is created on first use from /etc/ktemata/wifi.conf, which post-install.sh
# writes from --hotspot-ssid/-pass/-addr/-band. Running the installer with --hotspot still
# creates and starts the profile immediately; this helper is for switching afterwards.
#
# Mutating commands need root. The desktop entry runs as the desktop user, and sudoers
# (/etc/sudoers.d/ktemata-wifi) allows exactly the three mode words, so no password prompt.

set -euo pipefail

# AP settings. `/etc/ktemata/wifi.conf` is the source of truth; the old wifi-mode.conf is
# still read when the new file is absent, so existing installs keep working.
#   AP_NAME      NetworkManager connection/profile name (internal)
#   AP_WELCOME   SSID clients see; empty falls back to Ktemata
#   AP_PASSWORD  WPA2 passphrase; empty leaves a new profile open
#   AP_ADDR, AP_CIDR, AP_BAND  optional network settings
# Deliberately not overridable from the environment: the helper runs as root, and sourcing a
# user-chosen file would be a privilege escalation.
CONFIG=/etc/ktemata/wifi.conf
LEGACY_CONFIG=/etc/ktemata/wifi-mode.conf
NO_NAT_CONF=/etc/NetworkManager/conf.d/90-ktemata-no-nat.conf
WIFI_IF=${WIFI_IF:-wlan0}
AP_ADDR=${AP_ADDR:-10.10.10.1}
AP_CIDR=${AP_CIDR:-24}
AP_BAND=${AP_BAND:-auto}      # auto | 2.4 | 5

SELF=${BASH_SOURCE[0]}
SELF=$(cd "$(dirname "$SELF")" && pwd)/$(basename "$SELF")

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_BOLD=$'\e[1m'; C_OFF=$'\e[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BOLD=""; C_OFF=""
fi

die() { printf '%s✗%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }
info() { printf '%s•%s %s\n' "$C_YELLOW" "$C_OFF" "$*" >&2; }

# These files are sourced as root, so a non-root-writable file would be a privilege escalation.
# Only enforced for the root process; the desktop user's unprivileged menu just reads defaults.
check_config_secure() {
    local f=$1 owner mode
    [ -r "$f" ] || return 0
    [ "$(id -u)" -eq 0 ] || return 0
    owner=$(stat -c '%u' "$f" 2>/dev/null || true)
    mode=$(stat -c '%a' "$f" 2>/dev/null || true)
    [ "$owner" = 0 ] || die "$f must be owned by root; run post-install.sh"
    case $mode in
        ''|*[!0-7]*) die "cannot check the permissions of $f" ;;
    esac
    [ $((8#$mode & 022)) -eq 0 ] || die "$f must not be group/other writable; chmod 600 $f"
}

check_config_secure "$CONFIG"
check_config_secure "$LEGACY_CONFIG"

if [ -r "$CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG"
elif [ -r "$LEGACY_CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$LEGACY_CONFIG"
fi

# Accept the old key names as well as the current ones.
AP_PROFILE=${AP_NAME:-${AP_PROFILE:-Ktemata}}      # connection.id
AP_SSID=${AP_WELCOME:-${AP_SSID:-Ktemata}}         # 802-11-wireless.ssid
AP_PASS=${AP_PASSWORD:-${AP_PASS:-}}               # empty: open network

usage() {
    cat <<EOF
${C_BOLD}wifi-mode${C_OFF} — Ktemata Wi-Fi control (NetworkManager)

USAGE
  wifi-mode [menu|status|client|ap|off]

  menu      Choose client, access point or off (zenity, else terminal).
  status    Print the current mode.
  client    Radio on, access point down; join a known client network.
  ap        Radio on; start the '$AP_SSID' access point at $AP_ADDR/$AP_CIDR.
  off       Radio off. NetworkManager keeps this across reboots.

No argument is the same as 'menu'. AP_NAME, AP_WELCOME, AP_PASSWORD and the network
settings are read from $CONFIG; post-install.sh writes it.
EOF
}

has_nmcli() {
    command -v nmcli >/dev/null 2>&1 || \
        die "nmcli not found: this switcher needs NetworkManager"
}

ap_profile_exists() {
    nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$AP_PROFILE"
}

# The active profile, whatever its connection.id, that is running in AP mode. The installer
# may have created it under a different name (for example ktemata-ap) than AP_NAME.
active_ap_profile() {
    local name
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        [ "$(nmcli -g 802-11-wireless.mode connection show "$name" 2>/dev/null || true)" = ap ] || continue
        printf '%s\n' "$name"
        return 0
    done < <(nmcli -t -f NAME connection show --active 2>/dev/null)
    return 1
}

is_ap_profile() {
    [ "$(nmcli -g 802-11-wireless.mode connection show "$1" 2>/dev/null || true)" = ap ]
}

radio_state() {
    nmcli radio wifi 2>/dev/null || printf 'unknown\n'
}

# The active wireless connection that is not an access point, if any.
client_connection() {
    local name
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        is_ap_profile "$name" && continue
        printf '%s\n' "$name"
        return 0
    done < <(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null |
             awk -F: '$2 ~ /wireless/ { print $1 }')
    return 1
}

current_mode() {
    if [ "$(radio_state)" != enabled ]; then
        printf 'off\n'
    elif [ -n "$(active_ap_profile || true)" ]; then
        printf 'ap\n'
    else
        printf 'client\n'
    fi
}

status_text() {
    local name ap_name ap_ssid
    if [ "$(radio_state)" != enabled ]; then
        printf 'Off - Wi-Fi radio disabled\n'
    elif ap_name=$(active_ap_profile) && [ -n "$ap_name" ]; then
        ap_ssid=$(nmcli -g 802-11-wireless.ssid connection show "$ap_name" 2>/dev/null || true)
        printf 'Access point - %s at %s/%s\n' "${ap_ssid:-$ap_name}" "$AP_ADDR" "$AP_CIDR"
    elif name=$(client_connection) && [ -n "$name" ]; then
        printf 'Client - connected to %s\n' "$name"
    else
        printf 'Client - radio on, not connected\n'
    fi
}

ap_profile_mode() {
    nmcli -g 802-11-wireless.mode connection show "$AP_PROFILE" 2>/dev/null || true
}

ap_profile_key_mgmt() {
    nmcli -g 802-11-wireless-security.key-mgmt connection show "$AP_PROFILE" 2>/dev/null || true
}

# A profile whose connection.id is not AP_NAME but whose SSID is AP_WELCOME (for example the
# old Ktemata profile) is adopted instead of creating a second profile for the same network.
profile_with_ssid() {
    local ssid=$1 name
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        [ "$name" = "$AP_PROFILE" ] && continue
        if [ "$(nmcli -g 802-11-wireless.ssid connection show "$name" 2>/dev/null || true)" = "$ssid" ]; then
            printf '%s\n' "$name"
            return 0
        fi
    done < <(nmcli -t -f NAME connection show 2>/dev/null)
    return 1
}

# Shared mode gives DHCP and DNS, but NetworkManager has no per-connection switch to stop it
# NATing clients onto the uplink. `ipv4.ip-forward` does not exist (nmcli: "invalid property").
# The firewall backend is global, so a drop-in disables masquerading for shared connections.
ensure_no_nat() {
    local want='firewall-backend=none'
    if [ -r "$NO_NAT_CONF" ] && grep -qx "$want" "$NO_NAT_CONF"; then
        # Ask NM to re-read its config: a manually dropped file may not have been loaded yet.
        nmcli general reload conf >/dev/null 2>&1 || true
        return 0
    fi
    info "disabling NetworkManager NAT for shared connections ($NO_NAT_CONF)"
    install -d -m 0755 "$(dirname "$NO_NAT_CONF")"
    {
        printf '[main]\n'
        printf '# Ktemata: the library AP serves DHCP/DNS but must not NAT clients onto the uplink.\n'
        printf '%s\n' "$want"
    } >"$NO_NAT_CONF"
    chmod 0644 "$NO_NAT_CONF"
    nmcli general reload conf >/dev/null 2>&1 || \
        systemctl reload NetworkManager >/dev/null 2>&1 || \
        info "reload NetworkManager to apply the no-NAT setting"
}

configure_ap_profile() {
    local args=(
        802-11-wireless.mode ap
        802-11-wireless.ssid "$AP_SSID"
        ipv4.method shared
        ipv4.addresses "$AP_ADDR/$AP_CIDR"
        ipv6.method disabled
        connection.autoconnect no
    )
    case $AP_BAND in
        2.4) args+=(802-11-wireless.band bg) ;;
        5)   args+=(802-11-wireless.band a) ;;
    esac
    nmcli connection modify "$AP_PROFILE" "${args[@]}" >/dev/null
}

# Apply AP_NAME / AP_WELCOME / AP_PASSWORD from the config. A missing profile is created (or an
# existing profile with the same SSID is adopted and renamed); the values are then applied on
# every start, so editing wifi.conf is enough. Empty AP_PASSWORD leaves the profile's security
# untouched; a profile created without it is open.
ensure_ap_profile() {
    if [ ! -r "$CONFIG" ] && [ ! -r "$LEGACY_CONFIG" ]; then
        die "neither $CONFIG nor $LEGACY_CONFIG exists; run post-install.sh"
    fi
    if [ -n "$AP_PASS" ] && [ ${#AP_PASS} -lt 8 ]; then
        die "AP_PASSWORD needs 8-63 characters (WPA2); current length is ${#AP_PASS}"
    fi
    if [ ${#AP_PASS} -gt 63 ]; then
        die "AP_PASSWORD needs 8-63 characters (WPA2); current length is ${#AP_PASS}"
    fi

    local existed=true
    if ! ap_profile_exists; then
        existed=false
        local adopt
        adopt=$(profile_with_ssid "$AP_SSID" || true)
        if [ -n "$adopt" ]; then
            info "adopting profile '$adopt' as '$AP_PROFILE' ($AP_SSID)"
            nmcli connection modify "$adopt" connection.id "$AP_PROFILE" >/dev/null
        else
            info "creating NetworkManager profile '$AP_PROFILE' ($AP_SSID) on $WIFI_IF"
            nmcli connection add type wifi ifname "$WIFI_IF" con-name "$AP_PROFILE" \
                autoconnect no ssid "$AP_SSID" >/dev/null
        fi
    fi

    if $existed && [ "$(ap_profile_mode)" != ap ]; then
        info "repairing profile '$AP_PROFILE' (missing 802-11-wireless.mode ap)"
    fi
    configure_ap_profile

    if [ -n "$AP_PASS" ]; then
        nmcli connection modify "$AP_PROFILE" \
            802-11-wireless-security.key-mgmt wpa-psk \
            802-11-wireless-security.psk "$AP_PASS" >/dev/null
    fi
    printf '%s✓%s profile %s ready: SSID %s at %s/%s\n' \
        "$C_GREEN" "$C_OFF" "$AP_PROFILE" "$AP_SSID" "$AP_ADDR" "$AP_CIDR" >&2
}

mode_client() {
    nmcli radio wifi on >/dev/null
    # The AP must not win the next autoconnect race after someone chose client mode. The active
    # AP may have a different connection.id than AP_NAME, so handle both.
    local active_ap
    active_ap=$(active_ap_profile || true)
    if [ -n "$active_ap" ]; then
        nmcli connection modify "$active_ap" connection.autoconnect no >/dev/null || true
    fi
    if ap_profile_exists && [ "$AP_PROFILE" != "$active_ap" ]; then
        nmcli connection modify "$AP_PROFILE" connection.autoconnect no >/dev/null || true
    fi
    if [ -n "$active_ap" ]; then
        nmcli connection down "$active_ap" >/dev/null || true
    fi

    local found=false name
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        is_ap_profile "$name" && continue
        found=true
        break
    done < <(nmcli -t -f NAME,TYPE connection show 2>/dev/null |
             awk -F: '$2 ~ /wireless/ { print $1 }')
    if ! $found; then
        printf 'Client mode: radio is on but no saved network exists.\n' >&2
        printf 'Join one in the desktop network menu first (or nmcli device wifi connect SSID).\n' >&2
        return 0
    fi

    local out
    if ! out=$(nmcli --wait 30 device connect "$WIFI_IF" 2>&1); then
        printf 'Client mode: radio is on, no network connected (%s).\n' "$out" >&2
        return 0
    fi
    printf '%s✓%s client mode: %s\n' "$C_GREEN" "$C_OFF" "$(status_text)"
}

mode_ap() {
    nmcli radio wifi on >/dev/null
    ensure_ap_profile
    ensure_no_nat
    # AP mode is an explicit choice: let it reconnect at boot, and prefer it over client
    # profiles that were also saved with autoconnect.
    nmcli connection modify "$AP_PROFILE" \
        connection.autoconnect yes connection.autoconnect-priority 100 >/dev/null

    # Force reactivation: `connection up` on an already-active AP does not apply a changed
    # SSID or PSK. Bring down the active AP (even under another id) and the target profile.
    local active_ap
    active_ap=$(active_ap_profile || true)
    if [ -n "$active_ap" ] && [ "$active_ap" != "$AP_PROFILE" ]; then
        nmcli connection down "$active_ap" >/dev/null || true
    fi
    nmcli connection down "$AP_PROFILE" >/dev/null 2>&1 || true

    local out
    if ! out=$(nmcli --wait 30 connection up "$AP_PROFILE" 2>&1); then
        die "could not bring up '$AP_PROFILE': $out"
    fi
    printf '%s✓%s access point: %s at %s/%s\n' \
        "$C_GREEN" "$C_OFF" "$AP_SSID" "$AP_ADDR" "$AP_CIDR"
    if [ -z "$AP_PASS" ] && [ -z "$(ap_profile_key_mgmt)" ]; then
        info "open network: anyone in radio range can read the library"
    fi
}

mode_off() {
    nmcli radio wifi off >/dev/null
    if [ "$(radio_state)" != disabled ]; then
        die "NetworkManager did not turn the Wi-Fi radio off (rfkill hard block?)"
    fi
    printf '%s✓%s Wi-Fi off\n' "$C_GREEN" "$C_OFF"
}

set_mode() {
    has_nmcli
    case $1 in
        client) mode_client ;;
        ap)     mode_ap ;;
        off)    mode_off ;;
        *)      die "unknown mode: $1" ;;
    esac
}

zenity_available() {
    command -v zenity >/dev/null 2>&1 &&
        { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }
}

gui_choose() {
    local current=$1 text=$2 client=TRUE ap=FALSE off=FALSE
    case $current in
        ap)  client=FALSE; ap=TRUE ;;
        off) client=FALSE; off=TRUE ;;
    esac
    zenity --list --radiolist --title="Ktemata Wi-Fi" --text="$text" \
        --column="" --column="mode" --column="Mode" \
        --hide-column=2 --print-column=2 --width=460 --height=300 \
        "$client" client "Client - join a known network" \
        "$ap" ap "Access point - share the library" \
        "$off" off "Off - radio disabled"
}

gui_message() {
    local kind=$1 text=$2
    if zenity_available; then
        zenity "--$kind" --title="Ktemata Wi-Fi" --text="$text" --width=420
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send "Ktemata Wi-Fi" "$text"
    else
        printf '%s\n' "$text" >&2
    fi
}

terminal_choose() {
    local text=$1 reply
    # Prompts go to stderr: the caller captures stdout, so anything printed there becomes part
    # of the answer instead of appearing on the terminal.
    printf '%s\n\n' "$text" >&2
    while :; do
        printf '  1) Client - join a known network\n' >&2
        printf '  2) Access point - share the library\n' >&2
        printf '  3) Off - radio disabled\n' >&2
        printf '  q) Cancel\n' >&2
        printf 'Choose: ' >&2
        read -r reply || return 1
        case $reply in
            1) printf 'client\n'; return 0 ;;
            2) printf 'ap\n'; return 0 ;;
            3) printf 'off\n'; return 0 ;;
            q|Q|'') return 1 ;;
        esac
    done
}

menu() {
    has_nmcli
    local choice out
    if zenity_available; then
        choice=$(gui_choose "$(current_mode)" "$(status_text)") || exit 0
    elif [ -t 0 ] && [ -t 1 ]; then
        choice=$(terminal_choose "$(status_text)") || exit 0
    else
        die "no graphical or terminal session; run: wifi-mode status|client|ap|off"
    fi
    [ -n "$choice" ] || exit 0
    case $choice in
        client|ap|off) ;;
        Client*)  choice=client ;;
        Access*)  choice=ap ;;
        Off*)     choice=off ;;
        *)        die "unexpected selection: $choice" ;;
    esac

    if [ "$(id -u)" -eq 0 ]; then
        set_mode "$choice"
    elif out=$(sudo -n -- "$SELF" "$choice" 2>&1); then
        :
    else
        gui_message error "Could not switch Wi-Fi mode.

$out"
        exit 1
    fi

    # tell the person what the box now does, not just that the command exited 0
    if zenity_available; then
        gui_message info "$(status_text)"
    else
        printf '%s\n' "$(status_text)"
    fi
}

main() {
    local cmd=${1:-menu}
    case $cmd in
        -h|--help|help) usage; exit 0 ;;
        menu)           menu ;;
        status)         has_nmcli; status_text ;;
        client|ap|off)
            if [ "$(id -u)" -eq 0 ]; then
                set_mode "$cmd"
            else
                has_nmcli
                if ! sudo -n -- "$SELF" "$cmd"; then
                    die "Wi-Fi changes need root: sudo $SELF $cmd"
                fi
            fi
            ;;
        *) die "unknown mode: $cmd (use menu, status, client, ap or off)" ;;
    esac
}

main "$@"

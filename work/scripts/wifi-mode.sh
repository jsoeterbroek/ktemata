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
# The AP profile is created on first use from /etc/ktemata/wifi-mode.conf, which post-install.sh
# writes from --hotspot-ssid/-pass/-addr/-band. Running the installer with --hotspot still
# creates and starts the profile immediately; this helper is for switching afterwards.
#
# Mutating commands need root. The desktop entry runs as the desktop user, and sudoers
# (/etc/sudoers.d/ktemata-wifi) allows exactly the three mode words, so no password prompt.

set -euo pipefail

# The AP profile settings are written by post-install.sh. Deliberately not overridable from the
# environment: the helper runs as root, and sourcing a user-chosen file would be a privilege
# escalation. Root owns this file; the sudoers rule does not preserve the environment.
CONFIG=/etc/ktemata/wifi-mode.conf
NO_NAT_CONF=/etc/NetworkManager/conf.d/90-ktemata-no-nat.conf
WIFI_IF=${WIFI_IF:-wlan0}
AP_PROFILE=${AP_PROFILE:-Ktemata}
AP_ADDR=${AP_ADDR:-10.10.10.1}
AP_CIDR=${AP_CIDR:-24}
AP_BAND=${AP_BAND:-auto}      # auto | 2.4 | 5
AP_PASS=${AP_PASS:-}          # empty: open network

if [ -r "$CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG"
fi

SELF=${BASH_SOURCE[0]}
SELF=$(cd "$(dirname "$SELF")" && pwd)/$(basename "$SELF")

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_BOLD=$'\e[1m'; C_OFF=$'\e[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BOLD=""; C_OFF=""
fi

die() { printf '%s✗%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }
info() { printf '%s•%s %s\n' "$C_YELLOW" "$C_OFF" "$*" >&2; }

usage() {
    cat <<EOF
${C_BOLD}wifi-mode${C_OFF} — Ktemata Wi-Fi control (NetworkManager)

USAGE
  wifi-mode [menu|status|client|ap|off]

  menu      Choose client, access point or off (zenity, else terminal).
  status    Print the current mode.
  client    Radio on, access point down; join a known client network.
  ap        Radio on; start the '$AP_PROFILE' access point at $AP_ADDR/$AP_CIDR.
  off       Radio off. NetworkManager keeps this across reboots.

No argument is the same as 'menu'. The AP profile is created on first use from
$CONFIG; post-install.sh writes it.
EOF
}

has_nmcli() {
    command -v nmcli >/dev/null 2>&1 || \
        die "nmcli not found: this switcher needs NetworkManager"
}

ap_profile_exists() {
    nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$AP_PROFILE"
}

ap_profile_active() {
    nmcli -t -f NAME connection show --active 2>/dev/null | grep -Fxq "$AP_PROFILE"
}

radio_state() {
    nmcli radio wifi 2>/dev/null || printf 'unknown\n'
}

# The active wireless connection that is not the access point, if any.
client_connection() {
    nmcli -t -f NAME,TYPE connection show --active 2>/dev/null |
        awk -F: -v ap="$AP_PROFILE" '$2 ~ /wireless/ && $1 != ap { print $1; exit }'
}

current_mode() {
    if [ "$(radio_state)" != enabled ]; then
        printf 'off\n'
    elif ap_profile_active; then
        printf 'ap\n'
    else
        printf 'client\n'
    fi
}

status_text() {
    local name
    if [ "$(radio_state)" != enabled ]; then
        printf 'Off - Wi-Fi radio disabled\n'
    elif ap_profile_active; then
        printf 'Access point - %s at %s/%s\n' "$AP_PROFILE" "$AP_ADDR" "$AP_CIDR"
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

# Create the AP profile on first use and repair one left half-configured by an interrupted run
# (the old helper failed on ipv4.ip-forward after `connection add`). A working profile made by
# --hotspot, or edited by hand, is not overwritten.
ensure_ap_profile() {
    if ! ap_profile_exists; then
        # Fail closed: creating a profile without the installer's config would silently produce
        # an open access point with the built-in defaults.
        [ -r "$CONFIG" ] || \
            die "$CONFIG is missing; run post-install.sh, or create the '$AP_PROFILE' profile first"
        info "creating NetworkManager profile '$AP_PROFILE' on $WIFI_IF"
        nmcli connection add type wifi ifname "$WIFI_IF" con-name "$AP_PROFILE" \
            autoconnect no ssid "$AP_PROFILE" >/dev/null
    fi

    if [ "$(ap_profile_mode)" != ap ]; then
        info "repairing profile '$AP_PROFILE' (missing 802-11-wireless.mode ap)"
        configure_ap_profile
    fi

    if [ -n "$AP_PASS" ] && [ -z "$(ap_profile_key_mgmt)" ]; then
        nmcli connection modify "$AP_PROFILE" \
            802-11-wireless-security.key-mgmt wpa-psk \
            802-11-wireless-security.psk "$AP_PASS" >/dev/null
    fi
    printf '%s✓%s profile %s ready (%s/%s)\n' \
        "$C_GREEN" "$C_OFF" "$AP_PROFILE" "$AP_ADDR" "$AP_CIDR" >&2
}

mode_client() {
    nmcli radio wifi on >/dev/null
    # The AP must not win the next autoconnect race after someone chose client mode.
    if ap_profile_exists; then
        nmcli connection modify "$AP_PROFILE" connection.autoconnect no >/dev/null || true
    fi
    if ap_profile_active; then
        nmcli connection down "$AP_PROFILE" >/dev/null || true
    fi

    local saved
    saved=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null) || saved=
    if ! awk -F: -v ap="$AP_PROFILE" \
            '$2 ~ /wireless/ && $1 != ap { found=1 } END { exit !found }' <<<"$saved"; then
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
    ensure_no_nat
    ensure_ap_profile
    # AP mode is an explicit choice: let it reconnect at boot, and prefer it over client
    # profiles that were also saved with autoconnect.
    nmcli connection modify "$AP_PROFILE" \
        connection.autoconnect yes connection.autoconnect-priority 100 >/dev/null

    local out
    if ! out=$(nmcli --wait 30 connection up "$AP_PROFILE" 2>&1); then
        die "could not bring up '$AP_PROFILE': $out"
    fi
    printf '%s✓%s access point: %s at %s/%s\n' \
        "$C_GREEN" "$C_OFF" "$AP_PROFILE" "$AP_ADDR" "$AP_CIDR"
    if [ -z "$AP_PASS" ]; then
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

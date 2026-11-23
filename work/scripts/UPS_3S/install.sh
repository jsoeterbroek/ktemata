#!/usr/bin/env bash
# Install the UPS tray app and its login autostart for the sudo invoking user.
set -euo pipefail

BUS=1
while [ $# -gt 0 ]; do
    case $1 in
        --i2c-bus) BUS=${2:?--i2c-bus needs a bus number}; shift ;;
        -h|--help)
            printf 'Usage: sudo %s [--i2c-bus N]\n' "$0"
            exit 0
            ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done
case $BUS in ''|*[!0-9]*) printf 'I2C bus must be a non-negative integer\n' >&2; exit 2 ;; esac
if [ "$(id -u)" -ne 0 ]; then
    printf 'Run as root: sudo %s --i2c-bus %s\n' "$0" "$BUS" >&2
    exit 1
fi

DESKTOP_USER=${SUDO_USER:-}
if [ -z "$DESKTOP_USER" ] || [ "$DESKTOP_USER" = root ]; then
    printf 'Run with sudo from the desktop user account so autostart has an owner.\n' >&2
    exit 1
fi
HOME_DIR=$(getent passwd "$DESKTOP_USER" | cut -d: -f6)
[ -n "$HOME_DIR" ] || { printf 'No such desktop user: %s\n' "$DESKTOP_USER" >&2; exit 1; }

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB=/usr/local/lib/ktemata-ups-tray
AUTO_START="$HOME_DIR/.config/autostart"

apt-get update
apt-get install -y \
    python3 python3-gi python3-smbus i2c-tools \
    gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 gir1.2-notify-0.7

install -d -m 0755 "$LIB/icons"
install -m 0755 "$SRC/ups_tray.py" "$LIB/ups_tray.py"
install -m 0644 "$SRC/INA219.py" "$LIB/INA219.py"
install -m 0644 "$SRC"/icons/*.svg "$LIB/icons/"
install -m 0755 "$SRC/ktemata-ups-tray" /usr/local/bin/ktemata-ups-tray

install -d -m 0755 -o "$DESKTOP_USER" -g "$(id -gn "$DESKTOP_USER")" "$AUTO_START"
cat >"$AUTO_START/ktemata-ups-tray.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ktemata UPS Monitor
Comment=Waveshare UPS Module 3S battery and runtime monitor
Exec=/usr/local/bin/ktemata-ups-tray --i2c-bus $BUS
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
chown "$DESKTOP_USER:$(id -gn "$DESKTOP_USER")" "$AUTO_START/ktemata-ups-tray.desktop"
chmod 0644 "$AUTO_START/ktemata-ups-tray.desktop"

printf 'Installed. Test: ktemata-ups-tray --i2c-bus %s --once\n' "$BUS"
printf 'Tray starts at the next desktop login for %s.\n' "$DESKTOP_USER"
printf 'Start now from that desktop session: ktemata-ups-tray --i2c-bus %s &\n' "$BUS"

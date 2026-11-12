#!/usr/bin/env python3
"""Push time, storage and Wi-Fi state to the Ktemata status OLED (FireBeetle 2 ESP32-UE).

The FireBeetle drives the 1.3" I2C OLED and is the I2C master for the UPS gauge,
DS3231 and BME688. It has no clock of its own unless the DS3231 is fitted, so the
Pi sends UTC plus the free space of the library filesystem over the USB serial
link, and reads the board's telemetry back. The board has no radio either, so the
Pi also reports its own Wi-Fi state (off / client / AP) for the WIFI screen.
Protocol: newline-delimited JSON at 115200 8N1, see firmware/README.md.

  python3 work/scripts/status-oled.py                  # autodetect, sync every hour
  python3 work/scripts/status-oled.py --port /dev/ttyUSB0
  python3 work/scripts/status-oled.py --storage /srv/kiwix/zim --verbose
  python3 work/scripts/status-oled.py --once            # one sync, echo 2 s, exit

Nothing outside the standard library: the port is driven with termios/select, so
this runs on a stock Raspberry Pi OS without pyserial. It waits for the board when
the port is absent and reopens it after an unplug, so systemd can keep it running.

Opening the CH340 port pulses the ESP32 reset line on some boards, so the sender
waits two seconds before its first command, re-sends until the board confirms with
`time synced`, and ignores non-JSON lines (the boot ROM writes free text). It holds
an exclusive lock: stop ktemata-status-oled.service before running it by hand, or the
two readers split the board's replies between them.
"""
import argparse
import fcntl
import glob
import json
import os
import re
import select
import signal
import subprocess
import sys
import termios
import time

BAUD = termios.B115200
CH340_IDS = ("1a86", "ch340", "ch341", "wch")
TIME_PERIOD = 3600        # UTC is re-sent hourly; the ESP32 millis() clock drifts
STORAGE_PERIOD = 60
WIFI_PERIOD = 15          # cheap read-only queries; the state only changes on user action
WIFI_IFACE = "wlan0"
BOOT_BANNER = "Ktemata r2 status OLED"
TIME_ACK = "time synced"
RESET_LOG = "reset"
MIN_EPOCH = 1_700_000_000  # the firmware ignores anything earlier (Nov 2023)
# Opening the CH340 can pulse the ESP32 reset; writing during the boot loses or truncates the
# first line, so wait before the first command. A command that is not confirmed within
# RETRY_PERIOD is sent again (MAX_TIME_RETRIES times, then hourly).
INITIAL_DELAY = 2.0
RETRY_PERIOD = 5.0
MAX_TIME_RETRIES = 6


def log(msg):
    print(msg, flush=True)


def printable(text):
    """Replace control bytes (boot ROM output) so journald keeps the line as text."""
    return "".join(ch if ch.isprintable() else " " for ch in text).rstrip()


class Link:
    """A serial line to the board, with line-oriented JSON in both directions."""

    def __init__(self, path):
        self.path = path
        self.fd = os.open(path, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        try:
            # One reader only: two processes on a tty split the incoming bytes between
            # them, so the board's acknowledgements would reach only one of them.
            fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            os.close(self.fd)
            raise OSError(f"another sender is using {path}") from None
        try:
            attrs = termios.tcgetattr(self.fd)
            attrs[0] = 0                                        # iflag: raw
            attrs[1] = 0                                        # oflag: raw
            attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
            if hasattr(termios, "HUPCL"):
                attrs[2] &= ~termios.HUPCL                      # no reset on close
            attrs[3] = 0                                        # lflag: raw
            attrs[4] = attrs[5] = BAUD
            attrs[6][termios.VMIN] = 0
            attrs[6][termios.VTIME] = 0
            termios.tcsetattr(self.fd, termios.TCSANOW, attrs)
        except Exception:
            os.close(self.fd)
            raise
        self.buffer = b""

    def close(self):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None

    def send(self, obj):
        data = (json.dumps(obj, separators=(",", ":")) + "\n").encode()
        while data:
            try:
                data = data[os.write(self.fd, data):]
            except BlockingIOError:
                select.select([], [self.fd], [], 1.0)

    def lines(self):
        """Read what is available and yield complete lines (without the newline)."""
        out = []
        while True:
            ready, _, _ = select.select([self.fd], [], [], 0)
            if not ready:
                break
            try:
                chunk = os.read(self.fd, 4096)
            except BlockingIOError:
                break
            if not chunk:                 # hang-up: the cable or the board went away
                raise OSError("serial hang-up")
            self.buffer += chunk
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                out.append(line.rstrip(b"\r").decode("utf-8", "replace"))
            if len(self.buffer) > 4096:      # a noisy line without a newline: drop it
                self.buffer = b""
        return out


def find_port():
    """Prefer the FireBeetle's CH340 on its stable /dev/serial/by-id name."""
    candidates = []
    try:
        for name in sorted(os.listdir("/dev/serial/by-id")):
            path = os.path.join("/dev/serial/by-id", name)
            low = name.lower()
            rank = 0 if any(k in low for k in CH340_IDS) else 1
            candidates.append((rank, path))
    except OSError:
        pass
    for path in sorted(glob.glob("/dev/ttyUSB*")) + sorted(glob.glob("/dev/ttyACM*")):
        candidates.append((2, path))
    if not candidates:
        return None
    return sorted(candidates)[0][1]


def storage_stats(path, warn):
    """Free/used of the filesystem holding the library, in df's terms."""
    if not os.path.isdir(path):
        warn(f"storage path {path} is missing; not sending storage data")
        return None
    st = os.statvfs(path)
    frsize = st.f_frsize or st.f_bsize
    free = st.f_bavail * frsize
    used = (st.f_blocks - st.f_bfree) * frsize
    total = used + free
    pct = (100.0 * used / total) if total else 0.0
    return round(pct, 1), round(free / 1e9, 1)


def sync_time(link, warn):
    epoch = int(time.time())
    if epoch < MIN_EPOCH:
        warn(f"clock reads {epoch} (before Nov 2023); the Pi has no time yet, not sending it")
        return False
    link.send({"cmd": "time", "epoch": epoch})
    return True


def sync_storage(link, path, warn):
    stats = storage_stats(path, warn)
    if stats is None:
        return False
    used_pct, free_gb = stats
    link.send({"cmd": "storage", "used_pct": used_pct, "free_gb": free_gb})
    return True


def run_quiet(cmd, timeout=3.0):
    """Ask a status tool; empty output means the tool or the device is not there."""
    try:
        return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              text=True, timeout=timeout).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def wifi_state():
    """'off', 'client' or 'ap' for the Pi's own radio. Read-only, no root needed.

    NetworkManager is the normal case: `post-install.sh --hotspot` writes an AP profile
    and Raspberry Pi OS Bookworm ships NM. The hostapd + dnsmasq fallback and a bare
    `iw` setup are recognised too. Wi-Fi is off unless someone enabled it, so anything
    that is not connected and not serving an AP reports 'off'.
    """
    # GENERAL.STATE 100 = connected on that interface.
    state = run_quiet(["nmcli", "-t", "-f", "GENERAL.STATE", "device", "show", WIFI_IFACE])
    if "GENERAL.STATE:100" in state:
        connection = run_quiet(
            ["nmcli", "-g", "GENERAL.CONNECTION", "device", "show", WIFI_IFACE]).strip()
        mode = run_quiet(
            ["nmcli", "-g", "802-11-wireless.mode", "connection", "show", connection]).strip()
        return "ap" if mode == "ap" else "client"
    # No NetworkManager profile: the hotspot may be a standalone hostapd service.
    if run_quiet(["systemctl", "is-active", "hostapd"]).strip() == "active":
        return "ap"
    # Bare setup: ask the driver.
    if "Connected to" in run_quiet(["iw", "dev", WIFI_IFACE, "link"]):
        return "client"
    # Last resort: a wireless interface that is administratively up is in station mode.
    # (Without nmcli/iw an AP cannot be distinguished, but Wi-Fi is off by default here.)
    try:
        with open(f"/sys/class/net/{WIFI_IFACE}/operstate") as operstate:
            if operstate.read().strip() == "up":
                return "client"
    except OSError:
        pass
    return "off"


def wifi_ip():
    """Dotted IPv4 of wlan0, from `ip` and then NetworkManager; empty if unknown."""
    out = run_quiet(["ip", "-4", "-o", "addr", "show", "dev", WIFI_IFACE])
    found = re.search(r"\binet\s+([0-9.]+)/", out)
    if found:
        return found.group(1)
    out = run_quiet(["nmcli", "-g", "IP4.ADDRESS", "device", "show", WIFI_IFACE]).strip()
    if out:
        return out.splitlines()[0].split("/")[0]
    return ""


def sync_wifi(link):
    state = wifi_state()
    ip = wifi_ip() if state != "off" else ""
    command = {"cmd": "wifi", "state": state}
    if ip:
        command["ip"] = ip
    link.send(command)
    return state, ip


def run_once(port, path):
    link = Link(port)
    log(f"opened {port}")
    try:
        time.sleep(INITIAL_DELAY)     # the open itself may have reset the board
        sync_time(link, log)
        sync_storage(link, path, log)
        wifi, ip = sync_wifi(link)
        log(f"wifi {wifi}{' ' + ip if ip else ''}")
        deadline = time.monotonic() + 2.0
        while time.monotonic() < deadline:
            for line in link.lines():
                print(line, flush=True)
            time.sleep(0.1)
    except OSError as exc:
        log(f"{port}: {exc}")
    finally:
        link.close()


def run_forever(port, path, args):
    explicit = args.port is not None
    warned = None

    def warn(msg):
        nonlocal warned
        if msg != warned:
            log(msg)
            warned = msg

    backoff = 0
    while True:
        path_now = port if explicit else (find_port() or port)
        if path_now is None:
            warn("no serial port; waiting for the FireBeetle")
            time.sleep(2)
            continue
        try:
            link = Link(path_now)
        except OSError as exc:
            warn(f"cannot open {path_now}: {exc}; retrying")
            time.sleep(min(2 ** backoff, 30))
            backoff += 1
            continue
        backoff = 0
        log(f"opened {path_now}")
        next_time = time.monotonic() + INITIAL_DELAY   # let a reset finish before writing
        next_storage = next_time
        next_wifi = next_time
        time_confirmed = False
        time_tries = 0
        last_alerts = None
        wifi_seen = None
        try:
            while True:
                try:
                    restart = retry = False
                    for line in link.lines():
                        if not line:
                            continue
                        if args.verbose:
                            log(printable(line))
                        try:
                            msg = json.loads(line)
                        except json.JSONDecodeError:
                            continue        # boot ROM noise, or another writer on the port
                        kind = msg.get("type")
                        name = msg.get("msg")
                        if kind == "log" and name == RESET_LOG:
                            # Why the board came up: a reboot loop is either the port resetting it
                            # (external pin), a sagging 5 V from the HAT (brownout) or a crash
                            # (panic / watchdog). Worth a journald line even without -v.
                            log(f"board reset: {msg.get('name', 'unknown')}"
                                f" (reason {msg.get('reason')})")
                        if kind == "log" and name == BOOT_BANNER:
                            restart = True     # the board rebooted: clock and storage are cold
                        elif kind == "log" and name == TIME_ACK:
                            if not time_confirmed:
                                log("clock synced")
                            time_confirmed = True
                            time_tries = 0
                            next_time = time.monotonic() + args.time_period
                        elif kind == "error":
                            detail = f"{name} {msg.get('detail', '')}".rstrip()
                            log(f"board rejected a command: {detail}")
                            retry = True       # truncated by the reset, or the ESP missed it
                        alerts = msg.get("alerts")
                        if kind == "telemetry" and alerts != last_alerts:
                            last_alerts = alerts
                            if isinstance(alerts, list) and alerts:
                                # The firmware dropped the environment alert: 2 entries now,
                                # 3 on older builds. Name them without indexing past the end.
                                names = ("battery", "storage") if len(alerts) == 2 else (
                                    "battery", "environment", "storage")
                                if len(names) != len(alerts):
                                    names = tuple(f"alert{i}" for i in range(len(alerts)))
                                log("alerts " + " ".join(
                                    f"{name}={value}" for name, value in zip(names, alerts)))

                    now = time.monotonic()
                    if restart:
                        log("board boot; sending time, storage and wifi")
                        time_confirmed = False
                        time_tries = 0
                        next_time = next_storage = next_wifi = 0.0
                    if retry and time_tries < MAX_TIME_RETRIES:
                        next_time = min(next_time, now + INITIAL_DELAY)
                        next_storage = min(next_storage, now + INITIAL_DELAY)
                        next_wifi = min(next_wifi, now + INITIAL_DELAY)
                    if now >= next_time:
                        if sync_time(link, warn):
                            time_tries += 1
                            if time_confirmed:
                                next_time = now + args.time_period
                            elif time_tries >= MAX_TIME_RETRIES:
                                warn("the board never confirmed the clock; retrying hourly")
                                next_time = now + args.time_period
                            else:
                                next_time = now + RETRY_PERIOD
                        else:
                            next_time = now + 10.0
                    if now >= next_storage:
                        sync_storage(link, path, warn)
                        next_storage = now + args.storage_period
                    if now >= next_wifi:
                        state, ip = sync_wifi(link)
                        seen = (state, ip)
                        if seen != wifi_seen:
                            log(f"wifi {state}{' ' + ip if ip else ''}")
                            wifi_seen = seen
                        next_wifi = now + WIFI_PERIOD
                except OSError as exc:
                    warn(f"{path_now}: {exc}; reopening")
                    break
                time.sleep(0.2)
        finally:
            link.close()
        time.sleep(1.0)


def main():
    parser = argparse.ArgumentParser(
        description="Send UTC, free space and Wi-Fi state to the Ktemata status OLED "
                    "over USB serial.")
    parser.add_argument("--port", help="serial device; default: autodetect the CH340")
    parser.add_argument("--storage", default=os.environ.get("ZIM_DIR", "/srv/kiwix/zim"),
                        help="filesystem to report (default: /srv/kiwix/zim)")
    parser.add_argument("--time-period", type=float, default=TIME_PERIOD,
                        help=f"seconds between UTC syncs (default: {TIME_PERIOD})")
    parser.add_argument("--storage-period", type=float, default=STORAGE_PERIOD,
                        help=f"seconds between storage updates (default: {STORAGE_PERIOD})")
    parser.add_argument("--once", action="store_true",
                        help="sync once, echo the board's lines for 2 s, exit")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="log every line from the board")
    args = parser.parse_args()

    if args.port is None:
        args.port = os.environ.get("KTEMATA_OLED_PORT") or None
    if args.once:
        port = args.port or find_port()
        if port is None:
            sys.exit("no serial port found")
        try:
            run_once(port, args.storage)
        except OSError as exc:
            sys.exit(f"cannot open {port}: {exc}")
        return
    # systemd stops the unit with SIGTERM; unwind so the port is closed without a hang-up
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        run_forever(args.port, args.storage, args)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()

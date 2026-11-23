#!/usr/bin/env python3
"""Raspberry Pi tray monitor for the Waveshare UPS Module 3S.

The INA219 reports negative current while the pack is discharging. Charge and
runtime are estimates: this board has a voltage/current gauge, not a coulomb
counter. The app alerts only; it never shuts down the Pi.
"""
from __future__ import annotations

import argparse
import math
import sys
import threading
import time
from collections import deque
from dataclasses import dataclass
from pathlib import Path

APP_ID = "ktemata-ups-3s"
ICON_DIR = Path(__file__).resolve().parent / "icons"
CURRENT_DEADBAND_MA = 20.0
MIN_DISCHARGE_W = 0.1
POWER_SAMPLES = 12
CRITICAL_REMINDER_S = 300.0


@dataclass(frozen=True)
class Reading:
    voltage_v: float
    current_ma: float
    power_w: float


@dataclass(frozen=True)
class Status:
    reading: Reading
    percent: float
    remaining_wh: float
    charging: bool
    discharging: bool
    average_discharge_w: float | None
    runtime_minutes: float | None
    severity: str

    @property
    def state(self) -> str:
        if self.charging:
            return "Charging"
        if self.discharging:
            return "On battery"
        return "Battery idle"


class BatteryModel:
    """Convert INA219 readings to conservative charge and runtime estimates."""

    def __init__(
        self,
        *,
        empty_v: float = 9.0,
        full_v: float = 12.6,
        capacity_wh: float = 33.3,
        usable_fraction: float = 0.85,
        warning_percent: float = 30.0,
        critical_percent: float = 15.0,
        warning_minutes: float = 45.0,
        critical_minutes: float = 15.0,
    ) -> None:
        if not full_v > empty_v > 0:
            raise ValueError("require full V > empty V > 0")
        if capacity_wh <= 0:
            raise ValueError("capacity must be positive")
        if not 0 < usable_fraction <= 1:
            raise ValueError("usable fraction must be in (0, 1]")
        if not 0 <= critical_percent <= warning_percent <= 100:
            raise ValueError("require 0 <= critical % <= warning % <= 100")
        if not 0 <= critical_minutes <= warning_minutes:
            raise ValueError("require 0 <= critical minutes <= warning minutes")
        self.empty_v = empty_v
        self.full_v = full_v
        self.usable_wh = capacity_wh * usable_fraction
        self.warning_percent = warning_percent
        self.critical_percent = critical_percent
        self.warning_minutes = warning_minutes
        self.critical_minutes = critical_minutes
        self._discharge_w = deque(maxlen=POWER_SAMPLES)

    def update(self, reading: Reading) -> Status:
        values = (reading.voltage_v, reading.current_ma, reading.power_w)
        if not all(math.isfinite(value) for value in values) or reading.voltage_v <= 0:
            raise ValueError("invalid INA219 reading")

        percent = 100.0 * (reading.voltage_v - self.empty_v) / (self.full_v - self.empty_v)
        percent = min(100.0, max(0.0, percent))
        remaining_wh = self.usable_wh * percent / 100.0
        charging = reading.current_ma > CURRENT_DEADBAND_MA
        discharging = reading.current_ma < -CURRENT_DEADBAND_MA
        average_w = None
        runtime_minutes = None

        if discharging:
            instantaneous_w = abs(reading.power_w)
            if instantaneous_w < MIN_DISCHARGE_W:
                instantaneous_w = reading.voltage_v * -reading.current_ma / 1000.0
            self._discharge_w.append(instantaneous_w)
            average_w = sum(self._discharge_w) / len(self._discharge_w)
            if average_w >= MIN_DISCHARGE_W:
                runtime_minutes = remaining_wh / average_w * 60.0
        else:
            # A charge/idle gap makes older discharge samples unrepresentative.
            self._discharge_w.clear()

        severity = "normal"
        if not charging:
            # Exact voltage thresholds must not move because 3.6 is not binary-exact.
            epsilon = 1e-9
            if percent <= self.critical_percent + epsilon or (
                runtime_minutes is not None and runtime_minutes <= self.critical_minutes
            ):
                severity = "critical"
            elif percent <= self.warning_percent + epsilon or (
                runtime_minutes is not None and runtime_minutes <= self.warning_minutes
            ):
                severity = "warning"

        return Status(
            reading=reading,
            percent=percent,
            remaining_wh=remaining_wh,
            charging=charging,
            discharging=discharging,
            average_discharge_w=average_w,
            runtime_minutes=runtime_minutes,
            severity=severity,
        )


def format_duration(minutes: float, *, long: bool = False) -> str:
    if minutes < 1:
        return "<1 minute" if long else "<1m"
    rounded = round(minutes)
    hours, mins = divmod(rounded, 60)
    if long:
        if not hours:
            return f"{mins} min"
        return f"{hours} h {mins:02d} min"
    return f"{hours}h{mins:02d}m" if hours else f"{mins}m"


def tray_label(status: Status) -> str:
    label = f"{status.percent:.0f}%"
    if status.charging:
        return label + " · charging"
    if status.runtime_minutes is not None:
        return label + " · " + format_duration(status.runtime_minutes)
    return label


def icon_name(status: Status) -> str:
    if status.charging:
        return "ups-charging"
    if status.severity in ("warning", "critical"):
        return "ups-" + status.severity
    return "ups-normal"


class SensorWorker(threading.Thread):
    """Own the SMBus object outside GTK's main thread and keep retrying I2C errors."""

    def __init__(self, args: argparse.Namespace, post_reading, post_error) -> None:
        super().__init__(name="ups-i2c", daemon=True)
        self.args = args
        self.post_reading = post_reading
        self.post_error = post_error
        self.stopping = threading.Event()

    def stop(self) -> None:
        self.stopping.set()

    @staticmethod
    def close(sensor) -> None:
        if sensor is not None and hasattr(sensor, "bus"):
            try:
                sensor.bus.close()
            except (AttributeError, OSError) as exc:
                print(f"I2C close failed: {exc}", file=sys.stderr, flush=True)

    def run(self) -> None:
        sensor = None
        try:
            while not self.stopping.is_set():
                try:
                    if sensor is None:
                        from INA219 import INA219

                        sensor = INA219(i2c_bus=self.args.i2c_bus, addr=self.args.address)
                    reading = Reading(
                        voltage_v=sensor.getBusVoltage_V(),
                        current_ma=sensor.getCurrent_mA(),
                        power_w=sensor.getPower_W(),
                    )
                    self.post_reading(reading)
                except (ImportError, OSError, IndexError, ValueError) as exc:
                    self.post_error(f"{type(exc).__name__}: {exc}")
                    self.close(sensor)
                    sensor = None
                self.stopping.wait(self.args.interval)
        finally:
            self.close(sensor)


class AlertState:
    """Notify on escalation, with a five-minute reminder while critical."""

    def __init__(self) -> None:
        self.level = "normal"
        self.last_notification = 0.0

    def due(self, severity: str, now: float) -> bool:
        rank = {"normal": 0, "warning": 1, "critical": 2}
        escalated = rank[severity] > rank[self.level]
        reminder = (
            severity == "critical"
            and self.level == "critical"
            and now - self.last_notification >= CRITICAL_REMINDER_S
        )
        self.level = severity
        if escalated or reminder:
            self.last_notification = now
            return True
        return False


def read_once(args: argparse.Namespace) -> Reading:
    from INA219 import INA219

    sensor = INA219(i2c_bus=args.i2c_bus, addr=args.address)
    try:
        return Reading(
            voltage_v=sensor.getBusVoltage_V(),
            current_ma=sensor.getCurrent_mA(),
            power_w=sensor.getPower_W(),
        )
    finally:
        SensorWorker.close(sensor)


def print_once(status: Status) -> None:
    print(f"State: {status.state}")
    print(f"Charge estimate: {status.percent:.1f}%")
    print(f"Usable energy remaining: {status.remaining_wh:.2f} Wh (estimate)")
    if status.runtime_minutes is not None:
        print(
            f"Runtime remaining: {format_duration(status.runtime_minutes, long=True)} "
            f"at {status.average_discharge_w:.2f} W"
        )
    else:
        print("Runtime remaining: unavailable unless discharging")
    print(f"Pack voltage: {status.reading.voltage_v:.3f} V")
    print(f"Battery current: {status.reading.current_ma:.1f} mA")
    print(f"Battery power: {status.reading.power_w:.3f} W")
    print(f"Alert level: {status.severity}")


def model_from_args(args: argparse.Namespace) -> BatteryModel:
    return BatteryModel(
        empty_v=args.empty_v,
        full_v=args.full_v,
        capacity_wh=args.capacity_wh,
        usable_fraction=args.usable_fraction,
        warning_percent=args.warning_percent,
        critical_percent=args.critical_percent,
        warning_minutes=args.warning_minutes,
        critical_minutes=args.critical_minutes,
    )


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--i2c-bus", type=int, default=1, help="Linux I2C bus number (default: 1)")
    parser.add_argument("--address", type=lambda value: int(value, 0), default=0x41,
                        help="INA219 address, decimal or hex (default: 0x41)")
    parser.add_argument("--interval", type=float, default=5.0, help="poll seconds (default: 5)")
    parser.add_argument("--empty-v", type=float, default=9.0, help="empty pack voltage")
    parser.add_argument("--full-v", type=float, default=12.6, help="full pack voltage")
    parser.add_argument("--capacity-wh", type=float, default=33.3,
                        help="rated 3S pack energy; 33.3 for 3.0 Ah cells")
    parser.add_argument("--usable-fraction", type=float, default=0.85,
                        help="usable pack energy fraction (default: 0.85)")
    parser.add_argument("--warning-percent", type=float, default=30.0)
    parser.add_argument("--critical-percent", type=float, default=15.0)
    parser.add_argument("--warning-minutes", type=float, default=45.0)
    parser.add_argument("--critical-minutes", type=float, default=15.0)
    parser.add_argument("--once", action="store_true", help="print one reading; do not start GTK")
    args = parser.parse_args(argv)
    try:
        if not 0 <= args.address <= 0x7F:
            raise ValueError("I2C address must be in 0..0x7f")
        if args.i2c_bus < 0:
            raise ValueError("I2C bus must not be negative")
        if args.interval <= 0:
            raise ValueError("interval must be positive")
        model_from_args(args)
    except ValueError as exc:
        parser.error(str(exc))
    return args


def run_tray(args: argparse.Namespace) -> int:
    try:
        import gi

        gi.require_version("Gtk", "3.0")
        gi.require_version("AyatanaAppIndicator3", "0.1")
        gi.require_version("Notify", "0.7")
        from gi.repository import AyatanaAppIndicator3 as AppIndicator
        from gi.repository import GLib, Gtk, Notify
    except (ImportError, ValueError) as exc:
        print(f"Tray dependencies unavailable: {exc}", file=sys.stderr)
        print("Run the install.sh beside this file to install GTK/AppIndicator dependencies.",
              file=sys.stderr)
        return 1

    class TrayApp:
        def __init__(self) -> None:
            self.model = model_from_args(args)
            self.alerts = AlertState()
            self.sensor_failed = False
            self.indicator = AppIndicator.Indicator.new_with_path(
                APP_ID, "ups-unknown", AppIndicator.IndicatorCategory.HARDWARE, str(ICON_DIR)
            )
            self.indicator.set_title("Ktemata UPS 3S")
            self.indicator.set_attention_icon_full("ups-critical", "Critical UPS battery")
            self.menu = Gtk.Menu()
            self.items = {}
            for key in ("state", "charge", "energy", "runtime", "pack", "power", "error"):
                item = Gtk.MenuItem(label="Starting UPS monitor…" if key == "state" else "")
                item.set_sensitive(False)
                item.show()
                self.menu.append(item)
                self.items[key] = item
            separator = Gtk.SeparatorMenuItem()
            separator.show()
            self.menu.append(separator)
            quit_item = Gtk.MenuItem(label="Quit UPS monitor")
            quit_item.connect("activate", self.quit)
            quit_item.show()
            self.menu.append(quit_item)
            self.indicator.set_menu(self.menu)
            self.indicator.set_label("UPS …", "100% · charging")
            self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)
            Notify.init(APP_ID)
            self.worker = SensorWorker(
                args,
                lambda reading: GLib.idle_add(self.apply_reading, reading),
                lambda error: GLib.idle_add(self.apply_error, error),
            )
            self.worker.start()
            GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, 2, self.quit)   # SIGINT
            GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, 15, self.quit)  # SIGTERM

        def notify(self, summary: str, body: str, critical: bool = False) -> None:
            try:
                notification = Notify.Notification.new(
                    summary, body, "battery-low" if critical else "battery-caution"
                )
                notification.set_urgency(
                    Notify.Urgency.CRITICAL if critical else Notify.Urgency.NORMAL
                )
                notification.show()
            except (GLib.Error, AttributeError, TypeError) as exc:
                print(f"Desktop notification failed: {exc}", file=sys.stderr, flush=True)

        def apply_reading(self, reading: Reading) -> bool:
            try:
                status = self.model.update(reading)
            except ValueError as exc:
                return self.apply_error(str(exc))
            self.sensor_failed = False
            reading = status.reading
            self.items["state"].set_label(f"{status.state} — {status.severity.upper()}")
            self.items["charge"].set_label(f"Charge: {status.percent:.1f}% (voltage estimate)")
            self.items["energy"].set_label(
                f"Usable energy remaining: {status.remaining_wh:.2f} Wh (estimate)"
            )
            if status.runtime_minutes is None:
                runtime = "Runtime remaining: unavailable unless discharging"
            else:
                runtime = (
                    f"Runtime remaining: {format_duration(status.runtime_minutes, long=True)} "
                    f"at {status.average_discharge_w:.2f} W average"
                )
            self.items["runtime"].set_label(runtime)
            self.items["pack"].set_label(
                f"Pack: {reading.voltage_v:.3f} V · {reading.current_ma:.1f} mA"
            )
            self.items["power"].set_label(f"Instantaneous battery power: {reading.power_w:.3f} W")
            self.items["error"].set_label("Alerts only; automatic shutdown is not configured")
            name = icon_name(status)
            self.indicator.set_icon_full(name, f"UPS battery {status.severity}")
            self.indicator.set_label(tray_label(status), "100% · charging")
            self.indicator.set_status(
                AppIndicator.IndicatorStatus.ATTENTION
                if status.severity == "critical"
                else AppIndicator.IndicatorStatus.ACTIVE
            )
            if self.alerts.due(status.severity, time.monotonic()):
                body = f"{status.percent:.0f}% charge; {status.remaining_wh:.1f} Wh usable remaining"
                if status.runtime_minutes is not None:
                    body += f"; about {format_duration(status.runtime_minutes, long=True)} left"
                body += ". Connect the 12.6 V charger."
                self.notify(f"UPS battery {status.severity}", body, status.severity == "critical")
            return False

        def apply_error(self, error: str) -> bool:
            first_error = not self.sensor_failed
            self.sensor_failed = True
            self.alerts.level = "normal"
            self.items["state"].set_label("UPS sensor unavailable — CRITICAL")
            for key in ("charge", "energy", "runtime", "pack", "power"):
                self.items[key].set_label("No recent reading")
            self.items["error"].set_label(
                f"I2C bus {args.i2c_bus}, address 0x{args.address:02x}: {error}"
            )
            self.indicator.set_icon_full("ups-unknown", "UPS sensor unavailable")
            self.indicator.set_label("UPS !", "UPS !")
            # ACTIVE selects the crossed-sensor icon; ATTENTION would select the low-battery icon.
            self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)
            if first_error:
                self.notify("UPS monitor unavailable", error, critical=True)
            return False

        def quit(self, *_args) -> bool:
            self.worker.stop()
            Gtk.main_quit()
            return False

    TrayApp()
    Gtk.main()
    return 0


def main(argv=None) -> int:
    args = parse_args(argv)
    if args.once:
        try:
            status = model_from_args(args).update(read_once(args))
        except (ImportError, OSError, IndexError, ValueError) as exc:
            print(f"UPS read failed on bus {args.i2c_bus}, address 0x{args.address:02x}: {exc}",
                  file=sys.stderr)
            return 1
        print_once(status)
        return 0
    return run_tray(args)


if __name__ == "__main__":
    raise SystemExit(main())

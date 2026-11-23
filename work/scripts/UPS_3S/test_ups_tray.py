import math
import unittest

from ups_tray import (
    AlertState,
    BatteryModel,
    Reading,
    format_duration,
    icon_name,
    parse_args,
    tray_label,
)


class BatteryModelTests(unittest.TestCase):
    def test_voltage_estimate_matches_waveshare_endpoints_and_midpoint(self):
        model = BatteryModel()
        self.assertEqual(model.update(Reading(9.0, 0, 0)).percent, 0)
        self.assertAlmostEqual(model.update(Reading(10.8, 0, 0)).percent, 50)
        self.assertEqual(model.update(Reading(12.6, 0, 0)).percent, 100)
        self.assertEqual(model.update(Reading(13.0, 100, 1)).percent, 100)
        self.assertEqual(model.update(Reading(8.5, -100, -1)).percent, 0)

    def test_remaining_energy_and_runtime_use_usable_pack_capacity(self):
        status = BatteryModel().update(Reading(10.8, -1000, -10.0))
        self.assertAlmostEqual(status.remaining_wh, 33.3 * 0.85 * 0.5)
        self.assertAlmostEqual(status.average_discharge_w, 10.0)
        self.assertAlmostEqual(status.runtime_minutes, status.remaining_wh / 10.0 * 60)
        self.assertEqual(status.state, "On battery")

    def test_discharge_power_is_unsigned_and_smoothed(self):
        model = BatteryModel()
        first = model.update(Reading(10.8, -1000, 10.0))
        second = model.update(Reading(10.8, -2000, -20.0))
        self.assertEqual(first.average_discharge_w, 10.0)
        self.assertEqual(second.average_discharge_w, 15.0)
        self.assertAlmostEqual(second.runtime_minutes, second.remaining_wh / 15.0 * 60)

    def test_zero_power_register_falls_back_to_voltage_times_current(self):
        status = BatteryModel().update(Reading(10.0, -500, 0.0))
        self.assertAlmostEqual(status.average_discharge_w, 5.0)
        self.assertIsNotNone(status.runtime_minutes)

    def test_charging_clears_runtime_and_suppresses_low_battery_alerts(self):
        model = BatteryModel()
        model.update(Reading(9.4, -1000, -9.4))
        status = model.update(Reading(9.4, 500, 4.7))
        self.assertTrue(status.charging)
        self.assertIsNone(status.runtime_minutes)
        self.assertEqual(status.severity, "normal")
        self.assertEqual(icon_name(status), "ups-charging")
        resumed = model.update(Reading(9.4, -1000, -9.4))
        self.assertAlmostEqual(resumed.average_discharge_w, 9.4)

    def test_current_deadband_does_not_claim_a_runtime(self):
        status = BatteryModel().update(Reading(10.8, 0, 0))
        self.assertEqual(status.state, "Battery idle")
        self.assertIsNone(status.runtime_minutes)

    def test_percentage_warning_and_critical_thresholds(self):
        model = BatteryModel()
        warning = model.update(Reading(10.08, 0, 0))
        critical = model.update(Reading(9.54, 0, 0))
        self.assertEqual(warning.severity, "warning")
        self.assertEqual(icon_name(warning), "ups-warning")
        self.assertEqual(critical.severity, "critical")
        self.assertEqual(icon_name(critical), "ups-critical")

    def test_short_runtime_can_warn_before_percentage_threshold(self):
        model = BatteryModel(capacity_wh=10, usable_fraction=1)
        warning = model.update(Reading(12.6, -12000, -12.0))
        self.assertEqual(warning.percent, 100)
        self.assertAlmostEqual(warning.runtime_minutes, 50)
        self.assertEqual(warning.severity, "normal")
        critical = model.update(Reading(12.6, -12000, -30.0))
        self.assertAlmostEqual(critical.runtime_minutes, 10 / 21 * 60)
        self.assertEqual(critical.severity, "warning")

    def test_critical_runtime_threshold_takes_priority(self):
        model = BatteryModel(capacity_wh=10, usable_fraction=1)
        status = model.update(Reading(12.6, -60000, -60.0))
        self.assertAlmostEqual(status.runtime_minutes, 10)
        self.assertEqual(status.severity, "critical")

    def test_invalid_sensor_values_are_rejected(self):
        model = BatteryModel()
        for reading in (Reading(0, -1, -1), Reading(math.nan, -1, -1),
                        Reading(10.8, math.inf, -1), Reading(10.8, -1, math.nan)):
            with self.subTest(reading=reading), self.assertRaises(ValueError):
                model.update(reading)

    def test_tray_text_and_duration_rounding(self):
        discharging = BatteryModel().update(Reading(10.8, -1000, -10.0))
        charging = BatteryModel().update(Reading(10.8, 1000, 10.0))
        self.assertEqual(tray_label(discharging), "50% · 1h25m")
        self.assertEqual(tray_label(charging), "50% · charging")
        self.assertEqual(format_duration(0.4), "<1m")
        self.assertEqual(format_duration(59.6), "1h00m")
        self.assertEqual(format_duration(65, long=True), "1 h 05 min")


class AlertStateTests(unittest.TestCase):
    def test_alerts_on_escalation_and_rate_limits_critical_reminders(self):
        alerts = AlertState()
        self.assertFalse(alerts.due("normal", 0))
        self.assertTrue(alerts.due("warning", 5))
        self.assertFalse(alerts.due("warning", 10))
        self.assertTrue(alerts.due("critical", 15))
        self.assertFalse(alerts.due("critical", 100))
        self.assertTrue(alerts.due("critical", 316))
        self.assertFalse(alerts.due("normal", 320))

    def test_recovery_allows_a_later_warning_to_notify(self):
        alerts = AlertState()
        self.assertTrue(alerts.due("warning", 5))
        alerts.due("normal", 10)
        self.assertTrue(alerts.due("warning", 15))


class CommandLineTests(unittest.TestCase):
    def test_alternate_pi5_bus_and_hex_address(self):
        args = parse_args(["--i2c-bus", "2", "--address", "0x41", "--once"])
        self.assertEqual(args.i2c_bus, 2)
        self.assertEqual(args.address, 0x41)
        self.assertTrue(args.once)


if __name__ == "__main__":
    unittest.main()

#pragma once

// ---------------------------------------------------------------------------
// Board: DFRobot FireBeetle 2 ESP32-UE (N16R2), SKU DFR1140
//        module ESP32-WROOM-32UE-N16R2 (ESP32-D0WDR2-V3)
//        16 MB flash, 2 MB QSPI PSRAM, external antenna, CH340 USB-serial
//
// Pin names come from the Arduino variant "dfrobot_firebeetle2_esp32e".
// I2C is on GPIO21/22. The GDI display connector is SPI and is not used by
// this 1.3" 4-pin I2C OLED.
// ---------------------------------------------------------------------------

#define PIN_I2C_SDA 21
#define PIN_I2C_SCL 22

// Sealed push button on the case, wired to GND. GPIO4 is D12 / A6 / T0 on the
// FireBeetle 2 and is free. The onboard user button is GPIO27; do not reuse
// it for the external button unless you want both to work in parallel.
#define PIN_BUTTON 4

// I2C addresses on the internal bus.
#define I2C_ADDR_OLED 0x3C
// 0 = connector at the bottom, 2 = rotated 180 degrees. Change if the module
// is mounted the other way up in the case.
#ifndef OLED_ROTATION
#define OLED_ROTATION 0
#endif
#define I2C_ADDR_DS3231 0x68
// r4: Waveshare UPS HAT (B) - INA219 gauge. 0x2D was the old HAT (E) address.
#define I2C_ADDR_UPS 0x42

#define I2C_CLOCK_HZ 100000

// ---------------------------------------------------------------------------
// Clock / timezone
// ---------------------------------------------------------------------------
// POSIX TZ string used by the OLED clock. Default: Europe/Amsterdam with
// European DST rules. The Pi sends UTC; the DS3231 stores UTC; the firmware
// applies this timezone only when rendering the time screen.
#ifndef TIMEZONE
#define TIMEZONE "CET-1CEST,M3.5.0,M10.5.0/3"
#endif

// ---------------------------------------------------------------------------
// UI timing
// ---------------------------------------------------------------------------
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define SCREEN_REFRESH_MS 500
// 0 disables idle blanking (useful while the sealed button is not fitted).
// The build sets 0 in platformio.ini; enable 60000UL once the button works.
#ifndef SCREEN_OFF_MS
#define SCREEN_OFF_MS 60000UL
#endif
#define RETURN_TO_TIME_MS 30000UL
// Cycle the four screens every 25 s while no panel button is fitted. 0 disables the cycle
// and restores the 30 s return-to-time behavior. The current build sets 25000UL; set it to
// 0 once the PBS-33B is wired and use the button.
#ifndef AUTO_CYCLE_MS
#define AUTO_CYCLE_MS 0UL
#endif
#define BUTTON_DEBOUNCE_MS 30
#define BUTTON_LONG_PRESS_MS 800

// ---------------------------------------------------------------------------
// Sampling / reporting
// ---------------------------------------------------------------------------
#define UPS_PERIOD_MS 5000UL
#define TELEMETRY_PERIOD_MS 10000UL
#define SERIAL_LINE_MAX 192

// Treat storage data older than this as stale (Pi off / serial unplugged).
#define STORAGE_STALE_MS (10UL * 60UL * 1000UL)

// ---------------------------------------------------------------------------
// Alert thresholds (see README "Status OLED"). Hysteresis is applied when an
// alert is already active so a value hovering at the limit does not flap.
// ---------------------------------------------------------------------------
constexpr float ALERT_BATT_WARN = 20.0f;   // %
constexpr float ALERT_BATT_CRIT = 10.0f;   // %
constexpr float ALERT_BATT_HYST = 2.0f;    // %

constexpr float ALERT_STORAGE_WARN = 90.0f;  // % used
constexpr float ALERT_STORAGE_CRIT = 97.0f;  // % used
constexpr float ALERT_STORAGE_HYST = 2.0f;   // %

// Rough runtime estimate for the r4 pack: 2x 18650 in 2S (7.2 V nominal, 3200 mAh).
// The r2/r3 HAT (E) was 4x 21700 (4S, 70 Wh). Tune after measuring the actual draw.
constexpr float BATTERY_NOMINAL_WH = 2 * 3.6f * 3.2f;  // 2 x 3200 mAh 18650, 2S

/*
 * Ktemata r2 - status OLED firmware
 *
 * Board: DFRobot FireBeetle 2 ESP32-UE (N16R2)
 *        ESP32-WROOM-32UE-N16R2 (ESP32-D0WDR2-V3, 2 MB PSRAM)
 *
 * Responsibilities (see README.md, "Status OLED"):
 *   - 1.3" 128x64 I2C OLED (SH1106 default, SSD1306 optional), four screens:
 *     time, battery, environment, storage
 *   - one sealed push button: short press = next screen, long press = ack alert
 *   - BME688 and DS3231 on the internal I2C bus
 *   - Waveshare UPS HAT (B) INA219 gauge at 0x42 (2S 18650)
 *   - newline-delimited JSON over USB CDC to/from the Raspberry Pi
 *
 * The firmware deliberately keeps Wi-Fi and Bluetooth off. Do not add radio
 * initialisation here.
 */

#include <Adafruit_GFX.h>
#include <Arduino.h>
#include <ArduinoJson.h>
#include <RTClib.h>
#include <Wire.h>
#include <bme68xLibrary.h>
#include <math.h>
#include <stdlib.h>
#include <time.h>

#include "config.h"
#include "ups_hat_b.h"

// ---------------------------------------------------------------------------
// Hardware
// ---------------------------------------------------------------------------
#if OLED_CONTROLLER_SH1106
#include <Adafruit_SH110X.h>
Adafruit_SH1106G display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);
#define OLED_BLACK SH110X_BLACK
#define OLED_WHITE SH110X_WHITE
#else
#include <Adafruit_SSD1306.h>
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);
#define OLED_BLACK SSD1306_BLACK
#define OLED_WHITE SSD1306_WHITE
#endif

bool oledBegin(uint8_t address) {
#if OLED_CONTROLLER_SH1106
  return display.begin(address, true);
#else
  return display.begin(SSD1306_SWITCHCAPVCC, address);
#endif
}

void oledPower(bool on) {
#if OLED_CONTROLLER_SH1106
  display.oled_command(on ? SH110X_DISPLAYON : SH110X_DISPLAYOFF);
#else
  display.ssd1306_command(on ? SSD1306_DISPLAYON : SSD1306_DISPLAYOFF);
#endif
}

RTC_DS3231 rtc;
Bme68x bme;
UpsHatB ups(Wire, I2C_ADDR_UPS);

bool oledOk = false;
bool rtcOk = false;
bool bmeOk = false;
bool upsOk = false;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum ScreenId : uint8_t {
  SCREEN_TIME = 0,
  SCREEN_BATTERY = 1,
  SCREEN_ENVIRONMENT = 2,
  SCREEN_STORAGE = 3,
};

enum AlertLevel : uint8_t {
  LEVEL_OK = 0,
  LEVEL_WARN = 1,
  LEVEL_CRIT = 2,
};

enum AlertId : uint8_t {
  ALERT_BATTERY = 0,
  ALERT_ENVIRONMENT = 1,
  ALERT_STORAGE = 2,
  ALERT_COUNT = 3,
};

struct AlertState {
  AlertLevel level = LEVEL_OK;
  AlertLevel ackedAt = LEVEL_OK;
};

struct EnvReading {
  bool valid = false;
  float temperatureC = NAN;
  float humidityPct = NAN;
  float pressureHpa = NAN;
  float gasKohm = NAN;
  float gasIndex = NAN;  // placeholder until BSEC2 is integrated
};

struct StorageReading {
  bool valid = false;
  float usedPct = NAN;
  float freeGb = NAN;
  uint32_t updatedMs = 0;
};

struct EnvAlertLevels {
  AlertLevel temperatureHigh = LEVEL_OK;
  AlertLevel temperatureLow = LEVEL_OK;
  AlertLevel humidity = LEVEL_OK;
  AlertLevel pressure = LEVEL_OK;
  AlertLevel gas = LEVEL_OK;
};

UpsStatus upsData;
EnvReading env;
StorageReading storage;
AlertState alerts[ALERT_COUNT];
EnvAlertLevels envAlertLevels;

ScreenId screen = SCREEN_TIME;
bool screenOn = true;
bool alertScreenActive = false;
uint32_t lastInteractionMs = 0;
uint32_t lastRenderMs = 0;

// RTC-less fallback: build time plus elapsed millis, or host-supplied epoch.
DateTime buildTime;
bool clockFromHost = false;
int64_t clockBaseEpoch = 0;  // Unix epoch at millis() == 0

// BME68x forced-mode state machine (avoids blocking on the measurement).
bool bmeMeasuring = false;
uint32_t bmeMeasureStartMs = 0;
uint32_t lastSensorTickMs = 0;
uint32_t bmeMeasureDurationUs = 0;

// Pressure history for the 3 h trend, one sample per minute.
float pressureHistory[PRESSURE_HISTORY_SLOTS];
uint32_t pressureHistoryMs[PRESSURE_HISTORY_SLOTS];
uint8_t pressureHead = 0;
uint8_t pressureCount = 0;
uint32_t lastPressureSampleMs = 0;

uint32_t lastTelemetryMs = 0;

char serialLine[SERIAL_LINE_MAX];
size_t serialLineLen = 0;

// Button state
bool buttonDown = false;
uint32_t buttonDownMs = 0;
bool buttonLongFired = false;

const char* const WEEKDAYS[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
const char* const MONTHS[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};

// ---------------------------------------------------------------------------
// Time helpers
// ---------------------------------------------------------------------------
DateTime currentTime() {
  if (rtcOk) {
    const DateTime t = rtc.now();
    // A blank/lost DS3231 reports 2000-01-01. Prefer the host clock then.
    if (t.year() >= 2024) {
      return t;
    }
  }

  if (clockFromHost) {
    // RTClib's DateTime(uint32_t) takes Unix epoch seconds (it subtracts the
    // 1970->2000 offset internally).
    return DateTime(
        static_cast<uint32_t>(clockBaseEpoch + millis() / 1000ULL));
  }

  return buildTime + TimeSpan(static_cast<int32_t>(millis() / 1000ULL));
}

uint32_t epochNow() { return currentTime().unixtime(); }

void syncTime(uint32_t epoch) {
  clockFromHost = true;
  clockBaseEpoch = static_cast<int64_t>(epoch) - millis() / 1000ULL;

  if (rtcOk) {
    rtc.adjust(DateTime(epoch));
  }
  Serial.printf("{\"type\":\"log\",\"msg\":\"time synced\",\"epoch\":%lu}\n",
                static_cast<unsigned long>(epoch));
}

// ---------------------------------------------------------------------------
// I2C helpers
// ---------------------------------------------------------------------------
bool i2cPresent(uint8_t address) {
  Wire.beginTransmission(address);
  return Wire.endTransmission() == 0;
}

void scanI2C() {
  Serial.println("{\"type\":\"log\",\"msg\":\"I2C scan\"}");
  uint8_t found = 0;
  for (uint8_t address = 1; address < 127; ++address) {
    if (i2cPresent(address)) {
      ++found;
      Serial.printf(
          "{\"type\":\"log\",\"msg\":\"I2C device\",\"addr\":%u,"
          "\"hex\":\"0x%02X\"}\n",
          address, address);
    }
  }
  if (found == 0) {
    Serial.println("{\"type\":\"log\",\"msg\":\"no I2C devices\"}");
  }
}

// ---------------------------------------------------------------------------
// Sensor initialisation and polling
// ---------------------------------------------------------------------------
void initBme688() {
  const uint8_t candidates[] = {I2C_ADDR_BME688_A, I2C_ADDR_BME688_B};
  for (uint8_t address : candidates) {
    if (!i2cPresent(address)) {
      continue;
    }
    bme.begin(address, Wire);
    if (bme.checkStatus() != BME68X_ERROR) {
      bme.setTPH(BME68X_OS_2X, BME68X_OS_16X, BME68X_OS_1X);
      bme.setHeaterProf(300, 100);  // 300 deg C for 100 ms
      bmeOk = true;
      Serial.printf(
          "{\"type\":\"log\",\"msg\":\"BME688 found\",\"addr\":%u}\n", address);
      return;
    }
  }
  bmeOk = false;
  Serial.println("{\"type\":\"log\",\"msg\":\"BME688 not found\"}");
}

float gasResistanceToIndex(float ohms) {
  // Placeholder index, not Bosch BSEC. Clean air on a BME688 is typically
  // several hundred kOhm; reducing/VOC gases pull the resistance down.
  // 1 MOhm -> 125, 100 kOhm -> 250, 10 kOhm -> 375, 1 kOhm -> 500.
  if (!(ohms > 0.0f)) {
    return NAN;
  }
  const float index = 500.0f - 125.0f * log10f(ohms / 1000.0f);
  return constrain(index, 0.0f, 500.0f);
}

void startBmeMeasurement(uint32_t now) {
  if (!bmeOk || bmeMeasuring) {
    return;
  }
  bme.setOpMode(BME68X_FORCED_MODE);
  bmeMeasureDurationUs = bme.getMeasDur();
  if (bmeMeasureDurationUs < 1000) {
    bmeMeasureDurationUs = 200000;
  }
  bmeMeasureStartMs = now;
  bmeMeasuring = true;
}

bool finishBmeMeasurement(uint32_t now) {
  if (!bmeMeasuring) {
    return false;
  }
  const uint32_t elapsedUs = (now - bmeMeasureStartMs) * 1000UL;
  if (elapsedUs + 1000UL < bmeMeasureDurationUs) {
    return false;
  }

  bmeMeasuring = false;
  bme68xData data;
  if (bme.fetchData() > 0) {
    bme.getData(data);
    env.valid = true;
    env.temperatureC = data.temperature;
    env.humidityPct = data.humidity;
    env.pressureHpa = data.pressure / 100.0f;
    env.gasKohm = data.gas_resistance / 1000.0f;
    env.gasIndex = gasResistanceToIndex(data.gas_resistance);

    if (now - lastPressureSampleMs >= PRESSURE_SAMPLE_PERIOD_MS) {
      pressureHistory[pressureHead] = env.pressureHpa;
      pressureHistoryMs[pressureHead] = now;
      pressureHead = (pressureHead + 1) % PRESSURE_HISTORY_SLOTS;
      if (pressureCount < PRESSURE_HISTORY_SLOTS) {
        ++pressureCount;
      }
      lastPressureSampleMs = now;
    }
    return true;
  }
  return false;
}

uint32_t lastUpsProbeMs = 0;

void pollUps() {
  if (!upsOk) {
    // Retry occasionally so a board connected after boot is picked up.
    if (millis() - lastUpsProbeMs < 30000UL) {
      return;
    }
    lastUpsProbeMs = millis();
    if (!ups.begin()) {
      return;
    }
    upsOk = true;
  }

  UpsStatus fresh;
  if (ups.read(fresh)) {
    upsData = fresh;
    upsOk = true;
  } else {
    upsOk = false;
  }
}

// Returns true when a usable ~3 h trend exists. Positive delta = rising.
bool pressureTrend3h(float& deltaHpa) {
  if (pressureCount < 2 || !env.valid) {
    return false;
  }

  const uint32_t now = millis();
  const uint32_t minAgeMs = 150UL * 60UL * 1000UL;  // need at least 2.5 h
  int oldestIndex = -1;

  for (uint8_t i = 0; i < pressureCount; ++i) {
    const int index =
        (pressureHead + PRESSURE_HISTORY_SLOTS - pressureCount + i) %
        PRESSURE_HISTORY_SLOTS;
    const uint32_t age = now - pressureHistoryMs[index];
    if (age >= minAgeMs) {
      oldestIndex = index;
      break;  // chronological scan: first match is the oldest enough
    }
  }

  if (oldestIndex < 0) {
    return false;
  }
  deltaHpa = env.pressureHpa - pressureHistory[oldestIndex];
  return true;
}

// ---------------------------------------------------------------------------
// Alerts
// ---------------------------------------------------------------------------
AlertLevel levelHigh(float value, float warn, float crit, float hysteresis,
                     AlertLevel previous) {
  if (value >= crit) {
    return LEVEL_CRIT;
  }
  if (previous == LEVEL_CRIT && value > crit - hysteresis) {
    return LEVEL_CRIT;
  }
  if (value >= warn) {
    return LEVEL_WARN;
  }
  if (previous != LEVEL_OK && value > warn - hysteresis) {
    return LEVEL_WARN;
  }
  return LEVEL_OK;
}

AlertLevel levelLow(float value, float warn, float crit, float hysteresis,
                    AlertLevel previous) {
  if (value <= crit) {
    return LEVEL_CRIT;
  }
  if (previous == LEVEL_CRIT && value < crit + hysteresis) {
    return LEVEL_CRIT;
  }
  if (value <= warn) {
    return LEVEL_WARN;
  }
  if (previous != LEVEL_OK && value < warn + hysteresis) {
    return LEVEL_WARN;
  }
  return LEVEL_OK;
}

ScreenId screenForAlert(AlertId id) {
  switch (id) {
    case ALERT_BATTERY:
      return SCREEN_BATTERY;
    case ALERT_ENVIRONMENT:
      return SCREEN_ENVIRONMENT;
    case ALERT_STORAGE:
      return SCREEN_STORAGE;
    default:
      return SCREEN_TIME;
  }
}

AlertLevel envAlertLevel() {
  if (!env.valid) {
    envAlertLevels = EnvAlertLevels();
    return LEVEL_OK;
  }

  // Each metric keeps its own hysteresis state; otherwise a warning from one
  // metric would keep an unrelated metric latched.
  envAlertLevels.temperatureHigh = levelHigh(
      env.temperatureC, ALERT_TEMP_HIGH_WARN, ALERT_TEMP_HIGH_CRIT,
      ALERT_TEMP_HYST, envAlertLevels.temperatureHigh);
  // Low temperature only warns (the README has no critical low threshold).
  envAlertLevels.temperatureLow =
      levelLow(env.temperatureC, ALERT_TEMP_LOW_WARN, -100.0f, ALERT_TEMP_HYST,
               envAlertLevels.temperatureLow);
  envAlertLevels.humidity =
      levelHigh(env.humidityPct, ALERT_RH_WARN, 200.0f, ALERT_RH_HYST,
                envAlertLevels.humidity);

  float pressureDelta = 0.0f;
  if (pressureTrend3h(pressureDelta)) {
    // A falling trend is the warning: use the negated delta.
    envAlertLevels.pressure =
        levelHigh(-pressureDelta, ALERT_PRESS_DROP_WARN, ALERT_PRESS_DROP_CRIT,
                  ALERT_PRESS_HYST, envAlertLevels.pressure);
  } else {
    envAlertLevels.pressure = LEVEL_OK;
  }

  if (!isnan(env.gasIndex)) {
    envAlertLevels.gas =
        levelHigh(env.gasIndex, ALERT_IAQ_WARN, ALERT_IAQ_CRIT, ALERT_IAQ_HYST,
                  envAlertLevels.gas);
  } else {
    envAlertLevels.gas = LEVEL_OK;
  }

  AlertLevel level = LEVEL_OK;
  level = max(level, envAlertLevels.temperatureHigh);
  level = max(level, envAlertLevels.temperatureLow);
  level = max(level, envAlertLevels.humidity);
  level = max(level, envAlertLevels.pressure);
  level = max(level, envAlertLevels.gas);
  return level;
}

void requestAlertScreen(bool newEvent = false) {
  alertScreenActive = true;
  for (uint8_t id = 0; id < ALERT_COUNT; ++id) {
    // Array order is the priority order: battery > environment > storage.
    if (alerts[id].level > LEVEL_OK && alerts[id].level > alerts[id].ackedAt) {
      screen = screenForAlert(static_cast<AlertId>(id));
      // The periodic refresh (newEvent == false) must not wake a blanked
      // display or reset the blanking timer; only a new alert or an explicit
      // acknowledgement does.
      if (newEvent) {
        if (!screenOn && oledOk) {
          oledPower(true);
        }
        screenOn = true;
        lastInteractionMs = millis();
      }
      return;
    }
  }
  alertScreenActive = false;
  screen = SCREEN_TIME;
}

void applyAlert(AlertId id, AlertLevel next) {
  AlertState& state = alerts[id];
  const AlertLevel previous = state.level;
  state.level = next;

  if (next == LEVEL_OK) {
    state.ackedAt = LEVEL_OK;
  } else if (next < previous) {
    // The condition improved after an acknowledgement; allow a later
    // escalation (warning -> critical) to notify again.
    state.ackedAt = LEVEL_OK;
  } else if (next > previous && next > state.ackedAt) {
    // New or escalated alert: wake and show it.
    requestAlertScreen(true);
  }
}

void updateAlerts() {
  // 2S 18650 pack: anything above ~5.5 V means cells are actually connected. (The old
  // 4S HAT (E) threshold of 5 V would treat one connected cell as a plausible pack.)
  const bool batteryPlausible = upsOk && upsData.batteryMv > 5500;
  const AlertLevel batteryLevel =
      batteryPlausible
          ? levelLow(static_cast<float>(upsData.percent), ALERT_BATT_WARN,
                     ALERT_BATT_CRIT, ALERT_BATT_HYST,
                     alerts[ALERT_BATTERY].level)
          : LEVEL_OK;

  const bool storageFresh =
      storage.valid && (millis() - storage.updatedMs) < STORAGE_STALE_MS;
  const AlertLevel storageLevel =
      storageFresh
          ? levelHigh(storage.usedPct, ALERT_STORAGE_WARN, ALERT_STORAGE_CRIT,
                      ALERT_STORAGE_HYST, alerts[ALERT_STORAGE].level)
          : LEVEL_OK;

  applyAlert(ALERT_BATTERY, batteryLevel);
  applyAlert(ALERT_ENVIRONMENT, envAlertLevel());
  applyAlert(ALERT_STORAGE, storageLevel);

  // If the alert that owns the screen cleared, fall back to the next one or
  // to the time screen.
  if (alertScreenActive) {
    requestAlertScreen();
  }
}

void acknowledgeActiveAlert() {
  for (uint8_t id = 0; id < ALERT_COUNT; ++id) {
    if (alerts[id].level > LEVEL_OK) {
      alerts[id].ackedAt = alerts[id].level;
      Serial.printf(
          "{\"type\":\"log\",\"msg\":\"alert acknowledged\",\"id\":%u}\n", id);
      break;
    }
  }
  // Show the next unacknowledged alert (battery > environment > storage), or
  // fall back to the time screen when none are left.
  alertScreenActive = true;
  requestAlertScreen(true);
}

AlertLevel overallAlertLevel() {
  AlertLevel level = LEVEL_OK;
  for (uint8_t id = 0; id < ALERT_COUNT; ++id) {
    level = max(level, alerts[id].level);
  }
  return level;
}

const char* activeAlertText() {
  if (alerts[ALERT_BATTERY].level != LEVEL_OK) {
    return "! BATTERY LOW";
  }
  if (alerts[ALERT_ENVIRONMENT].level != LEVEL_OK) {
    return "! ENVIRONMENT";
  }
  if (alerts[ALERT_STORAGE].level != LEVEL_OK) {
    return "! STORAGE FULL";
  }
  return nullptr;
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------
void drawHeader(const char* title) {
  display.setTextSize(1);
  display.setTextColor(OLED_WHITE);
  display.setCursor(0, 0);
  display.print(title);
  display.drawFastHLine(0, 9, SCREEN_WIDTH, OLED_WHITE);
}

void drawAlertBar() {
  const char* text = activeAlertText();
  if (text == nullptr) {
    return;
  }

  const bool critical = overallAlertLevel() == LEVEL_CRIT;
  display.fillRect(0, SCREEN_HEIGHT - 10, SCREEN_WIDTH, 10,
                   critical ? OLED_WHITE : OLED_BLACK);
  display.drawRect(0, SCREEN_HEIGHT - 10, SCREEN_WIDTH, 10, OLED_WHITE);
  display.setTextSize(1);
  display.setTextColor(critical ? OLED_BLACK : OLED_WHITE);
  display.setCursor(2, SCREEN_HEIGHT - 8);
  display.print(text);
}

void renderTimeScreen() {
  // The RTC and epochNow() are UTC. Convert to the configured local timezone
  // (Europe/Amsterdam by default) only for rendering, so DST is handled here.
  const time_t utc = static_cast<time_t>(epochNow());
  struct tm local = {};
  localtime_r(&utc, &local);
  char buf[40];

  snprintf(buf, sizeof(buf), "%02d:%02d", local.tm_hour, local.tm_min);
  display.setTextSize(3);
  display.setTextColor(OLED_WHITE);
  display.setCursor(19, 12);
  display.print(buf);

  snprintf(buf, sizeof(buf), "%s %02d %s %04d",
           WEEKDAYS[local.tm_wday], local.tm_mday, MONTHS[local.tm_mon],
           local.tm_year + 1900);
  display.setTextSize(1);
  display.setCursor((SCREEN_WIDTH - static_cast<int>(strlen(buf)) * 6) / 2, 38);
  display.print(buf);

  if (upsOk) {
    snprintf(buf, sizeof(buf), "BAT %3u%%%s", upsData.percent,
             upsData.charging ? " CHG" : "");
  } else {
    snprintf(buf, sizeof(buf), "BAT --");
  }
  display.setCursor(4, 50);
  display.print(buf);

  if (overallAlertLevel() != LEVEL_OK) {
    display.setCursor(SCREEN_WIDTH - 8, 50);
    display.print("!");
  }
}

void renderBatteryScreen() {
  drawHeader("BATTERY");
  char buf[40];

  if (!upsOk) {
    display.setCursor(0, 20);
    display.print("UPS HAT (B) not found");
    display.setCursor(0, 34);
    display.print("check 0x42 on I2C");
    return;
  }

  display.setCursor(0, 12);
  snprintf(buf, sizeof(buf), "%3u %%       %4.1f V", upsData.percent,
           upsData.batteryMv / 1000.0f);
  display.print(buf);

  display.setCursor(0, 22);
  snprintf(buf, sizeof(buf), "%+5.2f A    %+5.2f W",
           upsData.batteryMa / 1000.0f,
           (upsData.batteryMv / 1000.0f) * (upsData.batteryMa / 1000.0f));
  display.print(buf);

  display.setCursor(0, 32);
  if (upsData.charging) {
    display.print("charging");
  } else if (upsData.batteryMa < -20) {
    display.print("discharging");
  } else {
    display.print("idle");
  }
  snprintf(buf, sizeof(buf), "  %s", UpsHatB::chargeStateName(upsData.chargeState));
  display.print(buf);

  display.setCursor(0, 42);
  snprintf(buf, sizeof(buf), "in %4.1f V %s", upsData.vbusMv / 1000.0f,
           upsData.vbusPresent ? "present" : "absent");
  display.print(buf);

  display.setCursor(0, 52);
  if (upsData.dischargeMin > 0 && upsData.dischargeMin < 6000) {
    snprintf(buf, sizeof(buf), "~%uh%02um left", upsData.dischargeMin / 60,
             upsData.dischargeMin % 60);
  } else if (upsData.chargeMin > 0 && upsData.chargeMin < 6000) {
    snprintf(buf, sizeof(buf), "~%uh%02um to full", upsData.chargeMin / 60,
             upsData.chargeMin % 60);
  } else {
    snprintf(buf, sizeof(buf), "cell %u.%02u V",
             upsData.cellMv[0] / 1000, (upsData.cellMv[0] % 1000) / 10);
  }
  display.print(buf);
}

void renderEnvironmentScreen() {
  drawHeader("ENVIRONMENT");
  char buf[40];

  if (!env.valid) {
    display.setCursor(0, 20);
    display.print("BME688 not found");
    display.setCursor(0, 34);
    display.print("check 0x76 / 0x77");
    return;
  }

  display.setCursor(0, 12);
  snprintf(buf, sizeof(buf), "%5.1f C    %4.1f %%RH", env.temperatureC,
           env.humidityPct);
  display.print(buf);

  float delta = 0.0f;
  const bool trendOk = pressureTrend3h(delta);
  display.setCursor(0, 22);
  if (trendOk) {
    snprintf(buf, sizeof(buf), "%7.1f hPa %+4.1f/3h", env.pressureHpa, delta);
  } else {
    snprintf(buf, sizeof(buf), "%7.1f hPa   --/3h", env.pressureHpa);
  }
  display.print(buf);

  display.setCursor(0, 32);
  snprintf(buf, sizeof(buf), "gas %6.1f kOhm", env.gasKohm);
  display.print(buf);

  display.setCursor(0, 42);
  if (!isnan(env.gasIndex)) {
    snprintf(buf, sizeof(buf), "IAQ %3.0f (estimate)", env.gasIndex);
    display.print(buf);
  }

  display.setCursor(0, 52);
  display.print(alerts[ALERT_ENVIRONMENT].level != LEVEL_OK ? "ALERT" : "ok");
}

void renderStorageScreen() {
  drawHeader("STORAGE (from Pi)");
  char buf[40];

  if (!storage.valid) {
    display.setCursor(0, 20);
    display.print("no storage data yet");
    display.setCursor(0, 34);
    display.print("waiting for Pi JSON");
    return;
  }

  display.setCursor(0, 12);
  snprintf(buf, sizeof(buf), "%5.1f %% used", storage.usedPct);
  display.print(buf);

  display.setCursor(0, 24);
  snprintf(buf, sizeof(buf), "%6.1f GB free", storage.freeGb);
  display.print(buf);

  const uint32_t ageSeconds = (millis() - storage.updatedMs) / 1000UL;
  display.setCursor(0, 38);
  if (ageSeconds < 120) {
    snprintf(buf, sizeof(buf), "updated %lus ago",
             static_cast<unsigned long>(ageSeconds));
  } else {
    snprintf(buf, sizeof(buf), "updated %lum ago",
             static_cast<unsigned long>(ageSeconds / 60));
  }
  display.print(buf);

  display.setCursor(0, 52);
  if ((millis() - storage.updatedMs) > STORAGE_STALE_MS) {
    display.print("stale: Pi not sending");
  } else if (storage.usedPct >= 90.0f) {
    display.print("clean up the SSD");
  }
}

void render() {
  if (!oledOk || !screenOn) {
    return;
  }

  display.clearDisplay();
  switch (screen) {
    case SCREEN_TIME:
      renderTimeScreen();
      break;
    case SCREEN_BATTERY:
      renderBatteryScreen();
      break;
    case SCREEN_ENVIRONMENT:
      renderEnvironmentScreen();
      break;
    case SCREEN_STORAGE:
      renderStorageScreen();
      break;
  }

  if (screen != SCREEN_TIME) {
    drawAlertBar();
  }
  display.display();
}

void wakeScreen() {
  if (!screenOn) {
    screenOn = true;
    if (oledOk) {
      oledPower(true);
      Serial.println("{\"type\":\"log\",\"msg\":\"OLED wake\"}");
    }
    lastRenderMs = 0;  // force a redraw of the stale buffer
  }
  lastInteractionMs = millis();
}

void nextScreen() {
  wakeScreen();
  screen = static_cast<ScreenId>((static_cast<uint8_t>(screen) + 1) % 4);
  alertScreenActive = false;
  lastRenderMs = 0;
}

// ---------------------------------------------------------------------------
// Button
// ---------------------------------------------------------------------------
void pollButton() {
  const bool pressed = digitalRead(PIN_BUTTON) == LOW;
  const uint32_t now = millis();

  if (pressed && !buttonDown) {
    buttonDown = true;
    buttonDownMs = now;
    buttonLongFired = false;
    return;
  }

  if (!pressed && buttonDown) {
    buttonDown = false;
    if (!buttonLongFired && now - buttonDownMs >= BUTTON_DEBOUNCE_MS) {
      nextScreen();
    }
    return;
  }

  if (pressed && !buttonLongFired &&
      now - buttonDownMs >= BUTTON_LONG_PRESS_MS) {
    buttonLongFired = true;
    acknowledgeActiveAlert();
    wakeScreen();
    lastRenderMs = 0;
  }
}

// ---------------------------------------------------------------------------
// Serial protocol (newline-delimited JSON)
// ---------------------------------------------------------------------------
void sendTelemetry() {
  JsonDocument doc;
  doc["type"] = "telemetry";
  doc["ms"] = millis();
  doc["time"] = epochNow();

  JsonObject battery = doc["battery"].to<JsonObject>();
  battery["present"] = upsOk;
  battery["percent"] = upsData.percent;
  battery["mv"] = upsData.batteryMv;
  battery["ma"] = upsData.batteryMa;
  battery["charging"] = upsData.charging;
  battery["fast"] = upsData.fastCharging;
  battery["vbus"] = upsData.vbusPresent;
  battery["vbus_mv"] = upsData.vbusMv;
  battery["remaining_mah"] = upsData.remainingMah;
  battery["discharge_min"] = upsData.dischargeMin;
  battery["charge_min"] = upsData.chargeMin;

  JsonObject environment = doc["environment"].to<JsonObject>();
  environment["present"] = env.valid;
  environment["temperature_c"] = env.temperatureC;
  environment["humidity_pct"] = env.humidityPct;
  environment["pressure_hpa"] = env.pressureHpa;
  environment["gas_kohm"] = env.gasKohm;
  environment["gas_index"] = env.gasIndex;

  JsonObject disk = doc["storage"].to<JsonObject>();
  disk["present"] = storage.valid;
  disk["used_pct"] = storage.usedPct;
  disk["free_gb"] = storage.freeGb;
  disk["age_s"] = storage.valid ? (millis() - storage.updatedMs) / 1000UL : 0;

  JsonArray alertArray = doc["alerts"].to<JsonArray>();
  alertArray.add(static_cast<uint8_t>(alerts[ALERT_BATTERY].level));
  alertArray.add(static_cast<uint8_t>(alerts[ALERT_ENVIRONMENT].level));
  alertArray.add(static_cast<uint8_t>(alerts[ALERT_STORAGE].level));

  serializeJson(doc, Serial);
  Serial.println();
}

void handleSerialLine(char* line) {
  JsonDocument doc;
  const DeserializationError error = deserializeJson(doc, line);
  if (error) {
    Serial.printf("{\"type\":\"error\",\"msg\":\"bad json\",\"detail\":\"%s\"}\n",
                  error.c_str());
    return;
  }

  const char* cmd = doc["cmd"] | "";
  if (strcmp(cmd, "time") == 0) {
    const uint32_t epoch = doc["epoch"] | 0;
    if (epoch > 1700000000UL) {  // sanity: after Nov 2023
      syncTime(epoch);
    }
  } else if (strcmp(cmd, "storage") == 0) {
    const float used = doc["used_pct"] | -1.0f;
    const float freeGb = doc["free_gb"] | -1.0f;
    if (used >= 0.0f && used <= 100.0f && freeGb >= 0.0f) {
      storage.valid = true;
      storage.usedPct = used;
      storage.freeGb = freeGb;
      storage.updatedMs = millis();
    }
  } else if (strcmp(cmd, "ack") == 0) {
    acknowledgeActiveAlert();
  } else if (strcmp(cmd, "screen") == 0) {
    const int index = doc["index"] | -1;
    if (index >= 0 && index < 4) {
      screen = static_cast<ScreenId>(index);
      alertScreenActive = false;
      wakeScreen();
      lastRenderMs = 0;
      Serial.printf(
          "{\"type\":\"log\",\"msg\":\"screen set\",\"index\":%d}\n", index);
    }
  } else if (strcmp(cmd, "status") == 0) {
    sendTelemetry();
  } else {
    Serial.println("{\"type\":\"error\",\"msg\":\"unknown cmd\"}");
  }
}

void pollSerial() {
  while (Serial.available()) {
    const char c = static_cast<char>(Serial.read());
    if (c == '\r') {
      continue;
    }
    if (c == '\n') {
      serialLine[serialLineLen] = '\0';
      if (serialLineLen > 0) {
        handleSerialLine(serialLine);
      }
      serialLineLen = 0;
    } else if (serialLineLen < sizeof(serialLine) - 1) {
      serialLine[serialLineLen++] = c;
    } else {
      serialLineLen = 0;  // discard overlong line
    }
  }
}

// ---------------------------------------------------------------------------
// Setup / loop
// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  const uint32_t serialWait = millis();
  while (!Serial && millis() - serialWait < 1500) {
    delay(10);
  }

  Serial.println();
  Serial.println("{\"type\":\"log\",\"msg\":\"Ktemata r2 status OLED\"}");

  // POSIX timezone rules (including DST) for the OLED clock.
  setenv("TZ", TIMEZONE, 1);
  tzset();
  Serial.printf(
      "{\"type\":\"log\",\"msg\":\"mcu\",\"model\":\"%s\",\"cores\":%u,"
      "\"flash\":%u,\"psram_found\":%s,\"psram\":%u}\n",
      ESP.getChipModel(), ESP.getChipCores(), ESP.getFlashChipSize(),
      psramFound() ? "true" : "false", ESP.getPsramSize());

  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL, I2C_CLOCK_HZ);
  scanI2C();

  pinMode(PIN_BUTTON, INPUT_PULLUP);

  // The Adafruit begin() can return true even when nothing ACKs, so probe
  // the address first. Some modules are strapped to 0x3D.
  uint8_t oledAddress = 0;
  if (i2cPresent(I2C_ADDR_OLED)) {
    oledAddress = I2C_ADDR_OLED;
  } else if (i2cPresent(0x3D)) {
    oledAddress = 0x3D;
  }
  if (oledAddress != 0) {
    oledOk = oledBegin(oledAddress);
    // Adafruit's OLED init may raise the bus clock; the UPS MCU and the
    // sensors share this bus, so restore the conservative 100 kHz.
    Wire.setClock(I2C_CLOCK_HZ);
  }
  if (oledOk) {
    display.setRotation(OLED_ROTATION);
    display.clearDisplay();
    display.display();
    Serial.printf(
        "{\"type\":\"log\",\"msg\":\"OLED ready\",\"addr\":%u,"
        "\"hex\":\"0x%02X\"}\n",
        oledAddress, oledAddress);
  } else {
    Serial.println("{\"type\":\"log\",\"msg\":\"OLED not found\"}");
  }

  if (i2cPresent(I2C_ADDR_DS3231)) {
    rtcOk = rtc.begin(&Wire);
  }
  if (rtcOk) {
    Serial.printf(
        "{\"type\":\"log\",\"msg\":\"DS3231 found\",\"lost_power\":%s}\n",
        rtc.lostPower() ? "true" : "false");
  }

  initBme688();
  if (i2cPresent(I2C_ADDR_UPS)) {
    upsOk = ups.begin();
  }
  if (upsOk) {
    Serial.println("{\"type\":\"log\",\"msg\":\"UPS HAT (B) found\"}");
  }

  // Build time is local to the build machine. Convert it to a UTC epoch so
  // the unsynced fallback clock is consistent with the DS3231/Pi UTC store.
  const DateTime buildLocal(F(__DATE__), F(__TIME__));
  struct tm buildTm = {};
  buildTm.tm_year = buildLocal.year() - 1900;
  buildTm.tm_mon = buildLocal.month() - 1;
  buildTm.tm_mday = buildLocal.day();
  buildTm.tm_hour = buildLocal.hour();
  buildTm.tm_min = buildLocal.minute();
  buildTm.tm_sec = buildLocal.second();
  buildTm.tm_isdst = -1;
  const time_t buildEpoch = mktime(&buildTm);
  buildTime = buildEpoch > 0 ? DateTime(static_cast<uint32_t>(buildEpoch)) : buildLocal;

  lastInteractionMs = millis();
  lastPressureSampleMs = millis();
  lastTelemetryMs = millis();

  // Do not light the OLED forever on the bench; start on the time screen.
  screen = SCREEN_TIME;
  render();
}

void loop() {
  const uint32_t now = millis();

  pollButton();
  pollSerial();

  bool newData = false;
  if (now - lastSensorTickMs >= SENSOR_PERIOD_MS) {
    lastSensorTickMs = now;
    pollUps();
    startBmeMeasurement(now);
    newData = true;
  }
  if (finishBmeMeasurement(now)) {
    newData = true;
  }
  if (newData) {
    updateAlerts();
  }

  if (!alertScreenActive && screen != SCREEN_TIME &&
      now - lastInteractionMs >= RETURN_TO_TIME_MS) {
    screen = SCREEN_TIME;
    lastRenderMs = 0;
  }

  if (SCREEN_OFF_MS > 0 && screenOn &&
      now - lastInteractionMs >= SCREEN_OFF_MS) {
    screenOn = false;
    if (oledOk) {
      oledPower(false);
      Serial.println("{\"type\":\"log\",\"msg\":\"OLED blank\"}");
    }
  }

  if (screenOn && now - lastRenderMs >= SCREEN_REFRESH_MS) {
    render();
    lastRenderMs = now;
  }

  if (now - lastTelemetryMs >= TELEMETRY_PERIOD_MS) {
    sendTelemetry();
    lastTelemetryMs = now;
  }

  delay(5);
}

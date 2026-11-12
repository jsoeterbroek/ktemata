/*
 * Ktemata r2 - status OLED firmware
 *
 * Board: DFRobot FireBeetle 2 ESP32-UE (N16R2)
 *        ESP32-WROOM-32UE-N16R2 (ESP32-D0WDR2-V3, 2 MB PSRAM)
 *
 * Responsibilities (see README.md, "Status OLED"):
 *   - 1.3" 128x64 I2C OLED (SH1106 default, SSD1306 optional), four screens:
 *     time, power, storage, wifi
 *   - one sealed push button: short press = next screen, long press = ack alert
 *   - DS3231 on the internal I2C bus
 *   - Waveshare UPS HAT (B) INA219 gauge at 0x42 (2S 18650)
 *   - charge-input sense line on ADC1: is a source connected, and is it steady or sagging
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
#include <esp_log.h>
#include <esp_system.h>
#include <math.h>
#include <stdlib.h>
#include <time.h>

#include "chg_sense.h"
#include "config.h"
#include "fonts/Roboto18pt7b.h"
#include "fonts/Roboto5pt7b.h"
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
UpsHatB ups(Wire, I2C_ADDR_UPS);

bool oledOk = false;
bool rtcOk = false;
bool upsOk = false;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum ScreenId : uint8_t {
  SCREEN_TIME = 0,
  SCREEN_POWER = 1,
  SCREEN_STORAGE = 2,
  SCREEN_WIFI = 3,
  SCREEN_COUNT = 4,
};

// The radio lives on the Pi; the board only mirrors what the Pi reports over serial.
// The firmware does not initialise Wi-Fi (see the header comment).
enum WifiMode : uint8_t {
  WIFI_OFF = 0,
  WIFI_CLIENT = 1,
  WIFI_AP = 2,
};

enum AlertLevel : uint8_t {
  LEVEL_OK = 0,
  LEVEL_WARN = 1,
  LEVEL_CRIT = 2,
};

enum AlertId : uint8_t {
  ALERT_BATTERY = 0,
  ALERT_STORAGE = 1,
  ALERT_COUNT = 2,
};

struct AlertState {
  AlertLevel level = LEVEL_OK;
  AlertLevel ackedAt = LEVEL_OK;
};

struct StorageReading {
  bool valid = false;
  float usedPct = NAN;
  float freeGb = NAN;
  uint32_t updatedMs = 0;
};

struct WifiReading {
  bool valid = false;
  WifiMode mode = WIFI_OFF;
  char ip[16] = {0};           // dotted quad reported by the Pi (station or AP)
  uint32_t updatedMs = 0;
};

UpsStatus upsData;
ChargeInput chargeIn;
StorageReading storage;
WifiReading wifi;
AlertState alerts[ALERT_COUNT];

ScreenId screen = SCREEN_TIME;
bool screenOn = true;
bool alertScreenActive = false;
uint32_t lastInteractionMs = 0;
uint32_t lastRenderMs = 0;

// RTC-less fallback: build time plus elapsed millis, or host-supplied epoch.
uint32_t buildTimeEpoch = 0;
bool clockFromHost = false;
int64_t clockBaseEpoch = 0;  // Unix epoch at millis() == 0

uint32_t lastUpsTickMs = 0;

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

  return DateTime(buildTimeEpoch) +
         TimeSpan(static_cast<int32_t>(millis() / 1000ULL));
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
// UPS polling
// ---------------------------------------------------------------------------
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
      return SCREEN_POWER;
    case ALERT_STORAGE:
      return SCREEN_STORAGE;
    default:
      return SCREEN_TIME;
  }
}

void requestAlertScreen(bool newEvent = false) {
  alertScreenActive = true;
  for (uint8_t id = 0; id < ALERT_COUNT; ++id) {
    // Array order is the priority order: battery > storage.
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
  // Show the next unacknowledged alert (battery > storage), or
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
  if (alerts[ALERT_STORAGE].level != LEVEL_OK) {
    return "! STORAGE FULL";
  }
  return nullptr;
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------
// Roboto (Adafruit_GFX bitmap fonts in include/fonts/). The cursor of a custom
// font is on the baseline, not the top-left, so these helpers take the top of
// the line and add the ascent of Roboto5pt7b (7 px) or the clock digits (24 px).
constexpr int BODY_ASCENT = 7;
constexpr int CLOCK_ASCENT = 24;

void bodyFont() {
  display.setFont(&Roboto5pt7b);
  display.setTextSize(1);
}

void bodyCursor(int x, int top) {
  bodyFont();
  display.setCursor(x, top + BODY_ASCENT);
}

// Ink box of the text at the current font; callers use it to centre.
int textWidth(const char* text) {
  int16_t x1, y1;
  uint16_t w, h;
  display.getTextBounds(text, 0, 0, &x1, &y1, &w, &h);
  return static_cast<int>(w);
}

int textLeft(const char* text) {
  int16_t x1, y1;
  uint16_t w, h;
  display.getTextBounds(text, 0, 0, &x1, &y1, &w, &h);
  return static_cast<int>(x1);
}

void bodyCentered(int top, const char* text) {
  bodyFont();
  const int left = (SCREEN_WIDTH - textWidth(text)) / 2 - textLeft(text);
  display.setCursor(left, top + BODY_ASCENT);
  display.print(text);
}

void clockCentered(int baseline, const char* text) {
  display.setFont(&Roboto18pt7b);
  display.setTextSize(1);
  const int left = (SCREEN_WIDTH - textWidth(text)) / 2 - textLeft(text);
  display.setCursor(left, baseline);
  display.print(text);
}

// 9x9 clock and 11x7 battery, drawn with primitives so no extra bitmap is needed.
void drawClockIcon(int x, int top) {
  const int cx = x + 4;
  const int cy = top + 4;
  display.drawCircle(cx, cy, 4, OLED_WHITE);
  display.drawLine(cx, cy, cx, cy - 3, OLED_WHITE);   // hour hand
  display.drawLine(cx, cy, cx + 2, cy, OLED_WHITE);   // minute hand
}

void drawBatteryIcon(int x, int top, int percent) {
  display.drawRect(x, top, 9, 7, OLED_WHITE);
  display.fillRect(x + 9, top + 2, 2, 3, OLED_WHITE);  // terminal
  if (percent < 0) percent = 0;
  if (percent > 100) percent = 100;
  const int fill = (percent * 7 + 50) / 100;
  if (fill > 0) {
    display.fillRect(x + 1, top + 1, fill, 5, OLED_WHITE);
  }
}

// 6x7 plug: two prongs, body, lead. Shown when the pack is not discharging.
void drawPlugIcon(int x, int top) {
  display.drawFastVLine(x + 1, top, 2, OLED_WHITE);
  display.drawFastVLine(x + 4, top, 2, OLED_WHITE);
  display.drawRect(x, top + 2, 6, 3, OLED_WHITE);
  display.drawFastVLine(x + 3, top + 5, 2, OLED_WHITE);
}

void dateLine(int top, const char* text) {
  bodyFont();
  const int icon = 9, gap = 4;
  const int left = (SCREEN_WIDTH - (icon + gap + textWidth(text))) / 2;
  drawClockIcon(left, top);
  display.setCursor(left + icon + gap - textLeft(text), top + BODY_ASCENT);
  display.print(text);
}

void batteryLine(int top, const char* text, int percent, bool mains) {
  bodyFont();
  const int icon = 11, gap = 4, plug = 6;
  const int w = textWidth(text);
  const int extra = mains ? gap + plug : 0;
  const int left = (SCREEN_WIDTH - (icon + gap + w + extra)) / 2;
  drawBatteryIcon(left, top, percent);
  display.setCursor(left + icon + gap - textLeft(text), top + BODY_ASCENT);
  display.print(text);
  if (mains) {
    drawPlugIcon(left + icon + gap + w + gap, top + 1);
  }
}

void drawHeader(const char* title) {
  display.setTextColor(OLED_WHITE);
  bodyCursor(0, 0);
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
  display.setTextColor(critical ? OLED_BLACK : OLED_WHITE);
  bodyCursor(2, SCREEN_HEIGHT - 8);
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
  display.setTextColor(OLED_WHITE);
  clockCentered(CLOCK_ASCENT + 1, buf);   // 24 px digits, 1 px top margin

  // No leading zero on the day; two spaces separate the date blocks so the proportional
  // font does not run them together.
  snprintf(buf, sizeof(buf), "%s   %d %s   %04d",
           WEEKDAYS[local.tm_wday], local.tm_mday, MONTHS[local.tm_mon],
           local.tm_year + 1900);
  dateLine(31, buf);

  if (upsOk) {
    snprintf(buf, sizeof(buf), "BAT %3u%%%s", upsData.percent,
             upsData.charging ? " CHG" : "");
  } else {
    snprintf(buf, sizeof(buf), "BAT --");
  }
  batteryLine(44, buf, upsOk ? static_cast<int>(upsData.percent) : 0,
              upsOk && upsData.mains);

  if (overallAlertLevel() != LEVEL_OK) {
    bodyCursor(SCREEN_WIDTH - 8, 44);
    display.print("!");
  }
}

bool lowBattery() {
  return upsOk && upsData.percent <= static_cast<uint16_t>(ALERT_BATT_CRIT);
}

void renderPowerScreen() {
  drawHeader("POWER");
  char buf[40];

  if (!upsOk) {
    bodyCursor(0, 20);
    display.print("UPS HAT (B) not found");
    bodyCursor(0, 34);
    display.print("check 0x42 on I2C");
    return;
  }

  // Rows are packed from the top so a state that has nothing to report does not leave a
  // gap: on mains there is no load (the charger feeds the regulator) and no OL flag (the
  // charging / battery full row already says the pack is on external power).
  //
  // The charge-input sense line takes the third row whenever a source is connected, in place of
  // the load percentage: on a weak source the input voltage is the number that explains why the
  // pack is still draining, and on mains the load % is not observable anyway.
  int y = 12;

  bodyCursor(0, y);
  snprintf(buf, sizeof(buf), "%3u %%       %4.1f V", upsData.percent,
           upsData.batteryMv / 1000.0f);
  display.print(buf);
  y += 10;

  bodyCursor(0, y);
  snprintf(buf, sizeof(buf), "%+5.2f A    %+5.2f W",
           upsData.batteryMa / 1000.0f,
           (upsData.batteryMv / 1000.0f) * (upsData.batteryMa / 1000.0f));
  display.print(buf);
  y += 10;

  const bool showInput = chargeIn.valid && chargeIn.present;
  if (showInput) {
    bodyCursor(0, y);
    // No adjective until the window has filled: "varying" from two samples would be a guess.
    const char* quality = chargeIn.stable ? "steady"
                          : (chargeIn.samples >= chgs::WINDOW ? "varying" : "");
    snprintf(buf, sizeof(buf), "IN %4.1f V %s", chargeIn.railMv / 1000.0f, quality);
    display.print(buf);
    y += 10;
  } else if (!upsData.mains) {
    bodyCursor(0, y);
    if (upsData.loadValid) {
      snprintf(buf, sizeof(buf), "OB%s  load %u%%", lowBattery() ? " LB" : "",
               upsData.loadPct);
    } else {
      snprintf(buf, sizeof(buf), "OB%s", lowBattery() ? " LB" : "");
    }
    display.print(buf);
    y += 10;
  }

  bodyCursor(0, y);
  if (!upsData.mains) {
    display.print(showInput ? "disch. weak in" : "discharging");
  } else if (upsData.charging) {
    display.print("charging");
  } else {
    display.print("battery full");
  }
  y += 10;

  if (upsData.runtimeValid) {
    bodyCursor(0, y);
    if (upsData.runtimeSec < 60UL) {
      snprintf(buf, sizeof(buf), "~%lus left", static_cast<unsigned long>(upsData.runtimeSec));
    } else if (upsData.runtimeSec < 3600UL) {
      snprintf(buf, sizeof(buf), "~%lum left", static_cast<unsigned long>(upsData.runtimeSec / 60));
    } else {
      const uint32_t minutes = upsData.runtimeSec / 60UL;
      snprintf(buf, sizeof(buf), "~%luh%02lum left",
               static_cast<unsigned long>(minutes / 60UL),
               static_cast<unsigned long>(minutes % 60UL));
    }
    display.print(buf);
  } else if (upsData.chargeMin > 0 && upsData.chargeMin < 6000) {
    bodyCursor(0, y);
    snprintf(buf, sizeof(buf), "~%uh%02um to full", upsData.chargeMin / 60,
             upsData.chargeMin % 60);
    display.print(buf);
  }
  // On mains with no charge estimate there is no runtime row, so stop after "battery full".
}

// The board has no radio: the Pi reports the state of its own Wi-Fi over serial.
const char* wifiStateText() {
  switch (wifi.mode) {
    case WIFI_CLIENT:
      return "station mode";
    case WIFI_AP:
      return "access point";
    default:
      return "off";
  }
}

const char* wifiStateName() {
  switch (wifi.mode) {
    case WIFI_CLIENT:
      return "client";
    case WIFI_AP:
      return "ap";
    default:
      return "off";
  }
}

void renderWifiScreen() {
  drawHeader("WIFI");

  if (!wifi.valid) {
    bodyCursor(0, 20);
    display.print("no wifi data yet");
    bodyCursor(0, 34);
    display.print("waiting for Pi JSON");
    return;
  }

  bodyCursor(0, 12);
  display.print(wifiStateText());

  bodyCursor(0, 24);
  display.print(wifi.ip[0] ? wifi.ip : "no IP");
}

void renderStorageScreen() {
  drawHeader("STORAGE");
  char buf[40];

  if (!storage.valid) {
    bodyCursor(0, 20);
    display.print("no storage data yet");
    bodyCursor(0, 34);
    display.print("waiting for Pi JSON");
    return;
  }

  bodyCursor(0, 12);
  snprintf(buf, sizeof(buf), "%5.1f %% used", storage.usedPct);
  display.print(buf);

  bodyCursor(0, 24);
  snprintf(buf, sizeof(buf), "%6.1f GB free", storage.freeGb);
  display.print(buf);

  bodyCursor(0, 52);
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
    case SCREEN_POWER:
      renderPowerScreen();
      break;
    case SCREEN_STORAGE:
      renderStorageScreen();
      break;
    case SCREEN_WIFI:
      renderWifiScreen();
      break;
    default:
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
  screen = static_cast<ScreenId>((static_cast<uint8_t>(screen) + 1) % SCREEN_COUNT);
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
  battery["mains"] = upsData.mains;
  battery["ol"] = upsOk && upsData.mains;
  battery["ob"] = upsOk && !upsData.mains;
  battery["lb"] = lowBattery();
  if (upsOk) {
    battery["status"] = upsData.mains ? (lowBattery() ? "OL LB" : "OL")
                                      : (lowBattery() ? "OB LB" : "OB");
  } else {
    battery["status"] = nullptr;
  }
  if (upsData.loadValid) {
    battery["load_pct"] = upsData.loadPct;
  } else {
    battery["load_pct"] = nullptr;
  }
  if (upsData.runtimeValid) {
    battery["runtime_s"] = upsData.runtimeSec;
  } else {
    battery["runtime_s"] = nullptr;
  }
  battery["fast"] = upsData.fastCharging;
  battery["vbus"] = upsData.vbusPresent;
  battery["vbus_mv"] = upsData.vbusMv;
  battery["remaining_mah"] = upsData.remainingMah;
  battery["charge_min"] = upsData.chargeMin;

  // Charge-input sense line. "source" is what the hardware can actually prove: no rail, a rail
  // that is carrying the load, or a rail that is present while the pack still discharges (a source
  // too weak to cover the load - a shaded panel, a crank between turns). Mains vs solar vs crank is
  // not knowable from one voltage, so the JSON says "steady"/"varying" instead of guessing.
  JsonObject input = doc["input"].to<JsonObject>();
  input["present"] = chargeIn.present;
  input["rail_mv"] = chargeIn.valid ? chargeIn.railMv : 0;
  input["stable"] = chargeIn.present && chargeIn.stable;
  input["samples"] = chargeIn.samples;
  const char* source = "battery";
  if (chargeIn.present) {
    source = (upsOk && !upsData.mains) ? "external-weak" : "external";
  }
  battery["source"] = source;
  battery["input_mv"] = chargeIn.valid ? chargeIn.railMv : 0;
  battery["input_stable"] = chargeIn.present && chargeIn.stable;

  JsonObject disk = doc["storage"].to<JsonObject>();
  disk["present"] = storage.valid;
  disk["used_pct"] = storage.usedPct;
  disk["free_gb"] = storage.freeGb;
  disk["age_s"] = storage.valid ? (millis() - storage.updatedMs) / 1000UL : 0;

  // Mirror of the Pi's own radio; the board has none.
  JsonObject wifiJson = doc["wifi"].to<JsonObject>();
  wifiJson["present"] = wifi.valid;
  if (wifi.valid) {
    wifiJson["state"] = wifiStateName();
    wifiJson["ip"] = wifi.ip[0] ? wifi.ip : nullptr;
    wifiJson["age_s"] = (millis() - wifi.updatedMs) / 1000UL;
  } else {
    wifiJson["state"] = nullptr;
    wifiJson["age_s"] = nullptr;
  }

  JsonArray alertArray = doc["alerts"].to<JsonArray>();
  alertArray.add(static_cast<uint8_t>(alerts[ALERT_BATTERY].level));
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
  } else if (strcmp(cmd, "wifi") == 0) {
    const char* state = doc["state"] | "";
    if (strcmp(state, "off") == 0) {
      wifi.mode = WIFI_OFF;
    } else if (strcmp(state, "client") == 0) {
      wifi.mode = WIFI_CLIENT;
    } else if (strcmp(state, "ap") == 0) {
      wifi.mode = WIFI_AP;
    } else {
      Serial.println("{\"type\":\"error\",\"msg\":\"wifi state must be off, client or ap\"}");
      return;
    }
    const char* ip = doc["ip"] | "";
    strncpy(wifi.ip, ip, sizeof(wifi.ip) - 1);
    wifi.ip[sizeof(wifi.ip) - 1] = '\0';
    if (wifi.mode == WIFI_OFF) {
      wifi.ip[0] = '\0';
    }
    wifi.valid = true;
    wifi.updatedMs = millis();
  } else if (strcmp(cmd, "ack") == 0) {
    acknowledgeActiveAlert();
  } else if (strcmp(cmd, "screen") == 0) {
    const int index = doc["index"] | -1;
    if (index >= 0 && index < SCREEN_COUNT) {
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
// Why the chip came up. Without it a board that reboots "sometimes" is indistinguishable from one
// the serial port reset (opening the CH340 pulses EN) - and a brownout on the 5 V from the HAT
// looks exactly like both.
const char* resetReasonName(esp_reset_reason_t reason) {
  switch (reason) {
    case ESP_RST_POWERON:   return "power-on";
    case ESP_RST_EXT:       return "external pin";
    case ESP_RST_SW:        return "software";
    case ESP_RST_PANIC:     return "panic";
    case ESP_RST_INT_WDT:   return "interrupt watchdog";
    case ESP_RST_TASK_WDT:  return "task watchdog";
    case ESP_RST_WDT:       return "watchdog";
    case ESP_RST_DEEPSLEEP: return "deep sleep";
    case ESP_RST_BROWNOUT:  return "brownout";
    case ESP_RST_SDIO:      return "sdio";
    default:                return "unknown";
  }
}

void setup() {
  Serial.begin(115200);
  const uint32_t serialWait = millis();
  while (!Serial && millis() - serialWait < 1500) {
    delay(10);
  }

  // The Pi parses this port as newline-delimited JSON. The Arduino core logger is compiled out
  // (-DCORE_DEBUG_LEVEL=0); this also quiets ESP-IDF components that log at runtime. The
  // firmware's own JSON logs below report absent devices.
  esp_log_level_set("*", ESP_LOG_NONE);

  Serial.println();
  Serial.println("{\"type\":\"log\",\"msg\":\"Ktemata r2 status OLED\"}");
  const esp_reset_reason_t resetReason = esp_reset_reason();
  Serial.printf("{\"type\":\"log\",\"msg\":\"reset\",\"reason\":%d,\"name\":\"%s\"}\n",
                static_cast<int>(resetReason), resetReasonName(resetReason));

  // POSIX timezone rules (including DST) for the OLED clock.
  setenv("TZ", TIMEZONE, 1);
  tzset();
  Serial.printf(
      "{\"type\":\"log\",\"msg\":\"mcu\",\"model\":\"%s\",\"cores\":%u,"
      "\"flash\":%lu,\"psram_found\":%s,\"psram\":%lu}\n",
      ESP.getChipModel(), ESP.getChipCores(),
      static_cast<unsigned long>(ESP.getFlashChipSize()),
      psramFound() ? "true" : "false",
      static_cast<unsigned long>(ESP.getPsramSize()));

  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL, I2C_CLOCK_HZ);
  scanI2C();

  pinMode(PIN_BUTTON, INPUT_PULLUP);

  // Charge-input sense line: the boot log carries the raw value so a wrong pin or a missing
  // resistor shows up here instead of being inferred from a state that never changes.
  chgSenseBegin();
  Serial.printf("{\"type\":\"log\",\"msg\":\"charge sense\",\"pin_mv\":%u,\"rail_mv\":%u}\n",
                chgSensePinMv(), chgSenseRailMv());

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
  buildTimeEpoch = buildEpoch > 0 ? static_cast<uint32_t>(buildEpoch)
                                  : buildLocal.unixtime();

  lastInteractionMs = millis();
  lastUpsTickMs = millis();
  lastTelemetryMs = millis();

  // Do not light the OLED forever on the bench; start on the time screen.
  screen = SCREEN_TIME;
  render();
}

void loop() {
  const uint32_t now = millis();

  pollButton();
  pollSerial();

  if (now - lastUpsTickMs >= UPS_PERIOD_MS) {
    lastUpsTickMs = now;
    chgSensePoll(chargeIn);   // independent of the gauge: works with the UPS absent
    pollUps();
    updateAlerts();
  }

#if AUTO_CYCLE_MS == 0
  if (!alertScreenActive && screen != SCREEN_TIME &&
      now - lastInteractionMs >= RETURN_TO_TIME_MS) {
    screen = SCREEN_TIME;
    lastRenderMs = 0;
  }
#else
  // No panel button yet: walk the four screens (and show the UPS statistics on the way).
  // Alerts still take over while active. Any wake (button, serial screen command, alert)
  // resets lastInteractionMs, so the next advance is 25 s after that.
  if (!alertScreenActive && now - lastInteractionMs >= AUTO_CYCLE_MS) {
    nextScreen();
  }
#endif

#if SCREEN_OFF_MS > 0
  if (screenOn && now - lastInteractionMs >= SCREEN_OFF_MS) {
    screenOn = false;
    if (oledOk) {
      oledPower(false);
      Serial.println("{\"type\":\"log\",\"msg\":\"OLED blank\"}");
    }
  }
#endif

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

#include "chg_sense.h"

#include "config.h"

namespace {
chgs::Window window;
bool wasPresent = false;
constexpr float DIVIDER = (CHG_SENSE_R1 + CHG_SENSE_R2) / CHG_SENSE_R2;   // 4.0

// Median of five conversions: the ESP32 ADC is noisy enough that a single read moves by tens of
// millivolts, and the stability test would then call a good supply "varying".
uint16_t readPinMv() {
  uint16_t v[5];
  for (uint8_t i = 0; i < 5; i++) {
    v[i] = static_cast<uint16_t>(analogReadMilliVolts(PIN_CHG_SENSE));
  }
  for (uint8_t i = 1; i < 5; i++) {
    const uint16_t key = v[i];
    int8_t j = static_cast<int8_t>(i) - 1;
    while (j >= 0 && v[j] > key) {
      v[j + 1] = v[j];
      j--;
    }
    v[j + 1] = key;
  }
  return v[2];
}
}  // namespace

uint16_t chgSensePinMv() { return readPinMv(); }

uint16_t chgSenseRailMv() {
  const float rail = static_cast<float>(readPinMv()) * DIVIDER;
  return static_cast<uint16_t>(rail > 65535.0f ? 65535.0f : rail + 0.5f);
}

void chgSenseBegin() {
  analogSetPinAttenuation(PIN_CHG_SENSE, ADC_11db);
  chgs::reset(window);
  wasPresent = false;
}

void chgSensePoll(ChargeInput& out) {
  const uint16_t pinMv = readPinMv();
  // A rail at 0 V divides to 0 V; that is a valid "nothing connected", not a broken ADC.
  const float rail = static_cast<float>(pinMv) * DIVIDER;
  out.railMv = static_cast<uint16_t>(rail > 65535.0f ? 65535.0f : rail + 0.5f);
  out.valid = true;

  chgs::push(window, out.railMv);
  wasPresent = chgs::present(out.railMv, wasPresent);
  out.present = wasPresent;
  out.stable = wasPresent && chgs::stable(window);
  out.samples = window.count;
}

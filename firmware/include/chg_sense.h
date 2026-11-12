#pragma once

// Charge-input sense line: one ADC channel on a divider from the UPS HAT (B)'s DC input, so the
// board can tell "no source" from "a source is connected" without waiting for pack current, and
// can see a supply that cannot carry the load.
//
// Wiring (docs/WIRING.md, "Power"): rail -> R1 30k -> ADC pin -> R2 10k -> GND, 100 nF from the
// pin to GND. 8.4 V reads ~2.10 V, inside the linear part of the ADC's 11 dB range; the divider
// draws 210 uA from the charger and nothing from the pack when the rail is dead.
//
// The pin is ADC1_CH0 (A0 / GPIO36) on the FireBeetle 2. Any ADC1 pin works - A1/A2/A3 are the
// alternates - but keep it off ADC2 (GPIO 0/2/4/12-15/25-27), which the radio claims.
// Override with -DPIN_CHG_SENSE=<gpio> if your board exposes a different header pin.

#include <Arduino.h>

#include "chg_sense_math.h"

struct ChargeInput {
  bool valid = false;        // the ADC produced a plausible reading
  uint16_t railMv = 0;       // the DC input, undivided, millivolts
  bool present = false;      // above the present threshold (hysteresis applied)
  bool stable = false;       // spread over the last minute is small: a regulated supply
  uint8_t samples = 0;       // samples in the window, saturating at chgs::WINDOW
};

void chgSenseBegin();
// Call once per UPS tick (5 s). Reads the ADC, filters it, updates the window and the latches.
void chgSensePoll(ChargeInput& out);

// The raw pin and the reconstructed rail, for the boot log: what the divider actually delivers, so
// a wrong pin or a missing resistor is visible in the serial output instead of being guessed at.
uint16_t chgSensePinMv();
uint16_t chgSenseRailMv();

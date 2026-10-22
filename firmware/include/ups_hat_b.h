#pragma once

#include <Arduino.h>
#include <Wire.h>

// Driver for the Waveshare UPS HAT (B), the r4 power board.
// Slave address 0x42 (INA219 current/voltage monitor; the HAT wires A0 to VS+ so the
// address is 0x40 | 0x02). All INA219 registers are 16 bit, big endian.
//
// The pack is 2S (2x 18650 in series), so pack voltage runs 6.0 V (empty) .. 8.4 V (full).
// The HAT reports the pack through its own shunt; it does not report per-cell voltages or
// a fuel-gauge percentage, so percent/remaining/charge-state are derived here:
//   - percent from the pack voltage under load (INA219 bus voltage)
//   - charging when current flows *into* the pack (positive shunt direction)
// There is no 8.4 V-input telemetry: the barrel charger is not monitored by the INA219.
//
// Reference: https://www.waveshare.com/wiki/UPS_HAT_(B) (INA219 demo) and the INA219 datasheet.

struct UpsStatus {
  bool present = false;

  bool charging = false;       // current into the pack, and the pack is not full
  bool fastCharging = false;   // always false on the HAT (B) - no PD telemetry
  bool vbusPresent = false;    // charger attached (approximated: pack current > 0)
  uint8_t chargeState = 0;     // 0 = idle, 1 = charging, 2 = full

  uint16_t vbusMv = 0;         // pack voltage (INA219 bus voltage)
  int16_t vbusMa = 0;          // pack current, same sign as batteryMa (kept for the UI)
  uint16_t vbusMw = 0;         // pack power

  uint16_t batteryMv = 0;      // pack voltage, millivolts
  int16_t batteryMa = 0;       // + into the pack (charging), - out of the pack
  uint16_t percent = 0;        // derived from batteryMv
  uint16_t remainingMah = 0;   // derived from percent x capacity
  uint16_t dischargeMin = 0;   // derived from remaining capacity / current
  uint16_t chargeMin = 0;      // derived from missing capacity / current
  uint16_t cellMv[4] = {0, 0, 0, 0};  // cellMv[0]/[1] = pack/2 estimate; 2S has no cell data
  uint8_t swRevision = 0;      // unused on the HAT (B)

  uint32_t lastReadMs = 0;
};

class UpsHatB {
 public:
  explicit UpsHatB(TwoWire& wire, uint8_t address = 0x42);

  bool begin();
  bool read(UpsStatus& out);

  // Human-readable state, matching the HAT (E) strings the UI already prints.
  static const char* chargeStateName(uint8_t state);

  // Pack model: 2S 18650, configurable capacity for the time estimates.
  static constexpr float CAPACITY_MAH = 3200.0f;

 private:
  bool writeU16(uint8_t reg, uint16_t value);
  bool readU16(uint8_t reg, uint16_t& value);
  bool readS16(uint8_t reg, int16_t& value);

  TwoWire& _wire;
  uint8_t _address;
  bool _calibrated = false;
  float _currentLsbMa = 0.1f;
};

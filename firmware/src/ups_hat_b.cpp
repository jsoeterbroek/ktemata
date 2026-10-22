#include "ups_hat_b.h"

#include <math.h>

// INA219 register map
namespace {
constexpr uint8_t REG_CONFIG = 0x00;
constexpr uint8_t REG_SHUNT = 0x01;
constexpr uint8_t REG_BUS = 0x02;
constexpr uint8_t REG_POWER = 0x03;
constexpr uint8_t REG_CURRENT = 0x04;
constexpr uint8_t REG_CALIBRATION = 0x05;

// 32 V bus range, gain /8 (±320 mV shunt), 12 bit, 8 sample averaging, continuous shunt+bus.
constexpr uint16_t CONFIG = 0x399F;

// The HAT (B) uses a 0.01 ohm shunt. With a 0.5 mA current LSB that gives a 6.5 A full
// scale, comfortably above the HAT's 5 A output and within the 15-bit register.
constexpr float SHUNT_OHMS = 0.01f;

// 2S 18650 pack model for the derived percentage.
constexpr float PACK_EMPTY_MV = 6000.0f;
constexpr float PACK_FULL_MV = 8400.0f;
}  // namespace

UpsHatB::UpsHatB(TwoWire& wire, uint8_t address) : _wire(wire), _address(address) {}

bool UpsHatB::writeU16(uint8_t reg, uint16_t value) {
  _wire.beginTransmission(_address);
  _wire.write(reg);
  _wire.write(static_cast<uint8_t>(value >> 8));
  _wire.write(static_cast<uint8_t>(value & 0xFF));
  return _wire.endTransmission() == 0;
}

bool UpsHatB::readU16(uint8_t reg, uint16_t& value) {
  _wire.beginTransmission(_address);
  _wire.write(reg);
  if (_wire.endTransmission(false) != 0) {
    return false;
  }
  if (_wire.requestFrom(_address, static_cast<uint8_t>(2)) != 2) {
    while (_wire.available()) {
      _wire.read();
    }
    return false;
  }
  const uint8_t hi = static_cast<uint8_t>(_wire.read());
  const uint8_t lo = static_cast<uint8_t>(_wire.read());
  value = static_cast<uint16_t>((hi << 8) | lo);
  return true;
}

bool UpsHatB::readS16(uint8_t reg, int16_t& value) {
  uint16_t raw;
  if (!readU16(reg, raw)) {
    return false;
  }
  value = static_cast<int16_t>(raw);
  return true;
}

bool UpsHatB::begin() {
  // Any HAT (B) answers as an INA219 once configured; the config register reads back.
  if (!writeU16(REG_CONFIG, CONFIG)) {
    return false;
  }

  uint16_t cfg = 0;
  if (!readU16(REG_CONFIG, cfg) || cfg != CONFIG) {
    return false;
  }

  // Calibration for the power/current registers:
  //   cal = trunc(0.04096 / (current_lsb * shunt))
  // Round, because the exact value (8192 for 0.5 mA / 10 mOhm) lands on a float boundary
  // and truncating a hair below it would bias every current reading by ~0.01 %.
  _currentLsbMa = 0.5f;
  const uint16_t cal = static_cast<uint16_t>(
      lroundf(0.04096f / ((_currentLsbMa / 1000.0f) * SHUNT_OHMS)));
  _calibrated = writeU16(REG_CALIBRATION, cal);
  return _calibrated;
}

bool UpsHatB::read(UpsStatus& out) {
  if (!_calibrated && !begin()) {
    out.present = false;
    return false;
  }

  uint16_t busRaw = 0;
  int16_t currentRaw = 0;
  uint16_t powerRaw = 0;
  if (!readU16(REG_BUS, busRaw) || !readS16(REG_CURRENT, currentRaw) ||
      !readU16(REG_POWER, powerRaw)) {
    out.present = false;
    return false;
  }

  // Bus voltage: bits 15..3, 4 mV per LSB. Bit 1 = conversion ready, bit 0 = math overflow.
  const uint16_t busMv = static_cast<uint16_t>((busRaw >> 3) * 4);
  const int32_t currentMa = lroundf(static_cast<float>(currentRaw) * _currentLsbMa);
  // power register: 20 x current LSB per bit (watts) -> milliwatts
  const uint32_t powerMw = static_cast<uint32_t>(powerRaw) * static_cast<uint32_t>(_currentLsbMa * 20.0f);

  out.batteryMv = busMv;
  out.vbusMv = busMv;
  out.batteryMa = static_cast<int16_t>(currentMa);
  out.vbusMa = out.batteryMa;
  out.vbusMw = static_cast<uint16_t>(powerMw > 65535 ? 65535 : powerMw);

  // Percentage from the 2S pack voltage (linear, clamped).
  float pct = (static_cast<float>(busMv) - PACK_EMPTY_MV) * 100.0f / (PACK_FULL_MV - PACK_EMPTY_MV);
  if (pct < 0.0f) pct = 0.0f;
  if (pct > 100.0f) pct = 100.0f;
  out.percent = static_cast<uint16_t>(pct + 0.5f);

  const float remaining = CAPACITY_MAH * (pct / 100.0f);
  out.remainingMah = static_cast<uint16_t>(remaining);

  // Sign convention: the HAT sources current into the Pi, so a discharging pack reads
  // negative here. Charging means current flowing into the pack.
  const bool currentIntoPack = out.batteryMa > 20;
  out.charging = currentIntoPack && out.percent < 99;
  out.vbusPresent = currentIntoPack;
  out.fastCharging = false;
  out.chargeState = out.percent >= 99 ? 2 : (out.charging ? 1 : 0);

  const float amps = fabsf(static_cast<float>(out.batteryMa)) / 1000.0f;
  if (amps > 0.05f) {
    const float hours = (out.charging ? (CAPACITY_MAH - remaining) : remaining) / (amps * 1000.0f);
    const uint16_t minutes = static_cast<uint16_t>(hours * 60.0f);
    if (out.charging) {
      out.chargeMin = minutes;
    } else {
      out.dischargeMin = minutes;
    }
  }

  // No per-cell telemetry on the HAT (B): report the pack split evenly.
  out.cellMv[0] = busMv / 2;
  out.cellMv[1] = busMv / 2;
  out.cellMv[2] = 0;
  out.cellMv[3] = 0;

  out.present = true;
  out.lastReadMs = millis();
  return true;
}

const char* UpsHatB::chargeStateName(uint8_t state) {
  switch (state) {
    case 0:
      return "discharging";
    case 1:
      return "charging";
    case 2:
      return "full";
    default:
      return "?";
  }
}

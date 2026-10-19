#include "ups_hat_e.h"

UpsHatE::UpsHatE(TwoWire& wire, uint8_t address)
    : _wire(wire), _address(address) {}

bool UpsHatE::readBytes(uint8_t reg, uint8_t* buf, size_t len) {
  _wire.beginTransmission(_address);
  _wire.write(reg);
  if (_wire.endTransmission(false) != 0) {
    return false;
  }

  const size_t got = _wire.requestFrom(_address, static_cast<uint8_t>(len));
  if (got != len) {
    // Drain anything that did arrive so the bus stays in sync.
    while (_wire.available()) {
      _wire.read();
    }
    return false;
  }

  for (size_t i = 0; i < len; ++i) {
    buf[i] = static_cast<uint8_t>(_wire.read());
  }
  return true;
}

bool UpsHatE::readU16(uint8_t reg, uint16_t& value) {
  uint8_t b[2];
  if (!readBytes(reg, b, sizeof(b))) {
    return false;
  }
  value = static_cast<uint16_t>(b[0]) | (static_cast<uint16_t>(b[1]) << 8);
  return true;
}

bool UpsHatE::readS16(uint8_t reg, int16_t& value) {
  uint16_t raw;
  if (!readU16(reg, raw)) {
    return false;
  }
  value = static_cast<int16_t>(raw);
  return true;
}

bool UpsHatE::begin() {
  // Register 0x00 is documented as the fixed ID 0x0a.
  uint8_t id = 0;
  if (!readBytes(0x00, &id, 1)) {
    return false;
  }
  return id == 0x0A || id == 0x0B;
}

bool UpsHatE::read(UpsStatus& out) {
  uint8_t status = 0;
  if (!readBytes(0x02, &status, 1)) {
    out.present = false;
    return false;
  }

  out.charging = (status & 0x80) != 0;
  out.fastCharging = (status & 0x40) != 0;
  out.vbusPresent = (status & 0x20) != 0;
  out.chargeState = status & 0x07;

  bool ok = true;
  ok &= readU16(0x10, out.vbusMv);
  ok &= readS16(0x12, out.vbusMa);
  ok &= readU16(0x14, out.vbusMw);
  ok &= readU16(0x20, out.batteryMv);
  ok &= readS16(0x22, out.batteryMa);
  ok &= readU16(0x24, out.percent);
  ok &= readU16(0x26, out.remainingMah);
  ok &= readU16(0x28, out.dischargeMin);
  ok &= readU16(0x2A, out.chargeMin);

  uint8_t cells[8];
  if (readBytes(0x30, cells, sizeof(cells))) {
    for (int i = 0; i < 4; ++i) {
      out.cellMv[i] = static_cast<uint16_t>(cells[i * 2]) |
                      (static_cast<uint16_t>(cells[i * 2 + 1]) << 8);
    }
  }

  uint8_t sw = 0;
  if (readBytes(0x50, &sw, 1)) {
    out.swRevision = sw;
  }

  // Plausibility clamp: a disconnected/blank pack can report 0xffff.
  if (out.percent > 100) {
    out.percent = 0;
  }

  out.present = ok;
  out.lastReadMs = millis();
  return ok;
}

const char* UpsHatE::chargeStateName(uint8_t state) {
  switch (state) {
    case 0:
      return "standby";
    case 1:
      return "trickle";
    case 2:
      return "CC charge";
    case 3:
      return "CV charge";
    case 4:
      return "pending";
    case 5:
      return "full";
    case 6:
      return "timeout";
    default:
      return "?";
  }
}

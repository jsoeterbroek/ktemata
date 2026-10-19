#pragma once

#include <Arduino.h>
#include <Wire.h>

// Driver for the Waveshare UPS HAT (E), register map V2.
// Slave address 0x2D. All multi-byte values are little endian:
// low byte at the lower register address.
//
// Reference: https://www.waveshare.com/wiki/UPS_HAT_(E)_Register
struct UpsStatus {
  bool present = false;

  bool charging = false;       // reg 0x02 bit 7
  bool fastCharging = false;   // reg 0x02 bit 6
  bool vbusPresent = false;    // reg 0x02 bit 5
  uint8_t chargeState = 0;     // reg 0x02 bits 2..0

  uint16_t vbusMv = 0;         // 0x10/0x11
  int16_t vbusMa = 0;          // 0x12/0x13, negative = output
  uint16_t vbusMw = 0;         // 0x14/0x15

  uint16_t batteryMv = 0;      // 0x20/0x21
  int16_t batteryMa = 0;       // 0x22/0x23, + charging, - discharging
  uint16_t percent = 0;        // 0x24/0x25
  uint16_t remainingMah = 0;   // 0x26/0x27
  uint16_t dischargeMin = 0;   // 0x28/0x29
  uint16_t chargeMin = 0;      // 0x2a/0x2b
  uint16_t cellMv[4] = {0, 0, 0, 0};  // 0x30..0x37
  uint8_t swRevision = 0;      // 0x50

  uint32_t lastReadMs = 0;
};

class UpsHatE {
 public:
  UpsHatE(TwoWire& wire, uint8_t address = 0x2D);

  bool begin();
  bool read(UpsStatus& out);

  // Human-readable charge state from register 0x02.
  static const char* chargeStateName(uint8_t state);

 private:
  bool readBytes(uint8_t reg, uint8_t* buf, size_t len);
  bool readU16(uint8_t reg, uint16_t& value);
  bool readS16(uint8_t reg, int16_t& value);

  TwoWire& _wire;
  uint8_t _address;
};

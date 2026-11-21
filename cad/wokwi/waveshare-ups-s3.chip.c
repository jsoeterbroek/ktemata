// Wokwi Custom Chip - For docs and examples see:
// https://docs.wokwi.com/chips-api/getting-started
//
// SPDX-License-Identifier: MIT
// Copyright 2023 Joost Soeterbroek

#include "wokwi-api.h"
#include <stdio.h>
#include <stdlib.h>

// Waveshare UPS 3S typically uses INA219 at 0x41 or 0x42
#define INA219_ADDR 0x41

// INA219 Register Map
#define REG_CONFIG        0x00
#define REG_SHUNT_VOLTAGE 0x01
#define REG_BUS_VOLTAGE   0x02
#define REG_POWER         0x03
#define REG_CURRENT       0x04
#define REG_CALIBRATION   0x05

typedef struct {
  uint8_t reg_pointer;
  uint8_t byte_index;
  uint16_t registers[6];
  uint32_t bus_voltage_attr;
  uint32_t shunt_voltage_attr;
} chip_state_t;

static void update_sensor_values(chip_state_t *chip) {
  // Read values from Wokwi UI sliders
  uint32_t bus_mv = attr_read(chip->bus_voltage_attr);
  int32_t shunt_uv = (int32_t)attr_read(chip->shunt_voltage_attr);

  // INA219 Bus Voltage Register (0x02): 4mV per LSB, shifted left by 3 bits
  uint16_t bus_raw = (bus_mv / 4) << 3;
  chip->registers[REG_BUS_VOLTAGE] = bus_raw;

  // INA219 Shunt Voltage Register (0x01): 10uV per LSB
  int16_t shunt_raw = (int16_t)(shunt_uv / 10);
  chip->registers[REG_SHUNT_VOLTAGE] = (uint16_t)shunt_raw;

  // Simplified Current & Power calculation based on 0.1 ohm shunt resistor
  // Assuming standard Waveshare calibration (Current LSB ~ 0.1mA)
  int16_t current_raw = (int16_t)(shunt_uv / 10); 
  chip->registers[REG_CURRENT] = (uint16_t)current_raw;

  uint16_t power_raw = (uint16_t)((abs(current_raw) * (bus_mv / 1000)) / 20);
  chip->registers[REG_POWER] = power_raw;
}

static bool on_i2c_connect(void *user_data, uint32_t address, bool read) {
  chip_state_t *chip = (chip_state_t *)user_data;
  if (address == INA219_ADDR) {
    chip->byte_index = 0;
    if (read) {
      update_sensor_values(chip);
    }
    return true; // ACK
  }
  return false; // NACK
}

static uint8_t on_i2c_read(void *user_data) {
  chip_state_t *chip = (chip_state_t *)user_data;
  uint16_t val = 0;

  if (chip->reg_pointer < 6) {
    val = chip->registers[chip->reg_pointer];
  }

  // INA219 transmits 16-bit registers MSB first
  uint8_t data = (chip->byte_index == 0) ? (val >> 8) & 0xFF : (val & 0xFF);
  chip->byte_index++;
  return data;
}

static bool on_i2c_write(void *user_data, uint8_t data) {
  chip_state_t *chip = (chip_state_t *)user_data;

  if (chip->byte_index == 0) {
    // First byte written sets the register pointer
    chip->reg_pointer = data;
  } else if (chip->reg_pointer < 6) {
    // Subsequent bytes write to the 16-bit register (MSB then LSB)
    if (chip->byte_index == 1) {
      chip->registers[chip->reg_pointer] = (data << 8);
    } else if (chip->byte_index == 2) {
      chip->registers[chip->reg_pointer] |= data;
    }
  }
  chip->byte_index++;
  return true; // ACK
}

void chip_init(void) {
  chip_state_t *chip = malloc(sizeof(chip_state_t));
  chip->reg_pointer = 0;
  chip->byte_index = 0;
  chip->registers[REG_CONFIG] = 0x399F; // Default INA219 reset config
  chip->registers[REG_CALIBRATION] = 4096;

  chip->bus_voltage_attr = attr_init("busVoltage", 11800); // Default 11.8V (3S Li-ion)
  chip->shunt_voltage_attr = attr_init("shuntVoltage", -15000); // Default discharging

  const i2c_config_t i2c_config = {
    .user_data = chip,
    .address = INA219_ADDR,
    .scl = pin_init("SCL", INPUT),
    .sda = pin_init("SDA", INPUT),
    .connect = on_i2c_connect,
    .read = on_i2c_read,
    .write = on_i2c_write,
  };

  i2c_init(&i2c_config);
  printf("Waveshare UPS S3 (INA219) initialized at 0x%02X\n", INA219_ADDR);
}

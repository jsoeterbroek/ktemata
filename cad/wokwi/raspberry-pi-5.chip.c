// Wokwi Custom Chip - For docs and examples see:
// https://docs.wokwi.com/chips-api/getting-started
//
// SPDX-License-Identifier: MIT
// Copyright 2023 Joost Soeterbroek

#include "wokwi-api.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  uart_dev_t uart0;
  uint32_t ping_attr;
  uint8_t last_ping;
} chip_state_t;

static void on_uart_rx_data(void *user_data, uint8_t byte) {
  chip_state_t *chip = (chip_state_t *)user_data;
  
  // Print incoming bytes from the ESP32-S3 to the Wokwi Chips Console
  printf("%c", byte);

  // When the ESP32 sends a newline, reply like a running Pi service
  if (byte == '\n') {
    const char *ack = "PI5:ACK\n";
    uart_write(chip->uart0, (uint8_t *)ack, strlen(ack));
  }
}

static void on_timer_event(void *user_data) {
  chip_state_t *chip = (chip_state_t *)user_data;
  uint8_t ping = (uint8_t)attr_read(chip->ping_attr);

  // Send a test message to the ESP32-S3 when the UI slider is toggled to 1
  if (ping == 1 && chip->last_ping == 0) {
    const char *msg = "PI5:STATUS_REQ\n";
    uart_write(chip->uart0, (uint8_t *)msg, strlen(msg));
    printf("[RPi5 Stub] Sent: %s", msg);
  }
  chip->last_ping = ping;
}

void chip_init(void) {
  chip_state_t *chip = malloc(sizeof(chip_state_t));
  chip->ping_attr = attr_init("sendHeartbeat", 0);
  chip->last_ping = 0;

  const uart_config_t uart_config = {
    .user_data = chip,
    .rx = pin_init("USB_FB_SERIAL", INPUT_PULLUP),
    .tx = pin_init("USB_FB_SERIAL", OUTPUT),
    .baud_rate = 115200,
    .rx_data = on_uart_rx_data,
  };
  chip->uart0 = uart_init(&uart_config);

  const timer_config_t timer_config = {
    .callback = on_timer_event,
    .user_data = chip,
  };
  timer_t timer_id = timer_init(&timer_config);
  timer_start(timer_id, 500000, true); // Check UI slider every 500ms

  printf("Raspberry Pi 5 Stub initialized (115200 baud)\n");
}

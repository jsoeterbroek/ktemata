#include "SPI.h"
#include "Adafruit_GFX.h"
#include "Adafruit_ILI9341.h"

#define TFT_DC 35
#define TFT_CS 3
#define TFT_MOSI 37
#define TFT_CLK 36


Adafruit_ILI9341 tft = Adafruit_ILI9341(TFT_CS, TFT_DC, TFT_MOSI, TFT_CLK);

void setup() {
  Serial.begin(115200); 
  Serial.println("Welcome to Wokwi, CORE-S3");
  
 
  tft.begin();

  // Configure the direction of the display
  const uint8_t mode = 0xc8;
  tft.sendCommand(ILI9341_MADCTL, &mode, 1);

  tft.setCursor(88, 60);
  tft.setTextColor(ILI9341_RED);
  tft.setTextSize(3);
  tft.println("CORE-S3");
}

const uint32_t colors[] = {
  ILI9341_GREEN,
  ILI9341_CYAN,
  ILI9341_MAGENTA,
  ILI9341_YELLOW,
};
uint8_t colorIndex = 0;

void loop() {
  tft.setTextSize(2);
  tft.setCursor(36, 106);
  tft.setTextColor(colors[colorIndex++ % 4]);
  tft.println("Welcome to Wokwi!");
  delay(250);
}
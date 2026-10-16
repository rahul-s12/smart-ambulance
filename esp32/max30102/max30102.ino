
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"

MAX30105 sensor;

long lastBeat = 0;
float bpm = 0;

void setup() {
  Serial.begin(115200);
  Wire.begin();

  Serial.println("Initializing MAX30102...");

  if (!sensor.begin(Wire, I2C_SPEED_STANDARD)) {
    Serial.println("MAX30102 not detected!");
    while (1);
  }

  sensor.setup();
  sensor.setPulseAmplitudeRed(0x0A);
  sensor.setPulseAmplitudeGreen(0);

  Serial.println("Place your finger on the sensor");
}

void loop() {
  long irValue = sensor.getIR();

  if (irValue < 50000) {
    Serial.println("No finger detected");
    lastBeat = 0;
    delay(100);
    return;
  }

  if (checkForBeat(irValue)) {
    long currentTime = millis();

    if (lastBeat != 0) {
      long delta = currentTime - lastBeat;
      bpm = 60000.0 / delta;

      if (bpm > 20 && bpm < 255) {
        Serial.print("Heart Rate: ");
        Serial.print(bpm);
        Serial.println(" BPM");
      }
    }

    lastBeat = currentTime;
  }
}

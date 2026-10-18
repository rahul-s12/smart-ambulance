#include <Wire.h>
#include "MAX30100_PulseOximeter.h"

#define REPORTING_PERIOD_MS 1000

PulseOximeter pox;
uint32_t lastReport = 0;

void onBeatDetected() { Serial.println("Beat detected!"); }

void setup() {
  Serial.begin(9600);
  Serial.println("Initializing MAX30100...");
  if (!pox.begin()) {
    Serial.println("MAX30100 not detected!");
    while (1);
  }
  Serial.println("MAX30100 initialized!");
  pox.setOnBeatDetectedCallback(onBeatDetected);
}

void loop() {
  pox.update();
  if (millis() - lastReport >= REPORTING_PERIOD_MS) {
    Serial.print("Heart Rate: ");
    Serial.print(pox.getHeartRate());
    Serial.print(" BPM | SpO2: ");
    Serial.print(pox.getSpO2());
    Serial.println(" %");
    lastReport = millis();
  }
}

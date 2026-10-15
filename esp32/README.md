# ESP32 Firmware

This folder is the starting point for ESP-IDF firmware deployed to the ambulance's ESP32. Initial inputs come from commonly available sensors or generated scenarios that simulate telemetry.

## Responsibilities

- Acquire available sensor values at configurable rates and apply explicit simulation mappings where required.
- Preserve actual units for direct measurements and identify mapped/generated vitals as simulated.
- Mark unavailable or invalid readings explicitly, without manufacturing a valid zero.
- Assign device identity, boot identity, sequence numbers, and acquisition timing to readings.
- Update the local OLED independently of phone and cloud connectivity.
- Encode and transmit agreed telemetry over BLE, with defined message framing and reconnect behavior.
- Use bounded queues so display or transport delays do not stall acquisition; expose dropped-reading or overflow counts.

Phone GPS, persistent phone uploads, MQTT/CoAP fallback, and cloud processing belong to other components.

## How to use this folder

1. Identify the ESP32 board, available sensors, OLED, pin assignments, and electrical requirements using the supporting references.
2. Agree on acquisition rates, simulation mappings, packet fields, and BLE behavior in `../docs/`.
3. Initialize an ESP-IDF project in this existing folder and record the selected ESP-IDF version and target board here.
4. Document exact environment setup, configuration, build, flash, and serial-monitor commands once the project exists.
5. Verify one input and OLED output locally, then integrate BLE with the phone using the agreed packet examples.
6. Verify invalid inputs, BLE disconnection, reconnection, device restart, and queue overflow. Document whether disconnected readings are buffered and what is lost when capacity is exceeded.

## Current state

No ESP-IDF project, board configuration, or firmware is initialized yet. `.gitkeep` preserves the planned component location.

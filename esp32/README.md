# ESP32 Firmware

This folder is the ESP-IDF firmware project deployed to the ambulance's ESP32. Initial inputs will come from commonly available sensors or generated scenarios that simulate telemetry.

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
3. Configure an ESP-IDF environment and select the target board using `idf.py set-target`.
4. Build with `idf.py build`, flash with `idf.py -p PORT flash`, and inspect logs with `idf.py -p PORT monitor`.
5. The current implementation is limited to `components/ble/`. It advertises as `Smart_Ambulance`, pairs using LE Secure Connections with Just Works confirmation, persists bond keys in NVS, exposes the reference GATT service, and responds to the one-byte test command `0x01` with a simulated vital frame.
6. Verify pairing, encryption, bonded reconnection, status reads, notification subscription, test-command delivery, and reconnection before adding inputs or OLED output.

## Current state

The ESP-IDF project and BLE component are initialized. Inputs, OLED output, task coordination, and physical sensor support are not implemented yet.

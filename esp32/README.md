# ESP32 Firmware

This folder is the ESP-IDF firmware project deployed to the ambulance's ESP32. Initial inputs will come from commonly available sensors or generated scenarios that simulate telemetry.

## Responsibilities

- Acquire available sensor values at configurable rates and apply explicit simulation mappings where required.
- Preserve actual units for direct measurements and identify mapped/generated vitals as simulated.
- Mark unavailable or invalid readings explicitly, without manufacturing a valid zero.
- Assign device identity, boot identity, sequence numbers, and acquisition timing to readings.
- Update the local OLED independently of phone and cloud connectivity.
- Publish telemetry over standard Bluetooth SIG GATT services and characteristics, with defined message framing and reconnect behavior. Do not add a project-specific custom BLE service unless the team explicitly changes this decision.
- Use bounded queues so display or transport delays do not stall acquisition; expose dropped-reading or overflow counts.

Phone GPS, persistent phone uploads, MQTT/CoAP fallback, and cloud processing belong to other components.

## How to use this folder

1. Identify the ESP32 board, available sensors, OLED, pin assignments, and electrical requirements using the supporting references.
2. Agree on acquisition rates, simulation mappings, packet fields, and BLE behavior in `../docs/`.
3. Configure an ESP-IDF environment and select the target board using `idf.py set-target`.
4. Build with `idf.py build`, flash with `idf.py -p PORT flash`, and inspect logs with `idf.py -p PORT monitor`.
5. The current implementation is limited to `components/ble/`; `main/` only initializes it. The Arduino sketches and the remaining component folders are preserved unchanged for later integration.
6. BLE advertises as `Smart_Ambulance`, pairs using LE Secure Connections with Just Works confirmation, persists bond keys in NVS, and exposes the Bluetooth SIG **Generic Health Sensor Service** (GHSS, `0x1840`). Bonding is triggered by the encrypted control-point access, so Android owns one pairing flow per connection. It uses `Live Health Observations` (`0x2B8B`, notifications) for vital observations and `GHS Control Point` (`0x2BF4`, write/indicate) to start or stop streaming. Generic Access (`0x1800`) and Generic Attribute (`0x1801`) are mandatory core services supplied by the BLE stack.
7. The service UUID is standard, not custom. The BLE component produces temporary simulated observations once per second after an encrypted client subscribes and writes `0x01` to the control point. Write `0x02` to stop the stream.
8. Control-point writes require link encryption (`WRITE_ENC`), so a client must complete pairing/encryption before it can start or stop telemetry.
9. Verify pairing, encryption, bonded reconnection, service discovery for `0x1840`, notification subscription for `0x2B8B`, control-point indication subscription for `0x2BF4`, periodic observations after `0x01`, stream stop after `0x02`, and reconnection before adding inputs or OLED output.

## Current state

The ESP-IDF project and BLE component are initialized. Arduino sketches, OLED output, task coordination outside BLE, and physical sensor integration remain unchanged.

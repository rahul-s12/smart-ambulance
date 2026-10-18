# Phone Application

This folder is the starting point for the Flutter application running on the ambulance phone. The phone acts as the gateway between ESP32 BLE telemetry and cloud services.

## Responsibilities

- Discover and connect to the ESP32 through standard Bluetooth SIG GATT, decode Generic Health Sensor Service observations, and detect sequence gaps and device restarts.
- Associate readings with the active demonstration session while preserving device and reading identity.
- Add phone location, location accuracy, and its timestamp when available. Missing GPS must not block telemetry upload.
- Persist accepted readings locally before upload and retain pending readings across application restarts.
- Upload through MQTT, use CoAP according to the agreed fallback policy, and process backend acceptance or rejection messages.
- Display BLE connection, upload state, pending readings, cloud results, and data freshness.

Sensor acquisition and OLED control belong to `esp32/`. Durable server storage and authoritative processing belong to `cloud/`.

## How to use this folder

1. Review `../docs/` for the agreed BLE layout, telemetry contract, session rules, and acknowledgment behavior.
2. Initialize the Flutter project in this existing folder when application development begins. Review generated files so this guide is preserved or incorporated.
3. Record the Flutter version, target platform, permissions, dependencies, and exact setup/run commands here after choosing them.
4. Implement BLE reception against the ESP32's Bluetooth SIG Generic Health Sensor Service (GHSS, `0x1840`), not a custom service. Subscribe to `Live Health Observations` (`0x2B8B`) and use `GHS Control Point` (`0x2BF4`) for start/stop commands and responses.
5. Add local persistence and verify that pending readings survive restart, then integrate cloud upload and confirmation.
6. Verify disconnection, reconnection, unavailable GPS, repeated uploads, and transport switching against the shared requirements.

## Current state

No Flutter project or runnable application is present yet. `.gitkeep` preserves the planned component location and may remain until initialization.

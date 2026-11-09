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

An Android Flutter project is present. The first implemented screen is a BLE gateway for the ESP32 demonstration firmware:

- scans for the Generic Health Sensor Service (`0x1840`);
- connects to `Smart_Ambulance`, discovers `0x2B8B` and `0x2BF4`, and enables their notification / indication subscriptions;
- sends `0x01` to start telemetry and `0x02` to stop it; and
- decodes the simulated heart-rate, SpO2, and temperature observations for display.
- includes foreground phone-GPS tracking, displaying latitude, longitude, accuracy, speed when available, and latest-fix time.
- includes local trip setup for an ambulance ID and assigned hospital. The
  selected hospital provides its preconfigured ambulance-entrance coordinates;
  drivers do not enter coordinates.
- uploads GPS during an active trip to the cloud location endpoint and displays
  the server-calculated route distance, ETA, and arrival time when available.

## Run the BLE gateway

1. Install Android Studio and its Android SDK, then run `flutter doctor` until the Android toolchain is available.
2. Connect an Android phone with developer mode and USB debugging enabled, or use an Android emulator with Bluetooth support where available.
3. From this folder, run `flutter pub get` and then `flutter run`.
4. Start the ESP32 firmware, tap **Scan for Smart_Ambulance**, select the device, and complete the phone pairing prompt.
5. Tap **Start telemetry**. The app enables the required GATT subscriptions before sending the `0x01` command.

## Run with live location upload

Start the cloud service first, then supply its reachable base URL when running
Flutter. For an Android emulator use `10.0.2.2` to reach a server on this
computer; a physical phone must use this computer’s LAN address.

```powershell
flutter run --dart-define=CLOUD_API_BASE_URL=http://10.0.2.2:3000
```

The Android development manifest allows clear-text HTTP so the local server can
be tested. Use HTTPS and remove `android:usesCleartextTraffic="true"` before a
production build. GPS updates are sent only after a trip has started. The app
keeps at most one request in flight and then sends the newest GPS fix, avoiding
a backlog when the network is slow.

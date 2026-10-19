# Review 2: screenshots and test evidence

The current BLE firmware generates demonstration readings. Label every capture **Simulated vital signs**. Source code is present for BLE and the Flutter screen; execution results must come from your actual device tests. No test is marked Pass in the presentation before you supply evidence.

## Captures to collect

| Capture | Where and what to show | What it supports |
|---|---|---|
| 01_device_scan.png | In the Flutter app, tap Scan for Smart_Ambulance. Capture the discovered Smart_Ambulance row, including RSSI if shown. | TC1: device discovery |
| 02_connected_ready.png | Select the ESP32, complete pairing, and capture “Connected and ready to start telemetry” with the start button visible. | TC2: connection and characteristic subscriptions |
| 03_streaming_vitals.png | Tap Start telemetry. Show the streaming status, heart rate in bpm, SpO2 in %, temperature in degrees C, and the accepted start event. | TC3: receipt and decoding of simulated observations |
| 04_stopped.png | Tap Stop. Show “Telemetry stopped” and the accepted stop event. Last values may remain visible. | TC4: stop acknowledgement; combine with recording to show updates cease |
| 05_reconnected.png | Tap Disconnect, scan again, select the ESP32 and start streaming again. Capture the resumed state. | TC5: manual reconnection; combine with recording or logs to show the transition |
| 06_esp32_serial.png | ESP-IDF monitor: capture advertising, client connected, Encryption enabled, notification/indication subscription, stream started, and telemetry sent. Use multiple crops if needed. | BLE encryption, subscription and transmitter evidence |
| 07_matched_values.png | Capture the phone and serial output for the same transmission interval. Show matching HR, SpO2 and temperature. | Data integrity check |
| 08_hardware_photo.jpg | Photograph the ESP32 powered and operating alongside the phone. Include only hardware actually used for this BLE demonstration. | Prototype setup context |

Slide 13 in the Wi-Fi/BLE revision contains three spaces: use 02, 03, and 04 or 05. Keep other captures as backup evidence or insert an additional evidence slide. All flowcharts and tables in the deck are already editable; you do not need to paste them.

## One useful screen recording

Record the complete sequence: scan, connect, start, observe several updates, stop, wait to confirm no new updates, disconnect, scan, reconnect, and restart. Approximately 45–90 seconds is usually enough, depending on pairing time. Capture corresponding timestamped serial logs separately. A single still image cannot establish update rate, continuous streaming or successful recovery.

## How to record results

| Test | Execution | Expected result | Record |
|---|---|---|---|
| TC1 | Scan with the ESP32 powered and advertising | Device appears in scan list | Capture 01; observed discovery time |
| TC2 | Select the device and pair | Ready status and subscriptions enabled | Capture 02 and encryption/subscription logs |
| TC3 | Start, observe several samples | App values change and match transmitted values | Capture 03, matched logs and recording |
| TC4 | Stop while streaming | Stop acknowledgement and no new telemetry notifications | Capture 04, stop log and timed recording |
| TC5 | Disconnect and manually reconnect | Advertising resumes and streaming restarts after Start | Capture 05 and sequence recording |

For each, write the date, phone model/Android version, firmware/app revision, actual outcome, Pass/Fail and evidence filename. If it fails, record the failure honestly. Rerun after a fix and keep the new evidence associated with the corrected revision.

The simulator runs on a nominal one-second task delay. This is a configured interval, not a measured delivery guarantee. Do not claim measured latency, delivery reliability, sensor accuracy or clinical validation from these screenshots. For an update-interval result, log successive receipt times and calculate the observed intervals. End-to-end latency needs matched acquisition/receipt timestamps and an appropriate clock reference, which the current UI does not provide.

## Do not include as completed results yet

Cloud uploads, persistent offline queue, MQTT/CoAP switching, hospital dashboard, integrated OLED/sensor pipeline, GPS location, ETA and ML risk prediction require future implementation and tests. The current app requests location permission for BLE-related operation but does not implement GPS tracking. Separate sensor sketches do not prove integration with the current BLE firmware.

## Before sharing captures

Crop to the useful app/log area. Keep text readable. Hide credentials and personal device identifiers if displayed. Use demonstration data throughout.


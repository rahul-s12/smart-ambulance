# Objective 3: Medical-device integration plan

Status: proposed engineering plan, 2 November 2026. No hardware purchases or runtime changes are made by this document. Exact ambulance equipment, protocol access, budget, and clinical partners remain to be confirmed.

## Proposed objective

Design and demonstrate an interoperable acquisition layer that receives measurements from selected medical devices, associates them with an ambulance patient session, and delivers them through the existing phone/cloud backbone with measurement provenance, timestamps, quality indicators, and offline recovery.

Success means demonstrating a documented real-device interface and reliable data delivery. It does not mean that the prototype gateway or dashboard is certified for clinical use.

## Existing backbone and gaps

- ESP-IDF firmware currently targets ESP32-C6 and publishes simulated observations using Generic Health Sensor Service UUID 0x1840.
- Flutter currently receives that demonstration stream and obtains foreground phone GPS. Persistent queuing, cloud upload, and patient-session records remain planned.
- The Node/MongoDB test backend generates simulated readings. Its validator requires heart rate, SpO2, and temperature together and accepts only source.type = simulation.
- The dashboard displays the test feed. Real-device integration requires separate provenance and freshness for each observation.
- Using standard BLE UUIDs alone does not establish full Bluetooth profile conformance or compatibility with commercial devices. Validate message encoding, procedures, and security against the relevant specification before claiming interoperability.

## Recommended architecture

```text
Medical device with documented BLE output --------------------+
                                                             |
Ordinary thermometer --> crew enters confirmed reading -------+--> Flutter gateway
                                                             |     - session/device association
Documented serial device --> approved isolated interface      |     - protocol adapters
                         --> ESP32-C6 --> existing BLE --------+     - observation normalization
                                                             |     - persistent upload queue
USB/Ethernet/vendor SDK device --> compatible host gateway ---+     - phone GPS
                                                                   |
                                                             authenticated upload
                                                                   |
                                                             cloud --> dashboard
```

The phone is already a BLE central and is the preferred initial integration point for compatible BLE instruments. The ESP32 remains useful for prototype acquisition and selected embedded serial adapters; it need not relay every commercial device. If an ESP32 must act as BLE central to a medical device and peripheral to the phone, explicitly develop and verify both roles, connection capacity, timing, and reconnection behavior.

Keep medical-device integration read-only in this objective. Preserve the instrument's local display and alarms independently of phone/cloud availability.

## What the survey does and does not establish

The attached equipment table is a useful list of possible interface families. It is not a compatibility list for particular models. The internal analog signal normally belongs inside the instrument: use the manufacturer's external measurement output rather than opening the instrument or tapping patient-connected circuits.

For each exact model and firmware revision, record:

| Question | Evidence required before selecting the integration |
| --- | --- |
| Is there an accessible data interface? | Manual and physical inspection; identify output port, wireless mode, and required accessory |
| Is it live, spot-check, or retrospective? | Actual packet trace or vendor sample; distinguish streaming from PDF/report/USB-file export |
| Is the protocol available? | GATT layout, packet specification, SDK/API, license/NDA requirements, sample decoder |
| What is exported? | Numeric values, waveform samples, units, timestamps, quality flags, device alarms |
| Does access work with our gateway? | Android compatibility, BLE pairing, USB host class/driver, serial pinout/settings, network setup |
| Is the use appropriate? | Intended use, local authorization, accessories, transport suitability, biomedical engineering review |
| What is the total cost? | Instrument, probes/cuffs, interface cable, SDK/license, isolation, replacements, support |

A Wi-Fi logo does not imply an open API. A USB socket may be for charging, service, or file export. An RS-232 port may provide a printer output rather than live telemetry. A converter changes electrical signaling, not a proprietary packet format.

## Temperature: practical acquisition paths

### Ordinary thermometer with no data output

There is no digital measurement output for an MCU to read. The practical first implementation is a phone form: enter the displayed value, unit, actual measurement time, measurement site/method, and operator identity; confirm it against the display; upload it as a manually transcribed device reading. Record both entry time and measurement time. If the latter is unknown, mark that explicitly.

Do not label this path as automatic acquisition. Do not attach wires to the display or internal sensor of a clinical thermometer as the integration strategy. Camera/OCR can be investigated later as assisted entry, with human confirmation and provenance; it is not the preferred first milestone.

### Connected clinical thermometer

Choose an exact model whose measurements can be accessed by our application through documented BLE, USB, serial, or a supported vendor API. A vendor phone app alone is not proof that third-party access is possible.

For a device implementing Bluetooth Health Thermometer Service, the standard service is 0x1809 and Temperature Measurement is 0x2A1C. Subscribe to indications, decode the specified flags and temperature representation, and handle optional timestamp/type fields. Some instruments instead use proprietary services and need a separate authorized adapter. Intermediate measurements, if available, must remain distinguishable from the final result. See [Bluetooth SIG's service specification](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/HTS_v1.0/out/en/index-en.html) and [Assigned Numbers](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/index-en.html).

Each completed spot measurement creates one observation. For example, a 37.2 C reading at 10:32 should appear as “37.2 C, measured 6 minutes ago” at 10:38. It must not acquire a new measurement timestamp on each dashboard refresh or upload retry.

### Temperature exported by a multiparameter monitor

If the ambulance monitor supports a compatible manufacturer-approved temperature probe and documented output, collect the temperature from the monitor's exported data. Record measurement site/type and whether the value is intermittent or continuous. This may eliminate a separate connected thermometer, but must be verified on the actual model.

A hobby temperature sensor can demonstrate the communication path, but does not establish interchangeable body/core-temperature accuracy or clinical validation.

## Components by implementation level

| Component | First demonstrator | Conditional expansion |
| --- | --- | --- |
| Android phone with BLE and internet | Reuse existing phone; receives devices and uploads readings | Managed rugged phone/tablet if field requirements justify it |
| Existing ESP32-C6 development board | Reuse for existing simulated feed and suitable embedded adapters | Additional MCU only if the selected interface requires it |
| One medical device with accessible output | Borrow/evaluate a documented BLE pulse oximeter or available monitor | Add more exact-model adapters after the first works |
| Temperature source | Existing thermometer with manual entry, or documented connected thermometer | Compatible continuous probe/monitor integration |
| BP source | Optional for first milestone | Connected NIBP instrument with approved cuff and accessible output |
| RS-232 interface | Not needed for a BLE-only device | Manufacturer cable plus appropriately specified isolated RS-232 interface and isolated power where required |
| USB host | Not needed for BLE/manual capture | Compatible Android USB host or Linux gateway, OTG/power arrangement, driver and manufacturer SDK |
| Ethernet/Wi-Fi gateway | Phone connectivity suffices initially | Linux/industrial gateway and router if the selected monitor requires them |
| Power | Bench supplies/power bank for development | Vehicle-rated protected DC-DC supply, fuse, reverse-polarity/transient protection, backup power |
| Packaging | Bench mounting and labelled leads | Secure cleanable enclosure, strain relief, mounting, connectors and cable management |
| Verification equipment | Access to device display, test phone and diagnostic logs | Borrow patient simulator/appropriate instrument analyzer through the lab or biomedical team |

The sensors, signal conditioning, ADC, algorithms, and safety barriers are normally inside a complete medical instrument. Buying that instrument does not also require buying its internal sensor ICs.

For an OEM-module approach, the manufacturer may supply a measurement module plus matched probe, documented host interface, and evaluation kit. Add an MCU/host, power and enclosure as specified by that kit. This entails more integration and system validation than reading a finished instrument. Nonin describes OEM modules and development kits with technical/interface resources on its [OEM page](https://www.nonin.com/oem/); protocol access and suitability must still be confirmed with the supplier.

Do not list MAX30102 boards, generic temperature modules, or simple ECG breakouts as equivalent substitutes for finished medical-grade instruments. They can remain clearly labelled development/demo inputs.

### MCU and wired-interface choices

- Keep the current ESP32-C6 for BLE and documented UART-based acquisition where suitable. Its fixed-function USB Serial/JTAG port is not a general USB host for a USB thermometer or oximeter. See [Espressif's C6 serial documentation](https://docs.espressif.com/projects/esp-idf/en/stable/esp32c6/get-started/establish-serial-connection.html).
- If USB is required, first establish the instrument's USB class, driver, and SDK needs. Select a compatible host only after a bench proof. A USB connector or USB-to-UART cable alone is insufficient.
- RS-232 electrical levels must not connect directly to MCU UART pins. An RS-232 transceiver such as the [TI MAX3232](https://www.ti.com/product/MAX3232) illustrates level conversion; it does not itself provide galvanic isolation or establish a safe medical-system connection. Choose the actual approved interface with the manufacturer/biomedical team, including signal and power isolation requirements.
- Consider a Linux/industrial gateway later for multiple wired devices, vendor SDKs, Ethernet integration, or waveform processing. It is not required for the initial BLE thermometer/oximeter path.

## Software contract changes

Introduce a versioned observation contract so independent instruments can report independently. Keep existing simulation tests and demo behavior; add explicit measured-device and manual-entry ingestion rather than relabelling simulation packets.

Each observation should carry:

- Stable observation ID for retry/deduplication; schema version; ambulance and encounter/session IDs.
- Metric code, value, unit, measurement site/method where relevant.
- Device identity, model/firmware when available, adapter version, acquisition method, and simulation flag.
- Measurement time, gateway receipt time, server receipt time, and timestamp origin/clock uncertainty. Device identity must not depend only on a potentially rotating BLE address.
- Device-reported quality/validity, battery and connection information when available; distinguish unavailable quality from confirmed good quality.
- Original device record identity or a safe reference to captured source data where useful for traceability.

Do not infer missing vitals from other readings or insert zero. One valid temperature observation must be accepted without requiring simultaneous SpO2 and heart rate. A spot oximeter's pulse rate should remain identified as pulse rate, rather than silently treated as an ECG-derived measurement.

The phone persists observations before upload and retains them through restart. Upload retries retain the same observation ID and original acquisition time. Authenticated encrypted transport, application-level acknowledgments after durable storage, and access-controlled dashboard sessions are required before transmitting real patient data. Transport fallback cannot replace absent internet connectivity.

The dashboard needs per-metric source, age, quality, and missing-data states. Delayed queued data enters history without replacing newer measurements. Distinguish instrument-originated alarms from prototype-derived rules and predictions. Freshness expectations depend on the metric and device mode; do not use a single timeout for both continuous pulse observations and intermittent temperature/BP.

## Phased delivery and acceptance criteria

| Phase | Work | Evidence of completion |
| --- | --- | --- |
| 1: equipment/interface audit | Obtain actual ambulance/lab model list; ask for manuals, interface access and sample data; complete compatibility matrix | One exact-model integration selected with accessible protocol and realistic access/cost |
| 2: finish existing backbone | Deliver labelled simulated observations from phone through persistent queue and authenticated backend to dashboard | Phone restart, upload retry, duplicate and offline replay demonstrations |
| 3: temperature workflow | Add manual thermometer entry first; add connected thermometer adapter when accessible | Displayed reading, site, source and original time preserved end to end; no fabricated repeated measurements |
| 4: first automatic medical-device path | Integrate one documented oximeter or monitor; retain original device quality information | Side-by-side device/gateway/dashboard comparison within documented output resolution; independent source identity |
| 5: resilience and association | Exercise two sources, disconnects, bad packets, old device memory, device reboot, clock uncertainty, phone restart and encounter change | No cross-patient mixing, duplicate records, invalid numeric substitution, or stale values presented as new |
| 6: evaluate and report | Measure delivery latency, loss/recovery, battery impact and practical usability | Traceable results, exact supported-model list, limitations and future-work statement |

Use synthetic sessions, manufacturer demo modes, and appropriate simulators for development. Test data delivery and decoding separately from physiological accuracy; matching the device display does not clinically validate the device or our complete system. Any clinical deployment needs the applicable device/system, electrical safety, EMC, privacy and institutional review with qualified partners.

Suggested student-project scope: one automatic medical-device interface, one temperature workflow, and a reliable phone-to-hospital path. A second physical interface can be a stretch goal. If no actual medical instrument is available, report adapter feasibility and simulation separately; do not claim demonstrated medical-device integration.

## Future scope

1. Consolidate multiple vital streams through an accessible multiparameter monitor, while retaining provenance for each parameter.
2. Add documented NIBP, glucose and EtCO2 acquisition. BP and glucose are typically episodic; do not portray them as second-by-second measurements.
3. Add ECG/pleth/capnogram waveforms using separate chunked streaming/storage with sample rate, channel, calibration, gaps and time alignment. Numeric heart rate alone does not establish waveform support.
4. Export observations to a hospital-agreed HL7/FHIR interface, with terminology and unit mapping. [FHIR Observation](https://hl7.org/fhir/observation.html) represents measurements, including vital signs; it does not decode proprietary device ports.
5. Add ultrasound images/reports via the instrument's supported imaging workflow and hospital integration; this is separate from scalar-vital telemetry.
6. Add device fleet management, calibration/service records, secure provisioning, signed software updates and gateway health monitoring.
7. Evaluate a vehicle-powered industrial gateway/router with backup power and stronger unattended operation when phone-based operation becomes a limitation.
8. Investigate clinician-confirmed OCR for legacy displays and evaluate transcription errors before considering routine use.
9. Evaluate predictive models only after defining the clinical target and obtaining suitable authorized data and validation; connectivity alone does not validate a prediction.

Ventilator and infusion-pump expansion should initially export status/measurements only. Remote actuation or therapy changes are a separate project requiring a different safety and validation process.

## Information needed to finalize a purchase list

Exact device model/firmware and accessible port, budget, instrument access through the college/hospital, required parameters, spot versus continuous use, and whether the objective is a lab demonstration or intended ambulance deployment. Until those are known, the table above is a conditional bill of materials, not a verified shopping list.

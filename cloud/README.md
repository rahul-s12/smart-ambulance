# Cloud Processing

This folder is the starting point for the backend that accepts telemetry from the phone and provides stored readings and processing results to clients. It can run locally during development; a hosting provider has not been selected.

## Responsibilities

- Accept authenticated telemetry through MQTT and the planned CoAP fallback using the same logical processing path.
- Validate schema versions, identifiers, timestamps, units, quality, and simulation metadata.
- Deduplicate readings across retries and transports, and persist accepted data.
- Confirm application-level acceptance after durable storage and return defined rejection reasons for invalid messages.
- Keep historical replay separate from the latest reading so delayed uploads do not replace newer state.
- Apply configurable demonstration rules and deliver results to the phone and dashboard.
- Support later prediction and ETA work once targets, datasets, destinations, and calculation methods are defined.

Training and evaluation code may be placed in this existing folder when that work begins. Keep its execution and dependencies distinct from the running ingestion path; a model is not required for the first telemetry milestone.

## How to use this folder

1. Review the requirements and interface agreements in `../docs/`.
2. Select the backend runtime, database, broker, and client update mechanism, then document the decisions before initialization.
3. Add implementation files here and record dependency installation, local service startup, configuration, and run commands in this README.
4. Connect one MQTT ingestion path to validation and storage, then expose stored readings to the dashboard.
5. Verify reading identity, durable acceptance, duplicates, delayed messages, and invalid payload handling using synthetic examples.
6. Add CoAP to the same processing path and verify that switching transports cannot create duplicate records or repeated alert events.
7. Add processing capabilities incrementally with reproducible inputs and expected results.

## Configuration

Document required configuration names when implemented. Keep actual credentials, private keys, and patient records out of Git.

## Current state

No backend, database, broker configuration, or model is initialized yet. `.gitkeep` preserves the planned component location.

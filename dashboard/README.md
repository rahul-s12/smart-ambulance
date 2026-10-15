# Hospital Dashboard

This folder is the starting point for the hospital-facing web application. It presents ambulance session information and cloud processing results to hospital staff.

## Responsibilities

- Display the selected ambulance/session and its latest readings with units, quality, and simulation labels.
- Show historical trends without treating replayed data as current telemetry.
- Show location and its age, plus ETA when a defined backend calculation is available.
- Present alerts and prediction results with their timestamps and processing context.
- Distinguish live, stale, disconnected, and unavailable states.
- Retrieve data through authorized backend interfaces rather than direct BLE connections or embedded database credentials.

The backend owns ingestion, durable storage, and authoritative processing. The dashboard owns presentation and user interaction.

## How to use this folder

1. Review the agreed session, telemetry, result, and freshness definitions in `../docs/`.
2. Select the web framework and initialize it in this existing folder when dashboard development begins.
3. Document dependency installation, backend connection configuration, and exact development/build commands here.
4. Build the initial view with synthetic responses, then connect it to the backend's history and live-update interfaces.
5. Verify normal readings, missing values, delayed history, connection loss, and stale location without relying on a running ESP32.
6. Confirm the UI clearly identifies simulated data and does not present an unavailable prediction or ETA as a valid result.

## Current state

No dashboard framework or runnable web application is initialized yet. Localhost development does not require a cloud deployment. `.gitkeep` preserves this component location.

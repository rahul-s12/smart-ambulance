# Hospital Dashboard

Local hospital-facing dashboard for the Smart Ambulance cloud telemetry feed.

## Responsibilities

- Display the selected ambulance/session and its latest readings with units, quality, and simulation labels.
- Show historical trends without treating replayed data as current telemetry.
- Show location and its age, plus ETA when a defined backend calculation is available.
- Present alerts and prediction results with their timestamps and processing context.
- Distinguish live, stale, disconnected, and unavailable states.
- Retrieve data through authorized backend interfaces rather than direct BLE connections or embedded database credentials.

The backend owns ingestion, durable storage, and authoritative processing. The dashboard owns presentation and user interaction.

## Run locally

1. Start the cloud service from `../cloud` with `npm start`.
2. In this folder, run `npm start`.
3. Open `http://localhost:5173`.

The dashboard proxies requests to `http://localhost:3000`, so the browser only communicates with the local dashboard origin. Use `API_ORIGIN` to change the backend target when needed.

## Current dashboard behavior

- Displays MongoDB-backed simulated readings and live server-sent updates.
- Shows heart rate, SpO₂, temperature, reading history, and a trend chart.
- Makes unavailable location, ETA, alerts, and ML results explicit. It does not create placeholder clinical values.
- Shows connection and storage state, with error feedback when the cloud service is unavailable.

No third-party dependencies are required.

# Cloud Processing

This is the local MongoDB-backed test backend for the hospital dashboard. It generates one clearly labelled simulated ambulance reading per second, stores it in MongoDB, and exposes current, historical, and live-stream endpoints. It does not yet receive readings from the Flutter application.

## Responsibilities

- Accept authenticated telemetry through MQTT and the planned CoAP fallback using the same logical processing path.
- Validate schema versions, identifiers, timestamps, units, quality, and simulation metadata.
- Deduplicate readings across retries and transports, and persist accepted data.
- Confirm application-level acceptance after durable storage and return defined rejection reasons for invalid messages.
- Keep historical replay separate from the latest reading so delayed uploads do not replace newer state.
- Apply configurable demonstration rules and deliver results to the phone and dashboard.
- Support later prediction and ETA work once targets, datasets, destinations, and calculation methods are defined.

Training and evaluation code may be placed in this existing folder when that work begins. Keep its execution and dependencies distinct from the running ingestion path; a model is not required for the first telemetry milestone.

## Run locally

1. Run `npm install` in this folder.
2. Copy `.env.example` to `.env` and add your own `MONGODB_URI`.
3. Run `npm start`.

The service starts at `http://localhost:3000` unless `PORT` is changed. It generates telemetry immediately. If Atlas is unavailable, it runs in `memory-fallback` mode and retries MongoDB every 15 seconds. The `/health` response reports `storage: "memory-fallback"` until MongoDB reconnects; this mode is for local dashboard testing only and is not durable.

If Node reports `querySrv ECONNREFUSED` while using a `mongodb+srv://` URI, set `MONGODB_DNS_SERVER=1.1.1.1` in `.env`. This bypasses a local DNS resolver that rejects the Atlas SRV lookup; it does not route database traffic through Cloudflare.

The backend defaults to IPv4 (`MONGODB_IP_FAMILY=4`) because recent Node releases can otherwise prefer IPv6. Set it explicitly in your existing `.env` if it is not already present.

## Test endpoints

| Endpoint | Purpose |
| --- | --- |
| `GET /health` | Confirms the backend and generator status. |
| `GET /api/ambulances` | Lists ambulances with their latest reading time. |
| `GET /api/ambulances/SIM-AMB-001/latest` | Returns the newest simulated reading. |
| `GET /api/ambulances/SIM-AMB-001/readings?limit=30` | Returns recent simulated readings. |
| `GET /api/stream` | Server-sent event stream for dashboard live updates. |

`POST /api/telemetry` already validates the same reading shape for the later app-to-cloud integration. The current test backend accepts only readings with `source.type: "simulation"` to prevent the dashboard from mistaking a test feed for real data.

The local API permits browser requests without credentials so the local hospital dashboard can use a separate development port. Restrict allowed origins before any non-local deployment.

Run `npm test` to verify schema validation and the API using the in-memory test store. This checks the logic without a MongoDB URI; add your URI and start the service to verify persistence against your cluster.

## Configuration

Document required configuration names when implemented. Keep actual credentials, private keys, and patient records out of Git.

## Current state

MongoDB is the selected test storage. MQTT, CoAP, authentication, the phone upload client, GPS, ETA, alerts, and ML remain outside this test backend.

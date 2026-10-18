# Smart Ambulance

Smart Ambulance is a prototype for collecting patient-related telemetry in an ambulance and making it available to a hospital before arrival. The system connects ESP32 firmware, a Flutter phone application, cloud processing, and a hospital web dashboard.

The initial version uses commonly available sensors and generated scenarios to simulate medical telemetry. Simulated values must be clearly identified; they are demonstration data, not clinical measurements or validated medical predictions.

## System flow

1. The ESP32 reads available sensors or generates configured demonstration values.
2. Firmware displays local readings on an OLED and sends telemetry over BLE using Bluetooth SIG standard GATT services and characteristics, rather than a project-specific custom service.
3. The phone application receives readings, adds phone GPS when available, and buffers data for upload.
4. The application uploads through MQTT as the primary transport, with CoAP planned as a fallback. Both require internet connectivity; offline readings remain queued on the phone.
5. Cloud services validate and store telemetry, process results, and deliver updates to the phone and hospital dashboard.
6. The hospital dashboard presents readings, their freshness, location, and processing results. Risk prediction and ETA are planned capabilities whose methods and inputs still need to be defined.

See [the block diagram](block-diagram.png) for the project architecture.

## Repository structure and responsibilities

```text
smart-ambulance/
|-- app/                 Flutter phone application and telemetry gateway
|   |-- .gitkeep
|   `-- README.md
|-- cloud/               Telemetry ingestion, storage, processing, and APIs
|   |-- .gitkeep
|   `-- README.md
|-- dashboard/           Hospital web dashboard
|   |-- .gitkeep
|   `-- README.md
|-- docs/                Project requirements, interfaces, and setup documentation
|   |-- .gitkeep
|   `-- README.md
|-- esp32/               ESP-IDF firmware for acquisition, OLED, and BLE
|   |-- .gitkeep
|   `-- README.md
|-- references/          External sources, datasheets, and research references
|   |-- .gitkeep
|   `-- README.md
|-- block-diagram.png    Architecture reference
`-- README.md            Project overview and repository guide
```

The component folders are starting points, not initialized applications. Each folder README explains its responsibilities and the steps for using it. No particular backend stack, dashboard framework, or deployment provider has been selected here.

## Getting started

1. Review the block diagram and the folder responsibilities below.
2. Use `docs/` to agree on telemetry fields, units, simulation mappings, identifiers, timestamps, and transport behavior before implementing integrations.
3. Start with one simulated reading through `esp32/`, `app/`, `cloud/`, and `dashboard/`.
4. Verify reconnection, offline buffering, duplicate handling, and stale-data indicators before expanding the pipeline.
5. Add component-specific setup and run commands to the corresponding README when implementation files are introduced.

## Component boundaries

| Folder | Owns |
| --- | --- |
| [esp32](esp32/README.md) | Input acquisition, simulation mappings, local reading quality, OLED output, and standard BLE GATT publication |
| [app](app/README.md) | Standard-GATT BLE reception, session association, GPS enrichment, persistent upload queue, MQTT/CoAP selection, phone status display |
| [cloud](cloud/README.md) | Message validation, deduplication, durable storage, processing, application acknowledgments, client updates |
| [dashboard](dashboard/README.md) | Hospital-facing session views, readings, trends, location, alerts, and freshness indicators |
| [docs](docs/README.md) | Team-authored requirements, interface agreements, setup instructions, and verification procedures |
| [references](references/README.md) | Supporting external material and its source information |

## Shared working rules

- Preserve reading identity across BLE reception, upload retries, and transport fallback.
- Keep acquisition timing separate from phone and server receipt times.
- Record units, quality, and simulation origin; do not substitute zero for missing data.
- Keep local acquisition and OLED output independent of cloud availability.
- Keep credentials and real patient data out of the repository. Use synthetic examples for development.
- Update the relevant README when setup, responsibilities, or interfaces change.

## Placeholder files

Each component folder includes `.gitkeep` to preserve the intended layout in Git while development is staged. `.gitkeep` has no runtime behavior and is not required once a folder contains tracked files such as its README; it may remain until that component is initialized.

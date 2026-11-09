# Location and routing plan

## First milestone: phone location

The Flutter gateway can collect foreground location from the ambulance phone independently of BLE telemetry. Before a trip, the operator enters an ambulance ID and selects its assigned hospital. The selected hospital supplies its preconfigured ambulance-entrance coordinates, so drivers never enter coordinates. The app validates this configuration locally. Starting a valid trip automatically starts tracking and requests Android location permission only then. Ending the trip stops tracking. The app reports disabled location services, denied permission, and missing GPS fixes to the operator.

The phone screen displays these fields and, while an active trip is running,
uploads them to the cloud location endpoint:

| Field | Meaning |
| --- | --- |
| `latitude` | WGS-84 latitude in decimal degrees. |
| `longitude` | WGS-84 longitude in decimal degrees. |
| `accuracyMeters` | Horizontal accuracy supplied by the phone. |
| `capturedAt` | Time at which the phone acquired the fix, separate from BLE observation time. |
| `speedMetersPerSecond` | Phone-reported speed when available. |

The app suppresses phone-reported speeds below 3 km/h and smooths faster
values for display. This prevents stationary GPS drift from being presented as
ambulance movement. The same stabilized speed value is uploaded when available.

## Implemented flow

```text
Phone GPS -> Flutter location service -> cloud location endpoint
                                      -> OSRM route to assigned hospital
                                      -> dashboard location, distance, ETA
```

Each ambulance will have one assigned hospital and destination coordinates. The destination should be the ambulance entrance, not a hospital-centre coordinate. The system will not search for a nearest hospital.

## Deployment note

The app receives its cloud URL through `CLOUD_API_BASE_URL`, for example
`flutter run --dart-define=CLOUD_API_BASE_URL=http://10.0.2.2:3000` for an
Android emulator. A real phone must use the server's LAN address instead of
`localhost`. The development Android manifest permits HTTP for this local
setup; production must use HTTPS and disable clear-text traffic.

## Next milestones

1. Replace the temporary in-app hospital catalog with a destination assigned by the backend/dispatcher.
2. Persist queued updates across app restarts when the device is offline.
3. Replace the local destination catalog with dispatcher-assigned destinations.
4. Display route freshness, location freshness, ETA, and arrival status in the dashboard.

Location remains separate from simulated medical telemetry.

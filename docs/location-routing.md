# Location and routing plan

## First milestone: phone location

The Flutter gateway can collect foreground location from the ambulance phone independently of BLE telemetry. Before a trip, the operator enters an ambulance ID and selects its assigned hospital. The selected hospital supplies its preconfigured ambulance-entrance coordinates, so drivers never enter coordinates. The app validates this configuration locally. The operator explicitly starts tracking from the app. The app requests Android location permission only at that time and reports disabled location services, denied permission, and missing GPS fixes to the operator.

The phone screen currently displays these fields and does not upload them:

| Field | Meaning |
| --- | --- |
| `latitude` | WGS-84 latitude in decimal degrees. |
| `longitude` | WGS-84 longitude in decimal degrees. |
| `accuracyMeters` | Horizontal accuracy supplied by the phone. |
| `capturedAt` | Time at which the phone acquired the fix, separate from BLE observation time. |
| `speedMetersPerSecond` | Phone-reported speed when available. |

The app suppresses phone-reported speeds below 3 km/h and smooths faster
values for display. This prevents stationary GPS drift from being presented as
ambulance movement. The unfiltered location data is not uploaded in this
milestone.

## Planned flow

```text
Phone GPS -> Flutter location service -> cloud location endpoint
                                      -> OSRM route to assigned hospital
                                      -> dashboard location, distance, ETA
```

Each ambulance will have one assigned hospital and destination coordinates. The destination should be the ambulance entrance, not a hospital-centre coordinate. The system will not search for a nearest hospital.

## Next milestones

1. Replace the temporary in-app hospital catalog with a destination assigned by the backend/dispatcher.
2. Persist and upload location updates while preserving their original capture time.
3. Calculate the remaining route, distance, and ETA through OSRM in the cloud service.
4. Display route freshness, location freshness, ETA, and arrival status in the dashboard.

Until the cloud upload milestone, location remains on the device and is not part of simulated medical telemetry.

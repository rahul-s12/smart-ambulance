# Project Documentation

This folder holds team-authored explanations of how the system is intended to work and how to develop and verify it. The root `../block-diagram.png` remains the architecture reference.

## Responsibilities

- Record requirements and observable acceptance criteria for the full telemetry path.
- Define fields, units, schema versions, simulation mappings, device/session identity, and timestamp meaning.
- Specify BLE framing, MQTT topics, CoAP resources, acknowledgment behavior, and error handling.
- Describe buffering limits, retries, fallback/recovery rules, data ordering, and freshness thresholds.
- Record component setup instructions, integration procedures, and decisions affecting multiple components.
- Distinguish agreed behavior, proposed targets, and capabilities that are not yet implemented.

## How to use this folder

1. Start from the root project overview and block diagram.
2. Add documentation files directly in this existing folder as the team agrees on requirements; do not create additional folders yet.
3. Define the data contract and failure behavior before implementing an interface in multiple components.
4. Include synthetic example inputs, expected outputs, and steps to verify each agreed behavior.
5. Link relevant documentation from component READMEs and update it whenever an interface or decision changes.
6. Keep external supporting sources in `../references/` and link them from the team-authored explanation.

## Current state

This README describes the intended use of the folder. Detailed interface specifications and acceptance procedures still need to be agreed and written. `.gitkeep` preserves the folder during staged development.

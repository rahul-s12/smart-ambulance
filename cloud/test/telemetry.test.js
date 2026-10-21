import assert from 'node:assert/strict';
import test from 'node:test';
import { createSimulatedReading, validateReading } from '../src/telemetry.js';

test('simulated reading is valid and explicitly labelled', () => {
  const reading = createSimulatedReading({ ambulanceId: 'SIM-AMB-001', random: () => 0.5, now: new Date('2026-10-20T12:00:00.000Z') });
  assert.deepEqual(validateReading(reading), []);
  assert.equal(reading.source.type, 'simulation');
  assert.equal(reading.metrics.heartRateBpm, 76);
  assert.equal(reading.metrics.spo2Percent, 98);
  assert.equal(reading.metrics.temperatureC, 36.7);
});

test('invalid incoming telemetry is rejected', () => {
  assert.match(validateReading({ schemaVersion: 2, ambulanceId: '', metrics: {}, source: {} }).join(' '), /schemaVersion.*ambulanceId.*observedAt.*heartRateBpm.*simulation/);
});

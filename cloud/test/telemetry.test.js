import test from 'node:test';
import assert from 'node:assert/strict';
import { createSimulatedReading, validateReading } from '../src/telemetry.js';
import { InMemoryTelemetryStore, ResilientTelemetryStore } from '../src/store.js';

test('simulated reading includes every dashboard metric and an explicit source', () => {
  const reading = createSimulatedReading({ ambulanceId: 'SIM-AMB-001', now: new Date('2026-10-20T10:00:00.000Z'), random: () => 0.5 });
  assert.deepEqual(validateReading(reading), []);
  assert.equal(reading.ambulanceId, 'SIM-AMB-001');
  assert.equal(reading.source.type, 'simulation');
  assert.ok(Number.isFinite(reading.metrics.heartRateBpm));
  assert.ok(Number.isFinite(reading.metrics.spo2Percent));
  assert.ok(Number.isFinite(reading.metrics.temperatureC));
});

test('resilient storage preserves telemetry while MongoDB is unavailable', async () => {
  const fallback = new InMemoryTelemetryStore();
  const primary = { connect: async () => { throw new Error('offline'); } };
  const store = new ResilientTelemetryStore({ primary, fallback, onPrimaryError: () => {} });
  await store.connect();
  const reading = createSimulatedReading({ ambulanceId: 'SIM-AMB-001' });
  await store.save(reading);
  assert.equal(store.storage, 'memory-fallback');
  assert.equal((await store.latest('SIM-AMB-001')).readingId, reading.readingId);
});

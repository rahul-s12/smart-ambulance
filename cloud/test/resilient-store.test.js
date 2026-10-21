import assert from 'node:assert/strict';
import test from 'node:test';
import { InMemoryTelemetryStore, ResilientTelemetryStore } from '../src/store.js';
import { createSimulatedReading } from '../src/telemetry.js';

test('resilient store keeps test telemetry available when MongoDB is down', async () => {
  const primary = { connect: async () => { throw new Error('TLS unavailable'); }, close: async () => {} };
  const store = new ResilientTelemetryStore({ primary, fallback: new InMemoryTelemetryStore(), onPrimaryError: () => {} });
  await store.connect();
  const reading = createSimulatedReading({ ambulanceId: 'SIM-AMB-001' });
  await store.save(reading);
  assert.equal(store.storage, 'memory-fallback');
  assert.equal((await store.latest('SIM-AMB-001')).readingId, reading.readingId);
});

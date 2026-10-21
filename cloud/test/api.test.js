import assert from 'node:assert/strict';
import test from 'node:test';
import { once } from 'node:events';
import { InMemoryTelemetryStore } from '../src/store.js';
import { TelemetrySimulator, createSimulatedReading } from '../src/telemetry.js';
import { createApi } from '../src/server.js';

test('API stores and returns simulated telemetry', async (t) => {
  const store = new InMemoryTelemetryStore();
  const simulator = new TelemetrySimulator({ ambulanceId: 'SIM-AMB-001', intervalMs: 1000, publish: async () => {} });
  const { server, publish } = createApi({ store, simulator });
  server.listen(0);
  await once(server, 'listening');
  t.after(() => server.close());
  const address = server.address();
  const base = `http://127.0.0.1:${address.port}`;
  await publish(createSimulatedReading({ ambulanceId: 'SIM-AMB-001' }));
  const health = await (await fetch(`${base}/health`)).json();
  assert.equal(health.status, 'ok');
  assert.equal(health.storage, 'mongodb');
  const latest = await (await fetch(`${base}/api/ambulances/SIM-AMB-001/latest`)).json();
  assert.equal(latest.simulated, true);
  assert.equal(latest.reading.ambulanceId, 'SIM-AMB-001');
  const rejected = await fetch(`${base}/api/telemetry`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
  assert.equal(rejected.status, 422);
});

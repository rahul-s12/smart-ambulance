import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApi } from '../src/server.js';
import { InMemoryTelemetryStore } from '../src/store.js';
import { createSimulatedReading } from '../src/telemetry.js';

test('API returns health, latest reading, and history', async () => {
  const store = new InMemoryTelemetryStore(); await store.connect();
  const simulator = { active: true, ambulanceId: 'SIM-AMB-001', intervalMs: 1000 };
  const { server, publish } = createApi({ store, simulator }); server.listen(0); await once(server, 'listening');
  const origin = `http://127.0.0.1:${server.address().port}`;
  await publish(createSimulatedReading({ ambulanceId: simulator.ambulanceId }));
  const health = await (await fetch(`${origin}/health`)).json();
  const latest = await (await fetch(`${origin}/api/ambulances/SIM-AMB-001/latest`)).json();
  const history = await (await fetch(`${origin}/api/ambulances/SIM-AMB-001/readings?limit=3`)).json();
  assert.equal(health.status, 'ok'); assert.equal(latest.reading.ambulanceId, 'SIM-AMB-001'); assert.equal(history.readings.length, 1);
  await new Promise((resolve) => server.close(resolve));
});

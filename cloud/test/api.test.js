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

test('API stores phone GPS updates and returns an OSRM ETA', async (t) => {
  const store = new InMemoryTelemetryStore();
  const simulator = new TelemetrySimulator({ ambulanceId: 'SIM-AMB-001', intervalMs: 1000, publish: async () => {} });
  const routeService = {
    enabled: true,
    async route() {
      return { provider: 'osrm', distanceMeters: 4200, durationSeconds: 600, eta: '2026-11-03T10:10:00.000Z', routedAt: '2026-11-03T10:00:00.000Z' };
    },
  };
  const { server } = createApi({ store, simulator, routeService });
  server.listen(0);
  await once(server, 'listening');
  t.after(() => server.close());
  const address = server.address();
  const base = `http://127.0.0.1:${address.port}`;
  const body = {
    latitude: 12.9716,
    longitude: 77.5946,
    accuracyMeters: 8,
    speedMetersPerSecond: 4.2,
    capturedAt: '2026-11-03T10:00:00.000Z',
    destination: { hospitalName: 'City Hospital', latitude: 12.9352, longitude: 77.6245 },
  };
  const created = await fetch(`${base}/api/ambulances/AMB-001/location`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  assert.equal(created.status, 201);
  const result = await created.json();
  assert.equal(result.location.route.durationSeconds, 600);
  const latest = await (await fetch(`${base}/api/ambulances/AMB-001/location`)).json();
  assert.equal(latest.location.destination.hospitalName, 'City Hospital');
  assert.equal(latest.location.route.provider, 'osrm');
});

test('API rejects incomplete GPS updates', async (t) => {
  const store = new InMemoryTelemetryStore();
  const simulator = new TelemetrySimulator({ ambulanceId: 'SIM-AMB-001', intervalMs: 1000, publish: async () => {} });
  const { server } = createApi({ store, simulator });
  server.listen(0);
  await once(server, 'listening');
  t.after(() => server.close());
  const address = server.address();
  const response = await fetch(`http://127.0.0.1:${address.port}/api/ambulances/AMB-001/location`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
  assert.equal(response.status, 422);
  const body = await response.json();
  assert.match(body.errors.join(' '), /latitude.*destination/);
});

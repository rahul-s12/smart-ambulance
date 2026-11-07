import assert from 'node:assert/strict';
import test from 'node:test';
import { validateLocationUpdate } from '../src/location.js';
import { createOsrmRouteService, distanceMeters } from '../src/routing.js';

test('location validation accepts a complete GPS update', () => {
  const update = {
    latitude: 12.9716, longitude: 77.5946, capturedAt: '2026-11-03T10:00:00.000Z',
    destination: { hospitalName: 'City Hospital', latitude: 12.9352, longitude: 77.6245 },
  };
  assert.deepEqual(validateLocationUpdate(update), []);
  assert.ok(distanceMeters(update, update.destination) > 0);
});

test('OSRM service transforms a successful route response into an ETA', async () => {
  const service = createOsrmRouteService({
    baseUrl: 'http://osrm.test/',
    now: () => new Date('2026-11-03T10:00:00.000Z'),
    fetchImpl: async (url) => {
      assert.match(url, /77\.5946,12\.9716;77\.6245,12\.9352/);
      return { ok: true, json: async () => ({ code: 'Ok', routes: [{ distance: 4200.4, duration: 600.2 }] }) };
    },
  });
  const route = await service.route({ latitude: 12.9716, longitude: 77.5946 }, { latitude: 12.9352, longitude: 77.6245 });
  assert.deepEqual(route, { provider: 'osrm', distanceMeters: 4200, durationSeconds: 600, eta: '2026-11-03T10:10:00.200Z', routedAt: '2026-11-03T10:00:00.000Z' });
});

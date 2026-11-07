import http from 'node:http';
import { EventEmitter } from 'node:events';
import { validateReading } from './telemetry.js';
import { createLocationRecord, validateLocationUpdate } from './location.js';
import { createRouteCache } from './routing.js';

const json = (response, status, body) => {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(body));
};

const readJson = async (request) => {
  let body = '';
  for await (const chunk of request) body += chunk;
  return JSON.parse(body || '{}');
};

export function createApi({ store, simulator, routeService }) {
  const events = new EventEmitter();
  const routes = createRouteCache({ routeService: routeService ?? { enabled: false } });
  events.setMaxListeners(0);
  const publish = async (reading) => {
    const errors = validateReading(reading);
    if (errors.length) throw new Error(`Invalid generated telemetry: ${errors.join(' ')}`);
    await store.save(reading);
    events.emit('reading', reading);
    return reading;
  };

  const server = http.createServer(async (request, response) => {
    const url = new URL(request.url, `http://${request.headers.host}`);
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    try {
      if (request.method === 'OPTIONS') {
        response.writeHead(204);
        return response.end();
      }
      if (request.method === 'GET' && url.pathname === '/health') {
        return json(response, 200, { status: 'ok', storage: store.storage ?? 'mongodb', simulator: { active: simulator.active, ambulanceId: simulator.ambulanceId, intervalMs: simulator.intervalMs } });
      }
      if (request.method === 'GET' && url.pathname === '/api/ambulances') return json(response, 200, { ambulances: await store.listAmbulances(), simulated: true });
      const matches = url.pathname.match(/^\/api\/ambulances\/([^/]+)\/(latest|readings)$/);
      if (request.method === 'GET' && matches) {
        const ambulanceId = decodeURIComponent(matches[1]);
        if (matches[2] === 'latest') return json(response, 200, { reading: await store.latest(ambulanceId), simulated: true });
        const requested = Number(url.searchParams.get('limit') ?? 30);
        const limit = Number.isSafeInteger(requested) ? Math.min(Math.max(requested, 1), 100) : 30;
        return json(response, 200, { readings: await store.history(ambulanceId, limit), simulated: true });
      }
      const locationMatch = url.pathname.match(/^\/api\/ambulances\/([^/]+)\/location$/);
      if (request.method === 'GET' && locationMatch) {
        const ambulanceId = decodeURIComponent(locationMatch[1]);
        return json(response, 200, { location: await store.latestLocation(ambulanceId) });
      }
      if (request.method === 'GET' && url.pathname === '/api/stream') {
        response.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
        response.write(': Smart Ambulance simulated telemetry stream\n\n');
        const onReading = (reading) => response.write(`event: telemetry\ndata: ${JSON.stringify(reading)}\n\n`);
        const onLocation = (location) => response.write(`event: location\ndata: ${JSON.stringify(location)}\n\n`);
        events.on('reading', onReading);
        events.on('location', onLocation);
        request.on('close', () => {
          events.off('reading', onReading);
          events.off('location', onLocation);
        });
        return;
      }
      if (request.method === 'POST' && url.pathname === '/api/telemetry') {
        const reading = await readJson(request);
        const errors = validateReading(reading);
        if (errors.length) return json(response, 422, { errors });
        await publish(reading);
        return json(response, 201, { accepted: true, readingId: reading.readingId });
      }
      if (request.method === 'POST' && locationMatch) {
        const ambulanceId = decodeURIComponent(locationMatch[1]);
        if (!ambulanceId.trim()) return json(response, 422, { errors: ['ambulanceId is required.'] });
        const update = await readJson(request);
        const errors = validateLocationUpdate(update);
        if (errors.length) return json(response, 422, { errors });
        let route = null;
        try {
          route = await routes.routeFor(ambulanceId, update, update.destination);
        } catch (error) {
          console.warn(`Could not calculate OSRM route for ${ambulanceId}: ${error.message}`);
        }
        const location = createLocationRecord({ ambulanceId, update, route });
        await store.saveLocation(location);
        events.emit('location', location);
        return json(response, 201, { accepted: true, location });
      }
      return json(response, 404, { error: 'Not found' });
    } catch (error) {
      if (error instanceof SyntaxError) return json(response, 400, { error: 'Body must be valid JSON' });
      console.error(error);
      return json(response, 500, { error: 'Internal server error' });
    }
  });
  return { server, publish };
}

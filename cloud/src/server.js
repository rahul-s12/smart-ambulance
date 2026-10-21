import http from 'node:http';
import { EventEmitter } from 'node:events';
import { validateReading } from './telemetry.js';

const json = (response, status, body) => { response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' }); response.end(JSON.stringify(body)); };
const readJson = async (request) => { let body = ''; for await (const chunk of request) body += chunk; return JSON.parse(body || '{}'); };

export function createApi({ store, simulator }) {
  const events = new EventEmitter(); events.setMaxListeners(0);
  const publish = async (reading) => { const errors = validateReading(reading); if (errors.length) throw new Error(`Invalid generated telemetry: ${errors.join(' ')}`); await store.save(reading); events.emit('reading', reading); return reading; };
  const server = http.createServer(async (request, response) => {
    const url = new URL(request.url, `http://${request.headers.host}`); response.setHeader('Access-Control-Allow-Origin', '*'); response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS'); response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    try {
      if (request.method === 'OPTIONS') { response.writeHead(204); return response.end(); }
      if (request.method === 'GET' && url.pathname === '/health') return json(response, 200, { status: 'ok', storage: store.storage ?? 'mongodb', simulator: { active: simulator.active, ambulanceId: simulator.ambulanceId, intervalMs: simulator.intervalMs } });
      if (request.method === 'GET' && url.pathname === '/api/ambulances') return json(response, 200, { ambulances: await store.listAmbulances(), simulated: true });
      const matches = url.pathname.match(/^\/api\/ambulances\/([^/]+)\/(latest|readings)$/);
      if (request.method === 'GET' && matches) { const ambulanceId = decodeURIComponent(matches[1]); if (matches[2] === 'latest') return json(response, 200, { reading: await store.latest(ambulanceId), simulated: true }); const requested = Number(url.searchParams.get('limit') ?? 30); const limit = Number.isSafeInteger(requested) ? Math.min(Math.max(requested, 1), 100) : 30; return json(response, 200, { readings: await store.history(ambulanceId, limit), simulated: true }); }
      if (request.method === 'GET' && url.pathname === '/api/stream') { response.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' }); response.write(': Smart Ambulance simulated telemetry stream\n\n'); const onReading = (reading) => response.write(`event: telemetry\ndata: ${JSON.stringify(reading)}\n\n`); events.on('reading', onReading); request.on('close', () => events.off('reading', onReading)); return; }
      if (request.method === 'POST' && url.pathname === '/api/telemetry') { const reading = await readJson(request); const errors = validateReading(reading); if (errors.length) return json(response, 422, { errors }); await publish(reading); return json(response, 201, { accepted: true, readingId: reading.readingId }); }
      return json(response, 404, { error: 'Not found' });
    } catch (error) { if (error instanceof SyntaxError) return json(response, 400, { error: 'Body must be valid JSON' }); console.error(error); return json(response, 500, { error: 'Internal server error' }); }
  });
  return { server, publish };
}

import 'node:process';
import { setServers } from 'node:dns';
import { InMemoryTelemetryStore, MongoTelemetryStore, ResilientTelemetryStore } from './store.js';
import { TelemetrySimulator } from './telemetry.js';
import { createApi } from './server.js';

const required = (name) => {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required. Copy .env.example to .env and add a value.`);
  return value;
};

const config = {
  uri: required('MONGODB_URI'),
  databaseName: process.env.MONGODB_DATABASE ?? 'smart_ambulance_test',
  port: Number(process.env.PORT ?? 3000),
  intervalMs: Number(process.env.SIMULATOR_INTERVAL_MS ?? 1000),
  ambulanceId: process.env.SIMULATOR_AMBULANCE_ID ?? 'SIM-AMB-001',
  ipFamily: Number(process.env.MONGODB_IP_FAMILY ?? 4),
};

// Some Wi-Fi DNS resolvers reject SRV lookups used by mongodb+srv URIs.
// This is optional and only changes DNS resolution for this Node process.
if (process.env.MONGODB_DNS_SERVER) {
  setServers([process.env.MONGODB_DNS_SERVER]);
}
const store = new ResilientTelemetryStore({
  primary: new MongoTelemetryStore({ uri: config.uri, databaseName: config.databaseName, family: config.ipFamily }),
  fallback: new InMemoryTelemetryStore(),
  onPrimaryError: (error) => console.warn(`MongoDB unavailable; serving this test session from memory. Will retry: ${error.message}`),
});
await store.connect();
const simulator = new TelemetrySimulator({ ambulanceId: config.ambulanceId, intervalMs: config.intervalMs, publish: async () => {} });
const { server, publish } = createApi({ store, simulator });
simulator.publish = publish;
await new Promise((resolve) => server.listen(config.port, resolve));
simulator.start();
setInterval(() => { void store.reconnect(); }, 15000).unref();
console.log(`Smart Ambulance simulated backend running at http://localhost:${config.port} using ${store.storage}.`);

const stop = async () => {
  simulator.stop();
  await new Promise((resolve) => server.close(resolve));
  await store.close();
};
process.on('SIGINT', () => stop().then(() => process.exit(0)));
process.on('SIGTERM', () => stop().then(() => process.exit(0)));

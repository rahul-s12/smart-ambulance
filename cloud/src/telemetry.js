import { randomUUID } from 'node:crypto';

export const simulationSource = Object.freeze({
  type: 'simulation',
  label: 'Simulated demonstration data',
});

export function createSimulatedReading({ ambulanceId, now = new Date(), random = Math.random }) {
  const heartRateBpm = Math.round(76 + (random() - 0.5) * 10);
  const spo2Percent = Math.round(98 + (random() - 0.5) * 2);
  const temperatureC = Number((36.7 + (random() - 0.5) * 0.5).toFixed(2));

  return {
    schemaVersion: 1,
    readingId: randomUUID(),
    ambulanceId,
    observedAt: now.toISOString(),
    metrics: { heartRateBpm, spo2Percent, temperatureC },
    source: simulationSource,
  };
}

export function validateReading(reading) {
  const errors = [];
  if (!reading || typeof reading !== 'object') return ['Reading must be an object.'];
  if (reading.schemaVersion !== 1) errors.push('schemaVersion must be 1.');
  if (typeof reading.readingId !== 'string' || !reading.readingId) errors.push('readingId is required.');
  if (typeof reading.ambulanceId !== 'string' || !reading.ambulanceId.trim()) errors.push('ambulanceId is required.');
  if (Number.isNaN(Date.parse(reading.observedAt))) errors.push('observedAt must be an ISO timestamp.');
  const metrics = reading.metrics;
  if (!metrics || typeof metrics !== 'object') {
    errors.push('metrics is required.');
  } else {
    if (!Number.isFinite(metrics.heartRateBpm)) errors.push('metrics.heartRateBpm must be numeric.');
    if (!Number.isFinite(metrics.spo2Percent)) errors.push('metrics.spo2Percent must be numeric.');
    if (!Number.isFinite(metrics.temperatureC)) errors.push('metrics.temperatureC must be numeric.');
  }
  if (reading.source?.type !== 'simulation') errors.push('source.type must be simulation for this test backend.');
  return errors;
}

export class TelemetrySimulator {
  #timer;

  constructor({ ambulanceId, intervalMs, publish }) {
    this.ambulanceId = ambulanceId;
    this.intervalMs = intervalMs;
    this.publish = publish;
  }

  start() {
    if (this.#timer) return;
    this.#timer = setInterval(() => {
      void this.publish(createSimulatedReading({ ambulanceId: this.ambulanceId })).catch((error) => {
        console.error('Could not store simulated telemetry:', error);
      });
    }, this.intervalMs);
  }

  stop() {
    clearInterval(this.#timer);
    this.#timer = undefined;
  }

  get active() { return Boolean(this.#timer); }
}

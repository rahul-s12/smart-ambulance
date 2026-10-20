import { randomUUID } from 'node:crypto';

export const simulationSource = { type: 'simulation', label: 'Simulated demonstration data' };

export function createSimulatedReading({ ambulanceId, now = new Date(), random = Math.random }) {
  return {
    schemaVersion: 1,
    readingId: randomUUID(),
    ambulanceId,
    observedAt: now.toISOString(),
    metrics: {
      heartRateBpm: Math.round(71 + random() * 10),
      spo2Percent: Math.round(97 + random() * 2),
      temperatureC: Number((36.45 + random() * 0.5).toFixed(2)),
    },
    source: simulationSource,
  };
}

export function validateReading(reading) {
  const errors = [];
  if (!reading || typeof reading !== 'object') return ['Telemetry body is required.'];
  if (!reading.readingId) errors.push('readingId is required.');
  if (!reading.ambulanceId) errors.push('ambulanceId is required.');
  if (!reading.observedAt || Number.isNaN(Date.parse(reading.observedAt))) errors.push('observedAt must be an ISO timestamp.');
  const metrics = reading.metrics ?? {};
  for (const key of ['heartRateBpm', 'spo2Percent', 'temperatureC']) if (!Number.isFinite(metrics[key])) errors.push(`metrics.${key} must be a number.`);
  if (reading.source?.type !== 'simulation') errors.push('source.type must be simulation for the current test backend.');
  return errors;
}

export class TelemetrySimulator {
  constructor({ ambulanceId, intervalMs, publish }) { this.ambulanceId = ambulanceId; this.intervalMs = intervalMs; this.publish = publish; this.timer = null; }
  get active() { return this.timer !== null; }
  start() { if (this.timer) return; const publish = async () => { try { await this.publish(createSimulatedReading({ ambulanceId: this.ambulanceId })); } catch (error) { console.error('Failed to publish simulated telemetry:', error.message); } }; void publish(); this.timer = setInterval(() => void publish(), this.intervalMs); }
  stop() { if (this.timer) clearInterval(this.timer); this.timer = null; }
}

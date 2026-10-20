import { MongoClient } from 'mongodb';

export class MongoTelemetryStore {
  constructor({ uri, databaseName, family = 4 }) { this.client = new MongoClient(uri, { family, serverSelectionTimeoutMS: 10000 }); this.databaseName = databaseName; }
  async connect() { await this.client.connect(); this.readings = this.client.db(this.databaseName).collection('telemetry_readings'); await this.readings.createIndex({ readingId: 1 }, { unique: true }); await this.readings.createIndex({ ambulanceId: 1, observedAt: -1 }); }
  async close() { await this.client.close(); }
  async save(reading) { await this.readings.insertOne(reading); return reading; }
  async latest(ambulanceId) { return this.readings.findOne({ ambulanceId }, { sort: { observedAt: -1 }, projection: { _id: 0 } }); }
  async listAmbulances() { return this.readings.aggregate([{ $sort: { observedAt: -1 } }, { $group: { _id: '$ambulanceId', latestObservedAt: { $first: '$observedAt' } } }, { $project: { _id: 0, ambulanceId: '$_id', latestObservedAt: 1 } }]).toArray(); }
  async history(ambulanceId, limit) { return this.readings.find({ ambulanceId }, { projection: { _id: 0 } }).sort({ observedAt: -1 }).limit(limit).toArray(); }
}

export class InMemoryTelemetryStore {
  constructor() { this.items = []; }
  async connect() {} async close() {}
  async save(reading) { this.items.push(reading); return reading; }
  async latest(ambulanceId) { return this.items.filter((item) => item.ambulanceId === ambulanceId).at(-1) ?? null; }
  async listAmbulances() { return [...new Map(this.items.map((item) => [item.ambulanceId, item])).values()].map(({ ambulanceId, observedAt }) => ({ ambulanceId, latestObservedAt: observedAt })); }
  async history(ambulanceId, limit) { return this.items.filter((item) => item.ambulanceId === ambulanceId).slice(-limit).reverse(); }
}

export class ResilientTelemetryStore {
  constructor({ primary, fallback, onPrimaryError = console.warn }) { this.primary = primary; this.fallback = fallback; this.onPrimaryError = onPrimaryError; this.primaryAvailable = false; this.lastPrimaryErrorMessage = null; }
  get storage() { return this.primaryAvailable ? 'mongodb' : 'memory-fallback'; }
  async connect() { await this.fallback.connect(); try { await this.primary.connect(); this.primaryAvailable = true; this.lastPrimaryErrorMessage = null; for (const reading of this.fallback.items) { try { await this.primary.save(reading); } catch (error) { if (error?.code !== 11000) throw error; } } } catch (error) { this.primaryAvailable = false; this.reportPrimaryError(error); } }
  async reconnect() { if (!this.primaryAvailable) await this.connect(); }
  async close() { await this.fallback.close(); if (this.primaryAvailable) await this.primary.close(); }
  async save(reading) { await this.fallback.save(reading); if (!this.primaryAvailable) return reading; try { await this.primary.save(reading); } catch (error) { this.primaryAvailable = false; this.reportPrimaryError(error); } return reading; }
  async latest(ambulanceId) { return this.primaryAvailable ? this.primary.latest(ambulanceId) : this.fallback.latest(ambulanceId); }
  async listAmbulances() { return this.primaryAvailable ? this.primary.listAmbulances() : this.fallback.listAmbulances(); }
  async history(ambulanceId, limit) { return this.primaryAvailable ? this.primary.history(ambulanceId, limit) : this.fallback.history(ambulanceId, limit); }
  reportPrimaryError(error) { const message = error?.message ?? String(error); if (message === this.lastPrimaryErrorMessage) return; this.lastPrimaryErrorMessage = message; this.onPrimaryError(error); }
}

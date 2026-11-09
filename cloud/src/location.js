import { randomUUID } from 'node:crypto';

const isCoordinate = (value, minimum, maximum) => Number.isFinite(value) && value >= minimum && value <= maximum;

export function validateLocationUpdate(update) {
  const errors = [];
  if (!update || typeof update !== 'object') return ['Location update must be an object.'];
  if (!isCoordinate(update.latitude, -90, 90)) errors.push('latitude must be between -90 and 90.');
  if (!isCoordinate(update.longitude, -180, 180)) errors.push('longitude must be between -180 and 180.');
  if (Number.isNaN(Date.parse(update.capturedAt))) errors.push('capturedAt must be an ISO timestamp.');
  if (update.accuracyMeters !== undefined && (!Number.isFinite(update.accuracyMeters) || update.accuracyMeters < 0)) errors.push('accuracyMeters must be a non-negative number.');
  if (update.speedMetersPerSecond !== undefined && (!Number.isFinite(update.speedMetersPerSecond) || update.speedMetersPerSecond < 0)) errors.push('speedMetersPerSecond must be a non-negative number.');

  const destination = update.destination;
  if (!destination || typeof destination !== 'object') {
    errors.push('destination is required.');
  } else {
    if (typeof destination.hospitalName !== 'string' || !destination.hospitalName.trim()) errors.push('destination.hospitalName is required.');
    if (!isCoordinate(destination.latitude, -90, 90)) errors.push('destination.latitude must be between -90 and 90.');
    if (!isCoordinate(destination.longitude, -180, 180)) errors.push('destination.longitude must be between -180 and 180.');
  }
  return errors;
}

export function createLocationRecord({ ambulanceId, update, route = null }) {
  return {
    locationId: randomUUID(),
    ambulanceId,
    latitude: update.latitude,
    longitude: update.longitude,
    accuracyMeters: update.accuracyMeters ?? null,
    speedMetersPerSecond: update.speedMetersPerSecond ?? null,
    capturedAt: update.capturedAt,
    receivedAt: new Date().toISOString(),
    destination: update.destination,
    route,
  };
}

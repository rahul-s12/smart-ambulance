const toRadians = (degrees) => (degrees * Math.PI) / 180;

export function distanceMeters(from, to) {
  const radius = 6371000;
  const latitudeDelta = toRadians(to.latitude - from.latitude);
  const longitudeDelta = toRadians(to.longitude - from.longitude);
  const value = Math.sin(latitudeDelta / 2) ** 2
    + Math.cos(toRadians(from.latitude)) * Math.cos(toRadians(to.latitude)) * Math.sin(longitudeDelta / 2) ** 2;
  return 2 * radius * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
}

export function createOsrmRouteService({ baseUrl, fetchImpl = fetch, now = () => new Date() } = {}) {
  if (!baseUrl) return { enabled: false, async route() { return null; } };
  const normalizedBaseUrl = baseUrl.replace(/\/$/, '');
  return {
    enabled: true,
    async route(origin, destination) {
      const coordinates = `${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}`;
      const response = await fetchImpl(`${normalizedBaseUrl}/route/v1/driving/${coordinates}?overview=false&steps=false`);
      if (!response.ok) throw new Error(`OSRM route request failed with HTTP ${response.status}.`);
      const payload = await response.json();
      const route = payload.routes?.[0];
      if (payload.code !== 'Ok' || !Number.isFinite(route?.duration) || !Number.isFinite(route?.distance)) throw new Error('OSRM did not return a usable route.');
      const routedAt = now();
      return {
        provider: 'osrm',
        distanceMeters: Math.round(route.distance),
        durationSeconds: Math.round(route.duration),
        eta: new Date(routedAt.getTime() + route.duration * 1000).toISOString(),
        routedAt: routedAt.toISOString(),
      };
    },
  };
}

export function createRouteCache({ routeService, minimumMoveMeters = 30, minimumIntervalMs = 30000, now = () => new Date() }) {
  const entries = new Map();
  return {
    async routeFor(ambulanceId, origin, destination) {
      if (!routeService.enabled) return null;
      const entry = entries.get(ambulanceId);
      const destinationKey = `${destination.latitude},${destination.longitude}`;
      const elapsed = entry ? now().getTime() - entry.routedAt.getTime() : Infinity;
      const moved = entry ? distanceMeters(entry.origin, origin) : Infinity;
      if (entry && entry.destinationKey === destinationKey && moved < minimumMoveMeters && elapsed < minimumIntervalMs) return entry.route;
      const route = await routeService.route(origin, destination);
      entries.set(ambulanceId, { origin, destinationKey, route, routedAt: now() });
      return route;
    },
  };
}

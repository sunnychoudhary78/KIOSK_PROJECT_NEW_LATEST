import {
  APPROACH_CACHE_TTL_MS,
  approachCacheKey,
  approachEndpointsFromSnaps,
  classifySpeedIntervals,
  samplePointsAround,
  type ApproachTraffic,
  type LatLng,
  type SpeedReadingInterval,
} from './approach.js';

const ROADS_URL = 'https://roads.googleapis.com/v1/nearestRoads';
const ROUTES_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes';

type CacheEntry = { value: ApproachTraffic; expiresAt: number };

export type ApproachTrafficClient = {
  getApproachTraffic(station: LatLng): Promise<ApproachTraffic>;
};

type FetchLike = typeof fetch;

export function createApproachTrafficClient(options: {
  apiKey: string | undefined;
  fetchImpl?: FetchLike;
  now?: () => number;
  cacheTtlMs?: number;
}): ApproachTrafficClient {
  const cache = new Map<string, CacheEntry>();
  const fetchImpl = options.fetchImpl ?? fetch;
  const now = options.now ?? Date.now;
  const ttl = options.cacheTtlMs ?? APPROACH_CACHE_TTL_MS;
  const apiKey = options.apiKey?.trim() ?? '';

  return {
    async getApproachTraffic(station: LatLng): Promise<ApproachTraffic> {
      const key = approachCacheKey(station.lat, station.lng);
      const hit = cache.get(key);
      if (hit && hit.expiresAt > now()) {
        return hit.value;
      }

      let value: ApproachTraffic = 'unknown';
      if (apiKey) {
        try {
          value = await probeApproach(apiKey, station, fetchImpl);
        } catch {
          value = 'unknown';
        }
      }

      cache.set(key, { value, expiresAt: now() + ttl });
      return value;
    },
  };
}

async function probeApproach(
  apiKey: string,
  station: LatLng,
  fetchImpl: FetchLike,
): Promise<ApproachTraffic> {
  const snaps = await nearestRoads(apiKey, samplePointsAround(station), fetchImpl);
  const endpoints = approachEndpointsFromSnaps(station, snaps);
  if (!endpoints) {
    return 'unknown';
  }
  const intervals = await routeSpeedIntervals(apiKey, endpoints.origin, endpoints.destination, fetchImpl);
  return classifySpeedIntervals(intervals);
}

async function nearestRoads(
  apiKey: string,
  points: LatLng[],
  fetchImpl: FetchLike,
): Promise<LatLng[]> {
  const pointsParam = points.map((p) => `${p.lat},${p.lng}`).join('|');
  const url = `${ROADS_URL}?points=${encodeURIComponent(pointsParam)}&key=${encodeURIComponent(apiKey)}`;
  const response = await fetchImpl(url, { signal: AbortSignal.timeout(10_000) });
  if (!response.ok) {
    throw new Error(`Roads HTTP ${response.status}`);
  }
  const payload = (await response.json()) as {
    snappedPoints?: Array<{ location?: { latitude?: number; longitude?: number } }>;
  };
  const snaps: LatLng[] = [];
  for (const point of payload.snappedPoints ?? []) {
    const lat = point.location?.latitude;
    const lng = point.location?.longitude;
    if (typeof lat === 'number' && typeof lng === 'number') {
      snaps.push({ lat, lng });
    }
  }
  return snaps;
}

async function routeSpeedIntervals(
  apiKey: string,
  origin: LatLng,
  destination: LatLng,
  fetchImpl: FetchLike,
): Promise<SpeedReadingInterval[]> {
  const response = await fetchImpl(ROUTES_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask':
        'routes.distanceMeters,routes.duration,routes.staticDuration,routes.polyline,routes.travelAdvisory.speedReadingIntervals',
    },
    body: JSON.stringify({
      origin: { location: { latLng: { latitude: origin.lat, longitude: origin.lng } } },
      destination: {
        location: { latLng: { latitude: destination.lat, longitude: destination.lng } },
      },
      travelMode: 'DRIVE',
      routingPreference: 'TRAFFIC_AWARE',
      extraComputations: ['TRAFFIC_ON_POLYLINE'],
    }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) {
    throw new Error(`Routes HTTP ${response.status}`);
  }
  const payload = (await response.json()) as {
    routes?: Array<{
      travelAdvisory?: { speedReadingIntervals?: SpeedReadingInterval[] };
    }>;
  };
  return payload.routes?.[0]?.travelAdvisory?.speedReadingIntervals ?? [];
}

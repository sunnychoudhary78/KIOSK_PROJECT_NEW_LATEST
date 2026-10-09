import type { Logger } from '../../infrastructure/logging/logger.js';
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
const BODY_SNIPPET = 240;

type CacheEntry = { value: ApproachTraffic; expiresAt: number };

export type ApproachTrafficClient = {
  getApproachTraffic(station: LatLng): Promise<ApproachTraffic>;
};

type FetchLike = typeof fetch;

export function createApproachTrafficClient(options: {
  apiKey: string | undefined;
  logger: Logger;
  fetchImpl?: FetchLike;
  now?: () => number;
  cacheTtlMs?: number;
}): ApproachTrafficClient {
  const cache = new Map<string, CacheEntry>();
  const fetchImpl = options.fetchImpl ?? fetch;
  const now = options.now ?? Date.now;
  const ttl = options.cacheTtlMs ?? APPROACH_CACHE_TTL_MS;
  const apiKey = options.apiKey?.trim() ?? '';
  const logger = options.logger;

  return {
    async getApproachTraffic(station: LatLng): Promise<ApproachTraffic> {
      const key = approachCacheKey(station.lat, station.lng);
      const hit = cache.get(key);
      if (hit && hit.expiresAt > now()) {
        return hit.value;
      }

      const coords = { lat: roundCoord(station.lat), lng: roundCoord(station.lng) };
      let value: ApproachTraffic = 'unknown';

      if (!apiKey) {
        logger.warn({ event: 'approach_traffic_no_api_key', ...coords }, 'Approach traffic skipped');
      } else {
        try {
          value = await probeApproach(apiKey, station, fetchImpl, logger, coords);
        } catch (error) {
          const err = error instanceof Error ? error.message : String(error);
          // Roads/Routes HTTP failures are already logged with response body.
          if (!err.startsWith('Roads HTTP') && !err.startsWith('Routes HTTP')) {
            logger.warn(
              { event: 'approach_traffic_failed', ...coords, err },
              'Approach traffic probe failed',
            );
          }
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
  logger: Logger,
  coords: { lat: number; lng: number },
): Promise<ApproachTraffic> {
  const snaps = await nearestRoads(apiKey, samplePointsAround(station), fetchImpl, logger, coords);
  const endpoints = approachEndpointsFromSnaps(station, snaps);
  if (!endpoints) {
    logger.warn(
      { event: 'approach_traffic_no_road', ...coords, snapCount: snaps.length },
      'Approach traffic: no road snap/endpoints',
    );
    return 'unknown';
  }
  const intervals = await routeSpeedIntervals(
    apiKey,
    endpoints.origin,
    endpoints.destination,
    fetchImpl,
    logger,
    coords,
  );
  if (intervals.length === 0) {
    logger.warn(
      { event: 'approach_traffic_no_intervals', ...coords },
      'Approach traffic: empty speedReadingIntervals',
    );
    return 'unknown';
  }
  const status = classifySpeedIntervals(intervals);
  logger.debug({ event: 'approach_traffic_ok', ...coords, status }, 'Approach traffic ok');
  return status;
}

async function nearestRoads(
  apiKey: string,
  points: LatLng[],
  fetchImpl: FetchLike,
  logger: Logger,
  coords: { lat: number; lng: number },
): Promise<LatLng[]> {
  const pointsParam = points.map((p) => `${p.lat},${p.lng}`).join('|');
  const url = `${ROADS_URL}?points=${encodeURIComponent(pointsParam)}&key=${encodeURIComponent(apiKey)}`;
  const response = await fetchImpl(url, { signal: AbortSignal.timeout(10_000) });
  if (!response.ok) {
    const body = await readBodySnippet(response);
    logger.warn(
      { event: 'approach_traffic_roads_http', ...coords, status: response.status, body },
      'Approach traffic: Roads API error',
    );
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
  logger: Logger,
  coords: { lat: number; lng: number },
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
    const body = await readBodySnippet(response);
    logger.warn(
      { event: 'approach_traffic_routes_http', ...coords, status: response.status, body },
      'Approach traffic: Routes API error',
    );
    throw new Error(`Routes HTTP ${response.status}`);
  }
  const payload = (await response.json()) as {
    routes?: Array<{
      travelAdvisory?: { speedReadingIntervals?: SpeedReadingInterval[] };
    }>;
  };
  return payload.routes?.[0]?.travelAdvisory?.speedReadingIntervals ?? [];
}

async function readBodySnippet(response: Response): Promise<string> {
  try {
    const text = await response.text();
    return text.length <= BODY_SNIPPET ? text : `${text.slice(0, BODY_SNIPPET)}…`;
  } catch {
    return '';
  }
}

function roundCoord(value: number): number {
  return Math.round(value * 10_000) / 10_000;
}

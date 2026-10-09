import type { Logger } from '../../infrastructure/logging/logger.js';
import {
  APPROACH_CACHE_TTL_MS,
  buildRouteTrafficSegments,
  classifyApproachFromRoute,
  parseDurationSec,
  routeTrafficCacheKey,
  type ApproachTraffic,
  type LatLng,
  type RouteTrafficSegment,
  type SpeedReadingInterval,
} from './approach.js';

const ROUTES_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes';
const BODY_SNIPPET = 240;

export type RouteTrafficResult = {
  approachTraffic: ApproachTraffic;
  driveDistanceM: number | null;
  driveDurationSec: number | null;
  routeTrafficSegments: RouteTrafficSegment[];
};

const UNKNOWN_RESULT: RouteTrafficResult = {
  approachTraffic: 'unknown',
  driveDistanceM: null,
  driveDurationSec: null,
  routeTrafficSegments: [],
};

type CacheEntry = { value: RouteTrafficResult; expiresAt: number };

export type ApproachTrafficClient = {
  getRouteTraffic(origin: LatLng, station: LatLng): Promise<RouteTrafficResult>;
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
    async getRouteTraffic(origin: LatLng, station: LatLng): Promise<RouteTrafficResult> {
      const key = routeTrafficCacheKey(origin, station);
      const hit = cache.get(key);
      if (hit && hit.expiresAt > now()) {
        return hit.value;
      }

      const coords = {
        originLat: roundCoord(origin.lat),
        originLng: roundCoord(origin.lng),
        lat: roundCoord(station.lat),
        lng: roundCoord(station.lng),
      };
      let value: RouteTrafficResult = UNKNOWN_RESULT;

      if (!apiKey) {
        logger.warn({ event: 'approach_traffic_no_api_key', ...coords }, 'Route traffic skipped');
      } else {
        try {
          value = await probeRoute(apiKey, origin, station, fetchImpl, logger, coords);
        } catch (error) {
          const err = error instanceof Error ? error.message : String(error);
          if (!err.startsWith('Routes HTTP')) {
            logger.warn(
              { event: 'approach_traffic_failed', ...coords, err },
              'Route traffic probe failed',
            );
          }
          value = UNKNOWN_RESULT;
        }
      }

      cache.set(key, { value, expiresAt: now() + ttl });
      return value;
    },
  };
}

async function probeRoute(
  apiKey: string,
  origin: LatLng,
  station: LatLng,
  fetchImpl: FetchLike,
  logger: Logger,
  coords: { originLat: number; originLng: number; lat: number; lng: number },
): Promise<RouteTrafficResult> {
  const route = await computeRoute(apiKey, origin, station, fetchImpl, logger, coords);
  const intervals = route.intervals;
  if (intervals.length === 0) {
    logger.warn(
      { event: 'approach_traffic_no_intervals', ...coords },
      'Route traffic: empty speedReadingIntervals',
    );
    return {
      approachTraffic: 'unknown',
      driveDistanceM: route.distanceMeters,
      driveDurationSec: route.durationSec,
      routeTrafficSegments: [],
    };
  }

  const approachTraffic = classifyApproachFromRoute(intervals, route.distanceMeters ?? 0);
  const routeTrafficSegments = buildRouteTrafficSegments(intervals);
  logger.debug(
    {
      event: 'approach_traffic_ok',
      ...coords,
      status: approachTraffic,
      distanceM: route.distanceMeters,
      durationSec: route.durationSec,
    },
    'Route traffic ok',
  );
  return {
    approachTraffic,
    driveDistanceM: route.distanceMeters,
    driveDurationSec: route.durationSec,
    routeTrafficSegments,
  };
}

async function computeRoute(
  apiKey: string,
  origin: LatLng,
  destination: LatLng,
  fetchImpl: FetchLike,
  logger: Logger,
  coords: { originLat: number; originLng: number; lat: number; lng: number },
): Promise<{
  distanceMeters: number | null;
  durationSec: number | null;
  intervals: SpeedReadingInterval[];
}> {
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
        location: { latLng: { latitude: destination.lat, longitude: destination.lng } } },
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
      'Route traffic: Routes API error',
    );
    throw new Error(`Routes HTTP ${response.status}`);
  }
  const payload = (await response.json()) as {
    routes?: Array<{
      distanceMeters?: number;
      duration?: string;
      travelAdvisory?: { speedReadingIntervals?: SpeedReadingInterval[] };
    }>;
  };
  const route = payload.routes?.[0];
  const distanceMeters =
    typeof route?.distanceMeters === 'number' && Number.isFinite(route.distanceMeters)
      ? route.distanceMeters
      : null;
  return {
    distanceMeters,
    durationSec: parseDurationSec(route?.duration),
    intervals: route?.travelAdvisory?.speedReadingIntervals ?? [],
  };
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

import { haversineKm } from '../../shared/geo.js';
import type { NearbyStation } from './nearby.js';

export const APPROACH_HALF_LENGTH_M = 100;
/** End-of-route patch used for station approach / wait heuristic. */
export const APPROACH_PATCH_M = APPROACH_HALF_LENGTH_M * 2;
export const APPROACH_TRAFFIC_LIMIT = 5;
export const APPROACH_CACHE_TTL_MS = 5 * 60 * 1000;

/** Heuristic queue wait: spillover on approach road ≈ cars × fill time. */
export const FILL_MIN_PER_CAR = 3;
export const MODERATE_QUEUE_CARS = 2;
export const HEAVY_QUEUE_CARS = 5;

export type ApproachTraffic = 'clear' | 'moderate' | 'heavy' | 'unknown';

export type LatLng = { lat: number; lng: number };

export type RouteTrafficSpeed = 'NORMAL' | 'SLOW' | 'TRAFFIC_JAM';

export type SpeedReadingInterval = {
  speed?: string;
  startPolylinePointIndex?: number;
  endPolylinePointIndex?: number;
};

export type RouteTrafficSegment = {
  speed: RouteTrafficSpeed;
  fraction: number;
};

const EARTH_RADIUS_M = 6_371_000;

export function isApproachCandidate(station: { cng: boolean; ev: boolean }): boolean {
  return station.cng || station.ev;
}

/** Nearest CNG/EV rows already sorted by distance. */
export function pickApproachTargets(
  stations: NearbyStation[],
  limit: number = APPROACH_TRAFFIC_LIMIT,
): Array<{ index: number; station: NearbyStation }> {
  const targets: Array<{ index: number; station: NearbyStation }> = [];
  for (let index = 0; index < stations.length; index += 1) {
    const station = stations[index];
    if (!station || !isApproachCandidate(station)) {
      continue;
    }
    targets.push({ index, station });
    if (targets.length >= limit) {
      break;
    }
  }
  return targets;
}

export function classifySpeedIntervals(intervals: SpeedReadingInterval[]): ApproachTraffic {
  if (intervals.length === 0) {
    return 'unknown';
  }
  let sawSlow = false;
  for (const interval of intervals) {
    const speed = interval.speed?.toUpperCase();
    if (speed === 'TRAFFIC_JAM') {
      return 'heavy';
    }
    if (speed === 'SLOW') {
      sawSlow = true;
    }
  }
  return sawSlow ? 'moderate' : 'clear';
}

/** Estimated queue wait minutes from approach status; null when none shown. */
export function waitMinutesForApproach(status: ApproachTraffic): number | null {
  if (status === 'moderate') {
    return MODERATE_QUEUE_CARS * FILL_MIN_PER_CAR;
  }
  if (status === 'heavy') {
    return HEAVY_QUEUE_CARS * FILL_MIN_PER_CAR;
  }
  return null;
}

/** Google Routes duration strings like `45s`, `90s`, or `12m34s`. */
export function parseDurationSec(raw: string | undefined | null): number | null {
  if (raw == null || raw === '') {
    return null;
  }
  const trimmed = raw.trim();
  const simple = /^(\d+(?:\.\d+)?)s$/i.exec(trimmed);
  if (simple) {
    return Math.max(0, Math.round(Number(simple[1])));
  }
  const compound = /^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+(?:\.\d+)?)s)?$/i.exec(trimmed);
  if (!compound) {
    return null;
  }
  const hours = Number(compound[1] ?? 0);
  const minutes = Number(compound[2] ?? 0);
  const seconds = Number(compound[3] ?? 0);
  if (!compound[1] && !compound[2] && !compound[3]) {
    return null;
  }
  return Math.max(0, Math.round(hours * 3600 + minutes * 60 + seconds));
}

export function normalizeRouteSpeed(speed: string | undefined): RouteTrafficSpeed {
  const upper = speed?.toUpperCase();
  if (upper === 'SLOW') {
    return 'SLOW';
  }
  if (upper === 'TRAFFIC_JAM') {
    return 'TRAFFIC_JAM';
  }
  return 'NORMAL';
}

/**
 * Collapse consecutive same-speed intervals into bar segments.
 * Fraction is polyline-index span share, normalized to sum ≈ 1.
 */
export function buildRouteTrafficSegments(
  intervals: SpeedReadingInterval[],
): RouteTrafficSegment[] {
  if (intervals.length === 0) {
    return [];
  }

  type Raw = { speed: RouteTrafficSpeed; span: number };
  const raw: Raw[] = [];
  for (const interval of intervals) {
    const start = interval.startPolylinePointIndex ?? 0;
    const end = interval.endPolylinePointIndex ?? start;
    const span = Math.max(1, end - start);
    const speed = normalizeRouteSpeed(interval.speed);
    const last = raw[raw.length - 1];
    if (last && last.speed === speed) {
      last.span += span;
    } else {
      raw.push({ speed, span });
    }
  }

  const total = raw.reduce((sum, row) => sum + row.span, 0);
  if (total <= 0) {
    return [];
  }

  const segments = raw.map((row) => ({
    speed: row.speed,
    fraction: row.span / total,
  }));
  const sum = segments.reduce((acc, row) => acc + row.fraction, 0);
  if (segments.length > 0 && sum > 0 && Math.abs(sum - 1) > 1e-9) {
    segments[segments.length - 1]!.fraction += 1 - sum;
  }
  return segments;
}

/** Classify station approach from intervals covering the last ~200 m of the route. */
export function classifyApproachFromRoute(
  intervals: SpeedReadingInterval[],
  distanceMeters: number,
  patchMeters: number = APPROACH_PATCH_M,
): ApproachTraffic {
  if (intervals.length === 0) {
    return 'unknown';
  }
  if (!(distanceMeters > 0)) {
    return classifySpeedIntervals(intervals);
  }

  let maxIndex = 0;
  for (const interval of intervals) {
    const end = interval.endPolylinePointIndex ?? interval.startPolylinePointIndex ?? 0;
    if (end > maxIndex) {
      maxIndex = end;
    }
  }
  if (maxIndex <= 0) {
    return classifySpeedIntervals(intervals);
  }

  const patchFraction = Math.min(1, patchMeters / distanceMeters);
  const threshold = maxIndex * (1 - patchFraction);
  const endIntervals = intervals.filter((interval) => {
    const start = interval.startPolylinePointIndex ?? 0;
    const end = interval.endPolylinePointIndex ?? start;
    return end >= threshold;
  });

  return classifySpeedIntervals(endIntervals.length > 0 ? endIntervals : intervals);
}

export function approachCacheKey(lat: number, lng: number): string {
  return `${lat.toFixed(4)},${lng.toFixed(4)}`;
}

export function routeTrafficCacheKey(origin: LatLng, station: LatLng): string {
  return `${approachCacheKey(origin.lat, origin.lng)}>${approachCacheKey(station.lat, station.lng)}`;
}

/** Destination roughly `meters` along `bearingDeg` (0 = north) from a WGS84 point. */
export function offsetMeters(origin: LatLng, bearingDeg: number, meters: number): LatLng {
  const br = (bearingDeg * Math.PI) / 180;
  const lat1 = (origin.lat * Math.PI) / 180;
  const lng1 = (origin.lng * Math.PI) / 180;
  const ang = meters / EARTH_RADIUS_M;
  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(ang) + Math.cos(lat1) * Math.sin(ang) * Math.cos(br),
  );
  const lng2 =
    lng1 +
    Math.atan2(
      Math.sin(br) * Math.sin(ang) * Math.cos(lat1),
      Math.cos(ang) - Math.sin(lat1) * Math.sin(lat2),
    );
  return { lat: (lat2 * 180) / Math.PI, lng: (lng2 * 180) / Math.PI };
}

export function bearingDegrees(from: LatLng, to: LatLng): number {
  const lat1 = (from.lat * Math.PI) / 180;
  const lat2 = (to.lat * Math.PI) / 180;
  const dLng = ((to.lng - from.lng) * Math.PI) / 180;
  const y = Math.sin(dLng) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
  const br = (Math.atan2(y, x) * 180) / Math.PI;
  return (br + 360) % 360;
}

/**
 * From snapped road points near a station, pick a center on the road and
 * endpoints about `halfLengthM` each way.
 */
export function approachEndpointsFromSnaps(
  station: LatLng,
  snaps: LatLng[],
  halfLengthM: number = APPROACH_HALF_LENGTH_M,
): { origin: LatLng; destination: LatLng } | null {
  if (snaps.length === 0) {
    return null;
  }

  let center = snaps[0]!;
  let centerDist = haversineKm(station.lat, station.lng, center.lat, center.lng);
  for (const snap of snaps.slice(1)) {
    const dist = haversineKm(station.lat, station.lng, snap.lat, snap.lng);
    if (dist < centerDist) {
      center = snap;
      centerDist = dist;
    }
  }

  let bearing: number | null = null;
  let bestPairDist = 0;
  for (let i = 0; i < snaps.length; i += 1) {
    for (let j = i + 1; j < snaps.length; j += 1) {
      const a = snaps[i]!;
      const b = snaps[j]!;
      const distM = haversineKm(a.lat, a.lng, b.lat, b.lng) * 1000;
      if (distM > bestPairDist && distM >= 8) {
        bestPairDist = distM;
        bearing = bearingDegrees(a, b);
      }
    }
  }

  if (bearing == null) {
    // Single snap: sample east–west along the map as a weak fallback.
    bearing = 90;
  }

  return {
    origin: offsetMeters(center, bearing, -halfLengthM),
    destination: offsetMeters(center, bearing, halfLengthM),
  };
}

export function samplePointsAround(station: LatLng, radiusM: number = 35): LatLng[] {
  return [
    station,
    offsetMeters(station, 0, radiusM),
    offsetMeters(station, 90, radiusM),
    offsetMeters(station, 180, radiusM),
    offsetMeters(station, 270, radiusM),
  ];
}

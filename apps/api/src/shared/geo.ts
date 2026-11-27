const EARTH_RADIUS_KM = 6371;

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

/**
 * Fix common "long, lat" entry mistakes for India/NCR kiosks.
 * Latitude here is ~6–37; longitude is ~68–98. If the pair looks swapped, correct it.
 */
export function normalizeLatLng(
  latitude: number,
  longitude: number,
): { latitude: number; longitude: number } {
  const latLooksLikeLng = latitude >= 40 && latitude <= 100;
  const lngLooksLikeLat = longitude >= 6 && longitude <= 40;
  if (latLooksLikeLng && lngLooksLikeLat) {
    return { latitude: longitude, longitude: latitude };
  }
  return { latitude, longitude };
}

/** True when both pins match at admin UI precision (5 decimal places ≈ 1 m). */
export function sameMapPin(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): boolean {
  const a = normalizeLatLng(lat1, lng1);
  const b = normalizeLatLng(lat2, lng2);
  return a.latitude.toFixed(5) === b.latitude.toFixed(5) && a.longitude.toFixed(5) === b.longitude.toFixed(5);
}

/** Great-circle distance between two WGS84 points, in kilometres. */
export function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const a = normalizeLatLng(lat1, lng1);
  const b = normalizeLatLng(lat2, lng2);
  if (sameMapPin(a.latitude, a.longitude, b.latitude, b.longitude)) {
    return 0;
  }
  const dLat = toRadians(b.latitude - a.latitude);
  const dLng = toRadians(b.longitude - a.longitude);
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(a.latitude)) * Math.cos(toRadians(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(x)));
}

/** Round distance for API responses (metres precision for short ranges). */
export function roundDistanceKm(km: number): number {
  if (km < 0.05) return 0;
  if (km < 10) return Math.round(km * 100) / 100;
  if (km < 100) return Math.round(km * 10) / 10;
  return Math.round(km);
}

import { haversineKm } from '../../shared/geo.js';
import type { FuelFlags } from './osm.js';

/** Search this far from the OpenStreetMap point for the Google pump. */
export const GOOGLE_MATCH_RADIUS_M = 100;

export type GooglePlaceCandidate = {
  id: string;
  latitude: number;
  longitude: number;
};

export function googleIncludedType(station: FuelFlags): 'gas_station' | 'electric_vehicle_charging_station' {
  const isFuel = station.petrol || station.diesel || station.cng || station.fuelUntyped;
  if (station.ev && !isFuel) {
    return 'electric_vehicle_charging_station';
  }
  return 'gas_station';
}

export function normalizeGooglePlaceId(id: string): string {
  const trimmed = id.trim();
  return trimmed.startsWith('places/') ? trimmed.slice('places/'.length) : trimmed;
}

/** Closest candidate inside the radius, or null when Google has no pump there. */
export function pickClosestGooglePlace(
  origin: { lat: number; lng: number },
  candidates: GooglePlaceCandidate[],
  radiusM: number = GOOGLE_MATCH_RADIUS_M,
): string | null {
  let best: { id: string; meters: number } | null = null;
  for (const candidate of candidates) {
    const id = normalizeGooglePlaceId(candidate.id);
    if (!id) {
      continue;
    }
    const meters = haversineKm(origin.lat, origin.lng, candidate.latitude, candidate.longitude) * 1000;
    if (meters > radiusM) {
      continue;
    }
    if (!best || meters < best.meters) {
      best = { id, meters };
    }
  }
  return best?.id ?? null;
}

export function parseNearbyPlaces(payload: unknown): GooglePlaceCandidate[] {
  if (!payload || typeof payload !== 'object') {
    return [];
  }
  const places = (payload as { places?: unknown }).places;
  if (!Array.isArray(places)) {
    return [];
  }
  const candidates: GooglePlaceCandidate[] = [];
  for (const place of places) {
    if (!place || typeof place !== 'object') {
      continue;
    }
    const record = place as { id?: unknown; location?: { latitude?: unknown; longitude?: unknown } };
    const latitude = record.location?.latitude;
    const longitude = record.location?.longitude;
    if (typeof record.id !== 'string' || typeof latitude !== 'number' || typeof longitude !== 'number') {
      continue;
    }
    candidates.push({ id: record.id, latitude, longitude });
  }
  return candidates;
}

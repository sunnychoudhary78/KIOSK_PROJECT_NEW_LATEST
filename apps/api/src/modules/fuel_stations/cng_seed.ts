import { haversineKm } from '../../shared/geo.js';
import { DELHI_NCR_BBOX } from './osm.js';
import { normalizeGooglePlaceId } from './google.js';

/** ~3 km in degrees at Delhi latitude. */
export const CNG_GRID_STEP_DEG = 0.027;
export const CNG_SEARCH_RADIUS_M = 2500;
export const CNG_MERGE_RADIUS_M = 80;

export type CngSeedPlace = {
  placeId: string;
  name: string | null;
  address: string | null;
  latitude: number;
  longitude: number;
};

export type CngMergeCandidate = {
  id: string;
  googlePlaceId: string | null;
  latitude: number;
  longitude: number;
  name: string | null;
  address: string | null;
};

export type CngMergeAction =
  | { type: 'update'; id: string; name: string | null; address: string | null; googlePlaceId: string }
  | { type: 'insert'; place: CngSeedPlace; osmId: string };

export function googleOsmId(placeId: string): string {
  return `google/${normalizeGooglePlaceId(placeId)}`;
}

export function isGoogleSourcedOsmId(osmId: string): boolean {
  return osmId.startsWith('google/');
}

export function pointInDelhiNcr(
  lat: number,
  lng: number,
  bbox: typeof DELHI_NCR_BBOX = DELHI_NCR_BBOX,
): boolean {
  return lat >= bbox.south && lat <= bbox.north && lng >= bbox.west && lng <= bbox.east;
}

export function buildNcrGrid(
  bbox: typeof DELHI_NCR_BBOX = DELHI_NCR_BBOX,
  stepDeg: number = CNG_GRID_STEP_DEG,
): Array<{ lat: number; lng: number }> {
  const cells: Array<{ lat: number; lng: number }> = [];
  for (let lat = bbox.south; lat <= bbox.north + 1e-9; lat += stepDeg) {
    for (let lng = bbox.west; lng <= bbox.east + 1e-9; lng += stepDeg) {
      cells.push({
        lat: Math.min(lat, bbox.north),
        lng: Math.min(lng, bbox.east),
      });
    }
  }
  return cells;
}

export function isCngStationName(name: string | null | undefined): boolean {
  return name != null && /\bCNG\b/i.test(name);
}

export function acceptCngPlace(
  place: {
    placeId: string;
    name: string | null;
    latitude: number;
    longitude: number;
  },
  bbox: typeof DELHI_NCR_BBOX = DELHI_NCR_BBOX,
): boolean {
  if (!place.placeId.trim()) {
    return false;
  }
  if (!isCngStationName(place.name)) {
    return false;
  }
  return pointInDelhiNcr(place.latitude, place.longitude, bbox);
}

export function decideCngMerge(
  place: CngSeedPlace,
  existing: CngMergeCandidate[],
  mergeRadiusM: number = CNG_MERGE_RADIUS_M,
): CngMergeAction {
  const placeId = normalizeGooglePlaceId(place.placeId);
  const byPlaceId = existing.find((row) => row.googlePlaceId === placeId);
  if (byPlaceId) {
    return {
      type: 'update',
      id: byPlaceId.id,
      name: byPlaceId.name?.trim() ? byPlaceId.name : place.name,
      address: byPlaceId.address?.trim() ? byPlaceId.address : place.address,
      googlePlaceId: placeId,
    };
  }

  let nearest: { row: CngMergeCandidate; meters: number } | null = null;
  for (const row of existing) {
    const meters = haversineKm(place.latitude, place.longitude, row.latitude, row.longitude) * 1000;
    if (meters > mergeRadiusM) {
      continue;
    }
    if (!nearest || meters < nearest.meters) {
      nearest = { row, meters };
    }
  }
  if (nearest) {
    return {
      type: 'update',
      id: nearest.row.id,
      name: nearest.row.name?.trim() ? nearest.row.name : place.name,
      address: nearest.row.address?.trim() ? nearest.row.address : place.address,
      googlePlaceId: nearest.row.googlePlaceId ?? placeId,
    };
  }

  return { type: 'insert', place: { ...place, placeId }, osmId: googleOsmId(placeId) };
}

export function parseTextSearchPlaces(payload: unknown): CngSeedPlace[] {
  if (!payload || typeof payload !== 'object') {
    return [];
  }
  const places = (payload as { places?: unknown }).places;
  if (!Array.isArray(places)) {
    return [];
  }
  const out: CngSeedPlace[] = [];
  for (const place of places) {
    if (!place || typeof place !== 'object') {
      continue;
    }
    const record = place as {
      id?: unknown;
      displayName?: { text?: unknown };
      formattedAddress?: unknown;
      location?: { latitude?: unknown; longitude?: unknown };
    };
    const lat = record.location?.latitude;
    const lng = record.location?.longitude;
    if (typeof record.id !== 'string' || typeof lat !== 'number' || typeof lng !== 'number') {
      continue;
    }
    const name =
      typeof record.displayName?.text === 'string' ? record.displayName.text.trim() || null : null;
    const address =
      typeof record.formattedAddress === 'string' ? record.formattedAddress.trim() || null : null;
    out.push({
      placeId: normalizeGooglePlaceId(record.id),
      name,
      address,
      latitude: lat,
      longitude: lng,
    });
  }
  return out;
}

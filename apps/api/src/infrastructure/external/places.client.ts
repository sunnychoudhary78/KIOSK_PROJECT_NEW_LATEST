import { AppError } from '../../shared/errors.js';
import type { Logger } from '../logging/logger.js';

const GOOGLE_AUTOCOMPLETE_URL = 'https://places.googleapis.com/v1/places:autocomplete';
const GOOGLE_PLACE_URL = 'https://places.googleapis.com/v1/places';
const OPEN_METEO_GEOCODE_URL = 'https://geocoding-api.open-meteo.com/v1/search';
const PLACES_TIMEOUT_MS = 12_000;
const MAX_SUGGESTIONS = 8;

export type PlaceSuggestion = {
  id: string;
  label: string;
  subtitle: string;
};

export type ResolvedPlace = {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
};

type FetchLike = typeof fetch;

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

function asString(value: unknown): string | undefined {
  if (typeof value === 'string' && value.trim()) {
    return value.trim();
  }
  return undefined;
}

function asNumber(value: unknown): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  const parsed = Number(asString(value));
  return Number.isFinite(parsed) ? parsed : undefined;
}

export function normalizeGooglePlaceId(id: string): string {
  const trimmed = id.trim();
  return trimmed.startsWith('places/') ? trimmed.slice('places/'.length) : trimmed;
}

export function encodeOpenMeteoPlaceId(input: {
  name: string;
  latitude: number;
  longitude: number;
}): string {
  return `om:${input.latitude},${input.longitude}|${encodeURIComponent(input.name)}`;
}

export function parseOpenMeteoPlaceId(id: string): ResolvedPlace | null {
  if (!id.startsWith('om:')) {
    return null;
  }
  const raw = id.slice(3);
  const pipe = raw.indexOf('|');
  if (pipe < 0) {
    return null;
  }
  const coords = raw.slice(0, pipe);
  const name = decodeURIComponent(raw.slice(pipe + 1));
  const [latText, lngText] = coords.split(',');
  const latitude = Number(latText);
  const longitude = Number(lngText);
  if (!name || !Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return null;
  }
  return { id, name, latitude, longitude };
}

export function mapGoogleAutocomplete(body: unknown): PlaceSuggestion[] {
  const root = asRecord(body);
  const suggestions = Array.isArray(root?.suggestions) ? root.suggestions : [];
  const mapped: PlaceSuggestion[] = [];
  for (const entry of suggestions) {
    const record = asRecord(entry);
    const prediction = asRecord(record?.placePrediction ?? record?.place_prediction);
    if (!prediction) {
      continue;
    }
    const placeId = asString(prediction.placeId ?? prediction.place_id);
    if (!placeId) {
      continue;
    }
    const structured = asRecord(prediction.structuredFormat ?? prediction.structured_format);
    const main =
      asString(asRecord(structured?.mainText ?? structured?.main_text)?.text) ??
      asString(asRecord(prediction.text)?.text) ??
      placeId;
    const secondary =
      asString(asRecord(structured?.secondaryText ?? structured?.secondary_text)?.text) ?? '';
    mapped.push({
      id: normalizeGooglePlaceId(placeId),
      label: main,
      subtitle: secondary,
    });
    if (mapped.length >= MAX_SUGGESTIONS) {
      break;
    }
  }
  return mapped;
}

export function mapGooglePlaceDetails(body: unknown, requestedId: string): ResolvedPlace {
  const root = asRecord(body);
  if (!root) {
    throw new AppError('validation_error', 'Place not found', 404);
  }
  const location = asRecord(root.location);
  const latitude = asNumber(location?.latitude);
  const longitude = asNumber(location?.longitude);
  if (latitude === undefined || longitude === undefined) {
    throw new AppError('validation_error', 'Place coordinates unavailable', 404);
  }
  const displayName =
    asString(asRecord(root.displayName)?.text) ??
    asString(root.formattedAddress) ??
    requestedId;
  return {
    id: normalizeGooglePlaceId(asString(root.id) ?? requestedId),
    name: displayName,
    latitude,
    longitude,
  };
}

export function mapOpenMeteoSuggestions(body: unknown): PlaceSuggestion[] {
  const root = asRecord(body);
  const results = Array.isArray(root?.results) ? root.results : [];
  const mapped: PlaceSuggestion[] = [];
  for (const entry of results) {
    const record = asRecord(entry);
    if (!record) {
      continue;
    }
    const name = asString(record.name);
    const latitude = asNumber(record.latitude);
    const longitude = asNumber(record.longitude);
    if (!name || latitude === undefined || longitude === undefined) {
      continue;
    }
    const parts = [record.admin1, record.country].map(asString).filter(Boolean);
    const fullName = [name, ...parts].join(', ');
    mapped.push({
      id: encodeOpenMeteoPlaceId({ name: fullName, latitude, longitude }),
      label: name,
      subtitle: parts.join(', '),
    });
    if (mapped.length >= MAX_SUGGESTIONS) {
      break;
    }
  }
  return mapped;
}

export type PlacesClient = {
  autocomplete(query: string): Promise<PlaceSuggestion[]>;
  resolve(id: string): Promise<ResolvedPlace>;
};

export function createPlacesClient(options: {
  apiKey?: string;
  logger: Logger;
  fetchImpl?: FetchLike;
}): PlacesClient {
  const fetchImpl = options.fetchImpl ?? fetch;
  const apiKey = options.apiKey?.trim() ?? '';

  async function openMeteoAutocomplete(query: string): Promise<PlaceSuggestion[]> {
    const url =
      `${OPEN_METEO_GEOCODE_URL}?` +
      new URLSearchParams({
        name: query,
        count: String(MAX_SUGGESTIONS),
        language: 'en',
        format: 'json',
      }).toString();
    const response = await fetchImpl(url, {
      method: 'GET',
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(PLACES_TIMEOUT_MS),
    });
    if (!response.ok) {
      throw new AppError('vedastro_failed', 'Unable to search places', 502, {
        status: response.status,
      });
    }
    return mapOpenMeteoSuggestions(await response.json());
  }

  async function googleAutocomplete(query: string): Promise<PlaceSuggestion[]> {
    const response = await fetchImpl(GOOGLE_AUTOCOMPLETE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
          'suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat',
      },
      body: JSON.stringify({
        input: query,
        includedRegionCodes: ['IN'],
      }),
      signal: AbortSignal.timeout(PLACES_TIMEOUT_MS),
    });
    if (!response.ok) {
      throw new AppError('vedastro_failed', 'Google Places autocomplete failed', 502, {
        status: response.status,
      });
    }
    return mapGoogleAutocomplete(await response.json());
  }

  async function googleDetails(id: string): Promise<ResolvedPlace> {
    const placeId = normalizeGooglePlaceId(id);
    const response = await fetchImpl(`${GOOGLE_PLACE_URL}/${encodeURIComponent(placeId)}`, {
      method: 'GET',
      headers: {
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
      },
      signal: AbortSignal.timeout(PLACES_TIMEOUT_MS),
    });
    if (response.status === 404) {
      throw new AppError('validation_error', 'Place not found', 404);
    }
    if (!response.ok) {
      throw new AppError('vedastro_failed', 'Google Place details failed', 502, {
        status: response.status,
      });
    }
    return mapGooglePlaceDetails(await response.json(), placeId);
  }

  return {
    async autocomplete(query: string): Promise<PlaceSuggestion[]> {
      const trimmed = query.trim();
      if (trimmed.length < 2) {
        return [];
      }
      if (apiKey) {
        try {
          const google = await googleAutocomplete(trimmed);
          if (google.length > 0) {
            return google;
          }
        } catch (error) {
          options.logger.warn({ err: error, query: trimmed }, '[Places] Google autocomplete failed');
        }
      }
      return openMeteoAutocomplete(trimmed);
    },

    async resolve(id: string): Promise<ResolvedPlace> {
      const trimmed = id.trim();
      if (!trimmed) {
        throw new AppError('validation_error', 'Place id is required', 400);
      }
      const openMeteo = parseOpenMeteoPlaceId(trimmed);
      if (openMeteo) {
        return openMeteo;
      }
      if (!apiKey) {
        throw new AppError(
          'validation_error',
          'Place details unavailable without Google Places key',
          400,
        );
      }
      return googleDetails(trimmed);
    },
  };
}

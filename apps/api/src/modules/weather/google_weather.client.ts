import type { Logger } from '../../infrastructure/logging/logger.js';
import {
  aqiLabelFromIndiaAqi,
  formatDominantPollutant,
  normalizeAqiCategory,
  weatherCodeFromGoogleType,
} from './labels.js';

const WEATHER_URL = 'https://weather.googleapis.com/v1/currentConditions:lookup';
const AIR_QUALITY_URL = 'https://airquality.googleapis.com/v1/currentConditions:lookup';
const AIR_QUALITY_HISTORY_URL = 'https://airquality.googleapis.com/v1/history:lookup';
export const WEATHER_CACHE_TTL_MS = 15 * 60 * 1000;

export type WeatherSnapshot = {
  temperatureC: number | null;
  feelsLikeC: number | null;
  humidityPct: number | null;
  weatherCode: number | null;
  weatherLabel: string | null;
  windKmh: number | null;
  uvIndex: number | null;
  aqi: number | null;
  aqiLabel: string | null;
  dominantPollutant: string | null;
};

export type AirQualityColor = { r: number; g: number; b: number };

export type AirQualityPollutant = {
  code: string;
  displayName: string;
  concentration: { value: number; units: string } | null;
};

export type AirQualityHealthRecommendations = {
  generalPopulation: string | null;
  elderly: string | null;
  lungDiseasePopulation: string | null;
  heartDiseasePopulation: string | null;
  athletes: string | null;
  pregnantWomen: string | null;
  children: string | null;
};

export type AirQualityDetail = {
  aqi: number | null;
  aqiLabel: string | null;
  dominantPollutant: string | null;
  color: AirQualityColor | null;
  pollutants: AirQualityPollutant[];
  healthRecommendations: AirQualityHealthRecommendations | null;
  updatedAt: string | null;
};

export type AirQualityHistoryPoint = {
  dateTime: string;
  aqi: number | null;
  aqiLabel: string | null;
};

export type AirQualityHistory = {
  points: AirQualityHistoryPoint[];
};

type CacheEntry<T> = { value: T; expiresAt: number };

export type GoogleWeatherClient = {
  getWeather(lat: number, lng: number): Promise<WeatherSnapshot>;
  getAirQualityDetail(lat: number, lng: number): Promise<AirQualityDetail>;
  getAirQualityHistory(lat: number, lng: number, hours?: number): Promise<AirQualityHistory>;
};

type FetchLike = typeof fetch;

export function createGoogleWeatherClient(options: {
  apiKey: string | undefined;
  logger: Logger;
  fetchImpl?: FetchLike;
  now?: () => number;
  cacheTtlMs?: number;
}): GoogleWeatherClient {
  const weatherCache = new Map<string, CacheEntry<WeatherSnapshot>>();
  const detailCache = new Map<string, CacheEntry<AirQualityDetail>>();
  const historyCache = new Map<string, CacheEntry<AirQualityHistory>>();
  const fetchImpl = options.fetchImpl ?? fetch;
  const now = options.now ?? Date.now;
  const ttl = options.cacheTtlMs ?? WEATHER_CACHE_TTL_MS;
  const apiKey = options.apiKey?.trim() ?? '';
  const logger = options.logger;

  return {
    async getWeather(lat: number, lng: number): Promise<WeatherSnapshot> {
      const key = cacheKey(lat, lng);
      const hit = weatherCache.get(key);
      if (hit && hit.expiresAt > now()) {
        return hit.value;
      }

      const coords = { lat: roundCoord(lat), lng: roundCoord(lng) };

      if (!apiKey) {
        logger.warn({ event: 'weather_google_no_api_key', ...coords }, 'Google weather skipped');
        throw new Error('Google Weather API key missing');
      }

      const [forecastResult, aqiResult] = await Promise.allSettled([
        fetchCurrentWeather(fetchImpl, apiKey, coords.lat, coords.lng),
        fetchAirQuality(fetchImpl, apiKey, coords.lat, coords.lng),
      ]);

      const forecastOk = forecastResult.status === 'fulfilled';
      const aqiOk = aqiResult.status === 'fulfilled';

      if (!forecastOk && !aqiOk) {
        const forecastErr =
          forecastResult.status === 'rejected'
            ? forecastResult.reason instanceof Error
              ? forecastResult.reason.message
              : String(forecastResult.reason)
            : null;
        logger.warn(
          { event: 'weather_google_failed', ...coords, err: forecastErr },
          'Google weather failed',
        );
        throw new Error('Google Weather unavailable');
      }

      if (!forecastOk) {
        logger.warn(
          {
            event: 'weather_forecast_failed',
            ...coords,
            err:
              forecastResult.reason instanceof Error
                ? forecastResult.reason.message
                : String(forecastResult.reason),
          },
          'Google Weather forecast failed',
        );
      }
      if (!aqiOk) {
        logger.warn(
          {
            event: 'weather_aqi_failed',
            ...coords,
            err:
              aqiResult.reason instanceof Error
                ? aqiResult.reason.message
                : String(aqiResult.reason),
          },
          'Google Air Quality failed',
        );
      }

      const forecast = forecastOk ? forecastResult.value : null;
      const aqi = aqiOk ? aqiResult.value : null;

      const value: WeatherSnapshot = {
        temperatureC: forecast?.temperatureC ?? null,
        feelsLikeC: forecast?.feelsLikeC ?? null,
        humidityPct: forecast?.humidityPct ?? null,
        weatherCode: forecast?.weatherCode ?? null,
        weatherLabel: forecast?.weatherLabel ?? null,
        windKmh: forecast?.windKmh ?? null,
        uvIndex: forecast?.uvIndex ?? null,
        aqi: aqi?.aqi ?? null,
        aqiLabel: aqi?.aqiLabel ?? null,
        dominantPollutant: aqi?.dominantPollutant ?? null,
      };

      weatherCache.set(key, { value, expiresAt: now() + ttl });
      return value;
    },

    async getAirQualityDetail(lat: number, lng: number): Promise<AirQualityDetail> {
      const key = cacheKey(lat, lng);
      const hit = detailCache.get(key);
      if (hit && hit.expiresAt > now()) {
        return hit.value;
      }

      const coords = { lat: roundCoord(lat), lng: roundCoord(lng) };
      if (!apiKey) {
        logger.warn({ event: 'aqi_detail_no_api_key', ...coords }, 'Google AQI detail skipped');
        throw new Error('Google Weather API key missing');
      }

      try {
        const value = await fetchAirQualityDetail(fetchImpl, apiKey, coords.lat, coords.lng);
        detailCache.set(key, { value, expiresAt: now() + ttl });
        return value;
      } catch (err) {
        logger.warn(
          {
            event: 'aqi_detail_failed',
            ...coords,
            err: err instanceof Error ? err.message : String(err),
          },
          'Google Air Quality detail failed',
        );
        throw err;
      }
    },

    async getAirQualityHistory(
      lat: number,
      lng: number,
      hours = 24,
    ): Promise<AirQualityHistory> {
      const clampedHours = clampHistoryHours(hours);
      const key = `${cacheKey(lat, lng)}:${clampedHours}`;
      const hit = historyCache.get(key);
      if (hit && hit.expiresAt > now()) {
        return hit.value;
      }

      const coords = { lat: roundCoord(lat), lng: roundCoord(lng) };
      if (!apiKey) {
        logger.warn({ event: 'aqi_history_no_api_key', ...coords }, 'Google AQI history skipped');
        throw new Error('Google Weather API key missing');
      }

      try {
        const value = await fetchAirQualityHistory(
          fetchImpl,
          apiKey,
          coords.lat,
          coords.lng,
          clampedHours,
        );
        historyCache.set(key, { value, expiresAt: now() + ttl });
        return value;
      } catch (err) {
        logger.warn(
          {
            event: 'aqi_history_failed',
            ...coords,
            hours: clampedHours,
            err: err instanceof Error ? err.message : String(err),
          },
          'Google Air Quality history failed',
        );
        throw err;
      }
    },
  };
}

export function clampHistoryHours(hours: number): number {
  if (!Number.isFinite(hours)) {
    return 24;
  }
  return Math.min(48, Math.max(1, Math.round(hours)));
}

export function parseWeatherPayload(payload: unknown): {
  temperatureC: number | null;
  feelsLikeC: number | null;
  humidityPct: number | null;
  weatherCode: number | null;
  weatherLabel: string | null;
  windKmh: number | null;
  uvIndex: number | null;
} {
  const root = asRecord(payload);
  const condition = asRecord(root?.weatherCondition);
  const description = asRecord(condition?.description);
  const temperature = asRecord(root?.temperature);
  const feelsLike = asRecord(root?.feelsLikeTemperature);
  const wind = asRecord(root?.wind);
  const windSpeed = asRecord(wind?.speed);
  const conditionType = typeof condition?.type === 'string' ? condition.type : null;
  const weatherLabel =
    typeof description?.text === 'string' && description.text.trim()
      ? description.text.trim()
      : null;

  return {
    temperatureC: asFiniteNumber(temperature?.degrees),
    feelsLikeC: asFiniteNumber(feelsLike?.degrees),
    humidityPct: asFiniteNumber(root?.relativeHumidity),
    weatherCode: weatherCodeFromGoogleType(conditionType),
    weatherLabel,
    windKmh: asFiniteNumber(windSpeed?.value),
    uvIndex: asFiniteNumber(root?.uvIndex),
  };
}

export function parseAirQualityPayload(payload: unknown): {
  aqi: number | null;
  aqiLabel: string | null;
  dominantPollutant: string | null;
} {
  const index = pickLocalIndex(payload);
  const aqi = asFiniteNumber(index?.aqi);
  const fromCategory = normalizeAqiCategory(
    typeof index?.category === 'string' ? index.category : null,
  );

  return {
    aqi,
    aqiLabel: fromCategory ?? aqiLabelFromIndiaAqi(aqi),
    dominantPollutant: formatDominantPollutant(
      typeof index?.dominantPollutant === 'string' ? index.dominantPollutant : null,
    ),
  };
}

export function parseAirQualityDetailPayload(payload: unknown): AirQualityDetail {
  const root = asRecord(payload);
  const index = pickLocalIndex(payload);
  const aqi = asFiniteNumber(index?.aqi);
  const fromCategory = normalizeAqiCategory(
    typeof index?.category === 'string' ? index.category : null,
  );
  const updatedAt = typeof root?.dateTime === 'string' && root.dateTime.trim() ? root.dateTime : null;

  return {
    aqi,
    aqiLabel: fromCategory ?? aqiLabelFromIndiaAqi(aqi),
    dominantPollutant: formatDominantPollutant(
      typeof index?.dominantPollutant === 'string' ? index.dominantPollutant : null,
    ),
    color: parseGoogleColor(index?.color),
    pollutants: parsePollutants(root?.pollutants),
    healthRecommendations: parseHealthRecommendations(root?.healthRecommendations),
    updatedAt,
  };
}

export function parseAirQualityHistoryPayload(payload: unknown): AirQualityHistory {
  const root = asRecord(payload);
  const hoursInfo = Array.isArray(root?.hoursInfo) ? root.hoursInfo : [];
  const points: AirQualityHistoryPoint[] = [];

  for (const hour of hoursInfo) {
    const record = asRecord(hour);
    if (!record) {
      continue;
    }
    const dateTime =
      typeof record.dateTime === 'string' && record.dateTime.trim() ? record.dateTime.trim() : null;
    if (!dateTime) {
      continue;
    }
    const parsed = parseAirQualityPayload({ indexes: record.indexes });
    points.push({
      dateTime,
      aqi: parsed.aqi,
      aqiLabel: parsed.aqiLabel,
    });
  }

  points.sort((a, b) => a.dateTime.localeCompare(b.dateTime));
  return { points };
}

function pickLocalIndex(payload: unknown): Record<string, unknown> | null {
  const root = asRecord(payload);
  const indexes = Array.isArray(root?.indexes) ? root.indexes : [];
  const records = indexes.map(asRecord).filter((item): item is Record<string, unknown> => item != null);

  return (
    records.find((item) => typeof item.code === 'string' && item.code.toLowerCase() !== 'uaqi') ??
    records[0] ??
    null
  );
}

function parseGoogleColor(value: unknown): AirQualityColor | null {
  const color = asRecord(value);
  if (!color) {
    return null;
  }
  const r = asColorChannel(color.red);
  const g = asColorChannel(color.green);
  const b = asColorChannel(color.blue);
  if (r == null || g == null || b == null) {
    return null;
  }
  return { r, g, b };
}

/** Google Color uses 0–1 floats; some samples use 0–255. Normalize to 0–255 ints. */
function asColorChannel(value: unknown): number | null {
  const n = asFiniteNumber(value);
  if (n == null) {
    return null;
  }
  if (n >= 0 && n <= 1) {
    return Math.round(n * 255);
  }
  if (n >= 0 && n <= 255) {
    return Math.round(n);
  }
  return null;
}

function parsePollutants(value: unknown): AirQualityPollutant[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const out: AirQualityPollutant[] = [];
  for (const item of value) {
    const record = asRecord(item);
    if (!record) {
      continue;
    }
    const rawCode = typeof record.code === 'string' ? record.code.trim() : '';
    if (!rawCode) {
      continue;
    }
    const displayName =
      (typeof record.displayName === 'string' && record.displayName.trim()) ||
      formatDominantPollutant(rawCode) ||
      rawCode.toUpperCase();
    const concentrationRecord = asRecord(record.concentration);
    const concentrationValue = asFiniteNumber(concentrationRecord?.value);
    const units =
      typeof concentrationRecord?.units === 'string' && concentrationRecord.units.trim()
        ? concentrationRecord.units.trim()
        : null;
    out.push({
      code: rawCode.toLowerCase(),
      displayName,
      concentration:
        concentrationValue != null && units
          ? { value: concentrationValue, units }
          : concentrationValue != null
            ? { value: concentrationValue, units: '' }
            : null,
    });
  }
  return out;
}

function parseHealthRecommendations(value: unknown): AirQualityHealthRecommendations | null {
  const root = asRecord(value);
  if (!root) {
    return null;
  }
  const recommendations: AirQualityHealthRecommendations = {
    generalPopulation: asOptionalString(root.generalPopulation),
    elderly: asOptionalString(root.elderly),
    lungDiseasePopulation: asOptionalString(root.lungDiseasePopulation),
    heartDiseasePopulation: asOptionalString(root.heartDiseasePopulation),
    athletes: asOptionalString(root.athletes),
    pregnantWomen: asOptionalString(root.pregnantWomen),
    children: asOptionalString(root.children),
  };
  const hasAny = Object.values(recommendations).some((text) => text != null);
  return hasAny ? recommendations : null;
}

function asOptionalString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed || null;
}

async function fetchCurrentWeather(
  fetchImpl: FetchLike,
  apiKey: string,
  lat: number,
  lng: number,
): Promise<{
  temperatureC: number | null;
  feelsLikeC: number | null;
  humidityPct: number | null;
  weatherCode: number | null;
  weatherLabel: string | null;
  windKmh: number | null;
  uvIndex: number | null;
}> {
  const url = new URL(WEATHER_URL);
  url.searchParams.set('key', apiKey);
  url.searchParams.set('location.latitude', String(lat));
  url.searchParams.set('location.longitude', String(lng));

  const response = await fetchImpl(url, { signal: AbortSignal.timeout(12_000) });
  if (!response.ok) {
    throw new Error(`Weather HTTP ${response.status}`);
  }
  return parseWeatherPayload(await response.json());
}

async function fetchAirQuality(
  fetchImpl: FetchLike,
  apiKey: string,
  lat: number,
  lng: number,
): Promise<{ aqi: number | null; aqiLabel: string | null; dominantPollutant: string | null }> {
  const url = new URL(AIR_QUALITY_URL);
  url.searchParams.set('key', apiKey);

  const response = await fetchImpl(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      location: { latitude: lat, longitude: lng },
      universalAqi: false,
      extraComputations: ['LOCAL_AQI'],
      languageCode: 'en',
    }),
    signal: AbortSignal.timeout(12_000),
  });
  if (!response.ok) {
    throw new Error(`Air quality HTTP ${response.status}`);
  }
  return parseAirQualityPayload(await response.json());
}

async function fetchAirQualityDetail(
  fetchImpl: FetchLike,
  apiKey: string,
  lat: number,
  lng: number,
): Promise<AirQualityDetail> {
  const url = new URL(AIR_QUALITY_URL);
  url.searchParams.set('key', apiKey);

  const response = await fetchImpl(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      location: { latitude: lat, longitude: lng },
      universalAqi: false,
      extraComputations: ['LOCAL_AQI', 'HEALTH_RECOMMENDATIONS', 'POLLUTANT_CONCENTRATION'],
      languageCode: 'en',
    }),
    signal: AbortSignal.timeout(12_000),
  });
  if (!response.ok) {
    throw new Error(`Air quality detail HTTP ${response.status}`);
  }
  return parseAirQualityDetailPayload(await response.json());
}

async function fetchAirQualityHistory(
  fetchImpl: FetchLike,
  apiKey: string,
  lat: number,
  lng: number,
  hours: number,
): Promise<AirQualityHistory> {
  const url = new URL(AIR_QUALITY_HISTORY_URL);
  url.searchParams.set('key', apiKey);

  const allPoints: AirQualityHistoryPoint[] = [];
  let pageToken: string | undefined;

  do {
    const body: Record<string, unknown> = {
      location: { latitude: lat, longitude: lng },
      hours,
      pageSize: Math.min(hours, 24),
      universalAqi: false,
      extraComputations: ['LOCAL_AQI'],
      languageCode: 'en',
    };
    if (pageToken) {
      body.pageToken = pageToken;
    }

    const response = await fetchImpl(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) {
      throw new Error(`Air quality history HTTP ${response.status}`);
    }

    const payload: unknown = await response.json();
    const page = parseAirQualityHistoryPayload(payload);
    allPoints.push(...page.points);

    const root = asRecord(payload);
    pageToken =
      typeof root?.nextPageToken === 'string' && root.nextPageToken.trim()
        ? root.nextPageToken.trim()
        : undefined;
  } while (pageToken);

  allPoints.sort((a, b) => a.dateTime.localeCompare(b.dateTime));
  // Deduplicate by dateTime if pages overlap.
  const seen = new Set<string>();
  const points = allPoints.filter((point) => {
    if (seen.has(point.dateTime)) {
      return false;
    }
    seen.add(point.dateTime);
    return true;
  });

  return { points };
}

function cacheKey(lat: number, lng: number): string {
  return `${roundCoord(lat)},${roundCoord(lng)}`;
}

function roundCoord(value: number): number {
  return Math.round(value * 10_000) / 10_000;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function asFiniteNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

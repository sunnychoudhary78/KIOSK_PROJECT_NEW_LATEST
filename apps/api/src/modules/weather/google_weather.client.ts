import type { Logger } from '../../infrastructure/logging/logger.js';
import {
  aqiLabelFromIndiaAqi,
  normalizeAqiCategory,
  weatherCodeFromGoogleType,
} from './labels.js';

const WEATHER_URL = 'https://weather.googleapis.com/v1/currentConditions:lookup';
const AIR_QUALITY_URL = 'https://airquality.googleapis.com/v1/currentConditions:lookup';
export const WEATHER_CACHE_TTL_MS = 15 * 60 * 1000;

export type WeatherSnapshot = {
  temperatureC: number | null;
  humidityPct: number | null;
  weatherCode: number | null;
  weatherLabel: string | null;
  windKmh: number | null;
  uvIndex: number | null;
  aqi: number | null;
  aqiLabel: string | null;
};

type CacheEntry = { value: WeatherSnapshot; expiresAt: number };

export type GoogleWeatherClient = {
  getWeather(lat: number, lng: number): Promise<WeatherSnapshot>;
};

type FetchLike = typeof fetch;

export function createGoogleWeatherClient(options: {
  apiKey: string | undefined;
  logger: Logger;
  fetchImpl?: FetchLike;
  now?: () => number;
  cacheTtlMs?: number;
}): GoogleWeatherClient {
  const cache = new Map<string, CacheEntry>();
  const fetchImpl = options.fetchImpl ?? fetch;
  const now = options.now ?? Date.now;
  const ttl = options.cacheTtlMs ?? WEATHER_CACHE_TTL_MS;
  const apiKey = options.apiKey?.trim() ?? '';
  const logger = options.logger;

  return {
    async getWeather(lat: number, lng: number): Promise<WeatherSnapshot> {
      const key = cacheKey(lat, lng);
      const hit = cache.get(key);
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
        humidityPct: forecast?.humidityPct ?? null,
        weatherCode: forecast?.weatherCode ?? null,
        weatherLabel: forecast?.weatherLabel ?? null,
        windKmh: forecast?.windKmh ?? null,
        uvIndex: forecast?.uvIndex ?? null,
        aqi: aqi?.aqi ?? null,
        aqiLabel: aqi?.aqiLabel ?? null,
      };

      cache.set(key, { value, expiresAt: now() + ttl });
      return value;
    },
  };
}

export function parseWeatherPayload(payload: unknown): {
  temperatureC: number | null;
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
  const wind = asRecord(root?.wind);
  const windSpeed = asRecord(wind?.speed);
  const conditionType = typeof condition?.type === 'string' ? condition.type : null;
  const weatherLabel =
    typeof description?.text === 'string' && description.text.trim()
      ? description.text.trim()
      : null;

  return {
    temperatureC: asFiniteNumber(temperature?.degrees),
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
} {
  const root = asRecord(payload);
  const indexes = Array.isArray(root?.indexes) ? root.indexes : [];
  const records = indexes.map(asRecord).filter((item): item is Record<string, unknown> => item != null);

  const local =
    records.find((item) => typeof item.code === 'string' && item.code.toLowerCase() !== 'uaqi') ??
    records[0] ??
    null;

  const aqi = asFiniteNumber(local?.aqi);
  const fromCategory = normalizeAqiCategory(
    typeof local?.category === 'string' ? local.category : null,
  );

  return {
    aqi,
    aqiLabel: fromCategory ?? aqiLabelFromIndiaAqi(aqi),
  };
}

async function fetchCurrentWeather(
  fetchImpl: FetchLike,
  apiKey: string,
  lat: number,
  lng: number,
): Promise<{
  temperatureC: number | null;
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
): Promise<{ aqi: number | null; aqiLabel: string | null }> {
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

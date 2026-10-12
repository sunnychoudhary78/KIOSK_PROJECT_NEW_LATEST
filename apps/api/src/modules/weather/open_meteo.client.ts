import type { Logger } from '../../infrastructure/logging/logger.js';
import { aqiLabelFromUsAqi, weatherLabelFromCode } from './labels.js';

const FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';
const AIR_QUALITY_URL = 'https://air-quality-api.open-meteo.com/v1/air-quality';
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

export type OpenMeteoClient = {
  getWeather(lat: number, lng: number): Promise<WeatherSnapshot>;
};

type FetchLike = typeof fetch;

export function createOpenMeteoClient(options: {
  logger: Logger;
  fetchImpl?: FetchLike;
  now?: () => number;
  cacheTtlMs?: number;
}): OpenMeteoClient {
  const cache = new Map<string, CacheEntry>();
  const fetchImpl = options.fetchImpl ?? fetch;
  const now = options.now ?? Date.now;
  const ttl = options.cacheTtlMs ?? WEATHER_CACHE_TTL_MS;
  const logger = options.logger;

  return {
    async getWeather(lat: number, lng: number): Promise<WeatherSnapshot> {
      const key = cacheKey(lat, lng);
      const hit = cache.get(key);
      if (hit && hit.expiresAt > now()) {
        return hit.value;
      }

      const coords = { lat: roundCoord(lat), lng: roundCoord(lng) };
      const [forecastResult, aqiResult] = await Promise.allSettled([
        fetchForecast(fetchImpl, coords.lat, coords.lng),
        fetchAirQuality(fetchImpl, coords.lat, coords.lng),
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
          { event: 'weather_open_meteo_failed', ...coords, err: forecastErr },
          'Open-Meteo weather failed',
        );
        throw new Error('Open-Meteo unavailable');
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
          'Open-Meteo forecast failed',
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
          'Open-Meteo air quality failed',
        );
      }

      const forecast = forecastOk ? forecastResult.value : null;
      const aqi = aqiOk ? aqiResult.value : null;
      const weatherCode = forecast?.weatherCode ?? null;
      const usAqi = aqi?.usAqi ?? null;

      const value: WeatherSnapshot = {
        temperatureC: forecast?.temperatureC ?? null,
        humidityPct: forecast?.humidityPct ?? null,
        weatherCode,
        weatherLabel: weatherLabelFromCode(weatherCode),
        windKmh: forecast?.windKmh ?? null,
        uvIndex: forecast?.uvIndex ?? null,
        aqi: usAqi,
        aqiLabel: aqiLabelFromUsAqi(usAqi),
      };

      cache.set(key, { value, expiresAt: now() + ttl });
      return value;
    },
  };
}

export function parseForecastPayload(payload: unknown): {
  temperatureC: number | null;
  humidityPct: number | null;
  weatherCode: number | null;
  windKmh: number | null;
  uvIndex: number | null;
} {
  const current = asRecord(asRecord(payload)?.current);
  return {
    temperatureC: asFiniteNumber(current?.temperature_2m),
    humidityPct: asFiniteNumber(current?.relative_humidity_2m),
    weatherCode: asFiniteNumber(current?.weather_code),
    windKmh: asFiniteNumber(current?.wind_speed_10m),
    uvIndex: asFiniteNumber(current?.uv_index),
  };
}

export function parseAirQualityPayload(payload: unknown): { usAqi: number | null } {
  const current = asRecord(asRecord(payload)?.current);
  return { usAqi: asFiniteNumber(current?.us_aqi) };
}

async function fetchForecast(
  fetchImpl: FetchLike,
  lat: number,
  lng: number,
): Promise<{
  temperatureC: number | null;
  humidityPct: number | null;
  weatherCode: number | null;
  windKmh: number | null;
  uvIndex: number | null;
}> {
  const url = new URL(FORECAST_URL);
  url.searchParams.set('latitude', String(lat));
  url.searchParams.set('longitude', String(lng));
  url.searchParams.set(
    'current',
    'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,uv_index',
  );
  url.searchParams.set('wind_speed_unit', 'kmh');
  url.searchParams.set('timezone', 'auto');

  const response = await fetchImpl(url, { signal: AbortSignal.timeout(12_000) });
  if (!response.ok) {
    throw new Error(`Forecast HTTP ${response.status}`);
  }
  return parseForecastPayload(await response.json());
}

async function fetchAirQuality(
  fetchImpl: FetchLike,
  lat: number,
  lng: number,
): Promise<{ usAqi: number | null }> {
  const url = new URL(AIR_QUALITY_URL);
  url.searchParams.set('latitude', String(lat));
  url.searchParams.set('longitude', String(lng));
  url.searchParams.set('current', 'us_aqi');
  url.searchParams.set('timezone', 'auto');

  const response = await fetchImpl(url, { signal: AbortSignal.timeout(12_000) });
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

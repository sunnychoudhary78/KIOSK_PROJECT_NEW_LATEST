import { describe, expect, it } from 'vitest';
import {
  aqiLabelFromIndiaAqi,
  formatDominantPollutant,
  normalizeAqiCategory,
  weatherCodeFromGoogleType,
} from '../src/modules/weather/labels.js';
import {
  createGoogleWeatherClient,
  parseAirQualityPayload,
  parseWeatherPayload,
} from '../src/modules/weather/google_weather.client.js';

describe('weather labels', () => {
  it('maps Google condition types to synthetic WMO-like codes', () => {
    expect(weatherCodeFromGoogleType('CLEAR')).toBe(0);
    expect(weatherCodeFromGoogleType('PARTLY_CLOUDY')).toBe(2);
    expect(weatherCodeFromGoogleType('CLOUDY')).toBe(3);
    expect(weatherCodeFromGoogleType('FOG')).toBe(45);
    expect(weatherCodeFromGoogleType('RAIN')).toBe(61);
    expect(weatherCodeFromGoogleType('RAIN_SHOWERS')).toBe(80);
    expect(weatherCodeFromGoogleType('SNOW')).toBe(71);
    expect(weatherCodeFromGoogleType('THUNDERSTORM')).toBe(95);
    expect(weatherCodeFromGoogleType(null)).toBeNull();
  });

  it('maps India CPCB AQI bands', () => {
    expect(aqiLabelFromIndiaAqi(40)).toBe('Good');
    expect(aqiLabelFromIndiaAqi(80)).toBe('Satisfactory');
    expect(aqiLabelFromIndiaAqi(142)).toBe('Moderate');
    expect(aqiLabelFromIndiaAqi(250)).toBe('Poor');
    expect(aqiLabelFromIndiaAqi(350)).toBe('Very Poor');
    expect(aqiLabelFromIndiaAqi(450)).toBe('Severe');
    expect(aqiLabelFromIndiaAqi(null)).toBeNull();
  });

  it('normalizes Google AQI category strings', () => {
    expect(normalizeAqiCategory('Good air quality')).toBe('Good');
    expect(normalizeAqiCategory('  Moderate  ')).toBe('Moderate');
    expect(normalizeAqiCategory('')).toBeNull();
  });

  it('formats dominant pollutant codes', () => {
    expect(formatDominantPollutant('pm25')).toBe('PM2.5');
    expect(formatDominantPollutant('pm10')).toBe('PM10');
    expect(formatDominantPollutant('no2')).toBe('NO2');
    expect(formatDominantPollutant('o3')).toBe('O3');
    expect(formatDominantPollutant('mystery')).toBe('MYSTERY');
    expect(formatDominantPollutant(null)).toBeNull();
  });
});

describe('google weather parsers', () => {
  it('parses current weather fields including feels-like', () => {
    const parsed = parseWeatherPayload({
      weatherCondition: {
        type: 'PARTLY_CLOUDY',
        description: { text: 'Partly cloudy', languageCode: 'en' },
      },
      temperature: { degrees: 32.1, unit: 'CELSIUS' },
      feelsLikeTemperature: { degrees: 36.4, unit: 'CELSIUS' },
      relativeHumidity: 48,
      uvIndex: 7.2,
      wind: { speed: { value: 12.4, unit: 'KILOMETERS_PER_HOUR' } },
    });
    expect(parsed).toEqual({
      temperatureC: 32.1,
      feelsLikeC: 36.4,
      humidityPct: 48,
      weatherCode: 2,
      weatherLabel: 'Partly cloudy',
      windKmh: 12.4,
      uvIndex: 7.2,
    });
  });

  it('prefers local AQI index and formats dominant pollutant', () => {
    expect(
      parseAirQualityPayload({
        indexes: [
          {
            code: 'uaqi',
            aqi: 10,
            category: 'Excellent air quality',
            dominantPollutant: 'o3',
          },
          {
            code: 'ind_cpcb',
            aqi: 142,
            category: 'Moderate air quality',
            dominantPollutant: 'pm25',
          },
        ],
      }),
    ).toEqual({ aqi: 142, aqiLabel: 'Moderate', dominantPollutant: 'PM2.5' });
  });

  it('falls back to India band labels when category missing', () => {
    expect(
      parseAirQualityPayload({
        indexes: [{ code: 'ind_cpcb', aqi: 80 }],
      }),
    ).toEqual({ aqi: 80, aqiLabel: 'Satisfactory', dominantPollutant: null });
  });

  it('caches weather responses for the same coordinates', async () => {
    let calls = 0;
    const fetchImpl = (async (input: RequestInfo | URL, init?: RequestInit) => {
      calls += 1;
      const url = String(input);
      if (url.includes('airquality.googleapis.com')) {
        expect(init?.method).toBe('POST');
        return new Response(
          JSON.stringify({
            indexes: [
              {
                code: 'ind_cpcb',
                aqi: 90,
                category: 'Satisfactory air quality',
                dominantPollutant: 'pm10',
              },
            ],
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
      return new Response(
        JSON.stringify({
          weatherCondition: {
            type: 'CLEAR',
            description: { text: 'Clear', languageCode: 'en' },
          },
          temperature: { degrees: 30, unit: 'CELSIUS' },
          feelsLikeTemperature: { degrees: 33, unit: 'CELSIUS' },
          relativeHumidity: 40,
          uvIndex: 6,
          wind: { speed: { value: 8, unit: 'KILOMETERS_PER_HOUR' } },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }) as typeof fetch;

    const client = createGoogleWeatherClient({
      apiKey: 'test-key',
      logger: {
        debug: () => undefined,
        info: () => undefined,
        warn: () => undefined,
        error: () => undefined,
        child: () => undefined as never,
      } as never,
      fetchImpl,
      now: () => 1_000,
      cacheTtlMs: 60_000,
    });

    const first = await client.getWeather(28.6139, 77.209);
    const second = await client.getWeather(28.6139, 77.209);
    expect(calls).toBe(2); // weather + aqi once
    expect(first.temperatureC).toBe(30);
    expect(first.feelsLikeC).toBe(33);
    expect(first.aqi).toBe(90);
    expect(first.weatherLabel).toBe('Clear');
    expect(first.weatherCode).toBe(0);
    expect(first.aqiLabel).toBe('Satisfactory');
    expect(first.dominantPollutant).toBe('PM10');
    expect(second).toEqual(first);
  });

  it('allows partial success when only AQI fails', async () => {
    const fetchImpl = (async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes('airquality.googleapis.com')) {
        return new Response('boom', { status: 500 });
      }
      return new Response(
        JSON.stringify({
          weatherCondition: {
            type: 'RAIN',
            description: { text: 'Rain', languageCode: 'en' },
          },
          temperature: { degrees: 22, unit: 'CELSIUS' },
          feelsLikeTemperature: { degrees: 21, unit: 'CELSIUS' },
          relativeHumidity: 70,
          uvIndex: 2,
          wind: { speed: { value: 15, unit: 'KILOMETERS_PER_HOUR' } },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }) as typeof fetch;

    const client = createGoogleWeatherClient({
      apiKey: 'test-key',
      logger: {
        debug: () => undefined,
        info: () => undefined,
        warn: () => undefined,
        error: () => undefined,
        child: () => undefined as never,
      } as never,
      fetchImpl,
      now: () => 1_000,
      cacheTtlMs: 60_000,
    });

    const snapshot = await client.getWeather(28.6139, 77.209);
    expect(snapshot.temperatureC).toBe(22);
    expect(snapshot.feelsLikeC).toBe(21);
    expect(snapshot.weatherCode).toBe(61);
    expect(snapshot.aqi).toBeNull();
    expect(snapshot.aqiLabel).toBeNull();
    expect(snapshot.dominantPollutant).toBeNull();
  });

  it('throws when API key is missing', async () => {
    const client = createGoogleWeatherClient({
      apiKey: '',
      logger: {
        debug: () => undefined,
        info: () => undefined,
        warn: () => undefined,
        error: () => undefined,
        child: () => undefined as never,
      } as never,
    });
    await expect(client.getWeather(28.6, 77.2)).rejects.toThrow(/API key missing/);
  });
});

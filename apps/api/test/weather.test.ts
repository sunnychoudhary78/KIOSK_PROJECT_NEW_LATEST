import { describe, expect, it } from 'vitest';
import {
  aqiLabelFromIndiaAqi,
  formatDominantPollutant,
  normalizeAqiCategory,
  weatherCodeFromGoogleType,
} from '../src/modules/weather/labels.js';
import {
  clampHistoryHours,
  createGoogleWeatherClient,
  parseAirQualityDetailPayload,
  parseAirQualityHistoryPayload,
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

describe('air quality detail and history', () => {
  it('clamps history hours to 1–48', () => {
    expect(clampHistoryHours(24)).toBe(24);
    expect(clampHistoryHours(0)).toBe(1);
    expect(clampHistoryHours(100)).toBe(48);
    expect(clampHistoryHours(Number.NaN)).toBe(24);
  });

  it('parses detail payload with pollutants and health recommendations', () => {
    expect(
      parseAirQualityDetailPayload({
        dateTime: '2026-11-16T10:00:00Z',
        indexes: [
          {
            code: 'ind_cpcb',
            aqi: 285,
            category: 'Poor air quality',
            dominantPollutant: 'pm25',
            color: { red: 0.8, green: 0.2, blue: 0.2 },
          },
        ],
        pollutants: [
          {
            code: 'pm25',
            displayName: 'PM2.5',
            concentration: { value: 142.5, units: 'MICROGRAMS_PER_CUBIC_METER' },
          },
          {
            code: 'pm10',
            displayName: 'PM10',
            concentration: { value: 210, units: 'MICROGRAMS_PER_CUBIC_METER' },
          },
        ],
        healthRecommendations: {
          generalPopulation: 'Limit prolonged outdoor exposure.',
          elderly: 'Avoid outdoor activity.',
          children: 'Reduce outdoor play.',
        },
      }),
    ).toEqual({
      aqi: 285,
      aqiLabel: 'Poor',
      dominantPollutant: 'PM2.5',
      color: { r: 204, g: 51, b: 51 },
      pollutants: [
        {
          code: 'pm25',
          displayName: 'PM2.5',
          concentration: { value: 142.5, units: 'MICROGRAMS_PER_CUBIC_METER' },
        },
        {
          code: 'pm10',
          displayName: 'PM10',
          concentration: { value: 210, units: 'MICROGRAMS_PER_CUBIC_METER' },
        },
      ],
      healthRecommendations: {
        generalPopulation: 'Limit prolonged outdoor exposure.',
        elderly: 'Avoid outdoor activity.',
        lungDiseasePopulation: null,
        heartDiseasePopulation: null,
        athletes: null,
        pregnantWomen: null,
        children: 'Reduce outdoor play.',
      },
      updatedAt: '2026-11-16T10:00:00Z',
    });
  });

  it('parses history hoursInfo into chronological points', () => {
    expect(
      parseAirQualityHistoryPayload({
        hoursInfo: [
          {
            dateTime: '2026-11-16T11:00:00Z',
            indexes: [{ code: 'ind_cpcb', aqi: 200, category: 'Moderate air quality' }],
          },
          {
            dateTime: '2026-11-16T10:00:00Z',
            indexes: [{ code: 'ind_cpcb', aqi: 180 }],
          },
        ],
      }),
    ).toEqual({
      points: [
        { dateTime: '2026-11-16T10:00:00Z', aqi: 180, aqiLabel: 'Moderate' },
        { dateTime: '2026-11-16T11:00:00Z', aqi: 200, aqiLabel: 'Moderate' },
      ],
    });
  });

  it('fetches and caches air quality detail', async () => {
    let calls = 0;
    const fetchImpl = (async (_input: RequestInfo | URL, init?: RequestInit) => {
      calls += 1;
      expect(init?.method).toBe('POST');
      const body = JSON.parse(String(init?.body ?? '{}')) as {
        extraComputations?: string[];
      };
      expect(body.extraComputations).toEqual(
        expect.arrayContaining(['LOCAL_AQI', 'HEALTH_RECOMMENDATIONS', 'POLLUTANT_CONCENTRATION']),
      );
      return new Response(
        JSON.stringify({
          dateTime: '2026-11-16T10:00:00Z',
          indexes: [
            {
              code: 'ind_cpcb',
              aqi: 120,
              category: 'Moderate air quality',
              dominantPollutant: 'pm10',
            },
          ],
          pollutants: [{ code: 'pm10', displayName: 'PM10' }],
          healthRecommendations: { generalPopulation: 'Sensitive groups should limit outdoor exertion.' },
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

    const first = await client.getAirQualityDetail(28.6139, 77.209);
    const second = await client.getAirQualityDetail(28.6139, 77.209);
    expect(calls).toBe(1);
    expect(first.aqi).toBe(120);
    expect(first.aqiLabel).toBe('Moderate');
    expect(first.dominantPollutant).toBe('PM10');
    expect(first.healthRecommendations?.generalPopulation).toContain('Sensitive groups');
    expect(second).toEqual(first);
  });

  it('fetches history and pages until nextPageToken is gone', async () => {
    let calls = 0;
    const fetchImpl = (async (_input: RequestInfo | URL, init?: RequestInit) => {
      calls += 1;
      const body = JSON.parse(String(init?.body ?? '{}')) as { pageToken?: string; hours?: number };
      expect(body.hours).toBe(24);
      if (!body.pageToken) {
        return new Response(
          JSON.stringify({
            hoursInfo: [
              {
                dateTime: '2026-11-16T11:00:00Z',
                indexes: [{ code: 'ind_cpcb', aqi: 150, category: 'Moderate air quality' }],
              },
            ],
            nextPageToken: 'page-2',
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
      expect(body.pageToken).toBe('page-2');
      return new Response(
        JSON.stringify({
          hoursInfo: [
            {
              dateTime: '2026-11-16T10:00:00Z',
              indexes: [{ code: 'ind_cpcb', aqi: 140, category: 'Moderate air quality' }],
            },
          ],
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

    const history = await client.getAirQualityHistory(28.6139, 77.209, 24);
    expect(calls).toBe(2);
    expect(history.points).toEqual([
      { dateTime: '2026-11-16T10:00:00Z', aqi: 140, aqiLabel: 'Moderate' },
      { dateTime: '2026-11-16T11:00:00Z', aqi: 150, aqiLabel: 'Moderate' },
    ]);

    const cached = await client.getAirQualityHistory(28.6139, 77.209, 24);
    expect(calls).toBe(2);
    expect(cached).toEqual(history);
  });
});

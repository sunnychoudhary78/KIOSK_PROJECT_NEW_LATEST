import { describe, expect, it } from 'vitest';
import { aqiLabelFromUsAqi, weatherLabelFromCode } from '../src/modules/weather/labels.js';
import {
  createOpenMeteoClient,
  parseAirQualityPayload,
  parseForecastPayload,
} from '../src/modules/weather/open_meteo.client.js';

describe('weather labels', () => {
  it('maps WMO weather codes to short labels', () => {
    expect(weatherLabelFromCode(0)).toBe('Clear');
    expect(weatherLabelFromCode(2)).toBe('Partly cloudy');
    expect(weatherLabelFromCode(3)).toBe('Overcast');
    expect(weatherLabelFromCode(61)).toBe('Rain');
    expect(weatherLabelFromCode(95)).toBe('Thunderstorm');
    expect(weatherLabelFromCode(null)).toBeNull();
  });

  it('maps US AQI bands', () => {
    expect(aqiLabelFromUsAqi(40)).toBe('Good');
    expect(aqiLabelFromUsAqi(80)).toBe('Moderate');
    expect(aqiLabelFromUsAqi(142)).toBe('Unhealthy for sensitive');
    expect(aqiLabelFromUsAqi(180)).toBe('Unhealthy');
    expect(aqiLabelFromUsAqi(220)).toBe('Very unhealthy');
    expect(aqiLabelFromUsAqi(null)).toBeNull();
  });
});

describe('open-meteo parsers', () => {
  it('parses forecast current fields', () => {
    const parsed = parseForecastPayload({
      current: {
        temperature_2m: 32.1,
        relative_humidity_2m: 48,
        weather_code: 2,
        wind_speed_10m: 12.4,
        uv_index: 7.2,
      },
    });
    expect(parsed).toEqual({
      temperatureC: 32.1,
      humidityPct: 48,
      weatherCode: 2,
      windKmh: 12.4,
      uvIndex: 7.2,
    });
  });

  it('parses air quality current fields', () => {
    expect(parseAirQualityPayload({ current: { us_aqi: 142 } })).toEqual({ usAqi: 142 });
  });

  it('caches weather responses for the same coordinates', async () => {
    let calls = 0;
    const fetchImpl = (async (input: RequestInfo | URL) => {
      calls += 1;
      const url = String(input);
      if (url.includes('air-quality')) {
        return new Response(JSON.stringify({ current: { us_aqi: 90 } }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      return new Response(
        JSON.stringify({
          current: {
            temperature_2m: 30,
            relative_humidity_2m: 40,
            weather_code: 0,
            wind_speed_10m: 8,
            uv_index: 6,
          },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }) as typeof fetch;

    const client = createOpenMeteoClient({
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
    expect(calls).toBe(2); // forecast + aqi once
    expect(first.temperatureC).toBe(30);
    expect(first.aqi).toBe(90);
    expect(first.weatherLabel).toBe('Clear');
    expect(first.aqiLabel).toBe('Moderate');
    expect(second).toEqual(first);
  });
});

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it, vi } from 'vitest';
import {
  buildVedAstroCalculateUrl,
  mapVedAstroChart,
  normalizeVedAstroBaseUrl,
  sanitizeVedAstroLocation,
  createVedAstroClient,
  extractKundaliSvg,
  formatDasaLabel,
  formatVedAstroNowStdTime,
  formatVedAstroStdTime,
  kundaliCalculatorForStyle,
  mapVedAstroMatchReport,
  mapVedAstroPanchangaTable,
  toChartSummary,
} from '../src/infrastructure/external/vedastro.client.js';
import { AppError } from '../src/shared/errors.js';
import type { Logger } from '../src/infrastructure/logging/logger.js';

const fixtureDir = dirname(fileURLToPath(import.meta.url));
const matchReportFixture = JSON.parse(
  readFileSync(join(fixtureDir, 'fixtures/match-report.json'), 'utf8'),
) as unknown;
const panchangaFixture = JSON.parse(
  readFileSync(join(fixtureDir, 'fixtures/panchanga-table.json'), 'utf8'),
) as unknown;

const silentLogger = { info: vi.fn(), warn: vi.fn(), error: vi.fn() } as unknown as Logger;

const planetPayload = {
  Status: 'Pass',
  Payload: {
    AllPlanetData: [
      {
        Sun: {
          PlanetRasiD1Sign: { Name: 'Cancer' },
          PlanetNavamshaD9Sign: { Name: 'Libra' },
          PlanetConstellation: 'Pushyami - 3',
          HousePlanetOccupiesBasedOnSign: 'House5',
          PlanetDignity: 'Friendly',
          IsPlanetRetrograde: 'False',
          PlanetsInConjunction: [],
          PlanetsAspectingPlanet: ['Saturn'],
        },
      },
      {
        Moon: {
          PlanetRasiD1Sign: { Name: 'Gemini' },
          PlanetNavamshaD9Sign: { Name: 'Aries' },
          PlanetConstellation: 'Punarvasu - 1',
          HousePlanetOccupiesBasedOnSign: 'House4',
          PlanetDignity: 'Neutral',
          IsPlanetRetrograde: 'False',
          PlanetsInConjunction: ['Mercury'],
          PlanetsAspectingPlanet: [],
        },
      },
    ],
  },
};

const housePayload = {
  Status: 'Pass',
  Payload: {
    AllHouseData: [
      {
        House1: {
          HouseSignName: 'Pisces',
          HouseRasiSign: { Name: 'Pisces' },
          HouseNavamshaD9Sign: { Name: 'Pisces' },
          HouseConstellation: 'Revathi - 4',
          LordOfHouse: { Name: 'Jupiter' },
          PlanetsInHouseBasedOnSign: [],
        },
      },
      {
        House4: {
          HouseSignName: 'Gemini',
          HouseRasiSign: { Name: 'Gemini' },
          HouseNavamshaD9Sign: { Name: 'Aries' },
          HouseConstellation: 'Punarvasu - 1',
          LordOfHouse: { Name: 'Mercury' },
          PlanetsInHouseBasedOnSign: ['Moon'],
        },
      },
    ],
  },
};

describe('VedAstro URL builder', () => {
  it('title-cases place names and splits comma/slash', () => {
    expect(sanitizeVedAstroLocation('Jaipur, Rajasthan')).toBe('Jaipur/Rajasthan');
    expect(sanitizeVedAstroLocation('New Delhi')).toBe('NewDelhi');
    expect(sanitizeVedAstroLocation('rampur')).toBe('Rampur');
  });

  it('appends /api when the host-only VedAstro origin is used', () => {
    expect(normalizeVedAstroBaseUrl('https://api.vedastro.org')).toBe('https://api.vedastro.org/api');
    expect(normalizeVedAstroBaseUrl('https://api.vedastro.org/api')).toBe(
      'https://api.vedastro.org/api',
    );
  });

  it('builds Calculate path with split date segments and literal offset', () => {
    const url = buildVedAstroCalculateUrl({
      baseUrl: 'https://api.vedastro.org',
      calculator: 'AllPlanetData',
      extraPath: 'PlanetName/All',
      location: 'Jaipur/Rajasthan',
      birthTime: '14:20',
      dateOfBirth: '1990-01-15',
    });
    expect(url).toBe(
      'https://api.vedastro.org/api/Calculate/AllPlanetData/PlanetName/All/Location/Jaipur/Rajasthan/Time/14:20/15/01/1990/+05:30',
    );
  });

  it('inserts extra path for house calculators', () => {
    const url = buildVedAstroCalculateUrl({
      baseUrl: 'https://api.vedastro.org/api/',
      calculator: 'AllHouseData',
      extraPath: 'HouseName/All',
      location: 'NewDelhi',
      birthTime: '12:00',
      dateOfBirth: '2000-12-01',
      utcOffset: '+05:30',
    });
    expect(url).toContain(
      '/Calculate/AllHouseData/HouseName/All/Location/NewDelhi/Time/12:00/01/12/2000/+05:30',
    );
  });

  it('builds North/South kundali Calculate paths with ChartType', () => {
    expect(kundaliCalculatorForStyle('north')).toBe('NorthIndianChart');
    expect(kundaliCalculatorForStyle('south')).toBe('SouthIndianChart');
    const north = buildVedAstroCalculateUrl({
      baseUrl: 'https://api.vedastro.org',
      calculator: kundaliCalculatorForStyle('north'),
      trailingPath: 'ChartType/RasiD1',
      location: 'Jaipur/Rajasthan',
      birthTime: '14:20',
      dateOfBirth: '1990-01-15',
    });
    expect(north).toBe(
      'https://api.vedastro.org/api/Calculate/NorthIndianChart/Location/Jaipur/Rajasthan/Time/14:20/15/01/1990/+05:30/ChartType/RasiD1',
    );
    const south = buildVedAstroCalculateUrl({
      baseUrl: 'https://api.vedastro.org/api',
      calculator: kundaliCalculatorForStyle('south'),
      trailingPath: 'ChartType/RasiD1',
      location: 'NewDelhi',
      birthTime: '12:00',
      dateOfBirth: '2000-12-01',
    });
    expect(south).toContain(
      '/Calculate/SouthIndianChart/Location/NewDelhi/Time/12:00/01/12/2000/+05:30/ChartType/RasiD1',
    );
  });
});

describe('extractKundaliSvg', () => {
  const sampleSvg = '<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>';

  it('reads SVG from Payload string', () => {
    expect(extractKundaliSvg({ Status: 'Pass', Payload: sampleSvg })).toBe(sampleSvg);
  });

  it('reads raw SVG text and strips leading junk', () => {
    expect(extractKundaliSvg(`prefix ${sampleSvg}`)).toBe(sampleSvg);
  });

  it('returns undefined when no SVG is present', () => {
    expect(extractKundaliSvg({ Status: 'Pass', Payload: 'not a chart' })).toBeUndefined();
  });
});

describe('formatDasaLabel', () => {
  it('formats Maha and Bhukti lords', () => {
    const body = {
      Status: 'Pass',
      Payload: {
        DasaForNow: {
          Rahu: {
            Type: 'Dasa',
            Lord: 'Rahu',
            SubDasas: {
              Saturn: {
                Type: 'Bhukti',
                Lord: 'Saturn',
                SubDasas: {},
              },
            },
          },
        },
      },
    };
    expect(formatDasaLabel(body, 2)).toEqual({
      label: 'Rahu – Saturn',
      levels: ['Rahu', 'Saturn'],
    });
  });
});

describe('MatchReport mapping', () => {
  it('formats StdTime and maps a compact ordered eight-kuta result', () => {
    expect(
      formatVedAstroStdTime({
        dateOfBirth: '1990-01-15',
        birthTime: '14:20',
        birthPlace: 'Jaipur',
      }),
    ).toBe('14:20 15/01/1990 +05:30');
    const result = mapVedAstroMatchReport(matchReportFixture);
    expect(result).toMatchObject({
      total: 20,
      max: 36,
      tone: 'mixed',
      summary: 'Problematic relationship',
    });
    expect(result.kutas).toHaveLength(8);
    expect(result.kutas.map((entry) => entry.key)).toEqual([
      'varna',
      'vasya',
      'dina',
      'yoni',
      'graha-maitri',
      'gana',
      'rasi',
      'nadi',
    ]);
    expect(result.kutas[4]).toMatchObject({ points: 0, maxPoints: 5, nature: 'Bad' });
    expect(result.kutas.every((entry) => entry.verdict.length <= 140)).toBe(true);
  });
});

describe('mapVedAstroChart', () => {
  it('compacts bulk planet and house payloads into a Vedic chart', () => {
    const chart = mapVedAstroChart({
      planets: planetPayload,
      houses: housePayload,
    });
    expect(chart).toMatchObject({
      lagna: 'Pisces',
      sunSign: 'Cancer',
      moonSign: 'Gemini',
      nakshatra: 'Punarvasu - 1',
    });
    expect(chart.planets).toEqual([
      {
        name: 'Sun',
        rasi: 'Cancer',
        navamsa: 'Libra',
        nakshatra: 'Pushyami - 3',
        house: 'House5',
        dignity: 'Friendly',
        retrograde: false,
        aspecting: ['Saturn'],
      },
      {
        name: 'Moon',
        rasi: 'Gemini',
        navamsa: 'Aries',
        nakshatra: 'Punarvasu - 1',
        house: 'House4',
        dignity: 'Neutral',
        retrograde: false,
        conjunct: ['Mercury'],
      },
    ]);
    expect(chart.houses).toEqual([
      {
        number: 'House1',
        rasi: 'Pisces',
        navamsa: 'Pisces',
        nakshatra: 'Revathi - 4',
        lord: 'Jupiter',
      },
      {
        number: 'House4',
        rasi: 'Gemini',
        navamsa: 'Aries',
        nakshatra: 'Punarvasu - 1',
        lord: 'Mercury',
        planetsInHouse: ['Moon'],
      },
    ]);
    expect(toChartSummary(chart)).toEqual({
      lagna: 'Pisces',
      sunSign: 'Cancer',
      moonSign: 'Gemini',
      nakshatra: 'Punarvasu - 1',
    });
  });
});

describe('createVedAstroClient', () => {
  function geoOk(name: string, latitude: number, longitude: number) {
    return new Response(
      JSON.stringify({
        results: [{ name, admin1: 'State', country: 'India', latitude, longitude }],
      }),
      { status: 200 },
    );
  }

  it('returns a compact chart from AllPlanetData even if houses fail', async () => {
    let planetBody: Record<string, unknown> | undefined;
    const fetchImpl = vi.fn(async (url: string | URL | Request, init?: RequestInit) => {
      const href = String(url);
      if (href.includes('geocoding-api.open-meteo.com')) {
        return geoOk('Pune', 18.52, 73.85);
      }
      if (href.endsWith('/Calculate/AllPlanetData') && init?.method === 'POST') {
        planetBody = JSON.parse(String(init.body)) as Record<string, unknown>;
        return new Response(JSON.stringify(planetPayload), { status: 200 });
      }
      if (href.endsWith('/Calculate/AllHouseData')) {
        return new Response('nope', { status: 500 });
      }
      return new Response('nope', { status: 500 });
    });

    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    const chart = await client.getChart({
      dateOfBirth: '1991-06-02',
      birthTime: '08:15',
      birthPlace: 'pune',
    });
    expect(chart.summary.sunSign).toBe('Cancer');
    expect(chart.summary.moonSign).toBe('Gemini');
    expect(chart.summary.lagna).toBeUndefined();
    expect(chart.details.planets).toHaveLength(2);
    expect(chart.details.houses).toEqual([]);
    expect(planetBody).toMatchObject({
      Ayanamsa: 'RAMAN',
      PlanetName: { Name: 'All' },
      Time: {
        StdTime: '08:15 02/06/1991 +05:30',
        Location: { Latitude: 18.52, Longitude: 73.85 },
      },
    });
  });

  it('includes house lagna when AllHouseData succeeds', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      const href = String(url);
      if (href.includes('geocoding-api.open-meteo.com')) {
        return geoOk('Rampur', 28.8, 79.02);
      }
      if (href.endsWith('/Calculate/AllPlanetData')) {
        return new Response(JSON.stringify(planetPayload), { status: 200 });
      }
      if (href.endsWith('/Calculate/AllHouseData')) {
        return new Response(JSON.stringify(housePayload), { status: 200 });
      }
      return new Response('nope', { status: 500 });
    });

    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    const chart = await client.getChart({
      dateOfBirth: '2000-07-29',
      birthTime: '21:30',
      birthPlace: 'Rampur',
    });
    expect(chart.summary.lagna).toBe('Pisces');
    expect(chart.details.houses[0]?.lord).toBe('Jupiter');
  });

  it('throws vedastro_failed when AllPlanetData fails', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      if (String(url).includes('geocoding-api.open-meteo.com')) {
        return geoOk('Pune', 18.52, 73.85);
      }
      return new Response('down', { status: 503 });
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    await expect(
      client.getChart({
        dateOfBirth: '1991-06-02',
        birthTime: '08:15',
        birthPlace: 'Pune',
      }),
    ).rejects.toMatchObject({ code: 'vedastro_failed' } satisfies Partial<AppError>);
  });

  it('includes VedAstro Fail payload in the error details', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      if (String(url).includes('geocoding-api.open-meteo.com')) {
        return geoOk('Pune', 18.52, 73.85);
      }
      return new Response(
        JSON.stringify({ Status: 'Fail', Payload: 'Calculator method not found!' }),
        { status: 200 },
      );
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    await expect(
      client.getChart({
        dateOfBirth: '1991-06-02',
        birthTime: '08:15',
        birthPlace: 'Pune',
      }),
    ).rejects.toMatchObject({
      code: 'vedastro_failed',
      details: { payload: 'Calculator method not found!' },
    });
  });

  it('returns kundali SVG from NorthIndianChart POST Payload', async () => {
    const sampleSvg = '<svg xmlns="http://www.w3.org/2000/svg"><circle r="1"/></svg>';
    let posted: Record<string, unknown> | undefined;
    const fetchImpl = vi.fn(async (url: string | URL | Request, init?: RequestInit) => {
      const href = String(url);
      if (href.includes('geocoding-api.open-meteo.com')) {
        return geoOk('Pune', 18.52, 73.85);
      }
      expect(href).toBe('https://api.vedastro.org/api/Calculate/NorthIndianChart');
      expect(init?.method).toBe('POST');
      posted = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return new Response(JSON.stringify({ Status: 'Pass', Payload: sampleSvg }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    const result = await client.getKundaliSvg({
      dateOfBirth: '1991-06-02',
      birthTime: '08:15',
      birthPlace: 'Pune',
      style: 'north',
    });
    expect(result).toEqual({
      style: 'north',
      chartType: 'RasiD1',
      svg: sampleSvg,
    });
    expect(posted).toMatchObject({
      ChartType: 'RasiD1',
      Time: { Location: { Latitude: 18.52, Longitude: 73.85 } },
    });
  });

  it('posts ChartType for each divisional chart and preserves its SVG', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request, init?: RequestInit) => {
      const href = String(url);
      if (href.includes('geocoding-api.open-meteo.com')) {
        return geoOk('Pune', 18.52, 73.85);
      }
      const body = JSON.parse(String(init?.body)) as { ChartType?: string };
      return new Response(`<svg aria-label="${body.ChartType}">${body.ChartType}</svg>`, {
        status: 200,
        headers: { 'Content-Type': 'image/svg+xml' },
      });
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });

    const results = await Promise.all(
      (['RasiD1', 'NavamshaD9', 'DashamamshaD10'] as const).map((chartType) =>
        client.getKundaliSvg({
          dateOfBirth: '1991-06-02',
          birthTime: '08:15',
          birthPlace: 'Pune',
          style: 'north',
          chartType,
        }),
      ),
    );

    expect(results.map((result) => result.chartType)).toEqual([
      'RasiD1',
      'NavamshaD9',
      'DashamamshaD10',
    ]);
    expect(new Set(results.map((result) => result.svg)).size).toBe(3);
  });

  it('throws when kundali response has no SVG', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      if (String(url).includes('geocoding-api.open-meteo.com')) {
        return geoOk('Pune', 18.52, 73.85);
      }
      return new Response(JSON.stringify({ Status: 'Pass', Payload: 'ok' }), { status: 200 });
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    await expect(
      client.getKundaliSvg({
        dateOfBirth: '1991-06-02',
        birthTime: '08:15',
        birthPlace: 'Pune',
        style: 'south',
      }),
    ).rejects.toMatchObject({ code: 'vedastro_failed' });
  });

  it('skips Open-Meteo for AllPlanetData when client coords are present', async () => {
    let planetBody: Record<string, unknown> | undefined;
    const fetchImpl = vi.fn(async (url: string | URL | Request, init?: RequestInit) => {
      const href = String(url);
      if (href.includes('geocoding-api.open-meteo.com')) {
        throw new Error('should not geocode');
      }
      if (href.endsWith('/Calculate/AllPlanetData') && init?.method === 'POST') {
        planetBody = JSON.parse(String(init.body)) as Record<string, unknown>;
        return new Response(JSON.stringify(planetPayload), { status: 200 });
      }
      if (href.endsWith('/Calculate/AllHouseData')) {
        return new Response(JSON.stringify(housePayload), { status: 200 });
      }
      return new Response('nope', { status: 500 });
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    await client.getChart({
      dateOfBirth: '1991-06-02',
      birthTime: '08:15',
      birthPlace: 'Pune',
      latitude: 18.52,
      longitude: 73.85,
    });
    expect(planetBody).toMatchObject({
      Time: {
        Location: { Name: 'Pune', Latitude: 18.52, Longitude: 73.85 },
      },
    });
    expect(fetchImpl.mock.calls.some((call) => String(call[0]).includes('open-meteo'))).toBe(
      false,
    );
  });

  it('returns a dasha label from DasaForNow POST', async () => {
    let posted: Record<string, unknown> | undefined;
    const fetchImpl = vi.fn(async (url: string | URL | Request, init?: RequestInit) => {
      const href = String(url);
      if (href.includes('geocoding-api.open-meteo.com')) {
        return geoOk('Pune', 18.52, 73.85);
      }
      expect(href).toBe('https://api.vedastro.org/api/Calculate/DasaForNow');
      posted = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return new Response(
        JSON.stringify({
          Status: 'Pass',
          Payload: {
            DasaForNow: {
              Venus: {
                Lord: 'Venus',
                SubDasas: { Mercury: { Lord: 'Mercury', SubDasas: {} } },
              },
            },
          },
        }),
        { status: 200 },
      );
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    await expect(
      client.getDasaForNow({
        dateOfBirth: '1991-06-02',
        birthTime: '08:15',
        birthPlace: 'Pune',
        latitude: 18.52,
        longitude: 73.85,
      }),
    ).resolves.toEqual({ label: 'Venus – Mercury', levels: ['Venus', 'Mercury'] });
    expect(posted).toMatchObject({
      Levels: 3,
      BirthTime: { Location: { Latitude: 18.52, Longitude: 73.85 } },
    });
    expect(fetchImpl.mock.calls.some((call) => String(call[0]).includes('open-meteo'))).toBe(
      false,
    );
  });

  it('geocodes both places and POSTs MatchReport with real coordinates', async () => {
    let posted: Record<string, unknown> | undefined;
    const fetchImpl = vi.fn(async (url: string | URL | Request, init?: RequestInit) => {
      const href = String(url);
      if (href.includes('geocoding-api.open-meteo.com')) {
        const isJaipur = href.includes('Jaipur');
        return new Response(
          JSON.stringify({
            results: [
              {
                name: isJaipur ? 'Jaipur' : 'Delhi',
                admin1: isJaipur ? 'Rajasthan' : 'Delhi',
                country: 'India',
                latitude: isJaipur ? 26.91 : 28.65,
                longitude: isJaipur ? 75.78 : 77.23,
              },
            ],
          }),
          { status: 200 },
        );
      }
      expect(href).toBe('https://api.vedastro.org/api/Calculate/MatchReport');
      expect(init?.method).toBe('POST');
      posted = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return new Response(
        JSON.stringify({
          Status: 'Pass',
          Payload: {
            MatchReport: {
              KutaScore: 25,
              Summary: { ScoreSummary: 'Strong compatibility' },
              PredictionList: [],
            },
          },
        }),
        { status: 200 },
      );
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });

    const result = await client.getMatchReport(
      {
        dateOfBirth: '1990-01-15',
        birthTime: '14:20',
        birthPlace: 'Jaipur, Rajasthan',
      },
      {
        dateOfBirth: '1992-06-20',
        birthTime: '10:30',
        birthPlace: 'Delhi, India',
      },
    );

    expect(result).toMatchObject({ total: 25, max: 36, tone: 'good' });
    expect(fetchImpl).toHaveBeenCalledTimes(3);
    expect(posted).toMatchObject({
      Ayanamsa: 'RAMAN',
      MaleBirthTime: {
        StdTime: '14:20 15/01/1990 +05:30',
        Location: { Latitude: 26.91, Longitude: 75.78 },
      },
      FemaleBirthTime: {
        StdTime: '10:30 20/06/1992 +05:30',
        Location: { Latitude: 28.65, Longitude: 77.23 },
      },
    });
  });

  it('surfaces a MatchReport Fail status', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      if (String(url).includes('geocoding-api.open-meteo.com')) {
        return new Response(
          JSON.stringify({ results: [{ name: 'Pune', latitude: 18.52, longitude: 73.85 }] }),
          { status: 200 },
        );
      }
      return new Response(JSON.stringify({ Status: 'Fail', Payload: 'Calculator method not found!' }), {
        status: 200,
      });
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    const birth = {
      dateOfBirth: '1991-06-02',
      birthTime: '08:15',
      birthPlace: 'Pune',
    };
    await expect(client.getMatchReport(birth, birth)).rejects.toMatchObject({
      code: 'vedastro_failed',
    });
  });

  it('rejects an unresolved birth place before MatchReport POST', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      if (String(url).includes('geocoding-api.open-meteo.com')) {
        return new Response(JSON.stringify({ results: [] }), { status: 200 });
      }
      throw new Error('MatchReport should not be called');
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    const birth = {
      dateOfBirth: '1991-06-02',
      birthTime: '08:15',
      birthPlace: 'Unknownville',
    };
    await expect(client.getMatchReport(birth, birth)).rejects.toMatchObject({
      code: 'validation_error',
    });
  });
});

describe('PanchangaTable mapping', () => {
  it('formats now StdTime in IST and maps a compact panchang snapshot', () => {
    const now = new Date(Date.UTC(2026, 9, 21, 10, 21, 0));
    expect(formatVedAstroNowStdTime(now)).toBe('15:51 21/10/2026 +05:30');
    expect(mapVedAstroPanchangaTable(panchangaFixture)).toEqual({
      weekday: 'Wednesday',
      tithi: 'Ekadasi (Sukla)',
      nakshatra: 'Dhanishta - 4',
      yoga: 'Ganda',
      karana: 'Vanija',
      lunarMonth: 'Aaswayuja',
      sunrise: '06:33',
      sunset: '17:49',
      horaLord: 'Saturn',
      dishaShool: 'North',
    });
  });

  it('geocodes the place and POSTs PanchangaTable with real coordinates', async () => {
    let posted: Record<string, unknown> | undefined;
    const fetchImpl = vi.fn(async (url: string | URL | Request, init?: RequestInit) => {
      const href = String(url);
      if (href.includes('geocoding-api.open-meteo.com')) {
        return new Response(
          JSON.stringify({
            results: [
              {
                name: 'Jaipur',
                admin1: 'Rajasthan',
                country: 'India',
                latitude: 26.91,
                longitude: 75.78,
              },
            ],
          }),
          { status: 200 },
        );
      }
      expect(href).toBe('https://api.vedastro.org/api/Calculate/PanchangaTable');
      expect(init?.method).toBe('POST');
      posted = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return new Response(JSON.stringify(panchangaFixture), { status: 200 });
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    const now = new Date(Date.UTC(2026, 9, 21, 10, 21, 0));
    const result = await client.getPanchangaTable({ birthPlace: 'Jaipur', now });
    expect(result.tithi).toBe('Ekadasi (Sukla)');
    expect(posted).toMatchObject({
      Ayanamsa: 'RAMAN',
      InputTime: {
        StdTime: '15:51 21/10/2026 +05:30',
        Location: { Latitude: 26.91, Longitude: 75.78 },
      },
    });
  });

  it('surfaces a PanchangaTable Fail status', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      if (String(url).includes('geocoding-api.open-meteo.com')) {
        return new Response(
          JSON.stringify({ results: [{ name: 'Pune', latitude: 18.52, longitude: 73.85 }] }),
          { status: 200 },
        );
      }
      return new Response(JSON.stringify({ Status: 'Fail', Payload: 'Calculator method not found!' }), {
        status: 200,
      });
    });
    const client = createVedAstroClient({
      baseUrl: 'https://api.vedastro.org',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    await expect(client.getPanchangaTable({ birthPlace: 'Pune' })).rejects.toMatchObject({
      code: 'vedastro_failed',
    });
  });
});

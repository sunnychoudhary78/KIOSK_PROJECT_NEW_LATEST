import { describe, expect, it, vi } from 'vitest';
import {
  buildVedAstroCalculateUrl,
  mapVedAstroChart,
  normalizeVedAstroBaseUrl,
  sanitizeVedAstroLocation,
  createVedAstroClient,
  toChartSummary,
} from '../src/infrastructure/external/vedastro.client.js';
import { AppError } from '../src/shared/errors.js';
import type { Logger } from '../src/infrastructure/logging/logger.js';

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
  it('returns a compact chart from AllPlanetData even if houses fail', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      const href = String(url);
      if (href.includes('AllPlanetData') && href.includes('PlanetName/All')) {
        return new Response(JSON.stringify(planetPayload), { status: 200 });
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
    expect(String(fetchImpl.mock.calls[0]?.[0])).toContain('/Location/Pune/');
    expect(String(fetchImpl.mock.calls[0]?.[0])).toContain(
      '/api/Calculate/AllPlanetData/PlanetName/All/',
    );
    expect(String(fetchImpl.mock.calls[0]?.[0])).toContain('Time/08:15/02/06/1991/+05:30');
  });

  it('includes house lagna when AllHouseData succeeds', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      const href = String(url);
      if (href.includes('AllPlanetData')) {
        return new Response(JSON.stringify(planetPayload), { status: 200 });
      }
      if (href.includes('AllHouseData')) {
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
    const fetchImpl = vi.fn(async () => new Response('down', { status: 503 }));
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
    const fetchImpl = vi.fn(async () =>
      new Response(
        JSON.stringify({ Status: 'Fail', Payload: 'Calculator method not found!' }),
        { status: 200 },
      ),
    );
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
});

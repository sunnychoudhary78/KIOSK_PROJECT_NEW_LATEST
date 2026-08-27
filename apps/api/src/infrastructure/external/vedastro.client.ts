import type { Logger } from '../logging/logger.js';
import { AppError } from '../../shared/errors.js';
import type {
  ChartSummary,
  CompactHouse,
  CompactPlanet,
  CompactVedicChart,
} from '../../modules/astrology/astrology.schemas.js';

export const VEDASTRO_DEFAULT_OFFSET = '+05:30';
export const VEDASTRO_FETCH_TIMEOUT_MS = 30_000;

export type VedAstroBirthInput = {
  dateOfBirth: string;
  birthTime: string;
  birthPlace: string;
  utcOffset?: string;
};

export type VedAstroChartResult = {
  summary: ChartSummary;
  details: CompactVedicChart;
};

export interface VedAstroClient {
  getChart(input: VedAstroBirthInput): Promise<VedAstroChartResult>;
}

type FetchLike = typeof fetch;

export function sanitizeVedAstroLocation(place: string): string {
  const parts = place
    .split(/[,/|]+/)
    .map((part) =>
      part
        .trim()
        .split(/\s+/)
        .filter(Boolean)
        .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(''),
    )
    .filter(Boolean);
  return parts.join('/') || 'NewDelhi';
}

export function splitIsoDate(dateOfBirth: string): { year: string; month: string; day: string } {
  const [year, month, day] = dateOfBirth.split('-');
  return { year: year ?? '2000', month: month ?? '01', day: day ?? '01' };
}

/** Bare `api.vedastro.org` is not a Calculate host; the live API is under `/api`. */
export function normalizeVedAstroBaseUrl(baseUrl: string): string {
  const base = baseUrl.replace(/\/$/, '');
  if (/^https?:\/\/api\.vedastro\.org$/i.test(base)) {
    return `${base}/api`;
  }
  return base;
}

export function buildVedAstroCalculateUrl(input: {
  baseUrl: string;
  calculator: string;
  extraPath?: string;
  location: string;
  birthTime: string;
  dateOfBirth: string;
  utcOffset?: string;
}): string {
  const { year, month, day } = splitIsoDate(input.dateOfBirth);
  const offset = input.utcOffset ?? VEDASTRO_DEFAULT_OFFSET;
  const extra = input.extraPath ? `/${input.extraPath.replace(/^\/|\/$/g, '')}` : '';
  const location = input.location
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');
  return (
    `${normalizeVedAstroBaseUrl(input.baseUrl)}/Calculate/${input.calculator}${extra}` +
    `/Location/${location}/Time/${input.birthTime}/${day}/${month}/${year}/${offset}`
  );
}

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
  if (typeof value === 'number' && Number.isFinite(value)) {
    return String(value);
  }
  return undefined;
}

function asBoolean(value: unknown): boolean | undefined {
  if (typeof value === 'boolean') {
    return value;
  }
  const text = asString(value)?.toLowerCase();
  if (text === 'true') {
    return true;
  }
  if (text === 'false') {
    return false;
  }
  return undefined;
}

function asStringList(value: unknown): string[] | undefined {
  if (!Array.isArray(value)) {
    return undefined;
  }
  const items = value.map((entry) => asString(entry)).filter((entry): entry is string => Boolean(entry));
  return items.length ? items : undefined;
}

function nestedName(record: Record<string, unknown> | null, keys: string[]): string | undefined {
  if (!record) {
    return undefined;
  }
  for (const key of keys) {
    const direct = asString(record[key]);
    if (direct) {
      return direct;
    }
    const nested = asRecord(record[key]);
    if (nested) {
      const fromNested = asString(nested.Name ?? nested.name ?? nested.Sign ?? nested.sign);
      if (fromNested) {
        return fromNested;
      }
    }
  }
  return undefined;
}

function payloadOf(body: unknown): Record<string, unknown> {
  const root = asRecord(body) ?? {};
  return asRecord(root.Payload) ?? asRecord(root.payload) ?? root;
}

/** VedAstro bulk payloads are `[{ Sun: {...} }, { Moon: {...} }]`. */
function namedEntries(list: unknown): Array<{ name: string; data: Record<string, unknown> }> {
  if (!Array.isArray(list)) {
    return [];
  }
  const entries: Array<{ name: string; data: Record<string, unknown> }> = [];
  for (const item of list) {
    const record = asRecord(item);
    if (!record) {
      continue;
    }
    for (const [name, value] of Object.entries(record)) {
      const data = asRecord(value);
      if (data) {
        entries.push({ name, data });
      }
    }
  }
  return entries;
}

function findNamed(entries: Array<{ name: string; data: Record<string, unknown> }>, names: string[]) {
  const wanted = new Set(names.map((name) => name.toLowerCase()));
  return entries.find((entry) => wanted.has(entry.name.toLowerCase()));
}

function compactPlanet(name: string, data: Record<string, unknown>): CompactPlanet {
  const planet: CompactPlanet = { name };
  const rasi = nestedName(data, ['PlanetRasiD1Sign', 'SignName']);
  const navamsa = nestedName(data, ['PlanetNavamshaD9Sign']);
  const nakshatra = nestedName(data, ['PlanetConstellation', 'Constellation', 'Nakshatra']);
  const house = asString(data.HousePlanetOccupiesBasedOnSign ?? data.HousePlanetOccupiesBasedOnLongitudes);
  const dignity = asString(data.PlanetDignity);
  const retrograde = asBoolean(data.IsPlanetRetrograde);
  const conjunct = asStringList(data.PlanetsInConjunction);
  const aspecting = asStringList(data.PlanetsAspectingPlanet);
  if (rasi) {
    planet.rasi = rasi;
  }
  if (navamsa) {
    planet.navamsa = navamsa;
  }
  if (nakshatra) {
    planet.nakshatra = nakshatra;
  }
  if (house) {
    planet.house = house;
  }
  if (dignity) {
    planet.dignity = dignity;
  }
  if (retrograde !== undefined) {
    planet.retrograde = retrograde;
  }
  if (conjunct) {
    planet.conjunct = conjunct;
  }
  if (aspecting) {
    planet.aspecting = aspecting;
  }
  return planet;
}

function compactHouse(name: string, data: Record<string, unknown>): CompactHouse {
  const house: CompactHouse = { number: name };
  const rasi = nestedName(data, ['HouseSignName', 'HouseRasiSign']);
  const navamsa = nestedName(data, ['HouseNavamshaD9Sign']);
  const nakshatra = nestedName(data, ['HouseConstellation']);
  const lord = nestedName(data, ['LordOfHouse']);
  const planetsInHouse = asStringList(data.PlanetsInHouseBasedOnSign ?? data.PlanetsInHouseBasedOnLongitudes);
  if (rasi) {
    house.rasi = rasi;
  }
  if (navamsa) {
    house.navamsa = navamsa;
  }
  if (nakshatra) {
    house.nakshatra = nakshatra;
  }
  if (lord) {
    house.lord = lord;
  }
  if (planetsInHouse) {
    house.planetsInHouse = planetsInHouse;
  }
  return house;
}

export function toChartSummary(details: CompactVedicChart): ChartSummary {
  const summary: ChartSummary = {};
  if (details.lagna) {
    summary.lagna = details.lagna;
  }
  if (details.sunSign) {
    summary.sunSign = details.sunSign;
  }
  if (details.moonSign) {
    summary.moonSign = details.moonSign;
  }
  if (details.nakshatra) {
    summary.nakshatra = details.nakshatra;
  }
  if (details.currentDasha) {
    summary.currentDasha = details.currentDasha;
  }
  return summary;
}

export function mapVedAstroChart(parts: {
  planets?: unknown;
  houses?: unknown;
}): CompactVedicChart {
  const planetPayload = payloadOf(parts.planets);
  const housePayload = payloadOf(parts.houses);
  const planetEntries = namedEntries(planetPayload.AllPlanetData ?? planetPayload.allPlanetData);
  const houseEntries = namedEntries(housePayload.AllHouseData ?? housePayload.allHouseData);

  const planets = planetEntries.map((entry) => compactPlanet(entry.name, entry.data));
  const houses = houseEntries.map((entry) => compactHouse(entry.name, entry.data));

  const sun = findNamed(planetEntries, ['Sun']);
  const moon = findNamed(planetEntries, ['Moon']);
  const lagna = findNamed(houseEntries, ['House1', 'Lagna', 'Ascendant']);

  const details: CompactVedicChart = {
    planets,
    houses,
  };
  const lagnaSign = lagna ? nestedName(lagna.data, ['HouseSignName', 'HouseRasiSign']) : undefined;
  const sunSign = sun ? nestedName(sun.data, ['PlanetRasiD1Sign', 'SignName']) : undefined;
  const moonSign = moon ? nestedName(moon.data, ['PlanetRasiD1Sign', 'SignName']) : undefined;
  const nakshatra = moon
    ? nestedName(moon.data, ['PlanetConstellation', 'Constellation', 'Nakshatra'])
    : undefined;
  if (lagnaSign) {
    details.lagna = lagnaSign;
  }
  if (sunSign) {
    details.sunSign = sunSign;
  }
  if (moonSign) {
    details.moonSign = moonSign;
  }
  if (nakshatra) {
    details.nakshatra = nakshatra;
  }
  return details;
}

export function createVedAstroClient(options: {
  baseUrl: string;
  logger: Logger;
  fetchImpl?: FetchLike;
}): VedAstroClient {
  const fetchImpl = options.fetchImpl ?? fetch;
  const baseUrl = normalizeVedAstroBaseUrl(options.baseUrl);

  async function getJson(url: string): Promise<unknown> {
    const response = await fetchImpl(url, {
      method: 'GET',
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(VEDASTRO_FETCH_TIMEOUT_MS),
    });
    let body: unknown = null;
    try {
      body = await response.json();
    } catch {
      body = null;
    }
    if (!response.ok) {
      throw new AppError('vedastro_failed', 'VedAstro request failed', 502, {
        status: response.status,
        url,
      });
    }
    const record = asRecord(body);
    const status = asString(record?.Status ?? record?.status);
    if (status && status.toLowerCase() !== 'pass' && status.toLowerCase() !== 'success') {
      throw new AppError('vedastro_failed', 'VedAstro returned an error status', 502, {
        status,
        url,
        payload: record?.Payload ?? record?.payload,
      });
    }
    return body;
  }

  return {
    async getChart(input: VedAstroBirthInput): Promise<VedAstroChartResult> {
      const location = sanitizeVedAstroLocation(input.birthPlace);
      const common = {
        baseUrl,
        location,
        birthTime: input.birthTime,
        dateOfBirth: input.dateOfBirth,
        utcOffset: input.utcOffset ?? VEDASTRO_DEFAULT_OFFSET,
      };
      const planetsUrl = buildVedAstroCalculateUrl({
        ...common,
        calculator: 'AllPlanetData',
        extraPath: 'PlanetName/All',
      });
      const housesUrl = buildVedAstroCalculateUrl({
        ...common,
        calculator: 'AllHouseData',
        extraPath: 'HouseName/All',
      });

      options.logger.info({ location, dateOfBirth: input.dateOfBirth }, '[VedAstro] fetching chart');
      const startedAt = Date.now();

      try {
        const [planets, houses] = await Promise.allSettled([getJson(planetsUrl), getJson(housesUrl)]);

        if (planets.status === 'rejected') {
          throw planets.reason;
        }

        const housesOk = houses.status === 'fulfilled';
        const details = mapVedAstroChart({
          planets: planets.value,
          houses: housesOk ? houses.value : undefined,
        });
        const summary = toChartSummary(details);
        options.logger.info(
          {
            planetsUrl,
            housesUrl,
            planetsOk: true,
            housesOk,
            durationMs: Date.now() - startedAt,
            summary,
            details,
          },
          '[VedAstro] chart ready',
        );
        return {
          summary,
          details,
        };
      } catch (error) {
        if (error instanceof AppError) {
          throw error;
        }
        options.logger.error({ err: error }, '[VedAstro] chart fetch failed');
        throw new AppError('vedastro_failed', 'Unable to compute Vedic chart', 502);
      }
    },
  };
}

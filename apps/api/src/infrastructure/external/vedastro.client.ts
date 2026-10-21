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

export type KundaliStyle = 'north' | 'south';
export type KundaliChartType = 'RasiD1' | 'NavamshaD9' | 'DashamamshaD10';

export const KUNDALI_CHART_META: Record<
  KundaliChartType,
  { title: 'Birth' | 'Marriage' | 'Career'; subtitle: string }
> = {
  RasiD1: { title: 'Birth', subtitle: 'Rasi' },
  NavamshaD9: { title: 'Marriage', subtitle: 'Navamsha' },
  DashamamshaD10: { title: 'Career', subtitle: 'Dashamsha' },
};

export const KUNDALI_PREFETCH_TYPES: KundaliChartType[] = [
  'RasiD1',
  'NavamshaD9',
  'DashamamshaD10',
];

export type VedAstroKundaliInput = VedAstroBirthInput & {
  style: KundaliStyle;
  chartType?: KundaliChartType;
};

export type VedAstroKundaliResult = {
  style: KundaliStyle;
  chartType: KundaliChartType;
  svg: string;
};

export type VedAstroDasaResult = {
  label: string;
  levels: string[];
};

export type VedAstroMatchKuta = {
  key: string;
  name: string;
  maxPoints: number;
  points?: number;
  nature: string;
  verdict: string;
};

export type VedAstroMatchResult = {
  total: number;
  max: 36;
  summary: string;
  tone: 'good' | 'mixed' | 'poor';
  kutas: VedAstroMatchKuta[];
};

export interface VedAstroClient {
  getChart(input: VedAstroBirthInput): Promise<VedAstroChartResult>;
  getKundaliSvg(input: VedAstroKundaliInput): Promise<VedAstroKundaliResult>;
  getDasaForNow(input: VedAstroBirthInput): Promise<VedAstroDasaResult>;
  getMatchReport(
    groom: VedAstroBirthInput,
    bride: VedAstroBirthInput,
  ): Promise<VedAstroMatchResult>;
}

export function kundaliCalculatorForStyle(style: KundaliStyle): 'NorthIndianChart' | 'SouthIndianChart' {
  return style === 'south' ? 'SouthIndianChart' : 'NorthIndianChart';
}

/**
 * Turn VedAstro DasaForNow payload into "Rahu – Saturn" (Maha + Bhukti).
 * Walks nested SubDasas up to two lords.
 */
export function formatDasaLabel(body: unknown, maxLevels = 2): VedAstroDasaResult {
  const root = asRecord(body);
  const payload = asRecord(root?.Payload ?? root?.payload) ?? root;
  const dasaRoot =
    asRecord(payload?.DasaForNow) ??
    asRecord(payload?.dasaForNow) ??
    payload;
  if (!dasaRoot) {
    return { label: '', levels: [] };
  }

  const levels: string[] = [];
  let current: Record<string, unknown> | null = dasaRoot;

  for (let depth = 0; depth < maxLevels && current; depth++) {
    const entries = Object.entries(current).filter(
      ([key, value]) => key !== 'SubDasas' && key !== 'subDasas' && asRecord(value) !== null,
    );
    if (entries.length === 0) {
      break;
    }
    const [name, node] = entries[0]!;
    const record = asRecord(node);
    const lord = asString(record?.Lord ?? record?.lord) ?? name;
    levels.push(lord);
    current = asRecord(record?.SubDasas ?? record?.subDasas);
  }

  return {
    label: levels.join(' – '),
    levels,
  };
}

const MATCH_KUTAS = [
  { key: 'varna', name: 'Varna', aliases: ['Varna'], maxPoints: 1 },
  { key: 'vasya', name: 'Vasya', aliases: ['Vasya Kuta', 'Vashya Kuta'], maxPoints: 2 },
  { key: 'dina', name: 'Dina (Tara)', aliases: ['Dina Kuta', 'Tara Kuta'], maxPoints: 3 },
  { key: 'yoni', name: 'Yoni', aliases: ['Yoni Kuta'], maxPoints: 4 },
  {
    key: 'graha-maitri',
    name: 'Graha Maitri',
    aliases: ['Graha Maitram', 'Graha Maitri'],
    maxPoints: 5,
  },
  { key: 'gana', name: 'Gana', aliases: ['Guna Kuta', 'Gana Kuta'], maxPoints: 6 },
  { key: 'rasi', name: 'Rasi (Bhakoot)', aliases: ['Rasi Kuta', 'Bhakoot'], maxPoints: 7 },
  { key: 'nadi', name: 'Nadi', aliases: ['Nadi Kuta'], maxPoints: 8 },
] as const;

export function formatVedAstroStdTime(input: VedAstroBirthInput): string {
  const { year, month, day } = splitIsoDate(input.dateOfBirth);
  return `${input.birthTime} ${day}/${month}/${year} ${input.utcOffset ?? VEDASTRO_DEFAULT_OFFSET}`;
}

function shortVerdict(value: unknown): string {
  const text = asString(value) ?? 'No detailed note returned.';
  return text.length <= 140 ? text : `${text.slice(0, 137).trimEnd()}…`;
}

export function mapVedAstroMatchReport(body: unknown): VedAstroMatchResult {
  const root = asRecord(body);
  const payload = asRecord(root?.Payload ?? root?.payload) ?? root;
  const report =
    asRecord(payload?.MatchReport ?? payload?.matchReport) ??
    payload;
  if (!report) {
    throw new AppError('vedastro_failed', 'VedAstro returned an empty match report', 502);
  }

  const predictions = Array.isArray(report.PredictionList)
    ? report.PredictionList.map(asRecord).filter((row): row is Record<string, unknown> => row !== null)
    : [];
  const total = asNumber(report.KutaScore) ?? 0;
  const summaryRecord = asRecord(report.Summary);
  const summary =
    asString(summaryRecord?.ScoreSummary) ??
    (total >= 24
      ? 'Strong compatibility'
      : total >= 18
        ? 'Moderate compatibility'
        : 'Compatibility needs careful consideration');

  const kutas = MATCH_KUTAS.map((spec) => {
    const row = predictions.find((candidate) => {
      const rowName = asString(candidate.Name)?.toLowerCase();
      return spec.aliases.some((alias) => alias.toLowerCase() === rowName);
    });
    const points = asNumber(row?.Score);
    return {
      key: spec.key,
      name: spec.name,
      maxPoints: spec.maxPoints,
      ...(points !== undefined ? { points } : {}),
      nature: asString(row?.Nature) ?? 'Neutral',
      verdict: shortVerdict(row?.Info),
    };
  });

  return {
    total,
    max: 36,
    summary,
    tone: total >= 24 ? 'good' : total >= 18 ? 'mixed' : 'poor',
    kutas,
  };
}

/** Extract SVG markup from a VedAstro JSON or raw text response body. */
export function extractKundaliSvg(body: unknown): string | undefined {
  if (typeof body === 'string') {
    const trimmed = body.trim();
    if (trimmed.includes('<svg')) {
      const start = trimmed.indexOf('<svg');
      return trimmed.slice(start);
    }
    return undefined;
  }
  const record = asRecord(body);
  if (!record) {
    return undefined;
  }
  const payload = record.Payload ?? record.payload;
  if (typeof payload === 'string' && payload.includes('<svg')) {
    const trimmed = payload.trim();
    const start = trimmed.indexOf('<svg');
    return trimmed.slice(start);
  }
  if (payload && typeof payload === 'object') {
    const nested = asRecord(payload);
    for (const key of ['Svg', 'svg', 'Chart', 'chart', 'Content', 'content']) {
      const value = nested?.[key];
      if (typeof value === 'string' && value.includes('<svg')) {
        const trimmed = value.trim();
        return trimmed.slice(trimmed.indexOf('<svg'));
      }
    }
  }
  return undefined;
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
  trailingPath?: string;
  location: string;
  birthTime: string;
  dateOfBirth: string;
  utcOffset?: string;
}): string {
  const { year, month, day } = splitIsoDate(input.dateOfBirth);
  const offset = input.utcOffset ?? VEDASTRO_DEFAULT_OFFSET;
  const extra = input.extraPath ? `/${input.extraPath.replace(/^\/|\/$/g, '')}` : '';
  const trailing = input.trailingPath
    ? `/${input.trailingPath.replace(/^\/|\/$/g, '')}`
    : '';
  const location = input.location
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');
  return (
    `${normalizeVedAstroBaseUrl(input.baseUrl)}/Calculate/${input.calculator}${extra}` +
    `/Location/${location}/Time/${input.birthTime}/${day}/${month}/${year}/${offset}${trailing}`
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

function asNumber(value: unknown): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  const parsed = Number(asString(value));
  return Number.isFinite(parsed) ? parsed : undefined;
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

  async function postJson(url: string, payload: unknown): Promise<unknown> {
    const response = await fetchImpl(url, {
      method: 'POST',
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
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

  async function geocodeBirthPlace(place: string): Promise<{
    name: string;
    latitude: number;
    longitude: number;
  }> {
    const city = place.split(/[,/|]+/)[0]?.trim() || place.trim();
    const url =
      'https://geocoding-api.open-meteo.com/v1/search?' +
      new URLSearchParams({
        name: city,
        count: '5',
        language: 'en',
        format: 'json',
      }).toString();
    const response = await fetchImpl(url, {
      method: 'GET',
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(VEDASTRO_FETCH_TIMEOUT_MS),
    });
    if (!response.ok) {
      throw new AppError('vedastro_failed', 'Unable to resolve birth place', 502, {
        status: response.status,
      });
    }
    const body = asRecord(await response.json());
    const results = Array.isArray(body?.results) ? body.results.map(asRecord).filter(Boolean) : [];
    const wanted = place.toLowerCase();
    const candidate =
      results.find((entry) => {
        const record = entry as Record<string, unknown>;
        const terms = [record.name, record.admin1, record.country]
          .map(asString)
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return wanted
          .split(/[\s,]+/)
          .filter((term) => term.length > 2)
          .every((term) => terms.includes(term));
      }) ??
      results[0];
    const record = asRecord(candidate);
    const latitude = asNumber(record?.latitude);
    const longitude = asNumber(record?.longitude);
    if (latitude === undefined || longitude === undefined) {
      throw new AppError('validation_error', `Birth place not found: ${place}`, 400);
    }
    const nameParts = [record?.name, record?.admin1, record?.country]
      .map(asString)
      .filter((value): value is string => Boolean(value));
    return {
      name: nameParts.join(', ') || place,
      latitude,
      longitude,
    };
  }

  async function getKundaliBody(url: string): Promise<unknown> {
    const response = await fetchImpl(url, {
      method: 'GET',
      headers: { Accept: 'application/json, image/svg+xml, text/plain, */*' },
      signal: AbortSignal.timeout(VEDASTRO_FETCH_TIMEOUT_MS),
    });
    const contentType = (response.headers.get('content-type') ?? '').toLowerCase();
    const text = await response.text();
    if (!response.ok) {
      throw new AppError('vedastro_failed', 'VedAstro kundali request failed', 502, {
        status: response.status,
        url,
      });
    }

    if (contentType.includes('json') || text.trimStart().startsWith('{')) {
      let body: unknown = null;
      try {
        body = JSON.parse(text) as unknown;
      } catch {
        body = null;
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

    return text;
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

    async getKundaliSvg(input: VedAstroKundaliInput): Promise<VedAstroKundaliResult> {
      const chartType: KundaliChartType = input.chartType ?? 'RasiD1';
      const calculator = kundaliCalculatorForStyle(input.style);
      const location = sanitizeVedAstroLocation(input.birthPlace);
      const url = buildVedAstroCalculateUrl({
        baseUrl,
        calculator,
        // VedAstro binds optional parameters only after the required Time
        // path. Putting ChartType before Location silently returns RasiD1.
        trailingPath: `ChartType/${chartType}`,
        location,
        birthTime: input.birthTime,
        dateOfBirth: input.dateOfBirth,
        utcOffset: input.utcOffset ?? VEDASTRO_DEFAULT_OFFSET,
      });

      options.logger.info(
        { location, dateOfBirth: input.dateOfBirth, style: input.style, chartType, calculator },
        '[VedAstro] fetching kundali SVG',
      );
      const startedAt = Date.now();

      try {
        const body = await getKundaliBody(url);
        const svg = extractKundaliSvg(body);
        if (!svg) {
          throw new AppError('vedastro_failed', 'VedAstro returned an empty kundali chart', 502, {
            url,
          });
        }
        options.logger.info(
          {
            url,
            style: input.style,
            chartType,
            svgBytes: svg.length,
            durationMs: Date.now() - startedAt,
          },
          '[VedAstro] kundali SVG ready',
        );
        return {
          style: input.style,
          chartType,
          svg,
        };
      } catch (error) {
        if (error instanceof AppError) {
          throw error;
        }
        options.logger.error({ err: error }, '[VedAstro] kundali fetch failed');
        throw new AppError('vedastro_failed', 'Unable to generate kundali chart', 502);
      }
    },

    async getDasaForNow(input: VedAstroBirthInput): Promise<VedAstroDasaResult> {
      const location = sanitizeVedAstroLocation(input.birthPlace);
      // Levels in the path breaks Location parsing on the free API; use defaults (3)
      // and trim to Maha + Bhukti in formatDasaLabel.
      const url = buildVedAstroCalculateUrl({
        baseUrl,
        calculator: 'DasaForNow',
        location,
        birthTime: input.birthTime,
        dateOfBirth: input.dateOfBirth,
        utcOffset: input.utcOffset ?? VEDASTRO_DEFAULT_OFFSET,
      });

      options.logger.info(
        { location, dateOfBirth: input.dateOfBirth },
        '[VedAstro] fetching DasaForNow',
      );
      const startedAt = Date.now();

      try {
        const body = await getJson(url);
        const dasa = formatDasaLabel(body, 2);
        if (!dasa.label) {
          throw new AppError('vedastro_failed', 'VedAstro returned an empty dasha', 502, { url });
        }
        options.logger.info(
          { url, label: dasa.label, levels: dasa.levels, durationMs: Date.now() - startedAt },
          '[VedAstro] DasaForNow ready',
        );
        return dasa;
      } catch (error) {
        if (error instanceof AppError) {
          throw error;
        }
        options.logger.error({ err: error }, '[VedAstro] DasaForNow failed');
        throw new AppError('vedastro_failed', 'Unable to compute current dasha', 502);
      }
    },

    async getMatchReport(
      groom: VedAstroBirthInput,
      bride: VedAstroBirthInput,
    ): Promise<VedAstroMatchResult> {
      const [groomLocation, brideLocation] = await Promise.all([
        geocodeBirthPlace(groom.birthPlace),
        geocodeBirthPlace(bride.birthPlace),
      ]);
      const url = `${baseUrl}/Calculate/MatchReport`;
      const requestBody = {
        Ayanamsa: 'RAMAN',
        MaleBirthTime: {
          StdTime: formatVedAstroStdTime(groom),
          Location: {
            Name: groomLocation.name,
            Longitude: groomLocation.longitude,
            Latitude: groomLocation.latitude,
          },
        },
        FemaleBirthTime: {
          StdTime: formatVedAstroStdTime(bride),
          Location: {
            Name: brideLocation.name,
            Longitude: brideLocation.longitude,
            Latitude: brideLocation.latitude,
          },
        },
      };
      options.logger.info(
        {
          groomPlace: groomLocation.name,
          bridePlace: brideLocation.name,
        },
        '[VedAstro] fetching MatchReport',
      );
      const startedAt = Date.now();
      try {
        const body = await postJson(url, requestBody);
        const result = mapVedAstroMatchReport(body);
        options.logger.info(
          {
            total: result.total,
            kutaCount: result.kutas.length,
            durationMs: Date.now() - startedAt,
          },
          '[VedAstro] MatchReport ready',
        );
        return result;
      } catch (error) {
        if (error instanceof AppError) {
          throw error;
        }
        options.logger.error({ err: error }, '[VedAstro] MatchReport failed');
        throw new AppError('vedastro_failed', 'Unable to compute kundali match', 502);
      }
    },
  };
}

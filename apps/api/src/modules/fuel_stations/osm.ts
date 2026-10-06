/** Delhi NCR box used by the fuel-station sync. South, west, north, east. */
export const DELHI_NCR_BBOX = {
  south: 28.4,
  west: 76.8,
  north: 28.9,
  east: 77.6,
} as const;

/** Hide a station after this many syncs fail to see it. */
export const MISS_DEACTIVATE_AFTER = 3;

const NAME_MAX = 200;
const ADDRESS_MAX = 400;

const PETROL_TAGS = [
  'fuel:petrol',
  'fuel:gasoline',
  'fuel:octane_91',
  'fuel:octane_92',
  'fuel:octane_95',
  'fuel:octane_98',
  'fuel:octane_100',
  'fuel:e5',
  'fuel:e10',
] as const;

const DIESEL_TAGS = ['fuel:diesel', 'fuel:biodiesel', 'fuel:hvo'] as const;

export type FuelFlags = {
  petrol: boolean;
  diesel: boolean;
  cng: boolean;
  ev: boolean;
  fuelUntyped: boolean;
};

export type MappedStation = FuelFlags & {
  osmId: string;
  name: string | null;
  address: string | null;
  latitude: number;
  longitude: number;
};

export function nextMissState(
  seen: boolean,
  missCount: number,
): { missCount: number; isActive: boolean } {
  if (seen) {
    return { missCount: 0, isActive: true };
  }
  const next = missCount + 1;
  return { missCount: next, isActive: next < MISS_DEACTIVATE_AFTER };
}

export function overpassQuery(bbox: typeof DELHI_NCR_BBOX = DELHI_NCR_BBOX): string {
  const box = `${bbox.south},${bbox.west},${bbox.north},${bbox.east}`;
  return `[out:json][timeout:90];
(
  node["amenity"="fuel"](${box});
  way["amenity"="fuel"](${box});
  node["amenity"="charging_station"](${box});
  way["amenity"="charging_station"](${box});
);
out center tags;`;
}

export function mapOsmElement(element: unknown): MappedStation | null {
  if (!element || typeof element !== 'object') {
    return null;
  }
  const record = element as Record<string, unknown>;
  const type = record.type;
  const id = record.id;
  if ((type !== 'node' && type !== 'way') || typeof id !== 'number') {
    return null;
  }

  const tags = asTags(record.tags);
  const amenity = tags.amenity;
  if (amenity !== 'fuel' && amenity !== 'charging_station') {
    return null;
  }

  const latitude = readCoord(record.lat) ?? readCoord(centerOf(record)?.lat);
  const longitude = readCoord(record.lon) ?? readCoord(centerOf(record)?.lon);
  if (latitude == null || longitude == null) {
    return null;
  }

  const name = clip(firstText(tags.name, tags.operator, tags.brand), NAME_MAX);
  const petrol = PETROL_TAGS.some((key) => tagEnabled(tags, key));
  const diesel = DIESEL_TAGS.some((key) => tagEnabled(tags, key));
  const cngDenied = tags['fuel:cng']?.trim().toLowerCase() === 'no';
  const cng = !cngDenied && (tagEnabled(tags, 'fuel:cng') || nameHasCng(name));
  const ev = amenity === 'charging_station' || tagEnabled(tags, 'fuel:electricity');
  const fuelUntyped = amenity === 'fuel' && !petrol && !diesel && !cng && !ev;

  return {
    osmId: `${type}/${id}`,
    name,
    address: formatAddress(tags),
    latitude,
    longitude,
    petrol,
    diesel,
    cng,
    ev,
    fuelUntyped,
  };
}

function asTags(value: unknown): Record<string, string> {
  if (!value || typeof value !== 'object') {
    return {};
  }
  const tags: Record<string, string> = {};
  for (const [key, raw] of Object.entries(value as Record<string, unknown>)) {
    if (typeof raw === 'string') {
      tags[key] = raw;
    }
  }
  return tags;
}

function centerOf(record: Record<string, unknown>): { lat?: unknown; lon?: unknown } | null {
  const center = record.center;
  if (!center || typeof center !== 'object') {
    return null;
  }
  return center as { lat?: unknown; lon?: unknown };
}

function readCoord(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function tagEnabled(tags: Record<string, string>, key: string): boolean {
  const value = tags[key]?.trim().toLowerCase();
  return value === 'yes' || value === 'designated' || value === 'only';
}

function nameHasCng(name: string | null): boolean {
  return name != null && /\bCNG\b/i.test(name);
}

function firstText(...values: Array<string | undefined>): string | null {
  for (const value of values) {
    const trimmed = value?.trim();
    if (trimmed) {
      return trimmed;
    }
  }
  return null;
}

function formatAddress(tags: Record<string, string>): string | null {
  const parts = ['addr:housenumber', 'addr:street', 'addr:suburb', 'addr:city']
    .map((key) => tags[key]?.trim())
    .filter((part): part is string => Boolean(part));
  return clip(parts.length > 0 ? parts.join(', ') : null, ADDRESS_MAX);
}

function clip(value: string | null, max: number): string | null {
  if (!value) {
    return null;
  }
  return value.length <= max ? value : value.slice(0, max);
}

/**
 * One-time / rare seed: find CNG stations across Delhi NCR via Places Text Search
 * and merge into fuel_stations. The API never calls this.
 *   cd apps/api && npm run fuel-stations:seed-cng-google
 */
import { PrismaClient } from '@prisma/client';
import { loadEnvFile } from '../config/load-env.js';
import {
  CNG_SEARCH_RADIUS_M,
  acceptCngPlace,
  buildNcrGrid,
  decideCngMerge,
  parseTextSearchPlaces,
  type CngSeedPlace,
} from '../modules/fuel_stations/cng_seed.js';
import { DELHI_NCR_BBOX } from '../modules/fuel_stations/osm.js';

const TEXT_SEARCH_URL = 'https://places.googleapis.com/v1/places:searchText';
const PAUSE_MS = 100;
const NAME_MAX = 200;
const ADDRESS_MAX = 400;

async function main() {
  loadEnvFile();
  const apiKey = process.env.SKP_GOOGLE_PLACES_API_KEY?.trim();
  if (!apiKey) {
    throw new Error('SKP_GOOGLE_PLACES_API_KEY is not set');
  }

  const prisma = new PrismaClient();
  try {
    const cells = buildNcrGrid();
    const byPlaceId = new Map<string, CngSeedPlace>();

    for (const cell of cells) {
      const places = await searchCngNear(apiKey, cell);
      for (const place of places) {
        if (acceptCngPlace(place, DELHI_NCR_BBOX)) {
          byPlaceId.set(place.placeId, place);
        }
      }
      await pause(PAUSE_MS);
    }

    const existing = await prisma.fuelStation.findMany({
      where: { isActive: true },
      select: {
        id: true,
        googlePlaceId: true,
        latitude: true,
        longitude: true,
        name: true,
        address: true,
      },
    });

    let updated = 0;
    let inserted = 0;
    const now = new Date();

    for (const place of byPlaceId.values()) {
      const action = decideCngMerge(place, existing);
      if (action.type === 'update') {
        await prisma.fuelStation.update({
          where: { id: action.id },
          data: {
            cng: true,
            googlePlaceId: action.googlePlaceId,
            name: clip(action.name, NAME_MAX),
            address: clip(action.address, ADDRESS_MAX),
            isActive: true,
            lastSeenAt: now,
            missCount: 0,
          },
        });
        updated += 1;
        const row = existing.find((item) => item.id === action.id);
        if (row) {
          row.googlePlaceId = action.googlePlaceId;
          row.name = action.name;
          row.address = action.address;
        }
      } else {
        const created = await prisma.fuelStation.create({
          data: {
            osmId: action.osmId,
            name: clip(action.place.name, NAME_MAX),
            address: clip(action.place.address, ADDRESS_MAX),
            latitude: action.place.latitude,
            longitude: action.place.longitude,
            petrol: false,
            diesel: false,
            cng: true,
            ev: false,
            fuelUntyped: false,
            googlePlaceId: action.place.placeId,
            lastSeenAt: now,
            missCount: 0,
            isActive: true,
          },
        });
        inserted += 1;
        existing.push({
          id: created.id,
          googlePlaceId: action.place.placeId,
          latitude: action.place.latitude,
          longitude: action.place.longitude,
          name: action.place.name,
          address: action.place.address,
        });
      }
    }

    console.info('CNG Google seed complete', {
      cells: cells.length,
      placesFound: byPlaceId.size,
      updated,
      inserted,
    });
  } finally {
    await prisma.$disconnect();
  }
}

async function searchCngNear(
  apiKey: string,
  cell: { lat: number; lng: number },
): Promise<CngSeedPlace[]> {
  const places: CngSeedPlace[] = [];
  let pageToken: string | undefined;

  for (let page = 0; page < 2; page += 1) {
    const body: Record<string, unknown> = {
      textQuery: 'CNG station',
      includedType: 'gas_station',
      strictTypeFiltering: true,
      pageSize: 20,
      languageCode: 'en',
      regionCode: 'IN',
      locationBias: {
        circle: {
          center: { latitude: cell.lat, longitude: cell.lng },
          radius: CNG_SEARCH_RADIUS_M,
        },
      },
    };
    if (pageToken) {
      body.pageToken = pageToken;
    }

    const response = await fetch(TEXT_SEARCH_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
          'places.id,places.displayName,places.formattedAddress,places.location,places.types,nextPageToken',
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(20_000),
    });
    if (!response.ok) {
      throw new Error(`Places Text Search HTTP ${response.status}`);
    }
    const payload = (await response.json()) as { nextPageToken?: string };
    places.push(...parseTextSearchPlaces(payload));
    pageToken = payload.nextPageToken?.trim() || undefined;
    if (!pageToken) {
      break;
    }
    await pause(PAUSE_MS);
  }

  return places;
}

function clip(value: string | null, max: number): string | null {
  if (!value) {
    return null;
  }
  return value.length <= max ? value : value.slice(0, max);
}

function pause(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});

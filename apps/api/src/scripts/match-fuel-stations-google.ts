/**
 * Attach a Google place id to each fuel station that does not have one yet.
 * The API never calls this. After setting SKP_GOOGLE_PLACES_API_KEY:
 *   cd apps/api && npm run fuel-stations:match-google
 */
import { PrismaClient } from '@prisma/client';
import { loadEnvFile } from '../config/load-env.js';
import {
  GOOGLE_MATCH_RADIUS_M,
  googleIncludedType,
  parseNearbyPlaces,
  pickClosestGooglePlace,
} from '../modules/fuel_stations/google.js';

const PLACES_URL = 'https://places.googleapis.com/v1/places:searchNearby';
const PAUSE_MS = 100;

async function main() {
  loadEnvFile();
  const apiKey = process.env.SKP_GOOGLE_PLACES_API_KEY?.trim();
  if (!apiKey) {
    throw new Error('SKP_GOOGLE_PLACES_API_KEY is not set');
  }

  const prisma = new PrismaClient();
  try {
    const stations = await prisma.fuelStation.findMany({
      where: { isActive: true, googlePlaceId: null },
      select: {
        id: true,
        latitude: true,
        longitude: true,
        petrol: true,
        diesel: true,
        cng: true,
        ev: true,
        fuelUntyped: true,
      },
    });

    let matched = 0;
    let unmatched = 0;
    for (const station of stations) {
      const placeId = await findPlaceId(apiKey, station);
      if (placeId) {
        await prisma.fuelStation.update({
          where: { id: station.id },
          data: { googlePlaceId: placeId },
        });
        matched += 1;
      } else {
        unmatched += 1;
      }
      await pause(PAUSE_MS);
    }

    console.info('Fuel station Google match complete', {
      considered: stations.length,
      matched,
      unmatched,
    });
  } finally {
    await prisma.$disconnect();
  }
}

async function findPlaceId(
  apiKey: string,
  station: {
    latitude: number;
    longitude: number;
    petrol: boolean;
    diesel: boolean;
    cng: boolean;
    ev: boolean;
    fuelUntyped: boolean;
  },
): Promise<string | null> {
  const response = await fetch(PLACES_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': 'places.id,places.location',
    },
    body: JSON.stringify({
      includedTypes: [googleIncludedType(station)],
      maxResultCount: 5,
      rankPreference: 'DISTANCE',
      locationRestriction: {
        circle: {
          center: { latitude: station.latitude, longitude: station.longitude },
          radius: GOOGLE_MATCH_RADIUS_M,
        },
      },
    }),
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) {
    throw new Error(`Google Places HTTP ${response.status}`);
  }
  const candidates = parseNearbyPlaces(await response.json());
  return pickClosestGooglePlace(
    { lat: station.latitude, lng: station.longitude },
    candidates,
  );
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

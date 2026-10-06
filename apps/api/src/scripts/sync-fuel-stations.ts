/**
 * Fill fuel_stations from OpenStreetMap for the Delhi NCR box.
 * The API never calls this. Schedule it daily on the host:
 *   cd apps/api && npm run fuel-stations:sync
 */
import { PrismaClient } from '@prisma/client';
import { loadEnvFile } from '../config/load-env.js';
import {
  DELHI_NCR_BBOX,
  mapOsmElement,
  nextMissState,
  overpassQuery,
  type MappedStation,
} from '../modules/fuel_stations/osm.js';

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';
const USER_AGENT = 'SKP-Kiosk/0.1 (fuel-station-sync)';
const CHUNK = 50;

async function main() {
  loadEnvFile();
  const prisma = new PrismaClient();
  try {
    const stations = await fetchStations();
    const seen = new Set(stations.map((station) => station.osmId));
    const now = new Date();
    await upsertStations(prisma, stations, now);

    const existing = await prisma.fuelStation.findMany({
      where: {
        latitude: { gte: DELHI_NCR_BBOX.south, lte: DELHI_NCR_BBOX.north },
        longitude: { gte: DELHI_NCR_BBOX.west, lte: DELHI_NCR_BBOX.east },
      },
      select: { id: true, osmId: true, missCount: true },
    });
    const missing = existing.filter((row) => !seen.has(row.osmId));
    await markMissing(prisma, missing);

    console.info('Fuel station sync complete', {
      upserted: seen.size,
      missing: missing.length,
    });
  } finally {
    await prisma.$disconnect();
  }
}

async function fetchStations(): Promise<MappedStation[]> {
  const response = await fetch(OVERPASS_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'User-Agent': USER_AGENT,
      Accept: 'application/json',
    },
    body: `data=${encodeURIComponent(overpassQuery())}`,
    signal: AbortSignal.timeout(90_000),
  });
  if (!response.ok) {
    throw new Error(`Overpass HTTP ${response.status}`);
  }
  const payload = (await response.json()) as { elements?: unknown[]; remark?: string };
  if (!Array.isArray(payload.elements)) {
    throw new Error(payload.remark ?? 'Overpass response did not include elements');
  }

  const byId = new Map<string, MappedStation>();
  for (const element of payload.elements) {
    const station = mapOsmElement(element);
    if (station) {
      byId.set(station.osmId, station);
    }
  }
  if (byId.size === 0) {
    throw new Error('Overpass returned no fuel or charging stations');
  }
  return [...byId.values()];
}

async function upsertStations(prisma: PrismaClient, stations: MappedStation[], now: Date) {
  for (let index = 0; index < stations.length; index += CHUNK) {
    const chunk = stations.slice(index, index + CHUNK);
    await prisma.$transaction(
      chunk.map((station) =>
        prisma.fuelStation.upsert({
          where: { osmId: station.osmId },
          create: {
            ...station,
            lastSeenAt: now,
            missCount: 0,
            isActive: true,
          },
          update: {
            name: station.name,
            address: station.address,
            latitude: station.latitude,
            longitude: station.longitude,
            petrol: station.petrol,
            diesel: station.diesel,
            cng: station.cng,
            ev: station.ev,
            fuelUntyped: station.fuelUntyped,
            lastSeenAt: now,
            missCount: 0,
            isActive: true,
          },
        }),
      ),
    );
  }
}

async function markMissing(
  prisma: PrismaClient,
  rows: Array<{ id: string; missCount: number }>,
) {
  for (let index = 0; index < rows.length; index += CHUNK) {
    const chunk = rows.slice(index, index + CHUNK);
    await prisma.$transaction(
      chunk.map((row) => {
        const next = nextMissState(false, row.missCount);
        return prisma.fuelStation.update({
          where: { id: row.id },
          data: next,
        });
      }),
    );
  }
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});

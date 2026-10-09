import type { FuelKind } from './nearby.js';

export type CatalogStationFlags = {
  petrol: boolean;
  diesel: boolean;
  cng: boolean;
  ev: boolean;
  fuelUntyped: boolean;
};

export type CatalogCounts = {
  all: number;
  fuel: number;
  cng: number;
  ev: number;
};

export function isCatalogFuel(station: CatalogStationFlags): boolean {
  return station.petrol || station.diesel || station.fuelUntyped;
}

export function matchesCatalogKind(station: CatalogStationFlags, kind: FuelKind): boolean {
  if (kind === 'all') {
    return true;
  }
  if (kind === 'fuel') {
    return isCatalogFuel(station);
  }
  if (kind === 'cng') {
    return station.cng;
  }
  return station.ev;
}

export function countCatalogKinds(stations: CatalogStationFlags[]): CatalogCounts {
  let fuel = 0;
  let cng = 0;
  let ev = 0;
  for (const station of stations) {
    if (isCatalogFuel(station)) {
      fuel += 1;
    }
    if (station.cng) {
      cng += 1;
    }
    if (station.ev) {
      ev += 1;
    }
  }
  return { all: stations.length, fuel, cng, ev };
}

export function filterCatalogStations<T extends CatalogStationFlags & { name: string | null; address: string | null }>(
  stations: T[],
  kind: FuelKind,
  q: string | undefined,
): T[] {
  const needle = q?.trim().toLowerCase();
  return stations.filter((station) => {
    if (!matchesCatalogKind(station, kind)) {
      return false;
    }
    if (!needle) {
      return true;
    }
    const name = station.name?.toLowerCase() ?? '';
    const address = station.address?.toLowerCase() ?? '';
    return name.includes(needle) || address.includes(needle);
  });
}

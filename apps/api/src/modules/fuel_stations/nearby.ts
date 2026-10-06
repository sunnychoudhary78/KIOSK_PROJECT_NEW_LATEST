import { haversineKm, roundDistanceKm } from '../../shared/geo.js';
import type { FuelFlags } from './osm.js';

/** Stations farther than this from the kiosk are omitted. */
export const NEARBY_RADIUS_KM = 5;

export type FuelKind = 'all' | 'fuel' | 'cng' | 'ev';

export type NearbyStationInput = FuelFlags & {
  name: string | null;
  address: string | null;
  latitude: number;
  longitude: number;
};

export type NearbyStation = NearbyStationInput & {
  distanceKm: number;
};

export type SearchBox = {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
};

const KM_PER_DEG_LAT = 111;

export function searchBox(lat: number, lng: number, radiusKm: number): SearchBox {
  const latDelta = radiusKm / KM_PER_DEG_LAT;
  const cos = Math.cos((lat * Math.PI) / 180);
  const lngDelta = radiusKm / (KM_PER_DEG_LAT * Math.max(0.2, Math.abs(cos)));
  return {
    minLat: lat - latDelta,
    maxLat: lat + latDelta,
    minLng: lng - lngDelta,
    maxLng: lng + lngDelta,
  };
}

export function matchesKind(station: FuelFlags, kind: FuelKind): boolean {
  if (kind === 'all') {
    return true;
  }
  if (kind === 'fuel') {
    return station.petrol || station.diesel || station.fuelUntyped;
  }
  if (kind === 'cng') {
    return station.cng;
  }
  return station.ev;
}

export function rankNearbyStations(
  stations: NearbyStationInput[],
  origin: { lat: number; lng: number },
  kind: FuelKind,
  radiusKm: number = NEARBY_RADIUS_KM,
  limit: number = 30,
): NearbyStation[] {
  return stations
    .filter((station) => matchesKind(station, kind))
    .map((station) => ({
      station,
      distanceKm: haversineKm(origin.lat, origin.lng, station.latitude, station.longitude),
    }))
    .filter((entry) => entry.distanceKm <= radiusKm)
    .sort((a, b) => a.distanceKm - b.distanceKm)
    .slice(0, limit)
    .map((entry) => ({
      name: entry.station.name,
      address: entry.station.address,
      latitude: entry.station.latitude,
      longitude: entry.station.longitude,
      petrol: entry.station.petrol,
      diesel: entry.station.diesel,
      cng: entry.station.cng,
      ev: entry.station.ev,
      fuelUntyped: entry.station.fuelUntyped,
      distanceKm: roundDistanceKm(entry.distanceKm),
    }));
}

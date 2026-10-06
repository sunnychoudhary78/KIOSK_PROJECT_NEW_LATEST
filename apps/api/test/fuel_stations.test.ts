import { describe, expect, it } from 'vitest';
import { mapOsmElement, nextMissState, overpassQuery } from '../src/modules/fuel_stations/osm.js';
import { rankNearbyStations } from '../src/modules/fuel_stations/nearby.js';

const origin = { lat: 28.6139, lng: 77.209 };

function station(overrides: Partial<Parameters<typeof rankNearbyStations>[0][number]> & {
  latitude: number;
  longitude: number;
}) {
  return {
    name: 'Pump',
    address: null,
    petrol: false,
    diesel: false,
    cng: false,
    ev: false,
    fuelUntyped: false,
    ...overrides,
  };
}

describe('mapOsmElement', () => {
  it('maps petrol and diesel tags on a fuel node', () => {
    const mapped = mapOsmElement({
      type: 'node',
      id: 10,
      lat: 28.61,
      lon: 77.2,
      tags: { amenity: 'fuel', name: 'Indian Oil', 'fuel:diesel': 'yes', 'fuel:octane_91': 'yes' },
    });
    expect(mapped).toMatchObject({
      osmId: 'node/10',
      name: 'Indian Oil',
      petrol: true,
      diesel: true,
      cng: false,
      ev: false,
      fuelUntyped: false,
    });
  });

  it('marks a fuel pump with no fuel tags as untyped', () => {
    const mapped = mapOsmElement({
      type: 'node',
      id: 11,
      lat: 28.62,
      lon: 77.21,
      tags: { amenity: 'fuel', name: 'HPCL' },
    });
    expect(mapped?.fuelUntyped).toBe(true);
    expect(mapped?.petrol).toBe(false);
    expect(mapped?.diesel).toBe(false);
  });

  it('treats a CNG name as CNG unless the tag says no', () => {
    const named = mapOsmElement({
      type: 'node',
      id: 12,
      lat: 28.62,
      lon: 77.21,
      tags: { amenity: 'fuel', name: 'HP CNG Pump' },
    });
    expect(named?.cng).toBe(true);
    expect(named?.fuelUntyped).toBe(false);

    const denied = mapOsmElement({
      type: 'node',
      id: 13,
      lat: 28.62,
      lon: 77.21,
      tags: { amenity: 'fuel', name: 'HP CNG Pump', 'fuel:cng': 'no' },
    });
    expect(denied?.cng).toBe(false);
    expect(denied?.fuelUntyped).toBe(true);
  });

  it('maps a charging station way from its center', () => {
    const mapped = mapOsmElement({
      type: 'way',
      id: 99,
      center: { lat: 28.63, lon: 77.22 },
      tags: { amenity: 'charging_station', name: 'EV Hub' },
    });
    expect(mapped).toMatchObject({
      osmId: 'way/99',
      latitude: 28.63,
      longitude: 77.22,
      ev: true,
      fuelUntyped: false,
    });
  });

  it('drops elements without coordinates', () => {
    expect(mapOsmElement({ type: 'node', id: 1, tags: { amenity: 'fuel' } })).toBeNull();
  });

  it('builds a Delhi NCR Overpass query', () => {
    const query = overpassQuery();
    expect(query).toContain('(28.4,76.8,28.9,77.6)');
    expect(query).toContain('amenity"="fuel"');
    expect(query).toContain('amenity"="charging_station"');
  });
});

describe('nextMissState', () => {
  it('resets a station that was seen', () => {
    expect(nextMissState(true, 2)).toEqual({ missCount: 0, isActive: true });
  });

  it('deactivates on the third miss', () => {
    expect(nextMissState(false, 0)).toEqual({ missCount: 1, isActive: true });
    expect(nextMissState(false, 1)).toEqual({ missCount: 2, isActive: true });
    expect(nextMissState(false, 2)).toEqual({ missCount: 3, isActive: false });
  });
});

describe('rankNearbyStations', () => {
  const nearbyFuel = station({
    name: 'Near',
    latitude: 28.62,
    longitude: 77.209,
    petrol: true,
  });
  const cng = station({
    name: 'CNG',
    latitude: 28.63,
    longitude: 77.209,
    cng: true,
  });
  const untyped = station({
    name: 'Untyped',
    latitude: 28.615,
    longitude: 77.209,
    fuelUntyped: true,
  });
  const far = station({
    name: 'Far',
    latitude: 28.9,
    longitude: 77.209,
    petrol: true,
  });
  const ev = station({
    name: 'EV',
    latitude: 28.614,
    longitude: 77.209,
    ev: true,
  });

  it('sorts by distance and drops stations outside the radius', () => {
    const items = rankNearbyStations([far, nearbyFuel, untyped], origin, 'all');
    expect(items.map((item) => item.name)).toEqual(['Untyped', 'Near']);
    expect(items[0]?.distanceKm).toBeGreaterThan(0);
  });

  it('keeps untyped pumps on the fuel filter and CNG on its own filter', () => {
    const fuel = rankNearbyStations([nearbyFuel, cng, untyped, ev], origin, 'fuel');
    expect(fuel.map((item) => item.name)).toEqual(['Untyped', 'Near']);

    const cngOnly = rankNearbyStations([nearbyFuel, cng, untyped], origin, 'cng');
    expect(cngOnly.map((item) => item.name)).toEqual(['CNG']);
  });

  it('respects the limit', () => {
    const items = rankNearbyStations([nearbyFuel, untyped, ev], origin, 'all', 5, 1);
    expect(items).toHaveLength(1);
    expect(items[0]?.name).toBe('EV');
  });
});

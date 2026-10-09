import { describe, expect, it } from 'vitest';
import {
  approachEndpointsFromSnaps,
  buildRouteTrafficSegments,
  classifyApproachFromRoute,
  classifySpeedIntervals,
  offsetMeters,
  parseDurationSec,
  pickApproachTargets,
  waitMinutesForApproach,
} from '../src/modules/fuel_stations/approach.js';
import { countCatalogKinds, filterCatalogStations } from '../src/modules/fuel_stations/catalog.js';
import {
  acceptCngPlace,
  buildNcrGrid,
  decideCngMerge,
  googleOsmId,
  isCngStationName,
  isGoogleSourcedOsmId,
  parseTextSearchPlaces,
} from '../src/modules/fuel_stations/cng_seed.js';
import {
  googleIncludedType,
  parseNearbyPlaces,
  pickClosestGooglePlace,
} from '../src/modules/fuel_stations/google.js';
import { mapOsmElement, nextMissState, overpassQuery } from '../src/modules/fuel_stations/osm.js';
import { rankNearbyStations } from '../src/modules/fuel_stations/nearby.js';
import { haversineKm } from '../src/shared/geo.js';

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

  it('passes a Google place id through to the response', () => {
    const items = rankNearbyStations(
      [station({ name: 'Near', latitude: 28.62, longitude: 77.209, petrol: true, googlePlaceId: 'ChIJpump' })],
      origin,
      'all',
    );
    expect(items[0]?.googlePlaceId).toBe('ChIJpump');
    expect(items[0]?.approachTraffic).toBeNull();
  });

  it('respects the limit', () => {
    const items = rankNearbyStations([nearbyFuel, untyped, ev], origin, 'all', 5, 1);
    expect(items).toHaveLength(1);
    expect(items[0]?.name).toBe('EV');
  });
});

describe('approach traffic helpers', () => {
  it('classifies jam over slow over clear', () => {
    expect(classifySpeedIntervals([{ speed: 'NORMAL' }, { speed: 'SLOW' }])).toBe('moderate');
    expect(
      classifySpeedIntervals([{ speed: 'SLOW' }, { speed: 'TRAFFIC_JAM' }, { speed: 'NORMAL' }]),
    ).toBe('heavy');
    expect(classifySpeedIntervals([{ speed: 'NORMAL' }])).toBe('clear');
    expect(classifySpeedIntervals([])).toBe('unknown');
  });

  it('maps approach status to heuristic queue wait minutes', () => {
    expect(waitMinutesForApproach('clear')).toBeNull();
    expect(waitMinutesForApproach('unknown')).toBeNull();
    expect(waitMinutesForApproach('moderate')).toBe(6);
    expect(waitMinutesForApproach('heavy')).toBe(15);
  });

  it('parses Google Routes duration strings', () => {
    expect(parseDurationSec('45s')).toBe(45);
    expect(parseDurationSec('90s')).toBe(90);
    expect(parseDurationSec('12m34s')).toBe(12 * 60 + 34);
    expect(parseDurationSec('1h2m3s')).toBe(3723);
    expect(parseDurationSec('')).toBeNull();
    expect(parseDurationSec(null)).toBeNull();
  });

  it('builds normalized route traffic segments', () => {
    const segments = buildRouteTrafficSegments([
      { speed: 'NORMAL', startPolylinePointIndex: 0, endPolylinePointIndex: 50 },
      { speed: 'SLOW', startPolylinePointIndex: 50, endPolylinePointIndex: 70 },
      { speed: 'SLOW', startPolylinePointIndex: 70, endPolylinePointIndex: 80 },
      { speed: 'TRAFFIC_JAM', startPolylinePointIndex: 80, endPolylinePointIndex: 100 },
    ]);
    expect(segments).toEqual([
      { speed: 'NORMAL', fraction: 0.5 },
      { speed: 'SLOW', fraction: 0.3 },
      { speed: 'TRAFFIC_JAM', fraction: 0.2 },
    ]);
  });

  it('classifies approach from the last 200 m of the route', () => {
    const intervals = [
      { speed: 'NORMAL', startPolylinePointIndex: 0, endPolylinePointIndex: 80 },
      { speed: 'TRAFFIC_JAM', startPolylinePointIndex: 80, endPolylinePointIndex: 100 },
    ];
    // 1000 m route → last 200 m ≈ last 20% of polyline indices → jam only
    expect(classifyApproachFromRoute(intervals, 1000)).toBe('heavy');
    expect(
      classifyApproachFromRoute(
        [
          { speed: 'NORMAL', startPolylinePointIndex: 0, endPolylinePointIndex: 90 },
          { speed: 'SLOW', startPolylinePointIndex: 90, endPolylinePointIndex: 100 },
        ],
        1000,
      ),
    ).toBe('moderate');
    expect(
      classifyApproachFromRoute(
        [{ speed: 'NORMAL', startPolylinePointIndex: 0, endPolylinePointIndex: 100 }],
        1000,
      ),
    ).toBe('clear');
  });

  it('picks the nearest CNG/EV stations only', () => {
    const items = rankNearbyStations(
      [
        station({ name: 'Fuel', latitude: 28.614, longitude: 77.209, petrol: true }),
        station({ name: 'CNG-A', latitude: 28.615, longitude: 77.209, cng: true }),
        station({ name: 'EV-A', latitude: 28.616, longitude: 77.209, ev: true }),
        station({ name: 'CNG-B', latitude: 28.617, longitude: 77.209, cng: true }),
      ],
      origin,
      'all',
    );
    const targets = pickApproachTargets(items, 2);
    expect(targets.map((t) => t.station.name)).toEqual(['CNG-A', 'EV-A']);
  });

  it('builds endpoints about 100 m each way from snapped road points', () => {
    const station = { lat: 28.6139, lng: 77.209 };
    const west = offsetMeters(station, 270, 20);
    const east = offsetMeters(station, 90, 20);
    const endpoints = approachEndpointsFromSnaps(station, [west, east], 100);
    expect(endpoints).not.toBeNull();
    const spanM =
      haversineKm(
        endpoints!.origin.lat,
        endpoints!.origin.lng,
        endpoints!.destination.lat,
        endpoints!.destination.lng,
      ) * 1000;
    expect(spanM).toBeGreaterThan(180);
    expect(spanM).toBeLessThan(220);
  });
});

describe('pickClosestGooglePlace', () => {
  const origin = { lat: 28.6139, lng: 77.209 };

  it('keeps the closest pump and strips the places prefix', () => {
    const id = pickClosestGooglePlace(origin, [
      { id: 'places/ChIJfar', latitude: 28.6145, longitude: 77.209 },
      { id: 'places/ChIJnear', latitude: 28.614, longitude: 77.209 },
    ]);
    expect(id).toBe('ChIJnear');
  });

  it('returns null when every candidate is outside the radius', () => {
    expect(
      pickClosestGooglePlace(origin, [{ id: 'ChIJfar', latitude: 28.62, longitude: 77.209 }]),
    ).toBeNull();
  });

  it('parses a Places nearby payload', () => {
    const candidates = parseNearbyPlaces({
      places: [{ id: 'ChIJpump', location: { latitude: 28.61, longitude: 77.2 } }, { id: 1 }],
    });
    expect(candidates).toEqual([{ id: 'ChIJpump', latitude: 28.61, longitude: 77.2 }]);
  });

  it('searches charging stations only for EV-only rows', () => {
    expect(
      googleIncludedType({ petrol: false, diesel: false, cng: false, ev: true, fuelUntyped: false }),
    ).toBe('electric_vehicle_charging_station');
    expect(
      googleIncludedType({ petrol: true, diesel: false, cng: false, ev: true, fuelUntyped: false }),
    ).toBe('gas_station');
  });
});

describe('catalog helpers', () => {
  const rows = [
    {
      name: 'IOC',
      address: 'Ring Road',
      petrol: true,
      diesel: true,
      cng: false,
      ev: false,
      fuelUntyped: false,
    },
    {
      name: 'IGL CNG',
      address: 'Dwarka',
      petrol: false,
      diesel: false,
      cng: true,
      ev: false,
      fuelUntyped: false,
    },
    {
      name: 'Tata EV',
      address: 'Noida',
      petrol: false,
      diesel: false,
      cng: false,
      ev: true,
      fuelUntyped: false,
    },
    {
      name: 'Untyped pump',
      address: null,
      petrol: false,
      diesel: false,
      cng: false,
      ev: false,
      fuelUntyped: true,
    },
  ];

  it('counts overlapping categories', () => {
    expect(countCatalogKinds(rows)).toEqual({ all: 4, fuel: 2, cng: 1, ev: 1 });
  });

  it('filters by kind and search text', () => {
    expect(filterCatalogStations(rows, 'cng', undefined).map((r) => r.name)).toEqual(['IGL CNG']);
    expect(filterCatalogStations(rows, 'fuel', 'ring').map((r) => r.name)).toEqual(['IOC']);
    expect(filterCatalogStations(rows, 'all', 'noida').map((r) => r.name)).toEqual(['Tata EV']);
  });
});

describe('cng google seed helpers', () => {
  it('builds an NCR grid and recognizes google osm ids', () => {
    const cells = buildNcrGrid();
    expect(cells.length).toBeGreaterThan(100);
    expect(cells[0]).toEqual({ lat: 28.4, lng: 76.8 });
    expect(isGoogleSourcedOsmId('google/ChIJabc')).toBe(true);
    expect(isGoogleSourcedOsmId('node/123')).toBe(false);
    expect(googleOsmId('places/ChIJabc')).toBe('google/ChIJabc');
  });

  it('keeps CNG-named places inside the box', () => {
    expect(isCngStationName('IGL CNG Station')).toBe(true);
    expect(isCngStationName('CNG kit fitting')).toBe(true);
    expect(isCngStationName('Petrol pump')).toBe(false);
    expect(
      acceptCngPlace({
        placeId: 'ChIJabc',
        name: 'IGL CNG',
        latitude: 28.61,
        longitude: 77.2,
      }),
    ).toBe(true);
    expect(
      acceptCngPlace({
        placeId: 'ChIJabc',
        name: 'IGL CNG',
        latitude: 27.0,
        longitude: 77.2,
      }),
    ).toBe(false);
  });

  it('updates by place id, merges nearby OSM rows, or inserts', () => {
    const place = {
      placeId: 'ChIJnew',
      name: 'HP CNG',
      address: 'Dwarka',
      latitude: 28.61,
      longitude: 77.21,
    };
    expect(
      decideCngMerge(place, [
        {
          id: '1',
          googlePlaceId: 'ChIJnew',
          latitude: 28.61,
          longitude: 77.21,
          name: 'Old',
          address: null,
        },
      ]),
    ).toMatchObject({ type: 'update', id: '1', name: 'Old', address: 'Dwarka' });

    expect(
      decideCngMerge(place, [
        {
          id: '2',
          googlePlaceId: null,
          latitude: 28.6101,
          longitude: 77.21,
          name: 'OSM pump',
          address: 'A',
        },
      ]),
    ).toMatchObject({ type: 'update', id: '2', googlePlaceId: 'ChIJnew', name: 'OSM pump' });

    expect(decideCngMerge(place, [])).toEqual({
      type: 'insert',
      place: { ...place, placeId: 'ChIJnew' },
      osmId: 'google/ChIJnew',
    });
  });

  it('parses Text Search payloads', () => {
    const places = parseTextSearchPlaces({
      places: [
        {
          id: 'places/ChIJx',
          displayName: { text: 'IGL CNG' },
          formattedAddress: 'Delhi',
          location: { latitude: 28.6, longitude: 77.2 },
        },
      ],
    });
    expect(places).toEqual([
      {
        placeId: 'ChIJx',
        name: 'IGL CNG',
        address: 'Delhi',
        latitude: 28.6,
        longitude: 77.2,
      },
    ]);
  });
});

import { describe, expect, it } from 'vitest';
import { haversineKm, normalizeLatLng, roundDistanceKm, sameMapPin } from '../src/shared/geo.js';
import { nearbyDevicesQuerySchema, registerDeviceSchema } from '../src/modules/devices/devices.schemas.js';

describe('haversineKm', () => {
  it('returns ~0 for identical points', () => {
    expect(haversineKm(28.6139, 77.209, 28.6139, 77.209)).toBeCloseTo(0, 5);
  });

  it('treats swapped long/lat as the same India pin', () => {
    expect(haversineKm(28.65195, 77.23149, 77.23149, 28.65195)).toBe(0);
    expect(sameMapPin(28.65195, 77.23149, 77.23149, 28.65195)).toBe(true);
    expect(normalizeLatLng(77.23149, 28.65195)).toEqual({
      latitude: 28.65195,
      longitude: 77.23149,
    });
  });

  it('matches a known Delhi–ish short distance', () => {
    // ~1.11 km between these two points
    const km = haversineKm(28.6139, 77.209, 28.6239, 77.209);
    expect(km).toBeGreaterThan(1.0);
    expect(km).toBeLessThan(1.3);
  });

  it('rounds short distances to centimetres of a km', () => {
    expect(roundDistanceKm(0.04)).toBe(0);
    expect(roundDistanceKm(1.234)).toBe(1.23);
    expect(roundDistanceKm(12.34)).toBe(12.3);
    expect(roundDistanceKm(123.4)).toBe(123);
  });
});

describe('device schemas', () => {
  it('requires lat/lng on register', () => {
    const ok = registerDeviceSchema.safeParse({
      name: 'Lobby',
      siteName: 'Demo',
      latitude: 28.61,
      longitude: 77.21,
    });
    expect(ok.success).toBe(true);

    const missing = registerDeviceSchema.safeParse({
      name: 'Lobby',
      siteName: 'Demo',
    });
    expect(missing.success).toBe(false);
  });

  it('parses nearby query with defaults', () => {
    const parsed = nearbyDevicesQuerySchema.parse({ lat: '28.6', lng: '77.2' });
    expect(parsed).toEqual({ lat: 28.6, lng: 77.2, limit: 20 });
  });
});

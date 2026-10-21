import { describe, expect, it, vi } from 'vitest';
import {
  createPlacesClient,
  encodeOpenMeteoPlaceId,
  mapGoogleAutocomplete,
  mapGooglePlaceDetails,
  mapOpenMeteoSuggestions,
  parseOpenMeteoPlaceId,
} from '../src/infrastructure/external/places.client.js';
import type { Logger } from '../src/infrastructure/logging/logger.js';

const silentLogger = { info: vi.fn(), warn: vi.fn(), error: vi.fn() } as unknown as Logger;

describe('places mapping', () => {
  it('maps Google autocomplete suggestions', () => {
    const suggestions = mapGoogleAutocomplete({
      suggestions: [
        {
          placePrediction: {
            placeId: 'places/ChIJ123',
            text: { text: 'Jaipur, Rajasthan, India' },
            structuredFormat: {
              mainText: { text: 'Jaipur' },
              secondaryText: { text: 'Rajasthan, India' },
            },
          },
        },
      ],
    });
    expect(suggestions).toEqual([
      { id: 'ChIJ123', label: 'Jaipur', subtitle: 'Rajasthan, India' },
    ]);
  });

  it('maps Google place details', () => {
    expect(
      mapGooglePlaceDetails(
        {
          id: 'places/ChIJ123',
          displayName: { text: 'Jaipur' },
          formattedAddress: 'Jaipur, Rajasthan, India',
          location: { latitude: 26.91, longitude: 75.78 },
        },
        'ChIJ123',
      ),
    ).toEqual({
      id: 'ChIJ123',
      name: 'Jaipur',
      latitude: 26.91,
      longitude: 75.78,
    });
  });

  it('maps Open-Meteo suggestions and round-trips om ids', () => {
    const suggestions = mapOpenMeteoSuggestions({
      results: [
        {
          name: 'Rampur',
          admin1: 'Uttar Pradesh',
          country: 'India',
          latitude: 28.8,
          longitude: 79.02,
        },
      ],
    });
    expect(suggestions[0]?.label).toBe('Rampur');
    const parsed = parseOpenMeteoPlaceId(suggestions[0]!.id);
    expect(parsed).toMatchObject({
      name: 'Rampur, Uttar Pradesh, India',
      latitude: 28.8,
      longitude: 79.02,
    });
    expect(
      encodeOpenMeteoPlaceId({
        name: 'Jaipur, Rajasthan, India',
        latitude: 26.91,
        longitude: 75.78,
      }),
    ).toContain('om:26.91,75.78|');
  });
});

describe('places client', () => {
  it('falls back to Open-Meteo when Google key is missing', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      expect(String(url)).toContain('geocoding-api.open-meteo.com');
      return new Response(
        JSON.stringify({
          results: [
            {
              name: 'Jaipur',
              admin1: 'Rajasthan',
              country: 'India',
              latitude: 26.91,
              longitude: 75.78,
            },
          ],
        }),
        { status: 200 },
      );
    });
    const client = createPlacesClient({
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    const suggestions = await client.autocomplete('Jai');
    expect(suggestions).toHaveLength(1);
    expect(suggestions[0]?.id.startsWith('om:')).toBe(true);
    const resolved = await client.resolve(suggestions[0]!.id);
    expect(resolved.latitude).toBe(26.91);
  });

  it('uses Google autocomplete when key is present', async () => {
    const fetchImpl = vi.fn(async () => {
      return new Response(
        JSON.stringify({
          suggestions: [
            {
              placePrediction: {
                placeId: 'ChIJGoogle',
                structuredFormat: {
                  mainText: { text: 'Delhi' },
                  secondaryText: { text: 'India' },
                },
              },
            },
          ],
        }),
        { status: 200 },
      );
    });
    const client = createPlacesClient({
      apiKey: 'test-key',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    const suggestions = await client.autocomplete('Del');
    expect(suggestions).toEqual([{ id: 'ChIJGoogle', label: 'Delhi', subtitle: 'India' }]);
  });
});

import { describe, expect, it, vi } from 'vitest';
import {
  ASTROLOGY_DISCLAIMER,
  createReadingFieldsSchema,
  llmReadingSchema,
  parseLlmJson,
  sniffPalmImageMime,
} from '../src/modules/astrology/astrology.schemas.js';
import {
  NOOP_ASTROLOGY_READING,
  OPENAI_CHAT_URL,
  createAstrologyLlmClient,
  createNoopAstrologyLlmClient,
  createOpenAiAstrologyClient,
} from '../src/infrastructure/external/openai.client.js';
import type { Logger } from '../src/infrastructure/logging/logger.js';

const silentLogger = { info: vi.fn(), warn: vi.fn(), error: vi.fn() } as unknown as Logger;

const subject = {
  name: 'Asha',
  gender: 'female' as const,
  dateOfBirth: '1992-03-18',
  birthTime: '12:00',
  birthPlace: 'Jaipur',
  birthTimeUnknown: true,
};

describe('astrology schemas', () => {
  it('parses multipart-like string flags', () => {
    const parsed = createReadingFieldsSchema.parse({
      name: 'Asha',
      gender: 'female',
      dateOfBirth: '1992-03-18',
      birthTime: '14:05',
      birthPlace: 'Jaipur, Rajasthan',
      birthTimeUnknown: 'true',
    });
    expect(parsed.birthTimeUnknown).toBe(true);
  });

  it('rejects invalid calendar dates', () => {
    const result = createReadingFieldsSchema.safeParse({
      name: 'Asha',
      gender: 'female',
      dateOfBirth: '1992-02-31',
      birthTime: '14:05',
      birthPlace: 'Jaipur',
    });
    expect(result.success).toBe(false);
  });

  it('strips markdown fences from LLM JSON', () => {
    const parsed = parseLlmJson('```json\n{"disclaimer":"x","palm":{}}\n```');
    expect(parsed).toEqual({ disclaimer: 'x', palm: {} });
  });

  it('sniffs JPEG, PNG, and WebP magic bytes', () => {
    expect(sniffPalmImageMime(Buffer.from([0xff, 0xd8, 0xff, 0xdb]))).toBe('image/jpeg');
    expect(
      sniffPalmImageMime(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00])),
    ).toBe('image/png');
    const webp = Buffer.alloc(12);
    webp.write('RIFF', 0);
    webp.write('WEBP', 8);
    expect(sniffPalmImageMime(webp)).toBe('image/webp');
    expect(sniffPalmImageMime(Buffer.from('BM'))).toBeUndefined();
  });
});

describe('astrology LLM client', () => {
  it('noop provider returns the fixture payload', async () => {
    const reading = await createNoopAstrologyLlmClient().generateReading({
      subject,
      chart: { sunSign: 'Pisces', planets: [], houses: [] },
      image: { mimeType: 'image/jpeg', buffer: Buffer.from('fake') },
    });
    expect(reading).toEqual(NOOP_ASTROLOGY_READING);
    expect(llmReadingSchema.safeParse(reading).success).toBe(true);
  });

  it('falls back to noop when openai has no key in local mode', async () => {
    const client = createAstrologyLlmClient({
      provider: 'openai',
      apiKey: '',
      model: 'gpt-4o',
      logger: silentLogger,
      allowNoopWhenDisabled: true,
    });
    const reading = await client.generateReading({
      subject,
      chart: { planets: [], houses: [] },
      image: { mimeType: 'image/jpeg', buffer: Buffer.from('x') },
    });
    expect(reading.disclaimer).toBe(ASTROLOGY_DISCLAIMER);
  });

  it('posts vision JSON to OpenAI and parses the message', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      expect(String(url)).toBe(OPENAI_CHAT_URL);
      return new Response(
        JSON.stringify({
          choices: [
            {
              message: {
                content: JSON.stringify({
                  disclaimer: ASTROLOGY_DISCLAIMER,
                  palm: {
                    summary: 'Open palm',
                    lifeLine: 'Life',
                    heartLine: 'Heart',
                    headLine: 'Head',
                    fateLine: 'Fate',
                  },
                  reading: {
                    overview: 'Overview',
                    personality: 'Personality',
                    career: 'Career',
                    health: 'Health',
                    relationships: 'Relationships',
                    period: 'Period',
                  },
                }),
              },
            },
          ],
        }),
        { status: 200 },
      );
    });

    const client = createOpenAiAstrologyClient({
      apiKey: 'sk-test',
      model: 'gpt-4o',
      logger: silentLogger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });
    const reading = await client.generateReading({
      subject,
      chart: { moonSign: 'Taurus', planets: [], houses: [] },
      image: { mimeType: 'image/jpeg', buffer: Buffer.from('abc') },
    });
    expect(reading.palm.lifeLine).toBe('Life');
    expect(reading.reading.overview).toBe('Overview');
    expect(fetchImpl).toHaveBeenCalledOnce();
  });
});

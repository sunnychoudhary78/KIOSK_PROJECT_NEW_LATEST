import type { Logger } from '../logging/logger.js';
import { AppError } from '../../shared/errors.js';
import {
  ASTROLOGY_DISCLAIMER,
  llmReadingSchema,
  parseLlmJson,
  type CompactVedicChart,
  type LlmReading,
  type ReadingSubject,
} from '../../modules/astrology/astrology.schemas.js';

export const OPENAI_CHAT_URL = 'https://api.openai.com/v1/chat/completions';

export type AstrologyLlmInput = {
  subject: ReadingSubject;
  chart: CompactVedicChart;
  image: { mimeType: string; buffer: Buffer };
};

export interface AstrologyLlmClient {
  generateReading(input: AstrologyLlmInput): Promise<LlmReading>;
}

type FetchLike = typeof fetch;

export const NOOP_ASTROLOGY_READING: LlmReading = {
  disclaimer: ASTROLOGY_DISCLAIMER,
  palm: {
    summary: 'A clear, open palm with balanced major lines.',
    lifeLine: 'A long, steady life line suggests vitality and a grounded pace.',
    heartLine: 'A warm heart line points to loyalty in close relationships.',
    headLine: 'A clear head line supports practical, thoughtful decisions.',
    fateLine: 'A visible fate line hints at purpose that strengthens with time.',
  },
  reading: {
    overview:
      'This is a sample reading used when OpenAI is not configured. The Vedic chart data is still computed when VedAstro is reachable.',
    personality: 'Steady, sincere, and more dependable than flashy.',
    career: 'Progress comes through consistent skill rather than sudden leaps.',
    health: 'Protect rest and routine; nothing here is a medical assessment.',
    relationships: 'Trust grows when you speak plainly and keep small promises.',
    period: 'The coming months favour finishing what you already started.',
  },
};

export function buildAstrologySystemPrompt(): string {
  return [
    'You are a kiosk assistant that writes short Vedic astrology and palmistry copy for entertainment.',
    'The provided VedAstro JSON is the only source of truth for planets, houses, lagna, rasi, navamsa, nakshatra, and dasha.',
    'Use planet rasi, navamsa, nakshatra, house, dignity, and aspects, plus house lords and occupants.',
    'Do not invent houses, dashas, or signs that contradict that JSON.',
    'The attached image is a palm photo. Comment only on visible palm features (life, heart, head, fate lines).',
    'If the palm is unclear, say so briefly and keep palm notes generic.',
    'If birth time is unknown, do not claim a precise lagna.',
    `Always set disclaimer to exactly: "${ASTROLOGY_DISCLAIMER}"`,
    'Reply with a single JSON object with keys disclaimer, palm, reading.',
    'palm must include summary, lifeLine, heartLine, headLine, fateLine.',
    'reading must include overview, personality, career, health, relationships, period.',
    'Each string should be 1-3 sentences, plain language, no markdown.',
  ].join(' ');
}

export function createNoopAstrologyLlmClient(logger?: Logger): AstrologyLlmClient {
  return {
    async generateReading(): Promise<LlmReading> {
      logger?.info(
        { palm: NOOP_ASTROLOGY_READING.palm, reading: NOOP_ASTROLOGY_READING.reading },
        '[Astrology LLM] noop reading',
      );
      return NOOP_ASTROLOGY_READING;
    },
  };
}

export function createOpenAiAstrologyClient(options: {
  apiKey: string;
  model: string;
  logger: Logger;
  fetchImpl?: FetchLike;
}): AstrologyLlmClient {
  const fetchImpl = options.fetchImpl ?? fetch;

  return {
    async generateReading(input: AstrologyLlmInput): Promise<LlmReading> {
      const mime = input.image.mimeType === 'image/jpg' ? 'image/jpeg' : input.image.mimeType;
      const startedAt = Date.now();
      options.logger.info(
        {
          model: options.model,
          image: { mime, bytes: input.image.buffer.length },
          planetCount: input.chart.planets.length,
          houseCount: input.chart.houses.length,
        },
        '[OpenAI] astrology request started',
      );
      const dataUrl = `data:${mime};base64,${input.image.buffer.toString('base64')}`;
      const userText = JSON.stringify(
        {
          subject: input.subject,
          vedastroChart: input.chart,
        },
        null,
        2,
      );

      const response = await fetchImpl(OPENAI_CHAT_URL, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${options.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: options.model,
          response_format: { type: 'json_object' },
          temperature: 0.6,
          messages: [
            { role: 'system', content: buildAstrologySystemPrompt() },
            {
              role: 'user',
              content: [
                { type: 'text', text: userText },
                { type: 'image_url', image_url: { url: dataUrl, detail: 'low' } },
              ],
            },
          ],
        }),
        signal: AbortSignal.timeout(60_000),
      });

      let body: unknown = null;
      try {
        body = await response.json();
      } catch {
        body = null;
      }

      if (!response.ok) {
        const message =
          body && typeof body === 'object' && body !== null && 'error' in body
            ? String(
                (body as { error?: { message?: unknown } }).error?.message ?? 'OpenAI request failed',
              )
            : 'OpenAI request failed';
        options.logger.warn({ status: response.status, message }, '[OpenAI] astrology failed');
        throw new AppError('llm_failed', message, 502);
      }

      const content =
        body && typeof body === 'object' && body !== null
          ? (body as { choices?: Array<{ message?: { content?: unknown } }> }).choices?.[0]?.message
              ?.content
          : undefined;
      if (typeof content !== 'string' || !content.trim()) {
        throw new AppError('llm_failed', 'OpenAI returned an empty reading', 502);
      }

      try {
        const parsed = llmReadingSchema.parse(parseLlmJson(content));
        const reading = {
          ...parsed,
          disclaimer: ASTROLOGY_DISCLAIMER,
        };
        options.logger.info(
          {
            model: options.model,
            durationMs: Date.now() - startedAt,
            disclaimer: reading.disclaimer,
            palm: reading.palm,
            reading: reading.reading,
          },
          '[OpenAI] astrology reading ready',
        );
        return reading;
      } catch (error) {
        options.logger.warn({ err: error, preview: content.slice(0, 240) }, '[OpenAI] invalid JSON');
        throw new AppError('llm_failed', 'OpenAI returned an invalid reading payload', 502);
      }
    },
  };
}

export function createAstrologyLlmClient(options: {
  provider: 'openai' | 'noop';
  apiKey: string;
  model: string;
  logger: Logger;
  fetchImpl?: FetchLike;
  allowNoopWhenDisabled?: boolean;
}): AstrologyLlmClient {
  const openaiReady = options.provider === 'openai' && Boolean(options.apiKey.trim());
  if (openaiReady) {
    return createOpenAiAstrologyClient({
      apiKey: options.apiKey.trim(),
      model: options.model,
      logger: options.logger,
      fetchImpl: options.fetchImpl,
    });
  }
  if (options.allowNoopWhenDisabled || options.provider === 'noop') {
    options.logger.info('[Astrology LLM] using noop provider');
    return createNoopAstrologyLlmClient(options.logger);
  }
  return {
    async generateReading(): Promise<LlmReading> {
      throw new AppError('ai_not_configured', 'OpenAI is not configured', 503);
    },
  };
}

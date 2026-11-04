import type { Logger } from '../logging/logger.js';
import { AppError } from '../../shared/errors.js';
import {
  ASTROLOGY_DISCLAIMER,
  kundaliInsightsSchema,
  llmReadingSchema,
  localeBulletsSchema,
  parseLlmJson,
  type CompactVedicChart,
  type KundaliInsights,
  type LocaleBullets,
  type LlmReading,
  type ReadingSubject,
} from '../../modules/astrology/astrology.schemas.js';

export const OPENAI_CHAT_URL = 'https://api.openai.com/v1/chat/completions';

export type AstrologyLlmInput = {
  subject: ReadingSubject;
  chart: CompactVedicChart;
  image: { mimeType: string; buffer: Buffer };
};

export type KundaliInsightsInput = {
  subject: ReadingSubject;
  chart: CompactVedicChart;
  style: 'north' | 'south';
  chartsPresent: Array<'RasiD1' | 'NavamshaD9' | 'DashamamshaD10'>;
};

export type MatchInsightsInput = {
  groom: ReadingSubject;
  bride: ReadingSubject;
  score: { total: number; max: number; summary: string; tone: string };
  kutas: Array<{
    name: string;
    maxPoints: number;
    points?: number;
    nature?: string;
    verdict?: string;
  }>;
};

export type TodayInsightsInput = {
  subject: ReadingSubject;
  panchang: Record<string, string | undefined>;
  dasha: { label: string; levels: string[] };
};

export interface AstrologyLlmClient {
  generateReading(input: AstrologyLlmInput): Promise<LlmReading>;
  generateKundaliInsights(input: KundaliInsightsInput): Promise<KundaliInsights>;
  generateMatchInsights(input: MatchInsightsInput): Promise<LocaleBullets>;
  generateTodayInsights(input: TodayInsightsInput): Promise<LocaleBullets>;
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

export const NOOP_LOCALE_BULLETS: LocaleBullets = {
  en: [
    'Your chart highlights steady growth through consistent effort.',
    'Focus on practical next steps rather than sudden leaps.',
    'Keep routines supportive of rest and clear communication.',
  ],
  hi: [
    'आपकी कुंडली निरंतर प्रयास से स्थिर विकास दिखाती है।',
    'अचानक छलांग के बजाय व्यावहारिक अगले कदम पर ध्यान दें।',
    'आराम और स्पष्ट संवाद वाली दिनचर्या बनाए रखें।',
  ],
};

export const NOOP_KUNDALI_INSIGHTS: KundaliInsights = {
  RasiD1: {
    en: [
      'Birth chart (D1): your lagna sets a sincere, grounded tone for how you meet the world.',
      'Sun and Moon themes favour steady habits and clear routines over flashy risk.',
      'Nakshatra colouring suggests you grow through patient focus rather than sudden leaps.',
      'House themes around work and home reward finishing what you already started.',
      'Current dasha energy supports practical next steps and protective daily structure.',
      'Treat these notes as entertainment only; no medical or legal advice is implied.',
    ],
    hi: [
      'जन्म कुंडली (D1): लग्न ईमानदार और स्थिर स्वभाव दिखाता है, जिससे आप दुनिया से मिलते हैं।',
      'सूर्य और चंद्र विषय दिखावटी जोखिम से अधिक नियमित आदतों और स्पष्ट दिनचर्या का समर्थन करते हैं।',
      'नक्षत्र रंग बताता है कि अचानक छलांग से अधिक धैर्यपूर्ण ध्यान से विकास होता है।',
      'कार्य और घर से जुड़े भाव अधूरे काम पूरे करने को पुरस्कृत करते हैं।',
      'वर्तमान दशा ऊर्जा व्यावहारिक अगले कदम और सुरक्षात्मक दैनिक ढाँचे का समर्थन करती है।',
      'ये नोट्स केवल मनोरंजन के लिए हैं; कोई चिकित्सा या कानूनी सलाह नहीं है।',
    ],
  },
  NavamshaD9: {
    en: [
      'Marriage chart (D9): partnership themes favour loyalty, patience, and mutual respect.',
      'Harmony grows when expectations about time, money, and care are spoken plainly.',
      'Shared routines and small rituals matter more than grand one-off gestures.',
      'Dignity and house colouring here point to warmth when both sides feel heard.',
      'Current period energy supports calm conversations over rushed decisions.',
      'Treat these notes as entertainment only; no medical or legal advice is implied.',
    ],
    hi: [
      'विवाह कुंडली (D9): संबंधों में वफादारी, धैर्य और पारस्परिक सम्मान अनुकूल हैं।',
      'समय, धन और देखभाल की अपेक्षाएँ साफ कहने से सामंजस्य बढ़ता है।',
      'बड़े एकमुश्त इशारों से अधिक साझा दिनचर्या और छोटे अनुष्ठान महत्वपूर्ण हैं।',
      'यहाँ की गरिमा और भाव रंग बताते हैं कि दोनों पक्ष सुने जाने पर गर्माहट बढ़ती है।',
      'वर्तमान अवधि जल्दबाजी से अधिक शांत बातचीत का समर्थन करती है।',
      'ये नोट्स केवल मनोरंजन के लिए हैं; कोई चिकित्सा या कानूनी सलाह नहीं है।',
    ],
  },
  DashamamshaD10: {
    en: [
      'Career chart (D10): progress comes through skill, craftsmanship, and consistency.',
      'Visible recognition tends to follow reliable delivery rather than loud self-promotion.',
      'Choose roles that reward deep work and finishing quality over haste.',
      'House and dignity themes here favour mentors, teams, and clear accountability.',
      'Current dasha colouring supports steady career steps and protective focus.',
      'Treat these notes as entertainment only; no medical or legal advice is implied.',
    ],
    hi: [
      'करियर कुंडली (D10): प्रगति कौशल, कारीगरी और निरंतरता से आती है।',
      'शोर भरे प्रचार से अधिक विश्वसनीय काम के बाद पहचान मिलती है।',
      'जल्दबाजी से अधिक गहराई और गुणवत्ता वाले काम चुनें।',
      'यहाँ के भाव और गरिमा विषय गुरु, टीम और स्पष्ट जवाबदेही का समर्थन करते हैं।',
      'वर्तमान दशा रंग स्थिर करियर कदम और सुरक्षात्मक ध्यान का समर्थन करता है।',
      'ये नोट्स केवल मनोरंजन के लिए हैं; कोई चिकित्सा या कानूनी सलाह नहीं है।',
    ],
  },
};

function pickKundaliNoop(chartsPresent: KundaliInsightsInput['chartsPresent']): KundaliInsights {
  const out: KundaliInsights = {};
  for (const key of chartsPresent) {
    const block = NOOP_KUNDALI_INSIGHTS[key];
    if (block) out[key] = block;
  }
  return out;
}

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

function buildKundaliInsightsPrompt(chartsPresent: string[]): string {
  return [
    'You write bilingual Vedic chart insights for a public kiosk (entertainment only).',
    'Use only the provided VedAstro chart JSON. Do not invent signs, houses, dashas, or placements.',
    'Return JSON only.',
    `Include keys only for these charts: ${chartsPresent.join(', ')}.`,
    'Each chart key maps to { "en": string[6|7|8], "hi": string[6|7|8] } with 5–8 bullets (prefer 6–8).',
    'en = English; hi = natural Hindi (Devanagari). Same meaning in both languages.',
    'Each bullet is 1–2 sentences, plain language, no markdown, no medical/legal advice.',
    'Ground bullets in concrete chart factors when present: lagna, sun/moon signs, nakshatra, current dasha, dignity, and house themes.',
    'RasiD1 = Birth/personality; NavamshaD9 = Marriage/partnership; DashamamshaD10 = Career.',
  ].join(' ');
}

function buildMatchInsightsPrompt(): string {
  return [
    'You write short bilingual Gun Milan insights for a kiosk (entertainment only).',
    'Use only the provided score and kuta JSON. Do not invent scores.',
    'Return JSON: { "en": string[3|4], "hi": string[3|4] }.',
    'en = English; hi = natural Hindi (Devanagari). Same meaning.',
    'Each bullet one short sentence, plain language, no markdown.',
  ].join(' ');
}

function buildTodayInsightsPrompt(): string {
  return [
    'You write short bilingual Today/Panchang insights for a kiosk (entertainment only).',
    'Use only the provided panchang and dasha JSON.',
    'Return JSON: { "en": string[3|4], "hi": string[3|4] }.',
    'en = English; hi = natural Hindi (Devanagari). Same meaning.',
    'Each bullet one short sentence, plain language, no markdown.',
  ].join(' ');
}

async function openAiJsonObject(options: {
  apiKey: string;
  model: string;
  logger: Logger;
  fetchImpl: FetchLike;
  system: string;
  user: unknown;
  label: string;
}): Promise<unknown> {
  const startedAt = Date.now();
  options.logger.info({ model: options.model, label: options.label }, '[OpenAI] astrology request started');
  const response = await options.fetchImpl(OPENAI_CHAT_URL, {
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
        { role: 'system', content: options.system },
        { role: 'user', content: JSON.stringify(options.user, null, 2) },
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
        ? String((body as { error?: { message?: unknown } }).error?.message ?? 'OpenAI request failed')
        : 'OpenAI request failed';
    options.logger.warn({ status: response.status, message, label: options.label }, '[OpenAI] astrology failed');
    throw new AppError('llm_failed', message, 502);
  }

  const content =
    body && typeof body === 'object' && body !== null
      ? (body as { choices?: Array<{ message?: { content?: unknown } }> }).choices?.[0]?.message?.content
      : undefined;
  if (typeof content !== 'string' || !content.trim()) {
    throw new AppError('llm_failed', 'OpenAI returned an empty reading', 502);
  }

  try {
    const parsed = parseLlmJson(content);
    options.logger.info(
      { model: options.model, label: options.label, durationMs: Date.now() - startedAt },
      '[OpenAI] astrology insights ready',
    );
    return parsed;
  } catch (error) {
    options.logger.warn({ err: error, preview: content.slice(0, 240) }, '[OpenAI] invalid JSON');
    throw new AppError('llm_failed', 'OpenAI returned an invalid reading payload', 502);
  }
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
    async generateKundaliInsights(input): Promise<KundaliInsights> {
      return pickKundaliNoop(input.chartsPresent);
    },
    async generateMatchInsights(): Promise<LocaleBullets> {
      return NOOP_LOCALE_BULLETS;
    },
    async generateTodayInsights(): Promise<LocaleBullets> {
      return NOOP_LOCALE_BULLETS;
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

    async generateKundaliInsights(input: KundaliInsightsInput): Promise<KundaliInsights> {
      const raw = await openAiJsonObject({
        apiKey: options.apiKey,
        model: options.model,
        logger: options.logger,
        fetchImpl,
        system: buildKundaliInsightsPrompt(input.chartsPresent),
        user: {
          subject: input.subject,
          style: input.style,
          chartsPresent: input.chartsPresent,
          vedastroChart: input.chart,
        },
        label: 'kundali_insights',
      });
      const parsed = kundaliInsightsSchema.parse(raw);
      const filtered: KundaliInsights = {};
      for (const key of input.chartsPresent) {
        const block = parsed[key];
        if (block) filtered[key] = block;
      }
      return Object.keys(filtered).length > 0 ? filtered : pickKundaliNoop(input.chartsPresent);
    },

    async generateMatchInsights(input: MatchInsightsInput): Promise<LocaleBullets> {
      const raw = await openAiJsonObject({
        apiKey: options.apiKey,
        model: options.model,
        logger: options.logger,
        fetchImpl,
        system: buildMatchInsightsPrompt(),
        user: input,
        label: 'match_insights',
      });
      return localeBulletsSchema.parse(raw);
    },

    async generateTodayInsights(input: TodayInsightsInput): Promise<LocaleBullets> {
      const raw = await openAiJsonObject({
        apiKey: options.apiKey,
        model: options.model,
        logger: options.logger,
        fetchImpl,
        system: buildTodayInsightsPrompt(),
        user: input,
        label: 'today_insights',
      });
      return localeBulletsSchema.parse(raw);
    },
  };
}

function notConfiguredClient(): AstrologyLlmClient {
  const fail = async () => {
    throw new AppError('ai_not_configured', 'OpenAI is not configured', 503);
  };
  return {
    generateReading: fail,
    generateKundaliInsights: fail,
    generateMatchInsights: fail,
    generateTodayInsights: fail,
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
  return notConfiguredClient();
}

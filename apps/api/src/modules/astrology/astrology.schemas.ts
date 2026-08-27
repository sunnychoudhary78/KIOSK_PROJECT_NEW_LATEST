import { z } from 'zod';

export const ASTROLOGY_DISCLAIMER =
  'For entertainment only. Not medical, legal, or financial advice.';

/** Detect JPEG / PNG / WebP from magic bytes. Ignores multer's guessed MIME. */
export function sniffPalmImageMime(buffer: Buffer): 'image/jpeg' | 'image/png' | 'image/webp' | undefined {
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return 'image/jpeg';
  }
  if (
    buffer.length >= 8 &&
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47 &&
    buffer[4] === 0x0d &&
    buffer[5] === 0x0a &&
    buffer[6] === 0x1a &&
    buffer[7] === 0x0a
  ) {
    return 'image/png';
  }
  if (
    buffer.length >= 12 &&
    buffer.toString('ascii', 0, 4) === 'RIFF' &&
    buffer.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return 'image/webp';
  }
  return undefined;
}

export type UploadedPalm = {
  originalname: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
};

function isCalendarDate(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) {
    return false;
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  return (
    date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day
  );
}

export const createReadingFieldsSchema = z.object({
  name: z.string().trim().min(1).max(80),
  gender: z.enum(['male', 'female', 'other']),
  dateOfBirth: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'dateOfBirth must be YYYY-MM-DD')
    .refine(isCalendarDate, 'dateOfBirth is not a valid date'),
  birthTime: z.string().regex(/^\d{2}:\d{2}$/, 'birthTime must be HH:mm'),
  birthPlace: z.string().trim().min(2).max(120),
  birthTimeUnknown: z
    .union([z.boolean(), z.string()])
    .optional()
    .transform((value) => value === true || value === 'true' || value === '1'),
});

export type CreateReadingFields = z.infer<typeof createReadingFieldsSchema>;

export const chartSummarySchema = z.object({
  lagna: z.string().optional(),
  sunSign: z.string().optional(),
  moonSign: z.string().optional(),
  nakshatra: z.string().optional(),
  currentDasha: z.string().optional(),
});

export type ChartSummary = z.infer<typeof chartSummarySchema>;

export type CompactPlanet = {
  name: string;
  rasi?: string;
  navamsa?: string;
  nakshatra?: string;
  house?: string;
  dignity?: string;
  retrograde?: boolean;
  conjunct?: string[];
  aspecting?: string[];
};

export type CompactHouse = {
  number: string;
  rasi?: string;
  navamsa?: string;
  nakshatra?: string;
  lord?: string;
  planetsInHouse?: string[];
};

export type CompactVedicChart = ChartSummary & {
  planets: CompactPlanet[];
  houses: CompactHouse[];
};

export const palmInsightSchema = z.object({
  summary: z.string().min(1),
  lifeLine: z.string().min(1),
  heartLine: z.string().min(1),
  headLine: z.string().min(1),
  fateLine: z.string().min(1),
});

export const readingSectionsSchema = z.object({
  overview: z.string().min(1),
  personality: z.string().min(1),
  career: z.string().min(1),
  health: z.string().min(1),
  relationships: z.string().min(1),
  period: z.string().min(1),
});

export const llmReadingSchema = z.object({
  disclaimer: z.string().min(1),
  palm: palmInsightSchema,
  reading: readingSectionsSchema,
});

export type LlmReading = z.infer<typeof llmReadingSchema>;

export type ReadingSubject = {
  name: string;
  gender: CreateReadingFields['gender'];
  dateOfBirth: string;
  birthTime: string;
  birthPlace: string;
  birthTimeUnknown: boolean;
};

export function parseLlmJson(text: string): unknown {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const raw = (fenced?.[1] ?? trimmed).trim();
  return JSON.parse(raw) as unknown;
}

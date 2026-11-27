import { z } from 'zod';

export const ASTROLOGY_CONTACT_KINDS = ['astrologer', 'pandit', 'numerology'] as const;

export const astrologyContactKindSchema = z.enum(ASTROLOGY_CONTACT_KINDS);

const optionalText = (max: number) =>
  z
    .union([z.string().trim().max(max), z.literal(''), z.null()])
    .optional()
    .transform((value) => {
      if (value == null) return null;
      const trimmed = value.trim();
      return trimmed.length > 0 ? trimmed : null;
    });

export const astrologyContactBodySchema = z.object({
  kind: astrologyContactKindSchema,
  name: z.string().trim().min(1).max(120),
  phone: z
    .string()
    .trim()
    .regex(/^\d{10}$/, 'Phone must be a 10-digit mobile number'),
  rating: z.coerce
    .number()
    .min(0)
    .max(5)
    .transform((value) => Math.round(value * 10) / 10),
  sortOrder: z.coerce.number().int().min(0).max(10_000).optional(),
  address: optionalText(240),
  degree: optionalText(120),
  experienceYears: z.preprocess((value) => {
    if (value === '' || value === undefined || value === null) return null;
    const n = Number(value);
    return Number.isFinite(n) ? n : value;
  }, z.number().int().min(0).max(80).nullable()),
});

export type AstrologyContactBody = z.infer<typeof astrologyContactBodySchema>;
export type AstrologyContactKind = z.infer<typeof astrologyContactKindSchema>;

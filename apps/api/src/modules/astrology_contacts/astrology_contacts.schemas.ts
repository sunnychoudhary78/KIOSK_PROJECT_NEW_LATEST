import { z } from 'zod';

export const ASTROLOGY_CONTACT_KINDS = ['astrologer', 'pandit'] as const;

export const astrologyContactKindSchema = z.enum(ASTROLOGY_CONTACT_KINDS);

export const astrologyContactBodySchema = z.object({
  kind: astrologyContactKindSchema,
  name: z.string().trim().min(1).max(120),
  phone: z
    .string()
    .trim()
    .regex(/^\d{10}$/, 'Phone must be a 10-digit mobile number'),
  rating: z
    .number()
    .min(0)
    .max(5)
    .refine((value) => Math.abs(value * 2 - Math.round(value * 2)) < 1e-9, {
      message: 'Rating must be in 0.5 steps',
    }),
  sortOrder: z.number().int().min(0).max(10_000).optional(),
});

export type AstrologyContactBody = z.infer<typeof astrologyContactBodySchema>;
export type AstrologyContactKind = z.infer<typeof astrologyContactKindSchema>;

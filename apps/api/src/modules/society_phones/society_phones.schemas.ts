import { z } from 'zod';

export const SOCIETY_PHONE_COLORS = [
  'blue',
  'green',
  'amber',
  'rose',
  'violet',
  'teal',
  'orange',
  'slate',
] as const;

export type SocietyPhoneColor = (typeof SOCIETY_PHONE_COLORS)[number];

export const addSocietyPhoneSchema = z.object({
  phone: z.string().trim().min(8).max(20),
  name: z.string().trim().max(120).optional().default(''),
  societyName: z.string().trim().max(160).optional().default(''),
  // Kept optional for older clients / imports; UI no longer collects a color tag.
  color: z.enum(SOCIETY_PHONE_COLORS).optional().default('blue'),
});

export function normalizeSocietyColor(raw: unknown): SocietyPhoneColor {
  const value = String(raw ?? '')
    .trim()
    .toLowerCase();
  if ((SOCIETY_PHONE_COLORS as readonly string[]).includes(value)) {
    return value as SocietyPhoneColor;
  }
  return 'blue';
}

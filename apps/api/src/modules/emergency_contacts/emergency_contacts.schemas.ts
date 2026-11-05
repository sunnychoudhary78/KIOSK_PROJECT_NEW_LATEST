import { z } from 'zod';

export const EMERGENCY_ICON_KEYS = [
  'sos',
  'police',
  'fire',
  'ambulance',
  'women',
  'child',
  'disaster',
  'phone',
] as const;

export const emergencyContactBodySchema = z.object({
  name: z.string().trim().min(1).max(120),
  phone: z.string().trim().min(2).max(32),
  icon: z.enum(EMERGENCY_ICON_KEYS).default('phone'),
  sortOrder: z.number().int().min(0).max(10_000).optional(),
});

export type EmergencyContactBody = z.infer<typeof emergencyContactBodySchema>;

import { z } from 'zod';

export const wellBeingPrintModeSchema = z.enum(['oxi', 'temp']);

export const wellBeingPrintBodySchema = z.object({
  mode: wellBeingPrintModeSchema,
  heartRate: z.number().finite().optional(),
  spo2: z.number().finite().optional(),
  tempC: z.number().finite().optional(),
  tempF: z.number().finite().optional(),
  heartRateInterpretation: z.string().trim().max(120).optional(),
  spo2Interpretation: z.string().trim().max(120).optional(),
  temperatureInterpretation: z.string().trim().max(120).optional(),
  measuredAt: z.string().datetime().optional(),
  idempotencyKey: z.string().trim().min(1).max(100).optional(),
});

export type WellBeingPrintBody = z.infer<typeof wellBeingPrintBodySchema>;

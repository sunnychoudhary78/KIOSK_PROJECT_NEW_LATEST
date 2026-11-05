import { z } from 'zod';

export const wellBeingPrintModeSchema = z.enum(['oxi', 'temp']);
export const wellBeingColorModeSchema = z.enum(['bw', 'color']);
export type WellBeingColorMode = z.infer<typeof wellBeingColorModeSchema>;

export const wellBeingPrintBodySchema = z.object({
  mode: wellBeingPrintModeSchema,
  colorMode: wellBeingColorModeSchema,
  heartRate: z.number().finite().optional(),
  spo2: z.number().finite().optional(),
  tempC: z.number().finite().optional(),
  tempF: z.number().finite().optional(),
  heartRateInterpretation: z.string().trim().max(120).optional(),
  spo2Interpretation: z.string().trim().max(120).optional(),
  temperatureInterpretation: z.string().trim().max(120).optional(),
  measuredAt: z.string().datetime().optional(),
  idempotencyKey: z.string().trim().min(1).max(100).optional(),
  phoneProofToken: z.string().trim().min(1).max(800).optional(),
});

export const wellBeingOtpRequestSchema = z.object({
  phone: z.string().trim().min(10).max(20),
});

export const wellBeingOtpVerifySchema = z.object({
  phone: z.string().trim().min(10).max(20),
  otp: z.string().trim().min(4).max(8),
  colorMode: wellBeingColorModeSchema,
});

export type WellBeingPrintBody = z.infer<typeof wellBeingPrintBodySchema>;
export type WellBeingOtpRequestBody = z.infer<typeof wellBeingOtpRequestSchema>;
export type WellBeingOtpVerifyBody = z.infer<typeof wellBeingOtpVerifySchema>;

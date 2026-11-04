import { z } from 'zod';

export const digilockerColorModeSchema = z.enum(['bw', 'color']);
export type DigiLockerColorMode = z.infer<typeof digilockerColorModeSchema>;

export const startDigiLockerSessionSchema = z.object({
  returnUrl: z.string().url().optional(),
});

export const printDigiLockerSchema = z.object({
  documentId: z.string().min(1),
  title: z.string().min(1).max(200).optional(),
  colorMode: digilockerColorModeSchema,
  idempotencyKey: z.string().min(8).max(100).optional(),
  phoneProofToken: z.string().trim().min(1).max(800).optional(),
});

export const digilockerOtpRequestSchema = z.object({
  phone: z.string().trim().min(10).max(20),
});

export const digilockerOtpVerifySchema = z.object({
  phone: z.string().trim().min(10).max(20),
  otp: z.string().trim().min(4).max(8),
  colorMode: digilockerColorModeSchema,
});

export type StartDigiLockerSessionInput = z.infer<typeof startDigiLockerSessionSchema>;
export type PrintDigiLockerInput = z.infer<typeof printDigiLockerSchema>;
export type DigiLockerOtpRequestBody = z.infer<typeof digilockerOtpRequestSchema>;
export type DigiLockerOtpVerifyBody = z.infer<typeof digilockerOtpVerifySchema>;

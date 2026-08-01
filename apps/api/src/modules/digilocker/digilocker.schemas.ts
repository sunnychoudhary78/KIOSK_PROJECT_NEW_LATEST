import { z } from 'zod';

export const startDigiLockerSessionSchema = z.object({
  returnUrl: z.string().url().optional(),
});

export const printDigiLockerSchema = z.object({
  documentId: z.string().min(1),
  title: z.string().min(1).max(200).optional(),
  idempotencyKey: z.string().min(8).max(100).optional(),
});

export type StartDigiLockerSessionInput = z.infer<typeof startDigiLockerSessionSchema>;
export type PrintDigiLockerInput = z.infer<typeof printDigiLockerSchema>;

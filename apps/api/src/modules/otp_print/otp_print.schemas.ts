import { z } from 'zod';

export const printColorModeSchema = z.enum(['bw', 'color']);
export type PrintColorModeInput = z.infer<typeof printColorModeSchema>;

export const redeemOtpSchema = z.object({
  code: z.string().min(4).max(8),
  idempotencyKey: z.string().min(8).max(100).optional(),
});

export type RedeemOtpInput = z.infer<typeof redeemOtpSchema>;

export function parsePrintColorMode(value: unknown): PrintColorModeInput {
  const parsed = printColorModeSchema.safeParse(value);
  return parsed.success ? parsed.data : 'bw';
}

export type UploadedPdf = {
  originalname: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
};

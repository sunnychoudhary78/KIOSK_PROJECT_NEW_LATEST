import { z } from 'zod';

export const redeemOtpSchema = z.object({
  code: z.string().min(4).max(8),
  idempotencyKey: z.string().min(8).max(100).optional(),
});

export type RedeemOtpInput = z.infer<typeof redeemOtpSchema>;

export type UploadedPdf = {
  originalname: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
};

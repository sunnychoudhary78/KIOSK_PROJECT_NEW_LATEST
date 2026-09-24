import { z } from 'zod';

export const otpPrintConfigSchema = z
  .object({
    ttlSeconds: z.number().int().min(60).max(86_400),
    otpLength: z.number().int().min(4).max(8),
    maxPagesPerSession: z.number().int().min(1).max(100),
    maxDocumentsPerSession: z.number().int().min(1).max(20),
    maxVerifyAttempts: z.number().int().min(1).max(20),
    maxFileSizeMb: z.number().int().min(1).max(50),
    freePagesPerSession: z.number().int().min(0).max(100),
    extraPageChargeRupees: z.number().int().min(0).max(1000),
    freeColorPagesPerSession: z.number().int().min(0).max(100).default(0),
    extraColorPageChargeRupees: z.number().int().min(0).max(1000).default(20),
  })
  .refine((value) => value.freePagesPerSession <= value.maxPagesPerSession, {
    message: 'freePagesPerSession cannot exceed maxPagesPerSession',
    path: ['freePagesPerSession'],
  })
  .refine((value) => value.freeColorPagesPerSession <= value.maxPagesPerSession, {
    message: 'freeColorPagesPerSession cannot exceed maxPagesPerSession',
    path: ['freeColorPagesPerSession'],
  });

export const citizenAuthConfigSchema = z.object({
  ttlSeconds: z.number().int().min(60).max(3600),
  otpLength: z.number().int().min(4).max(8),
  maxVerifyAttempts: z.number().int().min(1).max(20),
  requestCooldownSeconds: z.number().int().min(10).max(600),
});

export const updatePlatformSettingSchema = z.object({
  settingValue: z.unknown(),
  description: z.string().max(500).optional(),
  isActive: z.boolean().optional(),
});

export type UpdatePlatformSettingInput = z.infer<typeof updatePlatformSettingSchema>;

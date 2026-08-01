import { z } from 'zod';

export const smsConfigSchema = z.object({
  provider: z.literal('msg91'),
  enabled: z.boolean(),
  auth_key: z.string().max(200),
  sender_id: z.string().max(30),
  flow_id: z.string().max(50),
  otp_var_name: z.string().min(1).max(40),
  message_template: z
    .string()
    .min(1)
    .max(500)
    .refine((v) => v.includes('--'), 'message_template must include -- as the OTP placeholder'),
});

export const otpPrintConfigSchema = z.object({
  ttlSeconds: z.number().int().min(60).max(86_400),
  otpLength: z.number().int().min(4).max(8),
  maxPagesPerSession: z.number().int().min(1).max(100),
  maxDocumentsPerSession: z.number().int().min(1).max(20),
  maxVerifyAttempts: z.number().int().min(1).max(20),
  maxFileSizeMb: z.number().int().min(1).max(50),
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

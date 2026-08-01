import { z } from 'zod';

export const citizenOtpRequestSchema = z.object({
  phone: z.string().min(8).max(20),
});

export const citizenOtpVerifySchema = z.object({
  phone: z.string().min(8).max(20),
  otp: z.string().min(4).max(8),
});

export const adminLoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(128),
});

export const deviceTokenSchema = z.object({
  deviceKey: z.string().min(8),
  deviceSecret: z.string().min(8),
});

export type CitizenOtpRequestInput = z.infer<typeof citizenOtpRequestSchema>;
export type CitizenOtpVerifyInput = z.infer<typeof citizenOtpVerifySchema>;
export type AdminLoginInput = z.infer<typeof adminLoginSchema>;
export type DeviceTokenInput = z.infer<typeof deviceTokenSchema>;

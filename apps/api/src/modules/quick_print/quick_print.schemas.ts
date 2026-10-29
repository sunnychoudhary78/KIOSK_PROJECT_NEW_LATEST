import { z } from 'zod';
import { printColorModeSchema } from '../otp_print/otp_print.schemas.js';

export const verifyQuickPrintPaymentSchema = z.object({
  razorpay_order_id: z.string().min(1),
  razorpay_payment_id: z.string().min(1),
  razorpay_signature: z.string().min(1),
});

export const quickPrintPhoneOtpRequestSchema = z.object({
  phone: z.string().min(8).max(20),
});

export const quickPrintPhoneOtpVerifySchema = z.object({
  phone: z.string().min(8).max(20),
  otp: z.string().min(4).max(8),
});

export const openQuickPrintSupportQuerySchema = z.object({
  message: z.string().trim().min(1).max(500),
  paymentReference: z.string().trim().max(80).optional(),
});

export type VerifyQuickPrintPaymentInput = z.infer<typeof verifyQuickPrintPaymentSchema>;
export type QuickPrintPhoneOtpRequestInput = z.infer<typeof quickPrintPhoneOtpRequestSchema>;
export type QuickPrintPhoneOtpVerifyInput = z.infer<typeof quickPrintPhoneOtpVerifySchema>;
export { printColorModeSchema };

import { z } from 'zod';
import { printColorModeSchema } from '../otp_print/otp_print.schemas.js';

export const verifyQuickPrintPaymentSchema = z.object({
  razorpay_order_id: z.string().min(1),
  razorpay_payment_id: z.string().min(1),
  razorpay_signature: z.string().min(1),
});

export type VerifyQuickPrintPaymentInput = z.infer<typeof verifyQuickPrintPaymentSchema>;
export { printColorModeSchema };

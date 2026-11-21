import { z } from 'zod';

export const createRazorpayOrderSchema = z.object({
  challengeId: z.string().uuid(),
});

export const verifyRazorpayPaymentSchema = z.object({
  razorpay_order_id: z.string().min(1),
  razorpay_payment_id: z.string().min(1),
  razorpay_signature: z.string().min(1),
});

export const openSupportQuerySchema = z.object({
  challengeId: z.string().uuid(),
  message: z.string().trim().min(1).max(500),
  paymentReference: z.string().trim().max(80).optional(),
});

export const supportQueryChallengeQuerySchema = z.object({
  challengeId: z.string().uuid(),
});

export const listSupportQueriesQuerySchema = z.object({
  status: z.enum(['open', 'resolved']).optional(),
  source: z.enum(['payment', 'print', 'kiosk']).optional(),
});

export const openKioskSupportQuerySchema = z.object({
  category: z.enum(['print', 'charging', 'sensors', 'payment', 'other']),
  message: z
    .string()
    .trim()
    .min(1, 'Message is required')
    .max(500, 'Message must be 500 characters or fewer'),
  phone: z
    .string({ required_error: 'Phone is required' })
    .trim()
    .min(1, 'Phone is required')
    .max(20)
    .refine((value) => {
      const digits = value.replace(/\D/g, '');
      if (digits.length === 10) return /^[6-9]\d{9}$/.test(digits);
      if (digits.length === 12 && digits.startsWith('91')) {
        return /^[6-9]\d{9}$/.test(digits.slice(2));
      }
      if (digits.length === 11 && digits.startsWith('0')) {
        return /^[6-9]\d{9}$/.test(digits.slice(1));
      }
      return false;
    }, 'Enter a valid 10-digit mobile number'),
});

export const resolveSupportQuerySchema = z.object({
  resolution: z.enum(['reprinted', 'refunded', 'no_action']),
});

const paymentServiceValues = [
  'otp_print',
  'quick_print',
  'digilocker_print',
  'well_being_print',
  'astrology_print',
  'unknown',
] as const;

const dateOnly = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const listPaymentsQuerySchema = z.object({
  status: z
    .enum(['PENDING', 'PAID', 'FAILED', 'EXPIRED', 'CANCELLED', 'all'])
    .optional(),
  service: z.enum([...paymentServiceValues, 'all']).optional(),
  deviceId: z.string().uuid().optional(),
  from: dateOnly.optional(),
  to: dateOnly.optional(),
  q: z.string().trim().max(80).optional(),
  limit: z.coerce.number().int().min(1).max(500).optional(),
});

export const paymentsSummaryQuerySchema = listPaymentsQuerySchema.omit({ limit: true });

export type CreateRazorpayOrderInput = z.infer<typeof createRazorpayOrderSchema>;
export type VerifyRazorpayPaymentInput = z.infer<typeof verifyRazorpayPaymentSchema>;
export type OpenSupportQueryInput = z.infer<typeof openSupportQuerySchema>;
export type OpenKioskSupportQueryInput = z.infer<typeof openKioskSupportQuerySchema>;
export type ListSupportQueriesQuery = z.infer<typeof listSupportQueriesQuerySchema>;
export type ResolveSupportQueryInput = z.infer<typeof resolveSupportQuerySchema>;
export type ListPaymentsQuery = z.infer<typeof listPaymentsQuerySchema>;
export type PaymentsSummaryQuery = z.infer<typeof paymentsSummaryQuerySchema>;
export type PaymentServiceCode = (typeof paymentServiceValues)[number];

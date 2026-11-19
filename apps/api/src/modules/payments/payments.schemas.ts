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
  message: z.string().trim().min(1).max(500),
  phone: z
    .string()
    .trim()
    .max(20)
    .regex(/^[0-9+\-\s]*$/, 'Phone must be digits')
    .optional(),
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

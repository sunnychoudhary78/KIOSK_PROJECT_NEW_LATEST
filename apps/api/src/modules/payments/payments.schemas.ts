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
  source: z.enum(['payment', 'print']).optional(),
});

export const resolveSupportQuerySchema = z.object({
  resolution: z.enum(['reprinted', 'refunded', 'no_action']),
});

export type CreateRazorpayOrderInput = z.infer<typeof createRazorpayOrderSchema>;
export type VerifyRazorpayPaymentInput = z.infer<typeof verifyRazorpayPaymentSchema>;
export type OpenSupportQueryInput = z.infer<typeof openSupportQuerySchema>;
export type ListSupportQueriesQuery = z.infer<typeof listSupportQueriesQuerySchema>;
export type ResolveSupportQueryInput = z.infer<typeof resolveSupportQuerySchema>;

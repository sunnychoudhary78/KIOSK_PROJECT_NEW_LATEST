import crypto from 'node:crypto';
import Razorpay from 'razorpay';
import type { AppConfig } from '../../config/index.js';
import { AppError } from '../../shared/errors.js';

export type RazorpayOrderInput = {
  amountPaise: number;
  currency?: string;
  receipt: string;
  notes?: Record<string, string>;
};

export type CreatedRazorpayOrder = {
  id: string;
  amount: number;
  currency: string;
};

export function amountToPaise(amountRupees: number): number {
  return Math.round(amountRupees * 100);
}

export function verifyPaymentSignature(input: {
  orderId: string;
  paymentId: string;
  signature: string;
  keySecret: string;
}): boolean {
  const expected = crypto
    .createHmac('sha256', input.keySecret)
    .update(`${input.orderId}|${input.paymentId}`)
    .digest('hex');
  return timingSafeEqualHex(expected, input.signature);
}

export function verifyWebhookSignature(input: {
  rawBody: Buffer | string;
  signature: string;
  webhookSecret: string;
}): boolean {
  const body = typeof input.rawBody === 'string' ? input.rawBody : input.rawBody.toString('utf8');
  const expected = crypto.createHmac('sha256', input.webhookSecret).update(body).digest('hex');
  return timingSafeEqualHex(expected, input.signature);
}

function timingSafeEqualHex(expectedHex: string, actualHex: string): boolean {
  const expected = Buffer.from(expectedHex, 'utf8');
  const actual = Buffer.from(actualHex, 'utf8');
  if (expected.length !== actual.length) {
    return false;
  }
  return crypto.timingSafeEqual(expected, actual);
}

export class RazorpayClient {
  constructor(private readonly config: AppConfig) {}

  getKeyId(): string {
    const keyId = this.config.razorpay.keyId;
    if (!keyId) {
      throw new AppError('payments_not_configured', 'Razorpay is not configured', 503);
    }
    return keyId;
  }

  getKeySecret(): string {
    const secret = this.config.razorpay.keySecret;
    if (!secret) {
      throw new AppError('payments_not_configured', 'Razorpay is not configured', 503);
    }
    return secret;
  }

  getWebhookSecret(): string {
    const secret = this.config.razorpay.webhookSecret;
    if (!secret) {
      throw new AppError('payments_not_configured', 'Razorpay webhook is not configured', 503);
    }
    return secret;
  }

  async createOrder(input: RazorpayOrderInput): Promise<CreatedRazorpayOrder> {
    const client = new Razorpay({
      key_id: this.getKeyId(),
      key_secret: this.getKeySecret(),
    });
    const createOrder = client.orders.create.bind(client.orders) as (params: {
      amount: number;
      currency: string;
      receipt: string;
      payment_capture: 1;
      notes?: Record<string, string>;
    }) => Promise<{ id: string; amount: number | string; currency: string }>;
    const order = await createOrder({
      amount: input.amountPaise,
      currency: input.currency ?? 'INR',
      receipt: input.receipt.slice(0, 40),
      payment_capture: 1,
      notes: input.notes,
    });
    return {
      id: String(order.id),
      amount: Number(order.amount),
      currency: String(order.currency),
    };
  }
}

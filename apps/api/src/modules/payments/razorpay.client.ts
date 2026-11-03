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

  private client() {
    return new Razorpay({
      key_id: this.getKeyId(),
      key_secret: this.getKeySecret(),
    });
  }

  async createOrder(input: RazorpayOrderInput): Promise<CreatedRazorpayOrder> {
    const client = this.client();
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

  async createUpiQrCode(input: {
    amountPaise: number;
    description: string;
    closeByUnix: number;
    name?: string;
    notes?: Record<string, string>;
  }): Promise<{ id: string; imageUrl: string; closeBy: number }> {
    const qrApi = (this.client() as unknown as {
      qrCode: {
        create: (params: Record<string, unknown>) => Promise<{
          id: string;
          image_url?: string;
          close_by?: number;
        }>;
      };
    }).qrCode;

    const qr = await qrApi.create({
      type: 'upi_qr',
      usage: 'single_use',
      fixed_amount: true,
      payment_amount: input.amountPaise,
      description: input.description.slice(0, 512),
      name: (input.name ?? 'Kundali color print').slice(0, 40),
      close_by: input.closeByUnix,
      notes: input.notes,
    });

    const imageUrl = qr.image_url ? String(qr.image_url) : '';
    if (!imageUrl) {
      throw new AppError('payments_not_configured', 'Razorpay did not return a QR image URL', 502);
    }

    return {
      id: String(qr.id),
      imageUrl,
      closeBy: Number(qr.close_by ?? input.closeByUnix),
    };
  }

  async closeQrCode(qrCodeId: string): Promise<void> {
    const qrApi = (this.client() as unknown as {
      qrCode: { close: (id: string) => Promise<unknown> };
    }).qrCode;
    try {
      await qrApi.close(qrCodeId);
    } catch {
      // Already closed / paid — ignore.
    }
  }
}

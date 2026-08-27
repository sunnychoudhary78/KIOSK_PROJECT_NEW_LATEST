import crypto from 'node:crypto';
import { describe, expect, it } from 'vitest';
import {
  verifyPaymentSignature,
  verifyWebhookSignature,
} from '../src/modules/payments/razorpay.client.js';

describe('Razorpay HMAC helpers', () => {
  const secret = 'test_key_secret';

  it('accepts a valid payment signature', () => {
    const orderId = 'order_abc';
    const paymentId = 'pay_xyz';
    const signature = crypto.createHmac('sha256', secret).update(`${orderId}|${paymentId}`).digest('hex');
    expect(
      verifyPaymentSignature({
        orderId,
        paymentId,
        signature,
        keySecret: secret,
      }),
    ).toBe(true);
  });

  it('rejects a tampered payment signature', () => {
    expect(
      verifyPaymentSignature({
        orderId: 'order_abc',
        paymentId: 'pay_xyz',
        signature: 'deadbeef',
        keySecret: secret,
      }),
    ).toBe(false);
  });

  it('accepts a valid webhook signature over the raw body', () => {
    const rawBody = Buffer.from('{"event":"payment.captured"}', 'utf8');
    const signature = crypto.createHmac('sha256', 'whsec').update(rawBody).digest('hex');
    expect(
      verifyWebhookSignature({
        rawBody,
        signature,
        webhookSecret: 'whsec',
      }),
    ).toBe(true);
  });

  it('rejects webhook signatures of different length without throwing', () => {
    expect(
      verifyWebhookSignature({
        rawBody: '{"event":"payment.captured"}',
        signature: 'short',
        webhookSecret: 'whsec',
      }),
    ).toBe(false);
  });
});

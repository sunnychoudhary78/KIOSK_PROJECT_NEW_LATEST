import {
  OtpChallengeStatus,
  PaymentStatus,
  SupportQueryStatus,
} from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import { AppError } from '../src/shared/errors.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import type { OtpPrintService } from '../src/modules/otp_print/otp_print.service.js';
import { PaymentsService } from '../src/modules/payments/payments.service.js';
import type { RazorpayClient } from '../src/modules/payments/razorpay.client.js';

const userId = '22222222-2222-2222-2222-222222222222';
const challengeId = '11111111-1111-1111-1111-111111111111';
const paymentId = '33333333-3333-3333-3333-333333333333';
const queryId = '44444444-4444-4444-4444-444444444444';

function paymentRow(status: PaymentStatus = PaymentStatus.FAILED) {
  return {
    id: paymentId,
    challengeId,
    quickPrintSessionId: null,
    userId,
    status,
    pageCount: 8,
    freePages: 5,
    extraPages: 3,
    amountPaise: 3000,
    currency: 'INR',
    razorpayOrderId: 'order_test_1',
    razorpayPaymentId: null,
    razorpaySignature: null,
    failureReason: 'payment.failed',
    paidAt: null as Date | null,
    expiresAt: new Date('2026-10-27T12:00:00.000Z'),
    createdAt: new Date('2026-10-27T10:00:00.000Z'),
    updatedAt: new Date('2026-10-27T10:00:00.000Z'),
  };
}

function makeService(
  db: unknown,
  otpPrint: Partial<OtpPrintService> = {},
) {
  const audit = { record: vi.fn(async () => undefined) };
  const service = new PaymentsService(
    db as DbClient,
    {} as AppConfig,
    {} as RazorpayClient,
    otpPrint as OtpPrintService,
    audit as unknown as AuditService,
  );
  return { service, audit };
}

describe('payment support notes', () => {
  it('returns the same open note when the citizen sends again', async () => {
    let stored: Record<string, unknown> | null = null;
    const db = {
      otpChallenge: {
        findUnique: vi.fn(async () => ({
          id: challengeId,
          userId,
          status: OtpChallengeStatus.awaiting_payment,
          user: { phone: '9876543210' },
          payment: { ...paymentRow(), supportQuery: stored },
        })),
      },
      supportQuery: {
        create: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
          stored = {
            id: queryId,
            createdAt: new Date('2026-10-27T10:05:00.000Z'),
            resolvedAt: null,
            phone: data.phone,
            message: data.message,
            status: data.status,
            razorpayOrderId: data.razorpayOrderId,
            amountPaise: data.amountPaise,
            failureReason: data.failureReason,
            paymentId: data.paymentId,
            userId: data.userId,
          };
          return stored;
        }),
      },
    };
    const { service, audit } = makeService(db);

    const first = await service.openSupportQuery(userId, {
      challengeId,
      message: 'Money left my account',
    });
    const second = await service.openSupportQuery(userId, {
      challengeId,
      message: 'Sending again',
    });

    expect(first.id).toBe(queryId);
    expect(second.id).toBe(queryId);
    expect(second.message).toBe('Money left my account');
    expect(db.supportQuery.create).toHaveBeenCalledTimes(1);
    expect(audit.record).toHaveBeenCalledTimes(1);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'support_query.opened' }),
    );
  });

  it('rejects a note after the OTP has been sent', async () => {
    const db = {
      otpChallenge: {
        findUnique: vi.fn(async () => ({
          id: challengeId,
          userId,
          status: OtpChallengeStatus.pending,
          user: { phone: '9876543210' },
          payment: { ...paymentRow(PaymentStatus.PAID), supportQuery: null },
        })),
      },
    };
    const { service } = makeService(db);

    await expect(
      service.openSupportQuery(userId, { challengeId, message: 'Still waiting' }),
    ).rejects.toMatchObject({ code: 'payment_already_settled' } satisfies Partial<AppError>);
  });

  it('resolves an open note when the payment is fulfilled', async () => {
    const open = {
      id: queryId,
      paymentId,
      userId,
      phone: '9876543210',
      message: 'Money left my account',
      status: SupportQueryStatus.open,
      razorpayOrderId: 'order_test_1',
      amountPaise: 3000,
      failureReason: 'payment.failed',
      createdAt: new Date('2026-10-27T10:05:00.000Z'),
      resolvedAt: null as Date | null,
    };
    const db = {
      payment: {
        findUnique: vi.fn(async () => paymentRow(PaymentStatus.PENDING)),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          ...paymentRow(PaymentStatus.PAID),
          ...data,
          paidAt: new Date('2026-10-27T10:06:00.000Z'),
        })),
      },
      supportQuery: {
        findUnique: vi.fn(async () => open),
        update: vi.fn(async ({ data }: { data: { status: SupportQueryStatus; resolvedAt: Date } }) => ({
          ...open,
          ...data,
        })),
      },
    };
    const otpPrint = {
      issueOtpAndNotify: vi.fn(async () => ({ issued: true, alreadyIssued: false })),
    };
    const { service, audit } = makeService(db, otpPrint);

    const result = await service.fulfillRazorpayPayment({
      razorpayOrderId: 'order_test_1',
      razorpayPaymentId: 'pay_1',
      allowExpiredFulfillment: true,
    });

    expect(result.otpSent).toBe(true);
    expect(db.supportQuery.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: queryId },
        data: expect.objectContaining({ status: SupportQueryStatus.resolved }),
      }),
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'support_query.resolved',
        principalType: 'system',
      }),
    );
  });
});

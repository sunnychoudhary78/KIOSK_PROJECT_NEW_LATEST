import {
  OtpChallengeStatus,
  PaymentStatus,
  QuickPrintSessionStatus,
  SupportQueryStatus,
  SupportResolution,
} from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import { AppError } from '../src/shared/errors.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import type { OtpPrintService } from '../src/modules/otp_print/otp_print.service.js';
import { PaymentsService } from '../src/modules/payments/payments.service.js';
import { resolveSupportQuerySchema } from '../src/modules/payments/payments.schemas.js';
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
        updateMany: vi.fn(async () => ({ count: 1 })),
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
    expect(db.supportQuery.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: queryId, status: SupportQueryStatus.open },
        data: expect.objectContaining({
          status: SupportQueryStatus.resolved,
          resolution: SupportResolution.otp_sent,
        }),
      }),
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'support_query.resolved',
        principalType: 'system',
        metadata: expect.objectContaining({
          automatic: true,
          resolution: SupportResolution.otp_sent,
        }),
      }),
    );
  });

  it('stores a payment reference and the kiosk on a new note', async () => {
    const db = {
      otpChallenge: {
        findUnique: vi.fn(async () => ({
          id: challengeId,
          userId,
          status: OtpChallengeStatus.awaiting_payment,
          user: { phone: '9876543210' },
          device: { name: 'Gate Kiosk' },
          payment: { ...paymentRow(), supportQuery: null },
        })),
      },
      supportQuery: {
        create: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          id: queryId,
          createdAt: new Date('2026-10-27T10:05:00.000Z'),
          resolvedAt: null,
          printJobId: null,
          resolution: null,
          ...data,
        })),
      },
    };
    const { service } = makeService(db);
    const note = await service.openSupportQuery(userId, {
      challengeId,
      message: 'Money left my account',
      paymentReference: ' UPI123 ',
    });
    expect(note.paymentReference).toBe('UPI123');
    expect(note.kioskName).toBe('Gate Kiosk');
    expect(note.challengeId).toBe(challengeId);
    expect(note.phone).toBe('9876543210');
  });

  it('lists print context and the unfiltered open count', async () => {
    const createdAt = new Date('2026-10-27T10:05:00.000Z');
    const db = {
      supportQuery: {
        findMany: vi.fn(async () => [
          {
            id: queryId,
            paymentId: null,
            printJobId: '55555555-5555-5555-5555-555555555555',
            phone: '',
            message: 'Visitor says the pages were not received.',
            status: SupportQueryStatus.open,
            razorpayOrderId: null,
            amountPaise: 0,
            failureReason: null,
            paymentReference: null,
            resolution: null,
            createdAt,
            resolvedAt: null,
            payment: null,
            printJob: {
              status: 'failed',
              pagesExpected: 4,
              pagesReported: 1,
              errorMessage: 'paper out',
              device: { name: 'Gate Kiosk' },
              otpChallenge: { user: { phone: '9000000000' } },
              quickPrintSession: null,
            },
          },
        ]),
        count: vi.fn(async () => 3),
      },
    };
    const { service } = makeService(db);
    const result = await service.listSupportQueries({ status: 'open', source: 'print' });
    expect(db.supportQuery.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { status: 'open', printJobId: { not: null } },
      }),
    );
    expect(db.supportQuery.count).toHaveBeenCalledWith({
      where: { status: SupportQueryStatus.open },
    });
    expect(result.openCount).toBe(3);
    expect(result.items[0]).toMatchObject({
      source: 'print',
      kioskName: 'Gate Kiosk',
      phone: '9000000000',
      printJobStatus: 'failed',
      pagesExpected: 4,
      pagesReported: 1,
      printJobError: 'paper out',
    });
  });

  it('requires a resolution when staff close a note', async () => {
    const open = {
      id: queryId,
      paymentId,
      printJobId: null,
      phone: '9876543210',
      message: 'Money left my account',
      status: SupportQueryStatus.open,
      razorpayOrderId: 'order_test_1',
      amountPaise: 3000,
      failureReason: 'payment.failed',
      paymentReference: 'UPI123',
      resolution: null,
      createdAt: new Date('2026-10-27T10:05:00.000Z'),
      resolvedAt: null as Date | null,
      payment: { ...paymentRow(), challenge: null, quickPrintSession: null },
      printJob: null,
    };
    const stored = { ...open };
    const db = {
      supportQuery: {
        findUnique: vi.fn(async () => ({
          ...stored,
          payment: open.payment,
          printJob: null,
        })),
        updateMany: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
          Object.assign(stored, data);
          return { count: 1 };
        }),
      },
    };
    const { service, audit } = makeService(db);
    const resolved = await service.resolveSupportQuery(
      queryId,
      'admin-1',
      SupportResolution.refunded,
    );
    expect(resolved.resolution).toBe(SupportResolution.refunded);
    expect(resolved.status).toBe(SupportQueryStatus.resolved);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        metadata: expect.objectContaining({ resolution: SupportResolution.refunded }),
      }),
    );
  });

  it('resends the OTP for a paid note and resolves it', async () => {
    const note: Record<string, unknown> = {
      id: queryId,
      paymentId,
      printJobId: null,
      phone: '9876543210',
      message: 'No OTP',
      status: SupportQueryStatus.open,
      razorpayOrderId: 'order_test_1',
      amountPaise: 3000,
      failureReason: null,
      paymentReference: null,
      resolution: null,
      createdAt: new Date('2026-10-27T10:05:00.000Z'),
      resolvedAt: null,
      payment: {
        ...paymentRow(PaymentStatus.PAID),
        challenge: null,
        quickPrintSession: null,
      },
      printJob: null,
    };
    const db = {
      supportQuery: {
        findUnique: vi.fn(async () => note),
        updateMany: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
          Object.assign(note, data);
          return { count: 1 };
        }),
      },
    };
    const otpPrint = {
      issueOtpAndNotify: vi.fn(async () => ({ issued: true, alreadyIssued: false })),
    };
    const { service } = makeService(db, otpPrint);
    const result = await service.resendSupportOtp(queryId, 'admin-1');
    expect(otpPrint.issueOtpAndNotify).toHaveBeenCalledWith(challengeId, undefined);
    expect(result.status).toBe(SupportQueryStatus.resolved);
    expect(result.resolution).toBe(SupportResolution.otp_sent);
  });

  it('keeps the first resolution when a second close loses the race', async () => {
    const open = {
      id: queryId,
      paymentId,
      printJobId: null,
      phone: '9876543210',
      message: 'Money left my account',
      status: SupportQueryStatus.open,
      razorpayOrderId: 'order_test_1',
      amountPaise: 3000,
      failureReason: null,
      paymentReference: null,
      resolution: null as SupportResolution | null,
      createdAt: new Date('2026-10-27T10:05:00.000Z'),
      resolvedAt: null as Date | null,
      payment: { ...paymentRow(PaymentStatus.PAID), challenge: null, quickPrintSession: null },
      printJob: null,
    };
    let reads = 0;
    const db = {
      supportQuery: {
        findUnique: vi.fn(async () => {
          reads += 1;
          if (reads === 1) return open;
          return {
            ...open,
            status: SupportQueryStatus.resolved,
            resolution: SupportResolution.otp_sent,
            resolvedAt: new Date('2026-10-27T10:06:00.000Z'),
          };
        }),
        updateMany: vi.fn(async () => ({ count: 0 })),
      },
    };
    const { service, audit } = makeService(db);
    const result = await service.resolveSupportQuery(
      queryId,
      'admin-1',
      SupportResolution.refunded,
    );
    expect(result.resolution).toBe(SupportResolution.otp_sent);
    expect(result.status).toBe(SupportQueryStatus.resolved);
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('rejects otp_sent as a staff resolution', () => {
    expect(resolveSupportQuerySchema.safeParse({ resolution: 'otp_sent' }).success).toBe(false);
    expect(resolveSupportQuerySchema.safeParse({ resolution: 'refunded' }).success).toBe(true);
  });
});

describe('quick print support notes', () => {
  const sessionId = '55555555-5555-5555-5555-555555555555';

  function sessionRow(
    status: QuickPrintSessionStatus,
    supportQuery: Record<string, unknown> | null,
  ) {
    return {
      id: sessionId,
      status,
      deviceId: 'device-1',
      verifiedPhone: '9876543210',
      device: { name: 'Gate Kiosk' },
      payment: {
        ...paymentRow(),
        quickPrintSessionId: sessionId,
        challengeId: null,
        supportQuery,
      },
    };
  }

  it('keeps the first note when the visitor sends again', async () => {
    let stored: Record<string, unknown> | null = null;
    const db = {
      quickPrintSession: {
        findUnique: vi.fn(async () => sessionRow(QuickPrintSessionStatus.awaiting_payment, stored)),
      },
      supportQuery: {
        create: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
          stored = {
            id: queryId,
            createdAt: new Date('2026-10-27T10:05:00.000Z'),
            resolvedAt: null,
            printJobId: null,
            resolution: null,
            phone: data.phone,
            message: data.message,
            status: data.status,
            paymentReference: data.paymentReference,
            razorpayOrderId: data.razorpayOrderId,
            amountPaise: data.amountPaise,
            failureReason: data.failureReason,
          };
          return stored;
        }),
      },
    };
    const { service } = makeService(db);
    const first = await service.openQuickPrintSupportQuery('guest-token', {
      message: 'Money left my account',
      paymentReference: 'BANK9',
    });
    const second = await service.openQuickPrintSupportQuery('guest-token', {
      message: 'Sending again',
    });
    expect(first.id).toBe(queryId);
    expect(first.paymentReference).toBe('BANK9');
    expect(first.kioskName).toBe('Gate Kiosk');
    expect(second.message).toBe('Money left my account');
    expect(db.supportQuery.create).toHaveBeenCalledTimes(1);
  });

  it('rejects a note after the session is ready', async () => {
    const db = {
      quickPrintSession: {
        findUnique: vi.fn(async () => sessionRow(QuickPrintSessionStatus.ready, null)),
      },
    };
    const { service } = makeService(db);
    await expect(
      service.openQuickPrintSupportQuery('guest-token', { message: 'Too late' }),
    ).rejects.toMatchObject({ code: 'payment_already_settled' } satisfies Partial<AppError>);
  });

  it('resolves the note when the paid session becomes ready', async () => {
    const open = {
      id: queryId,
      paymentId,
      printJobId: null,
      phone: '9876543210',
      message: 'Money left my account',
      status: SupportQueryStatus.open,
      razorpayOrderId: 'order_test_1',
      amountPaise: 3000,
      failureReason: null,
      createdAt: new Date('2026-10-27T10:05:00.000Z'),
      resolvedAt: null as Date | null,
    };
    const db = {
      payment: {
        findUnique: vi.fn(async () => ({
          ...paymentRow(PaymentStatus.PENDING),
          quickPrintSessionId: sessionId,
          challengeId: null,
        })),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          ...paymentRow(PaymentStatus.PAID),
          quickPrintSessionId: sessionId,
          challengeId: null,
          ...data,
          paidAt: new Date('2026-10-27T10:06:00.000Z'),
        })),
      },
      quickPrintSession: {
        findUnique: vi.fn(async () => ({
          id: sessionId,
          deviceId: 'device-1',
          status: QuickPrintSessionStatus.awaiting_payment,
          expiresAt: new Date('2026-10-27T12:00:00.000Z'),
        })),
        update: vi.fn(async () => ({})),
      },
      supportQuery: {
        findUnique: vi.fn(async () => open),
        updateMany: vi.fn(async () => ({ count: 1 })),
      },
    };
    const { service } = makeService(db);
    const result = await service.fulfillRazorpayPayment({
      razorpayOrderId: 'order_test_1',
      razorpayPaymentId: 'pay_1',
      allowExpiredFulfillment: true,
    });
    expect(result.sessionReady).toBe(true);
    expect(db.supportQuery.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: queryId, status: SupportQueryStatus.open },
        data: expect.objectContaining({
          status: SupportQueryStatus.resolved,
          resolution: SupportResolution.session_ready,
        }),
      }),
    );
  });
});

import {
  OtpChallengeStatus,
  PaymentStatus,
  Prisma,
  QuickPrintSessionStatus,
  SupportQueryStatus,
  SupportResolution,
  type SupportQuery,
} from '@prisma/client';
import type { AppConfig } from '../../config/index.js';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError, isAppError } from '../../shared/errors.js';
import { hashSecret } from '../../shared/otp.js';
import type { AuditService } from '../audit/audit.service.js';
import { OtpPrintService } from '../otp_print/otp_print.service.js';
import {
  RazorpayClient,
  verifyPaymentSignature,
  verifyWebhookSignature,
} from './razorpay.client.js';
import type {
  CreateRazorpayOrderInput,
  OpenSupportQueryInput,
  VerifyRazorpayPaymentInput,
} from './payments.schemas.js';

const supportQueryInclude = {
  payment: {
    include: {
      challenge: { include: { device: true, user: true } },
      quickPrintSession: { include: { device: true } },
    },
  },
  printJob: {
    include: {
      device: true,
      otpChallenge: { include: { user: true } },
      quickPrintSession: true,
    },
  },
} satisfies Prisma.SupportQueryInclude;

type SupportQueryRecord = Prisma.SupportQueryGetPayload<{ include: typeof supportQueryInclude }>;

type SupportPublicContext = {
  paymentStatus: PaymentStatus | null;
  kioskName: string | null;
  fallbackPhone: string | null;
  challengeId: string | null;
  printJobStatus: string | null;
  pagesExpected: number | null;
  pagesReported: number | null;
  printJobError: string | null;
};

function cleanPaymentReference(value?: string | null) {
  const trimmed = value?.trim() ?? '';
  return trimmed.length > 0 ? trimmed : null;
}

function supportContextFromRecord(row: SupportQueryRecord): SupportPublicContext {
  const payment = row.payment;
  const job = row.printJob;
  const kioskName =
    payment?.challenge?.device?.name ??
    payment?.quickPrintSession?.device?.name ??
    job?.device?.name ??
    null;
  const fallbackPhone =
    payment?.challenge?.user?.phone ??
    payment?.quickPrintSession?.verifiedPhone ??
    job?.otpChallenge?.user?.phone ??
    job?.quickPrintSession?.verifiedPhone ??
    null;
  return {
    paymentStatus: payment?.status ?? null,
    kioskName,
    fallbackPhone,
    challengeId: payment?.challengeId ?? null,
    printJobStatus: job ? String(job.status) : null,
    pagesExpected: job?.pagesExpected ?? null,
    pagesReported: job?.pagesReported ?? null,
    printJobError: job?.errorMessage ?? null,
  };
}

type WebhookPayload = {
  event?: string;
  payload?: {
    payment?: {
      entity?: {
        id?: string;
        order_id?: string;
        amount?: number;
        status?: string;
      };
    };
  };
};

export class PaymentsService {
  constructor(
    private readonly db: DbClient,
    private readonly config: AppConfig,
    private readonly razorpay: RazorpayClient,
    private readonly otpPrint: OtpPrintService,
    private readonly audit: AuditService,
  ) {}

  async createCheckoutOrder(userId: string, input: CreateRazorpayOrderInput, correlationId?: string) {
    const challenge = await this.db.otpChallenge.findUnique({
      where: { id: input.challengeId },
      include: { payment: true },
    });
    if (!challenge || challenge.userId !== userId) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    if (!challenge.payment) {
      throw new AppError('payment_not_required', 'This print session does not require payment', 400);
    }

    if (challenge.payment.status === PaymentStatus.PAID) {
      const issued = await this.otpPrint.issueOtpAndNotify(challenge.id, correlationId);
      return {
        alreadyPaid: true,
        otpSent: issued.alreadyIssued || issued.issued,
        payment: this.toPublicPayment(challenge.payment),
        razorpay_key_id: this.razorpay.getKeyId(),
      };
    }

    if (
      challenge.status !== OtpChallengeStatus.awaiting_payment ||
      challenge.payment.status === PaymentStatus.EXPIRED ||
      challenge.payment.status === PaymentStatus.CANCELLED
    ) {
      throw new AppError('payment_unavailable', 'This print session cannot be paid', 400);
    }

    if (challenge.expiresAt.getTime() < Date.now() && challenge.payment.status === PaymentStatus.PENDING) {
      await this.db.$transaction([
        this.db.otpChallenge.update({
          where: { id: challenge.id },
          data: { status: OtpChallengeStatus.expired },
        }),
        this.db.payment.update({
          where: { id: challenge.payment.id },
          data: { status: PaymentStatus.EXPIRED },
        }),
      ]);
      throw new AppError('payment_expired', 'Payment window has expired. Upload again.', 400);
    }

    let payment = challenge.payment;
    if (payment.razorpayOrderId && payment.status === PaymentStatus.PENDING) {
      return {
        alreadyPaid: false,
        otpSent: false,
        payment: this.toPublicPayment(payment),
        razorpay_order_id: payment.razorpayOrderId,
        razorpay_key_id: this.razorpay.getKeyId(),
      };
    }

    const order = await this.razorpay.createOrder({
      amountPaise: payment.amountPaise,
      currency: payment.currency,
      receipt: payment.id,
      notes: {
        challenge_id: challenge.id,
        payment_id: payment.id,
        user_id: userId,
      },
    });

    payment = await this.db.payment.update({
      where: { id: payment.id },
      data: {
        status: PaymentStatus.PENDING,
        razorpayOrderId: order.id,
        failureReason: null,
      },
    });

    await this.audit.record({
      action: 'payment.order_created',
      principalType: 'citizen',
      principalId: userId,
      resourceType: 'payment',
      resourceId: payment.id,
      correlationId,
      metadata: { challengeId: challenge.id, razorpayOrderId: order.id, amountPaise: payment.amountPaise },
    });

    return {
      alreadyPaid: false,
      otpSent: false,
      payment: this.toPublicPayment(payment),
      razorpay_order_id: order.id,
      razorpay_key_id: this.razorpay.getKeyId(),
    };
  }

  async verifyCheckoutPayment(
    userId: string,
    input: VerifyRazorpayPaymentInput,
    correlationId?: string,
  ) {
    const payment = await this.db.payment.findUnique({
      where: { razorpayOrderId: input.razorpay_order_id },
    });
    if (!payment || payment.userId !== userId) {
      throw new AppError('not_found', 'Payment not found', 404);
    }

    const valid = verifyPaymentSignature({
      orderId: input.razorpay_order_id,
      paymentId: input.razorpay_payment_id,
      signature: input.razorpay_signature,
      keySecret: this.razorpay.getKeySecret(),
    });
    if (!valid) {
      if (payment.status === PaymentStatus.PENDING) {
        await this.db.payment.update({
          where: { id: payment.id },
          data: { status: PaymentStatus.FAILED, failureReason: 'invalid_signature' },
        });
      }
      throw new AppError('invalid_signature', 'Payment signature verification failed', 400);
    }

    return this.fulfillRazorpayPayment({
      razorpayOrderId: input.razorpay_order_id,
      razorpayPaymentId: input.razorpay_payment_id,
      razorpaySignature: input.razorpay_signature,
      amountPaise: payment.amountPaise,
      allowExpiredFulfillment: true,
      correlationId,
    });
  }

  async fulfillRazorpayPayment(input: {
    razorpayOrderId: string;
    razorpayPaymentId?: string;
    razorpaySignature?: string;
    amountPaise?: number;
    allowExpiredFulfillment: boolean;
    correlationId?: string;
  }) {
    const payment = await this.db.payment.findUnique({
      where: { razorpayOrderId: input.razorpayOrderId },
    });
    if (!payment) {
      throw new AppError('not_found', 'Payment not found', 404);
    }

    if (
      input.amountPaise != null &&
      Number(input.amountPaise) !== payment.amountPaise
    ) {
      throw new AppError('amount_mismatch', 'Captured amount does not match the order', 400);
    }

    if (payment.status === PaymentStatus.PAID) {
    if (payment.quickPrintSessionId) {
      await this.markQuickPrintReady(payment.quickPrintSessionId, payment.id, input.correlationId);
      return {
        alreadyPaid: true,
          otpSent: false,
          sessionReady: true,
          payment: this.toPublicPayment(payment),
        };
      }
      if (!payment.challengeId) {
        throw new AppError('not_found', 'Payment is not linked to a print session', 404);
      }
      const issued = await this.otpPrint.issueOtpAndNotify(payment.challengeId, input.correlationId);
      if (issued.issued || issued.alreadyIssued) {
        await this.resolveOpenSupportQuery(
          payment.id,
          input.correlationId,
          SupportResolution.otp_sent,
        );
      }
      return {
        alreadyPaid: true,
        otpSent: issued.alreadyIssued || issued.issued,
        payment: this.toPublicPayment(payment),
      };
    }

    if (payment.status !== PaymentStatus.PENDING && payment.status !== PaymentStatus.FAILED) {
      throw new AppError('payment_unavailable', 'Payment cannot be fulfilled', 400);
    }

    if (!input.allowExpiredFulfillment && payment.expiresAt.getTime() < Date.now()) {
      await this.db.payment.update({
        where: { id: payment.id },
        data: { status: PaymentStatus.EXPIRED },
      });
      throw new AppError('payment_expired', 'Payment window has expired', 400);
    }

    const updated = await this.db.payment.update({
      where: { id: payment.id },
      data: {
        status: PaymentStatus.PAID,
        razorpayPaymentId: input.razorpayPaymentId ?? payment.razorpayPaymentId,
        razorpaySignature: input.razorpaySignature ?? payment.razorpaySignature,
        paidAt: new Date(),
        failureReason: null,
      },
    });

    await this.audit.record({
      action: 'payment.paid',
      principalType: payment.userId ? 'citizen' : 'system',
      principalId: payment.userId,
      resourceType: 'payment',
      resourceId: payment.id,
      correlationId: input.correlationId,
      metadata: {
        challengeId: payment.challengeId,
        quickPrintSessionId: payment.quickPrintSessionId,
        razorpayOrderId: input.razorpayOrderId,
      },
    });

    if (payment.quickPrintSessionId) {
      await this.markQuickPrintReady(payment.quickPrintSessionId, payment.id, input.correlationId);
      return {
        alreadyPaid: false,
        otpSent: false,
        sessionReady: true,
        payment: this.toPublicPayment(updated),
      };
    }
    if (!payment.challengeId) {
      throw new AppError('not_found', 'Payment is not linked to a print session', 404);
    }

    const issued = await this.otpPrint.issueOtpAndNotify(payment.challengeId, input.correlationId);
    if (issued.issued || issued.alreadyIssued) {
      await this.resolveOpenSupportQuery(
        payment.id,
        input.correlationId,
        SupportResolution.otp_sent,
      );
    }
    return {
      alreadyPaid: false,
      otpSent: issued.issued || issued.alreadyIssued,
      payment: this.toPublicPayment(updated),
    };
  }

  private async markQuickPrintReady(sessionId: string, paymentId: string, correlationId?: string) {
    const session = await this.db.quickPrintSession.findUnique({ where: { id: sessionId } });
    if (!session) {
      return;
    }
    if (
      session.status === QuickPrintSessionStatus.ready ||
      session.status === QuickPrintSessionStatus.consumed
    ) {
      await this.resolveOpenSupportQuery(paymentId, correlationId, SupportResolution.session_ready);
      return;
    }
    const paidGraceMs = 5 * 60 * 1000;
    await this.db.quickPrintSession.update({
      where: { id: sessionId },
      data: {
        status: QuickPrintSessionStatus.ready,
        expiresAt: new Date(Math.max(session.expiresAt.getTime(), Date.now() + paidGraceMs)),
      },
    });
    await this.audit.record({
      action: 'quick_print.paid',
      principalType: 'system',
      principalId: session.deviceId,
      resourceType: 'quick_print_session',
      resourceId: sessionId,
      correlationId,
      metadata: { afterPayment: true },
    });
    await this.resolveOpenSupportQuery(paymentId, correlationId, SupportResolution.session_ready);
  }

  async markRazorpayPaymentFailed(razorpayOrderId: string, reason?: string) {
    const payment = await this.db.payment.findUnique({
      where: { razorpayOrderId },
    });
    if (!payment || payment.status !== PaymentStatus.PENDING) {
      return { updated: false };
    }
    await this.db.payment.update({
      where: { id: payment.id },
      data: {
        status: PaymentStatus.FAILED,
        failureReason: reason ?? 'payment.failed',
      },
    });
    return { updated: true };
  }

  async handleWebhook(rawBody: Buffer, signature: string | undefined, correlationId?: string) {
    if (!signature) {
      throw new AppError('invalid_signature', 'Missing Razorpay webhook signature', 400);
    }
    const valid = verifyWebhookSignature({
      rawBody,
      signature,
      webhookSecret: this.razorpay.getWebhookSecret(),
    });
    if (!valid) {
      throw new AppError('invalid_signature', 'Invalid Razorpay webhook signature', 400);
    }

    let event: WebhookPayload;
    try {
      event = JSON.parse(rawBody.toString('utf8')) as WebhookPayload;
    } catch {
      throw new AppError('validation_error', 'Invalid webhook payload', 400);
    }
    const entity = event.payload?.payment?.entity;
    const razorpayOrderId = entity?.order_id;
    const razorpayPaymentId = entity?.id;

    if (event.event === 'payment.captured' && razorpayOrderId) {
      try {
        await this.fulfillRazorpayPayment({
          razorpayOrderId,
          razorpayPaymentId,
          amountPaise: entity?.amount,
          allowExpiredFulfillment: true,
          correlationId,
        });
      } catch (error) {
        if (isAppError(error) && error.code === 'sms_failed') {
          return { status: 'ok' as const };
        }
        throw error;
      }
      return { status: 'ok' as const };
    }

    if (event.event === 'payment.failed' && razorpayOrderId) {
      await this.markRazorpayPaymentFailed(razorpayOrderId, 'payment.failed');
      return { status: 'ok' as const };
    }

    return { status: 'ok' as const };
  }

  async getSupportQuery(userId: string, challengeId: string) {
    const challenge = await this.loadSupportChallenge(userId, challengeId);
    this.assertOtpNotSent(challenge.status);
    const payment = challenge.payment;
    if (!payment) {
      throw new AppError('payment_not_required', 'This print session does not require payment', 400);
    }
    return {
      query: payment.supportQuery
        ? this.toPublicSupportQuery(payment.supportQuery, this.challengeContext(challenge, payment.status))
        : null,
    };
  }

  async openSupportQuery(userId: string, input: OpenSupportQueryInput, correlationId?: string) {
    const challenge = await this.loadSupportChallenge(userId, input.challengeId);
    this.assertOtpNotSent(challenge.status);
    const payment = challenge.payment;
    if (!payment) {
      throw new AppError('payment_not_required', 'This print session does not require payment', 400);
    }
    if (payment.supportQuery) {
      return this.toPublicSupportQuery(
        payment.supportQuery,
        this.challengeContext(challenge, payment.status),
      );
    }

    const created = await this.db.supportQuery.create({
      data: {
        paymentId: payment.id,
        userId,
        phone: challenge.user.phone ?? '',
        message: input.message,
        paymentReference: cleanPaymentReference(input.paymentReference),
        status: SupportQueryStatus.open,
        razorpayOrderId: payment.razorpayOrderId,
        amountPaise: payment.amountPaise,
        failureReason: payment.failureReason,
      },
    });

    await this.audit.record({
      action: 'support_query.opened',
      principalType: 'citizen',
      principalId: userId,
      resourceType: 'support_query',
      resourceId: created.id,
      correlationId,
      metadata: {
        challengeId: challenge.id,
        paymentId: payment.id,
        razorpayOrderId: payment.razorpayOrderId,
      },
    });

    return this.toPublicSupportQuery(created, this.challengeContext(challenge, payment.status));
  }

  async openQuickPrintSupportQuery(
    token: string,
    input: { message: string; paymentReference?: string | null },
    correlationId?: string,
  ) {
    const trimmed = token.trim();
    if (!trimmed) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    const session = await this.db.quickPrintSession.findUnique({
      where: { tokenHash: hashSecret(trimmed) },
      include: {
        device: { select: { name: true } },
        payment: { include: { supportQuery: true } },
      },
    });
    if (!session) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    if (
      session.status === QuickPrintSessionStatus.ready ||
      session.status === QuickPrintSessionStatus.consumed
    ) {
      throw new AppError('payment_already_settled', 'This payment is already settled', 409);
    }
    const payment = session.payment;
    if (!payment) {
      throw new AppError('payment_not_required', 'This print session does not require payment', 400);
    }
    const context: SupportPublicContext = {
      paymentStatus: payment.status,
      kioskName: session.device?.name ?? null,
      fallbackPhone: session.verifiedPhone,
      challengeId: null,
      printJobStatus: null,
      pagesExpected: null,
      pagesReported: null,
      printJobError: null,
    };
    if (payment.supportQuery) {
      return this.toPublicSupportQuery(payment.supportQuery, context);
    }

    const created = await this.db.supportQuery.create({
      data: {
        paymentId: payment.id,
        phone: session.verifiedPhone ?? '',
        message: input.message,
        paymentReference: cleanPaymentReference(input.paymentReference),
        status: SupportQueryStatus.open,
        razorpayOrderId: payment.razorpayOrderId,
        amountPaise: payment.amountPaise,
        failureReason: payment.failureReason,
      },
    });

    await this.audit.record({
      action: 'support_query.opened',
      principalType: 'system',
      principalId: session.deviceId,
      resourceType: 'support_query',
      resourceId: created.id,
      correlationId,
      metadata: {
        quickPrintSessionId: session.id,
        paymentId: payment.id,
        razorpayOrderId: payment.razorpayOrderId,
      },
    });

    return this.toPublicSupportQuery(created, context);
  }

  async listSupportQueries(filter: {
    status?: 'open' | 'resolved';
    source?: 'payment' | 'print';
  } = {}) {
    const where: Prisma.SupportQueryWhereInput = {};
    if (filter.status) {
      where.status = filter.status;
    }
    if (filter.source === 'payment') {
      where.printJobId = null;
    } else if (filter.source === 'print') {
      where.printJobId = { not: null };
    }
    const [rows, openCount] = await Promise.all([
      this.db.supportQuery.findMany({
        where,
        include: supportQueryInclude,
        orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
      }),
      this.db.supportQuery.count({ where: { status: SupportQueryStatus.open } }),
    ]);
    return {
      items: rows.map((row) => this.toPublicSupportQuery(row, supportContextFromRecord(row))),
      openCount,
    };
  }

  async resolveSupportQuery(
    queryId: string,
    adminId: string,
    resolution: SupportResolution,
    correlationId?: string,
  ) {
    const row = await this.db.supportQuery.findUnique({
      where: { id: queryId },
      include: supportQueryInclude,
    });
    if (!row) {
      throw new AppError('not_found', 'Support message not found', 404);
    }
    if (row.status === SupportQueryStatus.resolved) {
      return this.toPublicSupportQuery(row, supportContextFromRecord(row));
    }
    const won = await this.db.supportQuery.updateMany({
      where: { id: queryId, status: SupportQueryStatus.open },
      data: { status: SupportQueryStatus.resolved, resolvedAt: new Date(), resolution },
    });
    const current = await this.db.supportQuery.findUnique({
      where: { id: queryId },
      include: supportQueryInclude,
    });
    if (!current) {
      throw new AppError('not_found', 'Support message not found', 404);
    }
    if (won.count === 0) {
      return this.toPublicSupportQuery(current, supportContextFromRecord(current));
    }
    await this.audit.record({
      action: 'support_query.resolved',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'support_query',
      resourceId: queryId,
      correlationId,
      metadata: { paymentId: row.paymentId, resolution },
    });
    return this.toPublicSupportQuery(current, supportContextFromRecord(current));
  }

  async resendSupportOtp(queryId: string, adminId: string, correlationId?: string) {
    const row = await this.db.supportQuery.findUnique({
      where: { id: queryId },
      include: supportQueryInclude,
    });
    if (!row) {
      throw new AppError('not_found', 'Support message not found', 404);
    }
    const payment = row.payment;
    if (!payment || payment.status !== PaymentStatus.PAID || !payment.challengeId) {
      throw new AppError(
        'payment_required',
        'OTP can only be resent after a paid OTP print payment',
        402,
      );
    }
    const issued = await this.otpPrint.issueOtpAndNotify(payment.challengeId, correlationId);
    if (issued.issued || issued.alreadyIssued) {
      await this.resolveOpenSupportQuery(payment.id, correlationId, SupportResolution.otp_sent);
    }
    await this.audit.record({
      action: 'support_query.otp_resent',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'support_query',
      resourceId: queryId,
      correlationId,
      metadata: { paymentId: payment.id, challengeId: payment.challengeId },
    });
    const fresh = await this.db.supportQuery.findUnique({
      where: { id: queryId },
      include: supportQueryInclude,
    });
    if (!fresh) {
      throw new AppError('not_found', 'Support message not found', 404);
    }
    return this.toPublicSupportQuery(fresh, supportContextFromRecord(fresh));
  }

  private async resolveOpenSupportQuery(
    paymentId: string,
    correlationId: string | undefined,
    resolution: SupportResolution,
  ) {
    const open = await this.db.supportQuery.findUnique({ where: { paymentId } });
    if (!open || open.status !== SupportQueryStatus.open) {
      return;
    }
    const won = await this.db.supportQuery.updateMany({
      where: { id: open.id, status: SupportQueryStatus.open },
      data: { status: SupportQueryStatus.resolved, resolvedAt: new Date(), resolution },
    });
    if (won.count === 0) {
      return;
    }
    await this.audit.record({
      action: 'support_query.resolved',
      principalType: 'system',
      principalId: null,
      resourceType: 'support_query',
      resourceId: open.id,
      correlationId,
      metadata: { paymentId, automatic: true, resolution },
    });
  }

  private assertOtpNotSent(status: OtpChallengeStatus) {
    if (status === OtpChallengeStatus.pending || status === OtpChallengeStatus.redeemed) {
      throw new AppError('payment_already_settled', 'This payment already has an OTP', 409);
    }
  }

  private async loadSupportChallenge(userId: string, challengeId: string) {
    const challenge = await this.db.otpChallenge.findUnique({
      where: { id: challengeId },
      include: {
        user: true,
        device: { select: { name: true } },
        payment: { include: { supportQuery: true } },
      },
    });
    if (!challenge || challenge.userId !== userId) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    return challenge;
  }

  private challengeContext(
    challenge: { id: string; device: { name: string } | null; user: { phone: string | null } },
    paymentStatus: PaymentStatus,
  ): SupportPublicContext {
    return {
      paymentStatus,
      kioskName: challenge.device?.name ?? null,
      fallbackPhone: challenge.user.phone,
      challengeId: challenge.id,
      printJobStatus: null,
      pagesExpected: null,
      pagesReported: null,
      printJobError: null,
    };
  }

  private toPublicSupportQuery(query: SupportQuery, context: SupportPublicContext) {
    const phone = query.phone.trim() || context.fallbackPhone?.trim() || '';
    return {
      id: query.id,
      status: query.status,
      message: query.message,
      phone,
      amountPaise: query.amountPaise,
      razorpayOrderId: query.razorpayOrderId,
      failureReason: query.failureReason,
      paymentReference: query.paymentReference,
      paymentStatus: context.paymentStatus,
      challengeId: context.challengeId,
      kioskName: context.kioskName,
      printJobId: query.printJobId,
      printJobStatus: context.printJobStatus,
      pagesExpected: context.pagesExpected,
      pagesReported: context.pagesReported,
      printJobError: context.printJobError,
      source: query.printJobId ? 'print' as const : 'payment' as const,
      resolution: query.resolution,
      createdAt: query.createdAt.toISOString(),
      resolvedAt: query.resolvedAt?.toISOString() ?? null,
    };
  }

  private toPublicPayment(payment: {
    id: string;
    status: PaymentStatus;
    pageCount: number;
    freePages: number;
    extraPages: number;
    amountPaise: number;
    currency: string;
    razorpayOrderId: string | null;
    expiresAt: Date;
    paidAt: Date | null;
  }) {
    return {
      id: payment.id,
      status: payment.status,
      pageCount: payment.pageCount,
      freePages: payment.freePages,
      extraPages: payment.extraPages,
      amountPaise: payment.amountPaise,
      currency: payment.currency,
      razorpayOrderId: payment.razorpayOrderId,
      expiresAt: payment.expiresAt.toISOString(),
      paidAt: payment.paidAt?.toISOString() ?? null,
    };
  }
}

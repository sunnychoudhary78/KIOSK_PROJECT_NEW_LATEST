import { OtpChallengeStatus, PaymentStatus, QuickPrintSessionStatus } from '@prisma/client';
import type { AppConfig } from '../../config/index.js';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError, isAppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import { OtpPrintService } from '../otp_print/otp_print.service.js';
import {
  RazorpayClient,
  verifyPaymentSignature,
  verifyWebhookSignature,
} from './razorpay.client.js';
import type { CreateRazorpayOrderInput, VerifyRazorpayPaymentInput } from './payments.schemas.js';

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
        await this.markQuickPrintReady(payment.quickPrintSessionId, input.correlationId);
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
      await this.markQuickPrintReady(payment.quickPrintSessionId, input.correlationId);
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
    return {
      alreadyPaid: false,
      otpSent: issued.issued || issued.alreadyIssued,
      payment: this.toPublicPayment(updated),
    };
  }

  private async markQuickPrintReady(sessionId: string, correlationId?: string) {
    const session = await this.db.quickPrintSession.findUnique({ where: { id: sessionId } });
    if (!session) {
      return;
    }
    if (
      session.status === QuickPrintSessionStatus.ready ||
      session.status === QuickPrintSessionStatus.consumed
    ) {
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

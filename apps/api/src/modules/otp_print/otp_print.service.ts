import { mkdir, writeFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { PDFDocument } from 'pdf-lib';
import { OtpChallengeStatus, PaymentStatus, PrintJobSource } from '@prisma/client';
import type { OtpChallenge, OtpDocument, Payment } from '@prisma/client';
import type { AppConfig } from '../../config/index.js';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { SmsClient } from '../../infrastructure/external/sms.client.js';
import { AppError } from '../../shared/errors.js';
import { generateNumericOtp, hashOtp, sanitizeOtpDeliveryError } from '../../shared/otp.js';
import type { AuditService } from '../audit/audit.service.js';
import { PlatformSettingsService } from '../platform_settings/platform_settings.service.js';
import { PrintingService } from '../printing/printing.service.js';
import { ServicesCatalogService } from '../services/services.service.js';
import { quoteOtpPrintPages, type PrintQuote } from './otp_print.quote.js';
import type { RedeemOtpInput, UploadedPdf } from './otp_print.schemas.js';

const OTP_UPLOAD_DIR = join(process.cwd(), 'uploads', 'otp-print');

type ChallengeWithDocs = OtpChallenge & {
  documents: OtpDocument[];
  payment?: Payment | null;
};

async function countPdfPages(buffer: Buffer): Promise<number> {
  const doc = await PDFDocument.load(buffer, { ignoreEncryption: true });
  return doc.getPageCount();
}

function quoteFromPayment(payment: Payment): PrintQuote {
  return {
    pageCount: payment.pageCount,
    freePages: payment.freePages,
    extraPages: payment.extraPages,
    chargePerPageRupees: payment.extraPages > 0 ? Math.round(payment.amountPaise / payment.extraPages / 100) : 0,
    amountPaise: payment.amountPaise,
    currency: 'INR',
    paymentRequired: payment.amountPaise > 0,
  };
}

export class OtpPrintService {
  private readonly settings: PlatformSettingsService;

  constructor(
    private readonly db: DbClient,
    private readonly config: AppConfig,
    private readonly audit: AuditService,
    private readonly printing: PrintingService,
    private readonly services: ServicesCatalogService,
    private readonly sms: SmsClient,
  ) {
    this.settings = new PlatformSettingsService(db, audit);
  }

  async createChallenge(
    userId: string,
    files: UploadedPdf[],
    documentLabel: string | undefined,
    correlationId?: string,
  ) {
    const printConfig = await this.settings.getOtpPrintConfig();
    const otpLength = printConfig.otpLength || this.config.otp.length;
    const ttlSeconds = printConfig.ttlSeconds || this.config.otp.ttlSeconds;

    if (!files.length) {
      throw new AppError('validation_error', 'At least one PDF is required', 400);
    }
    if (files.length > printConfig.maxDocumentsPerSession) {
      throw new AppError(
        'too_many_documents',
        `Maximum ${printConfig.maxDocumentsPerSession} documents allowed`,
        400,
      );
    }

    const maxBytes = printConfig.maxFileSizeMb * 1024 * 1024;
    const prepared: Array<{
      file: UploadedPdf;
      pageCount: number;
      safeName: string;
    }> = [];

    let totalPages = 0;
    for (const file of files) {
      if (!file.mimetype.includes('pdf') && !file.originalname.toLowerCase().endsWith('.pdf')) {
        throw new AppError('invalid_file_type', 'Only PDF files are allowed', 400);
      }
      if (file.size <= 0 || file.size > maxBytes) {
        throw new AppError(
          'file_too_large',
          `Each PDF must be under ${printConfig.maxFileSizeMb} MB`,
          400,
        );
      }
      let pageCount: number;
      try {
        pageCount = await countPdfPages(file.buffer);
      } catch {
        throw new AppError('invalid_pdf', `Could not read PDF: ${file.originalname}`, 400);
      }
      if (pageCount < 1) {
        throw new AppError('invalid_pdf', `PDF has no pages: ${file.originalname}`, 400);
      }
      totalPages += pageCount;
      prepared.push({
        file,
        pageCount,
        safeName: file.originalname.replace(/[^\w.\- ()[\]]+/g, '_').slice(0, 180) || 'document.pdf',
      });
    }

    if (totalPages > printConfig.maxPagesPerSession) {
      throw new AppError(
        'page_limit_exceeded',
        `Total pages (${totalPages}) exceed the limit of ${printConfig.maxPagesPerSession}`,
        400,
      );
    }

    const user = await this.db.user.findUnique({ where: { id: userId } });
    if (!user?.phone) {
      throw new AppError('phone_required', 'Citizen account must have a phone number', 400);
    }

    const quote = quoteOtpPrintPages(totalPages, printConfig);
    const paymentRequired = quote.paymentRequired;
    if (paymentRequired && (!this.config.razorpay.keyId || !this.config.razorpay.keySecret)) {
      throw new AppError(
        'payments_not_configured',
        'Extra pages require payment, but Razorpay is not configured',
        503,
      );
    }
    const expiresAt = paymentRequired
      ? new Date(Date.now() + this.config.payments.windowMinutes * 60 * 1000)
      : new Date(Date.now() + ttlSeconds * 1000);
    const challengeId = randomUUID();
    const label =
      documentLabel?.trim() ||
      (prepared.length === 1 ? prepared[0]!.safeName : `${prepared.length} documents`);

    const challengeDir = join(OTP_UPLOAD_DIR, challengeId);
    await mkdir(challengeDir, { recursive: true });

    const documentRows: Array<{
      fileName: string;
      storagePath: string;
      contentType: string;
      pageCount: number;
      byteSize: number;
      sortOrder: number;
    }> = [];

    try {
      for (const [index, item] of prepared.entries()) {
        const storagePath = join(challengeDir, `${String(index).padStart(2, '0')}-${item.safeName}`);
        await writeFile(storagePath, item.file.buffer);
        documentRows.push({
          fileName: item.safeName,
          storagePath,
          contentType: 'application/pdf',
          pageCount: item.pageCount,
          byteSize: item.file.size,
          sortOrder: index,
        });
      }

      if (paymentRequired) {
        const challenge = await this.db.otpChallenge.create({
          data: {
            id: challengeId,
            userId,
            documentLabel: label,
            pageCount: totalPages,
            expiresAt,
            status: OtpChallengeStatus.awaiting_payment,
            documents: { create: documentRows },
            payment: {
              create: {
                userId,
                status: PaymentStatus.PENDING,
                pageCount: quote.pageCount,
                freePages: quote.freePages,
                extraPages: quote.extraPages,
                amountPaise: quote.amountPaise,
                currency: quote.currency,
                expiresAt,
              },
            },
          },
          include: { documents: { orderBy: { sortOrder: 'asc' } }, payment: true },
        });

        await this.audit.record({
          action: 'otp.created',
          principalType: 'citizen',
          principalId: userId,
          resourceType: 'otp_challenge',
          resourceId: challenge.id,
          correlationId,
          metadata: {
            documentLabel: label,
            pageCount: totalPages,
            documentCount: prepared.length,
            paymentRequired: true,
            extraPages: quote.extraPages,
            amountPaise: quote.amountPaise,
          },
        });

        return this.toPublicChallenge(challenge, quote);
      }

      const code = generateNumericOtp(otpLength);
      const challenge = await this.db.otpChallenge.create({
        data: {
          id: challengeId,
          userId,
          codeHash: hashOtp(code),
          codeHint: code.slice(-2),
          documentLabel: label,
          pageCount: totalPages,
          expiresAt,
          status: OtpChallengeStatus.pending,
          documents: { create: documentRows },
        },
        include: { documents: { orderBy: { sortOrder: 'asc' } }, payment: true },
      });

      try {
        await this.sms.sendOtp(user.phone, code, ttlSeconds);
      } catch (error) {
        await this.db.otpChallenge.delete({ where: { id: challenge.id } }).catch(() => undefined);
        await rm(challengeDir, { recursive: true, force: true }).catch(() => undefined);
        throw new AppError('sms_failed', sanitizeOtpDeliveryError(error), 502);
      }

      await this.audit.record({
        action: 'otp.created',
        principalType: 'citizen',
        principalId: userId,
        resourceType: 'otp_challenge',
        resourceId: challenge.id,
        correlationId,
        metadata: { documentLabel: label, pageCount: totalPages, documentCount: prepared.length, paymentRequired: false },
      });

      return this.toPublicChallenge(challenge, quote);
    } catch (error) {
      await rm(challengeDir, { recursive: true, force: true }).catch(() => undefined);
      throw error;
    }
  }

  async getChallengeForCitizen(userId: string, challengeId: string) {
    const challenge = await this.db.otpChallenge.findUnique({
      where: { id: challengeId },
      include: { documents: { orderBy: { sortOrder: 'asc' } }, payment: true },
    });
    if (!challenge || challenge.userId !== userId) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    const printConfig = await this.settings.getOtpPrintConfig();
    const quote = challenge.payment
      ? quoteFromPayment(challenge.payment)
      : quoteOtpPrintPages(challenge.pageCount, printConfig);
    return this.toPublicChallenge(challenge, quote);
  }

  /**
   * Generate OTP and send SMS after payment is captured.
   * Idempotent when the challenge is already pending/redeemed.
   * On SMS failure after a paid capture, reverts to awaiting_payment with no OTP.
   */
  async issueOtpAndNotify(challengeId: string, correlationId?: string) {
    const challenge = await this.db.otpChallenge.findUnique({
      where: { id: challengeId },
      include: { user: true, payment: true },
    });
    if (!challenge) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    if (
      challenge.status === OtpChallengeStatus.pending ||
      challenge.status === OtpChallengeStatus.redeemed
    ) {
      return { issued: false, alreadyIssued: true, challengeId };
    }
    if (challenge.status !== OtpChallengeStatus.awaiting_payment) {
      throw new AppError('otp_unavailable', 'Print session is not waiting for payment', 400);
    }
    if (challenge.payment && challenge.payment.status !== PaymentStatus.PAID) {
      throw new AppError('payment_required', 'Payment is not complete', 402);
    }
    if (!challenge.user.phone) {
      throw new AppError('phone_required', 'Citizen account must have a phone number', 400);
    }

    const printConfig = await this.settings.getOtpPrintConfig();
    const otpLength = printConfig.otpLength || this.config.otp.length;
    const ttlSeconds = printConfig.ttlSeconds || this.config.otp.ttlSeconds;
    const code = generateNumericOtp(otpLength);
    const expiresAt = new Date(Date.now() + ttlSeconds * 1000);

    const claimed = await this.db.otpChallenge.updateMany({
      where: {
        id: challengeId,
        status: OtpChallengeStatus.awaiting_payment,
        codeHash: null,
      },
      data: {
        codeHash: hashOtp(code),
        codeHint: code.slice(-2),
        status: OtpChallengeStatus.pending,
        expiresAt,
      },
    });

    if (claimed.count === 0) {
      const current = await this.db.otpChallenge.findUnique({ where: { id: challengeId } });
      if (
        current?.status === OtpChallengeStatus.pending ||
        current?.status === OtpChallengeStatus.redeemed
      ) {
        return { issued: false, alreadyIssued: true, challengeId };
      }
      throw new AppError('otp_unavailable', 'Could not issue print OTP', 409);
    }

    try {
      await this.sms.sendOtp(challenge.user.phone, code, ttlSeconds);
    } catch (error) {
      await this.db.otpChallenge.update({
        where: { id: challengeId },
        data: {
          codeHash: null,
          codeHint: null,
          status: OtpChallengeStatus.awaiting_payment,
        },
      });
      throw new AppError('sms_failed', sanitizeOtpDeliveryError(error), 502);
    }

    await this.audit.record({
      action: 'otp.issued',
      principalType: 'citizen',
      principalId: challenge.userId,
      resourceType: 'otp_challenge',
      resourceId: challengeId,
      correlationId,
      metadata: { afterPayment: true },
    });

    return { issued: true, alreadyIssued: false, challengeId };
  }

  async resendOtp(userId: string, challengeId: string, correlationId?: string) {
    const challenge = await this.db.otpChallenge.findUnique({
      where: { id: challengeId },
      include: { payment: true },
    });
    if (!challenge || challenge.userId !== userId) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    if (!challenge.payment || challenge.payment.status !== PaymentStatus.PAID) {
      throw new AppError('payment_required', 'OTP can only be resent after payment', 402);
    }
    if (challenge.status === OtpChallengeStatus.pending) {
      return { otpSent: true, alreadyIssued: true };
    }
    const result = await this.issueOtpAndNotify(challengeId, correlationId);
    return { otpSent: true, alreadyIssued: result.alreadyIssued };
  }

  async redeem(deviceId: string, input: RedeemOtpInput, correlationId?: string) {
    await this.services.assertEnabled(deviceId, 'otp_print');
    const printConfig = await this.settings.getOtpPrintConfig();

    const codeHash = hashOtp(input.code);
    const challenge = await this.db.otpChallenge.findFirst({
      where: {
        codeHash,
        status: OtpChallengeStatus.pending,
      },
      include: { documents: { orderBy: { sortOrder: 'asc' } } },
      orderBy: { createdAt: 'desc' },
    });

    if (!challenge) {
      throw new AppError('otp_invalid', 'Invalid or already used OTP', 400);
    }

    if (challenge.attemptCount >= printConfig.maxVerifyAttempts) {
      await this.db.otpChallenge.update({
        where: { id: challenge.id },
        data: { status: OtpChallengeStatus.cancelled },
      });
      throw new AppError('otp_locked', 'Too many invalid attempts for this OTP', 400);
    }

    if (challenge.expiresAt.getTime() < Date.now()) {
      await this.db.otpChallenge.update({
        where: { id: challenge.id },
        data: { status: OtpChallengeStatus.expired },
      });
      throw new AppError('otp_expired', 'OTP has expired', 400);
    }

    if (!challenge.documents.length) {
      throw new AppError('otp_empty', 'No documents linked to this OTP', 400);
    }

    const printJob = await this.printing.createJob(
      {
        source: PrintJobSource.otp_print,
        title: challenge.documentLabel,
        pageCount: challenge.pageCount,
        deviceId,
        payloadUrl: `/v1/otp-challenges/${challenge.id}/documents`,
        idempotencyKey: input.idempotencyKey ?? `otp-redeem-${challenge.id}`,
      },
      'device',
      deviceId,
      correlationId,
    );

    await this.db.otpChallenge.update({
      where: { id: challenge.id },
      data: {
        status: OtpChallengeStatus.redeemed,
        redeemedAt: new Date(),
        deviceId,
        printJobId: printJob.id,
      },
    });

    await this.audit.record({
      action: 'otp.redeemed',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'otp_challenge',
      resourceId: challenge.id,
      correlationId,
      metadata: { printJobId: printJob.id },
    });

    return {
      challengeId: challenge.id,
      printJob,
      documents: challenge.documents.map((d) => ({
        id: d.id,
        fileName: d.fileName,
        pageCount: d.pageCount,
        byteSize: d.byteSize,
        contentPath: `/otp-challenges/${challenge.id}/documents/${d.id}/content`,
      })),
    };
  }

  async getDocumentContent(deviceId: string, challengeId: string, documentId: string) {
    const challenge = await this.db.otpChallenge.findUnique({
      where: { id: challengeId },
      include: { documents: true },
    });

    if (!challenge || challenge.deviceId !== deviceId || challenge.status !== OtpChallengeStatus.redeemed) {
      throw new AppError('not_found', 'Document not available for this device', 404);
    }

    const doc = challenge.documents.find((d) => d.id === documentId);
    if (!doc) {
      throw new AppError('not_found', 'Document not found', 404);
    }

    return doc;
  }

  toPublicChallenge(challenge: ChallengeWithDocs, quote: PrintQuote) {
    const paymentRequired =
      challenge.status === OtpChallengeStatus.awaiting_payment || quote.paymentRequired;
    const otpSent =
      challenge.status === OtpChallengeStatus.pending ||
      challenge.status === OtpChallengeStatus.redeemed;
    return {
      id: challenge.id,
      status: challenge.status,
      paymentRequired: paymentRequired && !otpSent,
      otpSent,
      expiresAt: challenge.expiresAt.toISOString(),
      documentLabel: challenge.documentLabel,
      pageCount: challenge.pageCount,
      documents: challenge.documents.map((d) => ({
        id: d.id,
        fileName: d.fileName,
        pageCount: d.pageCount,
        byteSize: d.byteSize,
      })),
      quote,
    };
  }
}

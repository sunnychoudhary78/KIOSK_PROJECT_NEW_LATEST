import { mkdir, writeFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { randomBytes } from 'node:crypto';
import { PDFDocument } from 'pdf-lib';
import {
  PaymentStatus,
  PrintColorMode,
  PrintJobSource,
  QuickPrintSessionStatus,
} from '@prisma/client';
import type { Payment, QuickPrintDocument, QuickPrintSession } from '@prisma/client';
import type { AppConfig } from '../../config/index.js';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import { hashSecret } from '../../shared/otp.js';
import type { AuditService } from '../audit/audit.service.js';
import { printLimitsFromDevice } from '../devices/device_print_limits.js';
import { quoteOtpPrintPages, type PrintColorMode as QuoteColorMode, type PrintQuote } from '../otp_print/otp_print.quote.js';
import type { UploadedPdf } from '../otp_print/otp_print.schemas.js';
import { PlatformSettingsService } from '../platform_settings/platform_settings.service.js';
import { PrintingService } from '../printing/printing.service.js';
import { ServicesCatalogService } from '../services/services.service.js';
import { RazorpayClient, verifyPaymentSignature } from '../payments/razorpay.client.js';
import { PaymentsService } from '../payments/payments.service.js';

const QUICK_PRINT_UPLOAD_DIR = join(process.cwd(), 'uploads', 'quick-print');

const ACTIVE_STATUSES: QuickPrintSessionStatus[] = [
  QuickPrintSessionStatus.waiting_upload,
  QuickPrintSessionStatus.awaiting_payment,
];

const deviceQuoteSelect = {
  id: true,
  name: true,
  maxPagesPerSession: true,
  freePagesPerSession: true,
  extraPageChargeRupees: true,
  freeColorPagesPerSession: true,
  extraColorPageChargeRupees: true,
} as const;

type SessionWithRelations = QuickPrintSession & {
  documents: QuickPrintDocument[];
  payment?: Payment | null;
  device?: {
    id: string;
    name: string;
    maxPagesPerSession?: number;
    freePagesPerSession?: number;
    extraPageChargeRupees?: number;
    freeColorPagesPerSession?: number;
    extraColorPageChargeRupees?: number;
  } | null;
  printJob?: { id: string; status: string } | null;
};

async function countPdfPages(buffer: Buffer): Promise<number> {
  const doc = await PDFDocument.load(buffer, { ignoreEncryption: true });
  return doc.getPageCount();
}

function quoteFromPayment(payment: Payment): PrintQuote {
  return {
    printColorMode: payment.printColorMode === PrintColorMode.color ? 'color' : 'bw',
    pageCount: payment.pageCount,
    freePages: payment.freePages,
    extraPages: payment.extraPages,
    chargePerPageRupees: payment.extraPages > 0 ? Math.round(payment.amountPaise / payment.extraPages / 100) : 0,
    amountPaise: payment.amountPaise,
    currency: 'INR',
    paymentRequired: payment.amountPaise > 0 && payment.status !== PaymentStatus.PAID,
  };
}

export class QuickPrintService {
  private readonly settings: PlatformSettingsService;

  constructor(
    private readonly db: DbClient,
    private readonly config: AppConfig,
    private readonly audit: AuditService,
    private readonly printing: PrintingService,
    private readonly services: ServicesCatalogService,
    private readonly razorpay: RazorpayClient,
    private readonly payments: PaymentsService,
  ) {
    this.settings = new PlatformSettingsService(db, audit);
  }

  async createSession(deviceId: string, correlationId?: string) {
    await this.services.assertEnabled(deviceId, 'quick_print');
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: deviceQuoteSelect,
    });
    if (!device) {
      throw new AppError('not_found', 'Kiosk was not found', 404);
    }

    const printConfig = await this.settings.getQuickPrintConfig();
    const ttlSeconds = printConfig.ttlSeconds || 600;
    const token = randomBytes(32).toString('base64url');
    const expiresAt = new Date(Date.now() + ttlSeconds * 1000);

    await this.db.quickPrintSession.updateMany({
      where: { deviceId, status: { in: ACTIVE_STATUSES } },
      data: { status: QuickPrintSessionStatus.cancelled },
    });

    const session = await this.db.quickPrintSession.create({
      data: {
        deviceId,
        tokenHash: hashSecret(token),
        status: QuickPrintSessionStatus.waiting_upload,
        expiresAt,
      },
      include: {
        documents: { orderBy: { sortOrder: 'asc' } },
        payment: true,
        device: { select: deviceQuoteSelect },
      },
    });

    await this.audit.record({
      action: 'quick_print.session_started',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'quick_print_session',
      resourceId: session.id,
      correlationId,
      metadata: { expiresAt: expiresAt.toISOString() },
    });

    return {
      ...this.toPublicSession(session),
      publicUrl: `${this.config.printWeb.publicUrl}/s/${token}`,
    };
  }

  async getForDevice(deviceId: string, sessionId: string) {
    const session = await this.loadById(sessionId);
    if (session.deviceId !== deviceId) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    await this.ensureFresh(session);
    return this.toPublicSession(await this.loadById(sessionId));
  }

  async getByToken(token: string) {
    const session = await this.loadByToken(token);
    await this.ensureFresh(session);
    return this.toPublicSession(await this.loadById(session.id));
  }

  async uploadDocuments(
    token: string,
    files: UploadedPdf[],
    printColorMode: QuoteColorMode,
    correlationId?: string,
  ) {
    const session = await this.loadByToken(token);
    await this.ensureFresh(session);
    if (session.status !== QuickPrintSessionStatus.waiting_upload) {
      throw new AppError('session_not_accepting', 'This session already has documents', 400);
    }
    if (session.documents.length > 0) {
      throw new AppError('session_not_accepting', 'This session already has documents', 400);
    }

    const printConfig = await this.settings.getOtpPrintConfig();
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

    const printLimits = printLimitsFromDevice(session.device);
    const maxBytes = printConfig.maxFileSizeMb * 1024 * 1024;
    const prepared: Array<{ file: UploadedPdf; pageCount: number; safeName: string }> = [];
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

    if (totalPages > printLimits.maxPagesPerSession) {
      throw new AppError(
        'page_limit_exceeded',
        `Total pages (${totalPages}) exceed the limit of ${printLimits.maxPagesPerSession}`,
        400,
      );
    }

    const quote = quoteOtpPrintPages(totalPages, printLimits, printColorMode);
    if (quote.paymentRequired && (!this.config.razorpay.keyId || !this.config.razorpay.keySecret)) {
      throw new AppError(
        'payments_not_configured',
        'Extra pages require payment, but Razorpay is not configured',
        503,
      );
    }

    const persistedColorMode =
      printColorMode === 'color' ? PrintColorMode.color : PrintColorMode.bw;
    const label =
      prepared.length === 1 ? prepared[0]!.safeName : `${prepared.length} documents`;
    const sessionDir = join(QUICK_PRINT_UPLOAD_DIR, session.id);
    await mkdir(sessionDir, { recursive: true });

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
        const storagePath = join(sessionDir, `${String(index).padStart(2, '0')}-${item.safeName}`);
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

      const nextStatus = quote.paymentRequired
        ? QuickPrintSessionStatus.awaiting_payment
        : QuickPrintSessionStatus.ready;
      const expiresAt = quote.paymentRequired
        ? new Date(Date.now() + this.config.payments.windowMinutes * 60 * 1000)
        : session.expiresAt;

      await this.db.quickPrintSession.update({
        where: { id: session.id },
        data: {
          status: nextStatus,
          documentLabel: label,
          pageCount: totalPages,
          printColorMode: persistedColorMode,
          expiresAt,
          documents: { create: documentRows },
          ...(quote.paymentRequired
            ? {
                payment: {
                  create: {
                    status: PaymentStatus.PENDING,
                    pageCount: quote.pageCount,
                    freePages: quote.freePages,
                    extraPages: quote.extraPages,
                    printColorMode: persistedColorMode,
                    amountPaise: quote.amountPaise,
                    currency: quote.currency,
                    expiresAt,
                  },
                },
              }
            : {}),
        },
      });
    } catch (error) {
      await rm(sessionDir, { recursive: true, force: true }).catch(() => undefined);
      throw error;
    }

    await this.audit.record({
      action: 'quick_print.uploaded',
      principalType: 'system',
      principalId: session.deviceId,
      resourceType: 'quick_print_session',
      resourceId: session.id,
      correlationId,
      metadata: {
        pageCount: totalPages,
        documentCount: prepared.length,
        paymentRequired: quote.paymentRequired,
        printColorMode: quote.printColorMode,
      },
    });

    return this.toPublicSession(await this.loadById(session.id));
  }

  async createCheckoutOrder(token: string, correlationId?: string) {
    const session = await this.loadByToken(token);
    await this.ensureFresh(session);
    if (!session.payment) {
      throw new AppError('payment_not_required', 'This print session does not require payment', 400);
    }
    if (session.payment.status === PaymentStatus.PAID) {
      return {
        alreadyPaid: true,
        sessionReady: session.status === QuickPrintSessionStatus.ready,
        payment: this.toPublicPayment(session.payment),
        razorpay_key_id: this.razorpay.getKeyId(),
      };
    }
    if (
      session.status !== QuickPrintSessionStatus.awaiting_payment ||
      session.payment.status === PaymentStatus.EXPIRED ||
      session.payment.status === PaymentStatus.CANCELLED
    ) {
      throw new AppError('payment_unavailable', 'This print session cannot be paid', 400);
    }

    let payment = session.payment;
    if (payment.razorpayOrderId && payment.status === PaymentStatus.PENDING) {
      return {
        alreadyPaid: false,
        sessionReady: false,
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
        quick_print_session_id: session.id,
        payment_id: payment.id,
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
      principalType: 'system',
      principalId: session.deviceId,
      resourceType: 'payment',
      resourceId: payment.id,
      correlationId,
      metadata: {
        quickPrintSessionId: session.id,
        razorpayOrderId: order.id,
        amountPaise: payment.amountPaise,
      },
    });

    return {
      alreadyPaid: false,
      sessionReady: false,
      payment: this.toPublicPayment(payment),
      razorpay_order_id: order.id,
      razorpay_key_id: this.razorpay.getKeyId(),
    };
  }

  async verifyCheckoutPayment(
    token: string,
    input: { razorpay_order_id: string; razorpay_payment_id: string; razorpay_signature: string },
    correlationId?: string,
  ) {
    const session = await this.loadByToken(token);
    const payment = await this.db.payment.findUnique({
      where: { razorpayOrderId: input.razorpay_order_id },
    });
    if (!payment || payment.quickPrintSessionId !== session.id) {
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

    return this.payments.fulfillRazorpayPayment({
      razorpayOrderId: input.razorpay_order_id,
      razorpayPaymentId: input.razorpay_payment_id,
      razorpaySignature: input.razorpay_signature,
      amountPaise: payment.amountPaise,
      allowExpiredFulfillment: true,
      correlationId,
    });
  }

  async claim(deviceId: string, sessionId: string, correlationId?: string) {
    await this.services.assertEnabled(deviceId, 'quick_print');
    const session = await this.loadById(sessionId);
    if (session.deviceId !== deviceId) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    await this.ensureFresh(session);
    if (session.status !== QuickPrintSessionStatus.ready && session.status !== QuickPrintSessionStatus.consumed) {
      throw new AppError('session_not_ready', 'Documents are not ready to print yet', 400);
    }
    if (!session.documents.length) {
      throw new AppError('otp_empty', 'No documents linked to this session', 400);
    }

    const printJob = await this.printing.createJob(
      {
        source: PrintJobSource.quick_print,
        title: session.documentLabel || 'Quick Print',
        pageCount: session.pageCount,
        printColorMode: session.printColorMode,
        deviceId,
        payloadUrl: `/v1/quick-print/sessions/${session.id}/documents`,
        idempotencyKey: `quick-print-claim-${session.id}`,
      },
      'device',
      deviceId,
      correlationId,
    );

    if (session.status !== QuickPrintSessionStatus.consumed) {
      await this.db.quickPrintSession.update({
        where: { id: session.id },
        data: {
          status: QuickPrintSessionStatus.consumed,
          printJobId: printJob.id,
        },
      });
      await this.audit.record({
        action: 'quick_print.claimed',
        principalType: 'device',
        principalId: deviceId,
        resourceType: 'quick_print_session',
        resourceId: session.id,
        correlationId,
        metadata: { printJobId: printJob.id, printColorMode: session.printColorMode },
      });
    }

    return {
      sessionId: session.id,
      printJob,
      printColorMode: session.printColorMode === PrintColorMode.color ? 'color' : 'bw',
      documents: session.documents.map((doc) => ({
        id: doc.id,
        fileName: doc.fileName,
        pageCount: doc.pageCount,
        byteSize: doc.byteSize,
        contentPath: `/quick-print/sessions/${session.id}/documents/${doc.id}/content`,
      })),
    };
  }

  async getDocumentContent(deviceId: string, sessionId: string, documentId: string) {
    const session = await this.loadById(sessionId);
    if (
      session.deviceId !== deviceId ||
      (session.status !== QuickPrintSessionStatus.ready &&
        session.status !== QuickPrintSessionStatus.consumed)
    ) {
      throw new AppError('not_found', 'Document not available for this device', 404);
    }
    const doc = session.documents.find((item) => item.id === documentId);
    if (!doc) {
      throw new AppError('not_found', 'Document not found', 404);
    }
    return doc;
  }

  async cancel(deviceId: string, sessionId: string, correlationId?: string) {
    const session = await this.db.quickPrintSession.findUnique({ where: { id: sessionId } });
    if (!session || session.deviceId !== deviceId) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    if (
      session.status === QuickPrintSessionStatus.consumed ||
      session.status === QuickPrintSessionStatus.cancelled
    ) {
      return { cancelled: session.status === QuickPrintSessionStatus.cancelled };
    }
    await this.db.quickPrintSession.update({
      where: { id: sessionId },
      data: { status: QuickPrintSessionStatus.cancelled },
    });
    if (session.status === QuickPrintSessionStatus.awaiting_payment) {
      await this.db.payment.updateMany({
        where: { quickPrintSessionId: sessionId, status: PaymentStatus.PENDING },
        data: { status: PaymentStatus.CANCELLED },
      });
    }
    await this.audit.record({
      action: 'quick_print.cancelled',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'quick_print_session',
      resourceId: sessionId,
      correlationId,
    });
    return { cancelled: true };
  }

  private async loadByToken(token: string): Promise<SessionWithRelations> {
    const trimmed = token.trim();
    if (!trimmed) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    const session = await this.db.quickPrintSession.findUnique({
      where: { tokenHash: hashSecret(trimmed) },
      include: {
        documents: { orderBy: { sortOrder: 'asc' } },
        payment: true,
        device: { select: deviceQuoteSelect },
        printJob: { select: { id: true, status: true } },
      },
    });
    if (!session) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    return session;
  }

  private async loadById(sessionId: string): Promise<SessionWithRelations> {
    const session = await this.db.quickPrintSession.findUnique({
      where: { id: sessionId },
      include: {
        documents: { orderBy: { sortOrder: 'asc' } },
        payment: true,
        device: { select: deviceQuoteSelect },
        printJob: { select: { id: true, status: true } },
      },
    });
    if (!session) {
      throw new AppError('not_found', 'Print session not found', 404);
    }
    return session;
  }

  private async ensureFresh(session: SessionWithRelations) {
    const terminal =
      session.status === QuickPrintSessionStatus.consumed ||
      session.status === QuickPrintSessionStatus.cancelled ||
      session.status === QuickPrintSessionStatus.expired;
    if (terminal) {
      if (session.status === QuickPrintSessionStatus.expired) {
        throw new AppError('session_expired', 'This print session has expired', 400);
      }
      if (session.status === QuickPrintSessionStatus.cancelled) {
        throw new AppError('session_cancelled', 'This print session was cancelled', 400);
      }
      return;
    }
    if (session.expiresAt.getTime() >= Date.now()) {
      return;
    }
    await this.db.quickPrintSession.update({
      where: { id: session.id },
      data: { status: QuickPrintSessionStatus.expired },
    });
    if (session.payment?.status === PaymentStatus.PENDING) {
      await this.db.payment.update({
        where: { id: session.payment.id },
        data: { status: PaymentStatus.EXPIRED },
      });
    }
    throw new AppError('session_expired', 'This print session has expired', 400);
  }

  private toPublicPayment(payment: Payment) {
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

  toPublicSession(session: SessionWithRelations) {
    const limits = printLimitsFromDevice(session.device);
    const quote = session.payment
      ? quoteFromPayment(session.payment)
      : session.pageCount > 0
        ? quoteOtpPrintPages(
            session.pageCount,
            limits,
            session.printColorMode === PrintColorMode.color ? 'color' : 'bw',
          )
        : null;
    return {
      id: session.id,
      status: session.status,
      expiresAt: session.expiresAt.toISOString(),
      documentLabel: session.documentLabel,
      pageCount: session.pageCount,
      printColorMode: session.printColorMode === PrintColorMode.color ? 'color' : 'bw',
      deviceId: session.deviceId,
      deviceName: session.device?.name ?? null,
      paymentRequired:
        session.status === QuickPrintSessionStatus.awaiting_payment ||
        Boolean(quote?.paymentRequired && session.status !== QuickPrintSessionStatus.ready && session.status !== QuickPrintSessionStatus.consumed),
      documents: session.documents.map((doc) => ({
        id: doc.id,
        fileName: doc.fileName,
        pageCount: doc.pageCount,
        byteSize: doc.byteSize,
      })),
      quote,
      printLimits: limits,
      printJob: session.printJob ? { id: session.printJob.id, status: session.printJob.status } : null,
    };
  }
}

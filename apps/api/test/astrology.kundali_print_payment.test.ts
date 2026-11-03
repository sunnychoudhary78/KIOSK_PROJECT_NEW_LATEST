import { describe, expect, it, vi } from 'vitest';
import { PaymentStatus, PrintColorMode, PrintJobStatus } from '@prisma/client';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { Logger } from '../src/infrastructure/logging/logger.js';
import type { VedAstroClient } from '../src/infrastructure/external/vedastro.client.js';
import type { AstrologyLlmClient } from '../src/infrastructure/external/openai.client.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { AstrologyService } from '../src/modules/astrology/astrology.service.js';
import { PaymentsService } from '../src/modules/payments/payments.service.js';
import type { RazorpayClient } from '../src/modules/payments/razorpay.client.js';
import type { ServicesCatalogService } from '../src/modules/services/services.service.js';
import type { OtpPrintService } from '../src/modules/otp_print/otp_print.service.js';
import { PrintingService } from '../src/modules/printing/printing.service.js';
import { verifyWebhookSignature } from '../src/modules/payments/razorpay.client.js';
import crypto from 'node:crypto';

vi.mock('../src/modules/astrology/astrology_report_pdf.js', () => ({
  buildKundaliReportPdf: vi.fn(async () => Buffer.from('%PDF-1.4 mock')),
  buildMatchReportPdf: vi.fn(),
  buildPalmReportPdf: vi.fn(),
  buildTodayReportPdf: vi.fn(),
}));

vi.mock('../src/modules/printing/report_pdf.js', () => ({
  countPdfPages: vi.fn(async () => 1),
  buildReportPdf: vi.fn(),
  sanitizePdfText: (t: string) => t,
  svgToPng: vi.fn(),
}));

const silentLogger = { info: vi.fn(), warn: vi.fn(), error: vi.fn() } as unknown as Logger;

describe('AstrologyService.printKundali UPI QR payment', () => {
  const subject = {
    name: 'Asha',
    gender: 'female' as const,
    dateOfBirth: '1992-03-18',
    birthTime: '12:00',
    birthPlace: 'Jaipur',
    birthTimeUnknown: true,
  };

  function setup(chargeRupees: number) {
    const config = {
      razorpay: { keyId: 'rzp_test', keySecret: 'secret', webhookSecret: 'whsec' },
      payments: { windowMinutes: 15 },
      printWeb: { publicUrl: 'http://localhost:5174' },
    } as AppConfig;

    const razorpay = {
      getKeyId: () => 'rzp_test',
      getKeySecret: () => 'secret',
      createOrder: vi.fn(),
      createUpiQrCode: vi.fn(async () => ({
        id: 'qr_1',
        imageUrl: 'https://rzp.io/i/test-qr',
        closeBy: Math.floor(Date.now() / 1000) + 900,
      })),
      closeQrCode: vi.fn(async () => undefined),
    } as unknown as RazorpayClient;

    const payments = {
      fulfillRazorpayPayment: vi.fn(),
      fulfillRazorpayQrPayment: vi.fn(),
    } as unknown as PaymentsService;

    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          kundaliColorPrintChargeRupees: chargeRupees,
          printingPausedReason: null,
        })),
      },
      printJob: {
        findUnique: vi.fn(async () => null),
        create: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          id: 'job-1',
          status: PrintJobStatus.ready,
          source: data.source,
          title: data.title,
          pageCount: data.pageCount ?? 1,
          pagesExpected: data.pagesExpected ?? 1,
          pagesReported: null,
          spoolerJobId: null,
          pageCounterBefore: null,
          pageCounterAfter: null,
          reconcileStatus: 'pending',
          needsAdminReview: false,
          reconcileDetail: null,
          reconciledAt: null,
          printColorMode: PrintColorMode.color,
          deviceId: data.deviceId,
          payloadUrl: data.payloadUrl ?? null,
          payloadPath: null,
          createdAt: new Date(),
          updatedAt: new Date(),
        })),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          id: 'job-1',
          status: PrintJobStatus.ready,
          source: 'astrology_print',
          title: 'Kundali - Asha',
          pageCount: 1,
          pagesExpected: 1,
          pagesReported: null,
          spoolerJobId: null,
          pageCounterBefore: null,
          pageCounterAfter: null,
          reconcileStatus: 'pending',
          needsAdminReview: false,
          reconcileDetail: null,
          reconciledAt: null,
          printColorMode: PrintColorMode.color,
          deviceId: 'device-1',
          payloadUrl: data.payloadUrl ?? '/v1/print-jobs/job-1/content',
          payloadPath: data.payloadPath ?? 'tmp/astrology/job-1.pdf',
          createdAt: new Date(),
          updatedAt: new Date(),
        })),
      },
      payment: {
        create: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          id: 'pay-1',
          ...data,
          paidAt: null,
          createdAt: new Date(),
          updatedAt: new Date(),
        })),
        findUnique: vi.fn(),
        update: vi.fn(),
      },
    };

    const services = { assertEnabled: vi.fn(async () => undefined) };
    const audit = { record: vi.fn(async () => undefined) };

    const service = new AstrologyService(
      db as unknown as DbClient,
      {} as VedAstroClient,
      {} as AstrologyLlmClient,
      audit as unknown as AuditService,
      services as unknown as ServicesCatalogService,
      silentLogger,
      config,
      razorpay,
      payments,
    );

    return { service, db, razorpay };
  }

  it('returns paymentRequired false when charge is 0', async () => {
    const { service, db, razorpay } = setup(0);
    const result = await service.printKundali('device-1', {
      subject,
      style: 'north',
      chart: {},
      charts: [{ key: 'RasiD1', title: 'Birth', subtitle: 'Rasi', svg: '<svg/>' }],
    });
    expect(result.paymentRequired).toBe(false);
    expect(result.amountPaise).toBe(0);
    expect(result.qrImageUrl).toBeNull();
    expect(db.payment.create).not.toHaveBeenCalled();
    expect(razorpay.createUpiQrCode).not.toHaveBeenCalled();
  });

  it('creates UPI QR and returns qrImageUrl when charge is 50', async () => {
    const { service, db, razorpay } = setup(50);
    const result = await service.printKundali('device-1', {
      subject,
      style: 'north',
      chart: {},
      charts: [{ key: 'RasiD1', title: 'Birth', subtitle: 'Rasi', svg: '<svg/>' }],
    });
    expect(result.paymentRequired).toBe(true);
    expect(result.amountPaise).toBe(5000);
    expect(result.qrImageUrl).toBe('https://rzp.io/i/test-qr');
    expect(result.checkoutUrl).toBeNull();
    expect(razorpay.createUpiQrCode).toHaveBeenCalledOnce();
    expect(db.payment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          razorpayQrCodeId: 'qr_1',
          qrImageUrl: 'https://rzp.io/i/test-qr',
          amountPaise: 5000,
        }),
      }),
    );
  });

  it('rejects paid print when Razorpay is not configured', async () => {
    const config = {
      razorpay: { keyId: '', keySecret: '', webhookSecret: '' },
      payments: { windowMinutes: 15 },
      printWeb: { publicUrl: 'http://localhost:5174' },
    } as AppConfig;
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          kundaliColorPrintChargeRupees: 50,
          printingPausedReason: null,
        })),
      },
    };
    const service = new AstrologyService(
      db as unknown as DbClient,
      {} as VedAstroClient,
      {} as AstrologyLlmClient,
      { record: vi.fn() } as unknown as AuditService,
      { assertEnabled: vi.fn() } as unknown as ServicesCatalogService,
      silentLogger,
      config,
      {} as RazorpayClient,
      {} as PaymentsService,
    );
    await expect(
      service.printKundali('device-1', {
        subject,
        style: 'north',
        chart: {},
        charts: [{ key: 'RasiD1', title: 'Birth', subtitle: 'Rasi', svg: '<svg/>' }],
      }),
    ).rejects.toMatchObject({ code: 'payments_not_configured' });
  });
});

describe('PaymentsService.fulfillRazorpayQrPayment', () => {
  it('marks linked payment PAID on qr credit', async () => {
    const pending = {
      id: 'pay-1',
      printJobId: 'job-1',
      status: PaymentStatus.PENDING,
      amountPaise: 5000,
      currency: 'INR',
      pageCount: 1,
      freePages: 0,
      extraPages: 1,
      razorpayOrderId: null,
      razorpayQrCodeId: 'qr_1',
      razorpayPaymentId: null,
      expiresAt: new Date(Date.now() + 60_000),
      paidAt: null,
    };
    const db = {
      payment: {
        findUnique: vi.fn(async () => pending),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          ...pending,
          ...data,
          status: PaymentStatus.PAID,
          paidAt: new Date(),
        })),
      },
    };
    const razorpay = {
      getWebhookSecret: () => 'whsec',
      closeQrCode: vi.fn(),
    } as unknown as RazorpayClient;
    const service = new PaymentsService(
      db as unknown as DbClient,
      {} as AppConfig,
      razorpay,
      {} as OtpPrintService,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );

    const result = await service.fulfillRazorpayQrPayment({
      razorpayQrCodeId: 'qr_1',
      razorpayPaymentId: 'pay_rzp_1',
      amountPaise: 5000,
      allowExpiredFulfillment: true,
    });

    expect(result.alreadyPaid).toBe(false);
    expect(result.printReady).toBe(true);
    expect(db.payment.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: PaymentStatus.PAID }),
      }),
    );
  });

  it('fulfills via qr_code.credited webhook', async () => {
    const pending = {
      id: 'pay-1',
      printJobId: 'job-1',
      status: PaymentStatus.PENDING,
      amountPaise: 5000,
      currency: 'INR',
      pageCount: 1,
      freePages: 0,
      extraPages: 1,
      razorpayOrderId: null,
      razorpayQrCodeId: 'qr_1',
      razorpayPaymentId: null,
      expiresAt: new Date(Date.now() + 60_000),
      paidAt: null,
    };
    const db = {
      payment: {
        findUnique: vi.fn(async () => pending),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          ...pending,
          ...data,
          status: PaymentStatus.PAID,
          paidAt: new Date(),
        })),
      },
    };
    const secret = 'whsec';
    const body = Buffer.from(
      JSON.stringify({
        event: 'qr_code.credited',
        payload: {
          payment: { entity: { id: 'pay_rzp_1', amount: 5000, order_id: null } },
          qr_code: { entity: { id: 'qr_1' } },
        },
      }),
    );
    const signature = crypto.createHmac('sha256', secret).update(body).digest('hex');
    expect(verifyWebhookSignature({ rawBody: body, signature, webhookSecret: secret })).toBe(true);

    const razorpay = {
      getWebhookSecret: () => secret,
      closeQrCode: vi.fn(),
    } as unknown as RazorpayClient;
    const service = new PaymentsService(
      db as unknown as DbClient,
      {} as AppConfig,
      razorpay,
      {} as OtpPrintService,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );

    await service.handleWebhook(body, signature);
    expect(db.payment.update).toHaveBeenCalled();
  });
});

describe('PrintingService payment gate', () => {
  it('blocks printing when payment is pending', async () => {
    const db = {
      printJob: {
        findUnique: vi.fn(async () => ({
          id: 'job-1',
          deviceId: 'device-1',
          status: PrintJobStatus.ready,
          pagesExpected: 1,
          pageCount: 1,
          pagesReported: null,
          reconcileStatus: 'pending',
          needsAdminReview: false,
          payment: {
            id: 'pay-1',
            amountPaise: 5000,
            status: PaymentStatus.PENDING,
            expiresAt: new Date(Date.now() + 60_000),
          },
        })),
        update: vi.fn(),
      },
      payment: { update: vi.fn() },
    };
    const printing = new PrintingService(db as unknown as DbClient, {
      record: vi.fn(),
    } as unknown as AuditService);
    await expect(
      printing.updateStatus('job-1', { status: 'printing' }, 'device-1'),
    ).rejects.toMatchObject({ code: 'payment_required' });
  });

  it('allows printing when payment is paid', async () => {
    const jobRow = {
      id: 'job-1',
      deviceId: 'device-1',
      status: PrintJobStatus.ready,
      source: 'astrology_print',
      title: 'Kundali',
      pagesExpected: 1,
      pageCount: 1,
      pagesReported: null,
      spoolerJobId: null,
      pageCounterBefore: null,
      pageCounterAfter: null,
      reconcileStatus: 'pending',
      needsAdminReview: false,
      reconcileDetail: null,
      reconciledAt: null,
      printColorMode: PrintColorMode.color,
      payloadUrl: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      payment: {
        id: 'pay-1',
        amountPaise: 5000,
        status: PaymentStatus.PAID,
        expiresAt: new Date(Date.now() + 60_000),
      },
    };
    const db = {
      printJob: {
        findUnique: vi.fn(async () => jobRow),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          ...jobRow,
          ...data,
        })),
      },
      payment: { update: vi.fn() },
      phoneFreePageLedger: { createMany: vi.fn() },
      supportQuery: { updateMany: vi.fn() },
    };
    const printing = new PrintingService(db as unknown as DbClient, {
      record: vi.fn(),
    } as unknown as AuditService);
    const updated = await printing.updateStatus('job-1', { status: 'printing' }, 'device-1');
    expect(updated.status).toBe('printing');
  });
});

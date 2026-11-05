import { describe, expect, it, vi } from 'vitest';
import { PaymentStatus, PrintColorMode, PrintJobSource, PrintJobStatus } from '@prisma/client';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import type { RazorpayClient } from '../src/modules/payments/razorpay.client.js';
import { WellBeingService } from '../src/modules/well_being/well_being.service.js';
import { createWellBeingPhoneProofToken } from '../src/modules/well_being/well_being_phone_proof.js';

vi.mock('../src/modules/printing/report_pdf.js', () => ({
  countPdfPages: vi.fn(async () => 1),
  buildReportPdf: vi.fn(),
  sanitizePdfText: (t: string) => t,
  svgToPng: vi.fn(),
}));

vi.mock('../src/modules/well_being/well_being_report_pdf.js', () => ({
  buildHealthReportPdf: vi.fn(async () => Buffer.from('%PDF-1.4 mock')),
}));

vi.mock('node:fs/promises', () => ({
  mkdir: vi.fn(async () => undefined),
  writeFile: vi.fn(async () => undefined),
}));

describe('WellBeingService.printReport payment + quota', () => {
  const deviceId = 'device-1';

  function setup(rates: { bw: number; color: number }) {
    const config = {
      env: 'test',
      auth: { jwtSecret: 'test-jwt-secret-at-least-32-characters!!' },
      razorpay: { keyId: 'rzp_test', keySecret: 'secret', webhookSecret: 'whsec' },
      payments: { windowMinutes: 15 },
    } as AppConfig;

    const razorpay = {
      getKeyId: () => 'rzp_test',
      createUpiQrCode: vi.fn(async () => ({
        id: 'qr_wb_1',
        imageUrl: 'https://rzp.io/i/wb-qr',
        closeBy: Math.floor(Date.now() / 1000) + 900,
      })),
      closeQrCode: vi.fn(async () => undefined),
    } as unknown as RazorpayClient;

    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          extraPageChargeRupees: rates.bw,
          extraColorPageChargeRupees: rates.color,
          freeColorPagesPerSession: 5,
          freePagesPerSession: 5,
          maxPagesPerSession: 10,
          freeDisabledFromLocal: null,
          freeDisabledToLocal: null,
          printingPausedReason: null,
        })),
      },
      societyPhone: {
        findUnique: vi.fn(async () => null),
      },
      phoneFreePageLedger: {
        findMany: vi.fn(async () => []),
        findUnique: vi.fn(async () => null),
        create: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          id: 'ledger-1',
          ...data,
        })),
      },
      platformSetting: {
        findUnique: vi.fn(async () => null),
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
          freePagesGranted: data.freePagesGranted ?? 0,
          printColorMode: data.printColorMode ?? PrintColorMode.bw,
          deviceId: data.deviceId,
          payloadUrl: data.payloadUrl ?? null,
          payloadPath: null,
          digiLockerSessionId: null,
          createdAt: new Date(),
          updatedAt: new Date(),
        })),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          id: 'job-1',
          status: PrintJobStatus.ready,
          source: PrintJobSource.well_being_print,
          title: 'Health Report — Pulse oximetry',
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
          freePagesGranted: 0,
          printColorMode: PrintColorMode.bw,
          deviceId,
          payloadUrl: data.payloadUrl ?? '/v1/print-jobs/job-1/content',
          payloadPath: data.payloadPath ?? 'tmp/well_being/job-1.pdf',
          digiLockerSessionId: null,
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
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          id: 'pay-1',
          ...data,
        })),
      },
    };

    const audit = { record: vi.fn(async () => undefined) };
    const service = new WellBeingService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
      config,
      razorpay,
      { sendOtp: vi.fn() } as never,
    );

    return { service, db, razorpay, config };
  }

  const baseBody = {
    mode: 'oxi' as const,
    colorMode: 'bw' as const,
    heartRate: 72,
    spo2: 98,
  };

  it('returns paymentRequired false when B&W rate is 0', async () => {
    const { service, db, razorpay } = setup({ bw: 0, color: 20 });
    const result = await service.printReport(deviceId, baseBody);
    expect(result.paymentRequired).toBe(false);
    expect(result.amountPaise).toBe(0);
    expect(db.payment.create).not.toHaveBeenCalled();
    expect(razorpay.createUpiQrCode).not.toHaveBeenCalled();
  });

  it('creates UPI QR for color print using DigiLocker color rate × pages', async () => {
    const { service, db, razorpay } = setup({ bw: 10, color: 20 });
    const result = await service.printReport(deviceId, {
      ...baseBody,
      colorMode: 'color',
    });
    expect(result.paymentRequired).toBe(true);
    expect(result.amountPaise).toBe(2000); // 1 page × ₹20
    expect(result.qrImageUrl).toBe('https://rzp.io/i/wb-qr');
    expect(razorpay.createUpiQrCode).toHaveBeenCalledOnce();
    expect(db.payment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          amountPaise: 2000,
          printColorMode: PrintColorMode.color,
        }),
      }),
    );
  });

  it('skips QR and reserves free pages for society phone proof', async () => {
    const { service, db, razorpay, config } = setup({ bw: 10, color: 20 });
    db.societyPhone.findUnique = vi.fn(async () => ({ id: 'soc-1' }));
    db.platformSetting.findUnique = vi.fn(async ({ where }: { where: { settingKey: string } }) => {
      if (where.settingKey === 'society_free_quota_config') {
        return {
          settingKey: where.settingKey,
          settingValue: { period: 'monthly', freeBwPages: 10, freeColorPages: 10 },
          isActive: true,
          description: null,
        };
      }
      return null;
    });
    const phoneProofToken = createWellBeingPhoneProofToken({
      deviceId,
      phone: '+919876543210',
      jwtSecret: config.auth.jwtSecret,
    });
    const result = await service.printReport(deviceId, {
      ...baseBody,
      phoneProofToken,
    });
    expect(result.paymentRequired).toBe(false);
    expect(result.freePages).toBe(1);
    expect(razorpay.createUpiQrCode).not.toHaveBeenCalled();
    expect(db.phoneFreePageLedger.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          phone: '+919876543210',
          pages: 1,
          printJobId: 'job-1',
        }),
      }),
    );
  });

  it('falls back to paid QR when phone is not on society list', async () => {
    const { service, db, razorpay, config } = setup({ bw: 10, color: 20 });
    db.societyPhone.findUnique = vi.fn(async () => null);
    const phoneProofToken = createWellBeingPhoneProofToken({
      deviceId,
      phone: '+919876543210',
      jwtSecret: config.auth.jwtSecret,
    });
    const result = await service.printReport(deviceId, {
      ...baseBody,
      phoneProofToken,
    });
    expect(result.paymentRequired).toBe(true);
    expect(razorpay.createUpiQrCode).toHaveBeenCalledOnce();
    expect(db.phoneFreePageLedger.create).not.toHaveBeenCalled();
  });

  it('getPrintJobPayment returns PAID when no payment row', async () => {
    const { service, db } = setup({ bw: 10, color: 20 });
    db.printJob.findUnique = vi.fn(async () => ({
      id: 'job-1',
      source: PrintJobSource.well_being_print,
      deviceId,
      payment: null,
    }));
    const result = await service.getPrintJobPayment(deviceId, 'job-1');
    expect(result.paymentRequired).toBe(false);
    expect(result.status).toBe('PAID');
  });

  it('getPrintJobPayment returns pending payment details', async () => {
    const { service, db } = setup({ bw: 10, color: 20 });
    const expiresAt = new Date(Date.now() + 60_000);
    db.printJob.findUnique = vi.fn(async () => ({
      id: 'job-1',
      source: PrintJobSource.well_being_print,
      deviceId,
      payment: {
        id: 'pay-1',
        status: PaymentStatus.PENDING,
        amountPaise: 1000,
        currency: 'INR',
        paidAt: null,
        expiresAt,
        qrImageUrl: 'https://rzp.io/i/wb-qr',
        razorpayQrCodeId: 'qr_wb_1',
      },
    }));
    const result = await service.getPrintJobPayment(deviceId, 'job-1');
    expect(result.paymentRequired).toBe(true);
    expect(result.status).toBe(PaymentStatus.PENDING);
    expect(result.amountPaise).toBe(1000);
    expect(result.qrImageUrl).toBe('https://rzp.io/i/wb-qr');
  });

  it('rejects paid print when Razorpay is not configured', async () => {
    const config = {
      env: 'test',
      auth: { jwtSecret: 'test-jwt-secret-at-least-32-characters!!' },
      razorpay: { keyId: '', keySecret: '', webhookSecret: '' },
      payments: { windowMinutes: 15 },
    } as AppConfig;
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          extraPageChargeRupees: 10,
          extraColorPageChargeRupees: 20,
          freeColorPagesPerSession: 5,
          freePagesPerSession: 5,
          maxPagesPerSession: 10,
          freeDisabledFromLocal: null,
          freeDisabledToLocal: null,
          printingPausedReason: null,
        })),
      },
    };
    const service = new WellBeingService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
      config,
      { createUpiQrCode: vi.fn(), closeQrCode: vi.fn() } as unknown as RazorpayClient,
      { sendOtp: vi.fn() } as never,
    );
    await expect(service.printReport(deviceId, baseBody)).rejects.toMatchObject({
      code: 'payments_not_configured',
    });
  });
});

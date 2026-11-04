import { describe, expect, it, vi } from 'vitest';
import { DigiLockerSessionStatus, PrintColorMode, PrintJobSource, PrintJobStatus } from '@prisma/client';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { DigiLockerClient } from '../src/infrastructure/external/digilocker.types.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { DigiLockerService } from '../src/modules/digilocker/digilocker.service.js';
import { createDigiLockerPhoneProofToken } from '../src/modules/digilocker/digilocker_phone_proof.js';
import type { RazorpayClient } from '../src/modules/payments/razorpay.client.js';
import { PrintingService } from '../src/modules/printing/printing.service.js';
import type { ServicesCatalogService } from '../src/modules/services/services.service.js';

vi.mock('../src/modules/printing/report_pdf.js', () => ({
  countPdfPages: vi.fn(async () => 2),
  buildReportPdf: vi.fn(),
  sanitizePdfText: (t: string) => t,
  svgToPng: vi.fn(),
}));

vi.mock('node:fs/promises', () => ({
  mkdir: vi.fn(async () => undefined),
  writeFile: vi.fn(async () => undefined),
}));

describe('DigiLockerService.printDocument payment + quota', () => {
  const sessionId = 'sess-1';
  const deviceId = 'device-1';

  function setup(rates: { bw: number; color: number }) {
    const config = {
      env: 'test',
      auth: { jwtSecret: 'test-jwt-secret-at-least-32-characters!!' },
      razorpay: { keyId: 'rzp_test', keySecret: 'secret', webhookSecret: 'whsec' },
      payments: { windowMinutes: 15 },
      printWeb: { publicUrl: 'http://localhost:5174' },
    } as AppConfig;

    const razorpay = {
      getKeyId: () => 'rzp_test',
      createUpiQrCode: vi.fn(async () => ({
        id: 'qr_dl_1',
        imageUrl: 'https://rzp.io/i/dl-qr',
        closeBy: Math.floor(Date.now() / 1000) + 900,
      })),
      closeQrCode: vi.fn(async () => undefined),
    } as unknown as RazorpayClient;

    const session = {
      id: sessionId,
      deviceId,
      status: DigiLockerSessionStatus.authorized,
      authorizationUrl: 'https://example.test/auth',
      expiresAt: new Date(Date.now() + 60_000),
      authorizedAt: new Date(),
      accessToken: 'tok',
      idToken: 'idtok',
      tokenExpiresAt: new Date(Date.now() + 60_000),
    };

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
      digiLockerSession: {
        findUnique: vi.fn(async () => session),
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
          digiLockerSessionId: data.digiLockerSessionId ?? null,
          createdAt: new Date(),
          updatedAt: new Date(),
        })),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          id: 'job-1',
          status: PrintJobStatus.ready,
          source: PrintJobSource.digilocker_print,
          title: 'Aadhaar',
          pageCount: 2,
          pagesExpected: 2,
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
          payloadPath: data.payloadPath ?? 'tmp/digilocker/job-1.pdf',
          digiLockerSessionId: sessionId,
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
      },
    };

    const digiLocker = {
      downloadFile: vi.fn(async () => ({
        bytes: Buffer.from('%PDF-1.4 mock'),
        mimeType: 'application/pdf',
        fileName: 'doc.pdf',
      })),
    } as unknown as DigiLockerClient;

    const services = { assertEnabled: vi.fn(async () => undefined) };
    const audit = { record: vi.fn(async () => undefined) };
    const printing = new PrintingService(db as unknown as DbClient, audit as unknown as AuditService);

    const service = new DigiLockerService(
      db as unknown as DbClient,
      digiLocker,
      audit as unknown as AuditService,
      printing,
      services as unknown as ServicesCatalogService,
      config,
      razorpay,
      { sendOtp: vi.fn() } as never,
    );

    return { service, db, razorpay, config, digiLocker };
  }

  it('returns paymentRequired false when B&W rate is 0', async () => {
    const { service, db, razorpay } = setup({ bw: 0, color: 20 });
    const result = await service.printDocument(sessionId, deviceId, {
      documentId: 'uri:doc',
      title: 'Aadhaar',
      colorMode: 'bw',
    });
    expect(result.paymentRequired).toBe(false);
    expect(result.amountPaise).toBe(0);
    expect(db.payment.create).not.toHaveBeenCalled();
    expect(razorpay.createUpiQrCode).not.toHaveBeenCalled();
    expect(db.printJob.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          printColorMode: PrintColorMode.bw,
          pageCount: 2,
        }),
      }),
    );
  });

  it('creates UPI QR for color print using extraColorPageChargeRupees × pages', async () => {
    const { service, db, razorpay } = setup({ bw: 10, color: 20 });
    const result = await service.printDocument(sessionId, deviceId, {
      documentId: 'uri:doc',
      title: 'Aadhaar',
      colorMode: 'color',
    });
    expect(result.paymentRequired).toBe(true);
    expect(result.amountPaise).toBe(4000); // 2 pages × ₹20
    expect(result.qrImageUrl).toBe('https://rzp.io/i/dl-qr');
    expect(razorpay.createUpiQrCode).toHaveBeenCalledOnce();
    expect(db.payment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          amountPaise: 4000,
          extraPages: 2,
          printColorMode: PrintColorMode.color,
        }),
      }),
    );
  });

  it('skips QR and reserves free pages for society phone proof with enough remaining', async () => {
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
    const phoneProofToken = createDigiLockerPhoneProofToken({
      deviceId,
      phone: '+919876543210',
      jwtSecret: config.auth.jwtSecret,
    });
    const result = await service.printDocument(sessionId, deviceId, {
      documentId: 'uri:doc',
      title: 'Aadhaar',
      colorMode: 'bw',
      phoneProofToken,
    });
    expect(result.paymentRequired).toBe(false);
    expect(result.freePages).toBe(2);
    expect(razorpay.createUpiQrCode).not.toHaveBeenCalled();
    expect(db.phoneFreePageLedger.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          phone: '+919876543210',
          pages: 2,
          printJobId: 'job-1',
        }),
      }),
    );
  });

  it('falls back to paid QR when phone is not on society list', async () => {
    const { service, db, razorpay, config } = setup({ bw: 10, color: 20 });
    db.societyPhone.findUnique = vi.fn(async () => null);
    const phoneProofToken = createDigiLockerPhoneProofToken({
      deviceId,
      phone: '+919876543210',
      jwtSecret: config.auth.jwtSecret,
    });
    const result = await service.printDocument(sessionId, deviceId, {
      documentId: 'uri:doc',
      title: 'Aadhaar',
      colorMode: 'bw',
      phoneProofToken,
    });
    expect(result.paymentRequired).toBe(true);
    expect(razorpay.createUpiQrCode).toHaveBeenCalledOnce();
    expect(db.phoneFreePageLedger.create).not.toHaveBeenCalled();
  });

  it('falls back to paid when remaining free pages are insufficient for pageCount', async () => {
    const { service, db, razorpay, config } = setup({ bw: 10, color: 20 });
    db.societyPhone.findUnique = vi.fn(async () => ({ id: 'soc-1' }));
    db.platformSetting.findUnique = vi.fn(async ({ where }: { where: { settingKey: string } }) => {
      if (where.settingKey === 'society_free_quota_config') {
        return {
          settingKey: where.settingKey,
          settingValue: { period: 'monthly', freeBwPages: 1, freeColorPages: 0 },
          isActive: true,
          description: null,
        };
      }
      return null;
    });
    const phoneProofToken = createDigiLockerPhoneProofToken({
      deviceId,
      phone: '+919876543210',
      jwtSecret: config.auth.jwtSecret,
    });
    const result = await service.printDocument(sessionId, deviceId, {
      documentId: 'uri:doc',
      title: 'Aadhaar',
      colorMode: 'bw',
      phoneProofToken,
    });
    // pageCount=2, remaining=1 → paid
    expect(result.paymentRequired).toBe(true);
    expect(razorpay.createUpiQrCode).toHaveBeenCalledOnce();
    expect(db.phoneFreePageLedger.create).not.toHaveBeenCalled();
  });

  it('treats invalid phone proof as paid path', async () => {
    const { service, razorpay } = setup({ bw: 10, color: 20 });
    const result = await service.printDocument(sessionId, deviceId, {
      documentId: 'uri:doc',
      title: 'Aadhaar',
      colorMode: 'bw',
      phoneProofToken: 'not-a-valid-token',
    });
    expect(result.paymentRequired).toBe(true);
    expect(razorpay.createUpiQrCode).toHaveBeenCalledOnce();
  });

  it('rejects paid print when Razorpay is not configured', async () => {
    const { service } = setup({ bw: 10, color: 20 });
    // Replace config via new service instance
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
      digiLockerSession: {
        findUnique: vi.fn(async () => ({
          id: sessionId,
          deviceId,
          status: DigiLockerSessionStatus.authorized,
          authorizationUrl: 'https://example.test/auth',
          expiresAt: new Date(Date.now() + 60_000),
          authorizedAt: new Date(),
          accessToken: 'tok',
          idToken: 'idtok',
          tokenExpiresAt: new Date(Date.now() + 60_000),
        })),
      },
    };
    const digiLocker = {
      downloadFile: vi.fn(async () => ({
        bytes: Buffer.from('%PDF-1.4 mock'),
        mimeType: 'application/pdf',
        fileName: 'doc.pdf',
      })),
    } as unknown as DigiLockerClient;
    const config = {
      env: 'test',
      auth: { jwtSecret: 'test-jwt-secret-at-least-32-characters!!' },
      razorpay: { keyId: '', keySecret: '', webhookSecret: '' },
      payments: { windowMinutes: 15 },
    } as AppConfig;
    const serviceNoPay = new DigiLockerService(
      db as unknown as DbClient,
      digiLocker,
      { record: vi.fn() } as unknown as AuditService,
      {} as PrintingService,
      { assertEnabled: vi.fn() } as unknown as ServicesCatalogService,
      config,
      {} as RazorpayClient,
      { sendOtp: vi.fn() } as never,
    );
    await expect(
      serviceNoPay.printDocument(sessionId, deviceId, {
        documentId: 'uri:doc',
        colorMode: 'bw',
      }),
    ).rejects.toMatchObject({ code: 'payments_not_configured' });
  });
});

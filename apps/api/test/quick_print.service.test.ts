import { DeviceStatus, PaymentStatus, PrintJobSource, QuickPrintSessionStatus } from '@prisma/client';
import { PDFDocument } from 'pdf-lib';
import { describe, expect, it, vi } from 'vitest';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { SmsClient } from '../src/infrastructure/external/sms.client.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import type { PaymentsService } from '../src/modules/payments/payments.service.js';
import type { RazorpayClient } from '../src/modules/payments/razorpay.client.js';
import type { PrintingService } from '../src/modules/printing/printing.service.js';
import { QuickPrintService } from '../src/modules/quick_print/quick_print.service.js';
import type { ServicesCatalogService } from '../src/modules/services/services.service.js';
import { hashSecret } from '../src/shared/otp.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const otherDeviceId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const sessionId = '11111111-1111-1111-1111-111111111111';

function deviceRow() {
  return {
    id: deviceId,
    name: 'Lobby Kiosk',
    status: DeviceStatus.active,
    maxPagesPerSession: 10,
    freePagesPerSession: 5,
    extraPageChargeRupees: 10,
    freeColorPagesPerSession: 0,
    extraColorPageChargeRupees: 20,
    freeDisabledFromLocal: null,
    freeDisabledToLocal: null,
  };
}

function makeConfig(overrides: Partial<AppConfig> = {}): AppConfig {
  return {
    env: 'test',
    printWeb: { publicUrl: 'http://localhost:5174' },
    payments: { windowMinutes: 15 },
    razorpay: { keyId: 'rzp_test', keySecret: 'secret', webhookSecret: 'whsec' },
    ...overrides,
  } as AppConfig;
}

const sms = { sendOtp: vi.fn() } as unknown as SmsClient;

function withSms(serviceArgs: ConstructorParameters<typeof QuickPrintService>) {
  return serviceArgs;
}

function makeService(db: unknown) {
  return new QuickPrintService(
    ...withSms([
      db as DbClient,
      makeConfig(),
      { record: vi.fn() } as unknown as AuditService,
      {} as PrintingService,
      { assertEnabled: vi.fn() } as unknown as ServicesCatalogService,
      {} as RazorpayClient,
      {} as PaymentsService,
      sms,
    ]),
  );
}

function txPassthrough(db: Record<string, unknown>) {
  const client: Record<string, unknown> = {
    ...db,
    phoneFreePageLedger: {
      findMany: vi.fn().mockResolvedValue([]),
      findUnique: vi.fn().mockResolvedValue(null),
      create: vi.fn().mockResolvedValue({ id: 'ledger-1' }),
      updateMany: vi.fn().mockResolvedValue({ count: 0 }),
    },
  };
  client.$transaction = vi.fn(async (fn: (tx: unknown) => Promise<unknown>) => fn(client));
  return client;
}

async function onePagePdf() {
  const pdf = await PDFDocument.create();
  pdf.addPage();
  const bytes = Buffer.from(await pdf.save());
  return {
    originalname: 'a.pdf',
    mimetype: 'application/pdf',
    size: bytes.length,
    buffer: bytes,
  };
}

describe('QuickPrintService', () => {
  it('creates a session bound to the kiosk and returns a public URL', async () => {
    const created = {
      id: sessionId,
      deviceId,
      tokenHash: 'hash',
      status: QuickPrintSessionStatus.waiting_upload,
      documentLabel: '',
      pageCount: 0,
      freePagesGranted: 0,
      printColorMode: 'bw',
      verifiedPhone: null,
      phoneVerifiedAt: null,
      expiresAt: new Date(Date.now() + 600_000),
      printJobId: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      documents: [],
      payment: null,
      device: deviceRow(),
    };

    const db = txPassthrough({
      device: { findUnique: vi.fn().mockResolvedValue(deviceRow()) },
      platformSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      quickPrintSession: {
        updateMany: vi.fn().mockResolvedValue({ count: 0 }),
        create: vi.fn().mockResolvedValue(created),
      },
    });

    const service = makeService(db);
    const result = await service.createSession(deviceId);
    expect(result.id).toBe(sessionId);
    expect(result.publicUrl).toMatch(/^http:\/\/localhost:5174\/s\/[A-Za-z0-9_-]+$/);
    expect(result.status).toBe('waiting_upload');
    expect(result.phoneVerified).toBe(false);
  });

  it('does not create a session when printing is paused', async () => {
    const db = {
      device: {
        findUnique: vi.fn().mockResolvedValue({ printingPausedReason: 'paper_out' }),
      },
      quickPrintSession: { create: vi.fn() },
    };
    const service = makeService(db);
    await expect(service.createSession(deviceId)).rejects.toMatchObject({
      code: 'printing_paused',
      statusCode: 403,
    });
    expect(db.quickPrintSession.create).not.toHaveBeenCalled();
  });

  it('charges all pages when phone is not verified', async () => {
    const file = await onePagePdf();
    const token = 'guest-token';
    const waiting = {
      id: sessionId,
      deviceId,
      tokenHash: hashSecret(token),
      status: QuickPrintSessionStatus.waiting_upload,
      documentLabel: '',
      pageCount: 0,
      freePagesGranted: 0,
      printColorMode: 'bw',
      verifiedPhone: null,
      phoneVerifiedAt: null,
      expiresAt: new Date(Date.now() + 600_000),
      printJobId: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      documents: [],
      payment: null,
      device: deviceRow(),
    };
    const awaiting = {
      ...waiting,
      status: QuickPrintSessionStatus.awaiting_payment,
      documentLabel: 'a.pdf',
      pageCount: 1,
      freePagesGranted: 0,
      documents: [
        {
          id: '33333333-3333-3333-3333-333333333333',
          sessionId,
          fileName: 'a.pdf',
          storagePath: '/tmp/a.pdf',
          contentType: 'application/pdf',
          pageCount: 1,
          byteSize: file.size,
          sortOrder: 0,
          createdAt: new Date(),
        },
      ],
      payment: {
        id: '44444444-4444-4444-4444-444444444444',
        challengeId: null,
        quickPrintSessionId: sessionId,
        userId: null,
        status: PaymentStatus.PENDING,
        pageCount: 1,
        freePages: 0,
        extraPages: 1,
        printColorMode: 'bw',
        amountPaise: 1000,
        currency: 'INR',
        razorpayOrderId: null,
        razorpayPaymentId: null,
        razorpaySignature: null,
        failureReason: null,
        paidAt: null,
        expiresAt: new Date(Date.now() + 900_000),
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    };

    const db = txPassthrough({
      platformSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      quickPrintSession: {
        findUnique: vi.fn().mockResolvedValueOnce(waiting).mockResolvedValue(awaiting),
        update: vi.fn().mockResolvedValue(awaiting),
      },
    });

    const service = makeService(db);
    const result = await service.uploadDocuments(token, [file], 'bw');
    expect(result.status).toBe('awaiting_payment');
    expect(result.paymentRequired).toBe(true);
    expect(result.quote?.freePages).toBe(0);
    expect(result.quote?.amountPaise).toBe(1000);
  });

  it('marks a free upload ready when phone is verified and under quota', async () => {
    const file = await onePagePdf();
    const token = 'guest-token';
    const waiting = {
      id: sessionId,
      deviceId,
      tokenHash: hashSecret(token),
      status: QuickPrintSessionStatus.waiting_upload,
      documentLabel: '',
      pageCount: 0,
      freePagesGranted: 0,
      printColorMode: 'bw',
      verifiedPhone: '+919876543210',
      phoneVerifiedAt: new Date(),
      expiresAt: new Date(Date.now() + 600_000),
      printJobId: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      documents: [],
      payment: null,
      device: deviceRow(),
    };
    const ready = {
      ...waiting,
      status: QuickPrintSessionStatus.ready,
      documentLabel: 'a.pdf',
      pageCount: 1,
      freePagesGranted: 1,
      documents: [
        {
          id: '33333333-3333-3333-3333-333333333333',
          sessionId,
          fileName: 'a.pdf',
          storagePath: '/tmp/a.pdf',
          contentType: 'application/pdf',
          pageCount: 1,
          byteSize: file.size,
          sortOrder: 0,
          createdAt: new Date(),
        },
      ],
    };

    const db = txPassthrough({
      platformSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      quickPrintSession: {
        findUnique: vi
          .fn()
          .mockResolvedValueOnce(waiting)
          .mockResolvedValueOnce(ready)
          .mockResolvedValue(ready),
        update: vi.fn().mockResolvedValue(ready),
      },
    });

    const service = makeService(db);
    const result = await service.uploadDocuments(token, [file], 'bw');
    expect(result.status).toBe('ready');
    expect(result.paymentRequired).toBe(false);
    expect(result.phoneVerified).toBe(true);
  });

  it('requires payment when pages exceed the kiosk free quota', async () => {
    const pdf = await PDFDocument.create();
    for (let i = 0; i < 6; i += 1) pdf.addPage();
    const bytes = Buffer.from(await pdf.save());
    const files = [
      {
        originalname: 'long.pdf',
        mimetype: 'application/pdf',
        size: bytes.length,
        buffer: bytes,
      },
    ];
    const token = 'paid-token';
    const waiting = {
      id: sessionId,
      deviceId,
      tokenHash: hashSecret(token),
      status: QuickPrintSessionStatus.waiting_upload,
      documentLabel: '',
      pageCount: 0,
      freePagesGranted: 0,
      printColorMode: 'bw',
      verifiedPhone: '+919876543210',
      phoneVerifiedAt: new Date(),
      expiresAt: new Date(Date.now() + 600_000),
      printJobId: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      documents: [],
      payment: null,
      device: { ...deviceRow(), freePagesPerSession: 2 },
    };
    const awaiting = {
      ...waiting,
      status: QuickPrintSessionStatus.awaiting_payment,
      pageCount: 6,
      freePagesGranted: 2,
      documentLabel: 'long.pdf',
      documents: [
        {
          id: '33333333-3333-3333-3333-333333333330',
          sessionId,
          fileName: 'long.pdf',
          storagePath: '/tmp/long.pdf',
          contentType: 'application/pdf',
          pageCount: 6,
          byteSize: files[0]!.size,
          sortOrder: 0,
          createdAt: new Date(),
        },
      ],
      payment: {
        id: '44444444-4444-4444-4444-444444444444',
        challengeId: null,
        quickPrintSessionId: sessionId,
        userId: null,
        status: PaymentStatus.PENDING,
        pageCount: 6,
        freePages: 2,
        extraPages: 4,
        printColorMode: 'bw',
        amountPaise: 4000,
        currency: 'INR',
        razorpayOrderId: null,
        razorpayPaymentId: null,
        razorpaySignature: null,
        failureReason: null,
        paidAt: null,
        expiresAt: new Date(Date.now() + 900_000),
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    };

    const db = txPassthrough({
      platformSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      quickPrintSession: {
        findUnique: vi.fn().mockResolvedValueOnce(waiting).mockResolvedValue(awaiting),
        update: vi.fn().mockResolvedValue(awaiting),
      },
    });

    const service = makeService(db);
    const result = await service.uploadDocuments(token, files, 'bw');
    expect(result.status).toBe('awaiting_payment');
    expect(result.paymentRequired).toBe(true);
    expect(result.quote?.amountPaise).toBe(4000);
  });

  it('rejects claim from a different kiosk', async () => {
    const session = {
      id: sessionId,
      deviceId,
      tokenHash: 'hash',
      status: QuickPrintSessionStatus.ready,
      documentLabel: 'a.pdf',
      pageCount: 1,
      freePagesGranted: 1,
      printColorMode: 'bw',
      verifiedPhone: '+919876543210',
      phoneVerifiedAt: new Date(),
      expiresAt: new Date(Date.now() + 600_000),
      printJobId: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      documents: [
        {
          id: '33333333-3333-3333-3333-333333333333',
          sessionId,
          fileName: 'a.pdf',
          storagePath: '/tmp/a.pdf',
          contentType: 'application/pdf',
          pageCount: 1,
          byteSize: 10,
          sortOrder: 0,
          createdAt: new Date(),
        },
      ],
      payment: null,
      device: deviceRow(),
    };

    const service = makeService(
      txPassthrough({
        platformSetting: { findUnique: vi.fn().mockResolvedValue(null) },
        quickPrintSession: { findUnique: vi.fn().mockResolvedValue(session) },
      }),
    );

    await expect(service.claim(otherDeviceId, sessionId)).rejects.toMatchObject({
      code: 'not_found',
    });
  });

  it('claims a ready session and creates a print job', async () => {
    const session = {
      id: sessionId,
      deviceId,
      tokenHash: 'hash',
      status: QuickPrintSessionStatus.ready,
      documentLabel: 'a.pdf',
      pageCount: 1,
      freePagesGranted: 1,
      printColorMode: 'bw',
      verifiedPhone: '+919876543210',
      phoneVerifiedAt: new Date(),
      expiresAt: new Date(Date.now() + 600_000),
      printJobId: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      documents: [
        {
          id: '33333333-3333-3333-3333-333333333333',
          sessionId,
          fileName: 'a.pdf',
          storagePath: '/tmp/a.pdf',
          contentType: 'application/pdf',
          pageCount: 1,
          byteSize: 10,
          sortOrder: 0,
          createdAt: new Date(),
        },
      ],
      payment: null,
      device: deviceRow(),
    };

    const printing = {
      createJob: vi.fn().mockResolvedValue({
        id: '55555555-5555-5555-5555-555555555555',
        status: 'ready',
        source: PrintJobSource.quick_print,
      }),
    };

    const db = txPassthrough({
      platformSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      quickPrintSession: {
        findUnique: vi.fn().mockResolvedValue(session),
        update: vi.fn().mockResolvedValue({ ...session, status: QuickPrintSessionStatus.consumed }),
      },
    });

    const service = new QuickPrintService(
      db as unknown as DbClient,
      makeConfig(),
      { record: vi.fn() } as unknown as AuditService,
      printing as unknown as PrintingService,
      { assertEnabled: vi.fn() } as unknown as ServicesCatalogService,
      {} as RazorpayClient,
      {} as PaymentsService,
      sms,
    );

    const result = await service.claim(deviceId, sessionId);
    expect(result.printJob.id).toBe('55555555-5555-5555-5555-555555555555');
    expect(printing.createJob).toHaveBeenCalledWith(
      expect.objectContaining({ freePagesGranted: 1 }),
      'device',
      deviceId,
      undefined,
    );
  });

  it('cancels an open session', async () => {
    const db = txPassthrough({
      platformSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      quickPrintSession: {
        findUnique: vi.fn().mockResolvedValue({
          id: sessionId,
          deviceId,
          status: QuickPrintSessionStatus.waiting_upload,
        }),
        update: vi.fn().mockResolvedValue({}),
      },
      payment: { updateMany: vi.fn() },
    });
    const service = makeService(db);
    const result = await service.cancel(deviceId, sessionId);
    expect(result.cancelled).toBe(true);
  });
});

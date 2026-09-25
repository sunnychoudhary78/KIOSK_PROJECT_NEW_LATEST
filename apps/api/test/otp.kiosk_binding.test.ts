import { DeviceStatus, OtpChallengeStatus, PrintColorMode } from '@prisma/client';
import { PDFDocument } from 'pdf-lib';
import { describe, expect, it, vi } from 'vitest';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { SmsClient } from '../src/infrastructure/external/sms.client.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { OtpPrintService } from '../src/modules/otp_print/otp_print.service.js';
import type { PrintingService } from '../src/modules/printing/printing.service.js';
import type { ServicesCatalogService } from '../src/modules/services/services.service.js';

const userId = '22222222-2222-2222-2222-222222222222';
const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const otherDeviceId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

function deviceRow() {
  return {
    id: deviceId,
    name: 'Lobby Kiosk',
    status: DeviceStatus.active,
    maxPagesPerSession: 10,
    freePagesPerSession: 1,
    extraPageChargeRupees: 12,
    freeColorPagesPerSession: 0,
    extraColorPageChargeRupees: 20,
  };
}

function makeConfig(): AppConfig {
  return {
    otp: { length: 6, ttlSeconds: 1800 },
    payments: { windowMinutes: 15 },
    razorpay: { keyId: 'rzp_test', keySecret: 'secret' },
  } as AppConfig;
}

describe('OtpPrintService kiosk binding', () => {
  it('rejects create without a deviceId', async () => {
    const service = new OtpPrintService(
      { platformSetting: { findUnique: vi.fn() } } as unknown as DbClient,
      makeConfig(),
      { record: vi.fn() } as unknown as AuditService,
      {} as PrintingService,
      { assertEnabled: vi.fn() } as unknown as ServicesCatalogService,
      {} as SmsClient,
    );

    await expect(service.createChallenge(userId, [], 'Docs')).rejects.toMatchObject({
      code: 'validation_error',
      statusCode: 400,
    });
  });

  it('quotes extra pages from the selected kiosk', async () => {
    const pdf = await PDFDocument.create();
    pdf.addPage();
    const bytes = Buffer.from(await pdf.save());
    const files = [
      {
        originalname: 'a.pdf',
        mimetype: 'application/pdf',
        size: bytes.length,
        buffer: bytes,
      },
      {
        originalname: 'b.pdf',
        mimetype: 'application/pdf',
        size: bytes.length,
        buffer: bytes,
      },
    ];

    const created = {
      id: '11111111-1111-1111-1111-111111111111',
      userId,
      deviceId,
      codeHash: null,
      codeHint: null,
      documentLabel: 'Docs',
      pageCount: 2,
      printColorMode: PrintColorMode.bw,
      attemptCount: 0,
      status: OtpChallengeStatus.awaiting_payment,
      expiresAt: new Date(),
      redeemedAt: null,
      printJobId: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      documents: [],
      payment: {
        printColorMode: PrintColorMode.bw,
        pageCount: 2,
        freePages: 1,
        extraPages: 1,
        amountPaise: 1200,
      },
      device: { id: deviceId, name: 'Lobby Kiosk' },
    };

    const db = {
      device: { findUnique: vi.fn(async () => deviceRow()) },
      user: { findUnique: vi.fn(async () => ({ id: userId, phone: '+919999999999' })) },
      platformSetting: { findUnique: vi.fn(async () => null) },
      otpChallenge: { create: vi.fn(async () => created) },
    };
    const services = { assertEnabled: vi.fn(async () => undefined) };
    const service = new OtpPrintService(
      db as unknown as DbClient,
      makeConfig(),
      { record: vi.fn() } as unknown as AuditService,
      {} as PrintingService,
      services as unknown as ServicesCatalogService,
      {} as SmsClient,
    );

    const result = await service.createChallenge(
      userId,
      files,
      'Docs',
      'corr',
      'bw',
      deviceId,
    );

    expect(services.assertEnabled).toHaveBeenCalledWith(deviceId, 'otp_print');
    expect(result.deviceId).toBe(deviceId);
    expect(result.deviceName).toBe('Lobby Kiosk');
    expect(result.quote.freePages).toBe(1);
    expect(result.quote.extraPages).toBe(1);
    expect(result.quote.chargePerPageRupees).toBe(12);
    expect(result.quote.amountPaise).toBe(1200);
    expect(result.paymentRequired).toBe(true);
    expect(db.otpChallenge.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ deviceId }),
      }),
    );
  });

  it('rejects redeem on a different kiosk without consuming an attempt', async () => {
    const challenge = {
      id: '11111111-1111-1111-1111-111111111111',
      userId,
      deviceId,
      codeHash: 'hash',
      attemptCount: 0,
      status: OtpChallengeStatus.pending,
      expiresAt: new Date(Date.now() + 60_000),
      documents: [{ id: 'd1' }],
      printColorMode: PrintColorMode.bw,
    };
    const db = {
      otpChallenge: {
        findFirst: vi.fn(async () => challenge),
        update: vi.fn(),
      },
      platformSetting: { findUnique: vi.fn(async () => null) },
    };
    const printing = { createJob: vi.fn() };
    const service = new OtpPrintService(
      db as unknown as DbClient,
      makeConfig(),
      { record: vi.fn() } as unknown as AuditService,
      printing as unknown as PrintingService,
      { assertEnabled: vi.fn(async () => undefined) } as unknown as ServicesCatalogService,
      {} as SmsClient,
    );

    await expect(
      service.redeem(otherDeviceId, { code: '123456' }),
    ).rejects.toMatchObject({
      code: 'otp_wrong_kiosk',
      statusCode: 400,
    });
    expect(db.otpChallenge.update).not.toHaveBeenCalled();
    expect(printing.createJob).not.toHaveBeenCalled();
  });
});

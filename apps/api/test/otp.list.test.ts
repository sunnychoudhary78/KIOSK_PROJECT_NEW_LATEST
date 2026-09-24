import { OtpChallengeStatus, PrintColorMode } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { SmsClient } from '../src/infrastructure/external/sms.client.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { OtpPrintService } from '../src/modules/otp_print/otp_print.service.js';
import type { PrintingService } from '../src/modules/printing/printing.service.js';
import type { ServicesCatalogService } from '../src/modules/services/services.service.js';

const ownerId = '22222222-2222-2222-2222-222222222222';
const otherId = '33333333-3333-3333-3333-333333333333';
const createdAt = new Date('2026-09-24T10:00:00.000Z');

function challengeRow(userId: string) {
  return {
    id: '11111111-1111-1111-1111-111111111111',
    userId,
    codeHash: 'secret-hash',
    codeHint: '12',
    documentLabel: 'Certificates',
    pageCount: 3,
    printColorMode: PrintColorMode.bw,
    attemptCount: 0,
    status: OtpChallengeStatus.pending,
    expiresAt: createdAt,
    redeemedAt: null,
    deviceId: null,
    printJobId: null,
    createdAt,
    updatedAt: createdAt,
    documents: [
      {
        id: '44444444-4444-4444-4444-444444444444',
        challengeId: '11111111-1111-1111-1111-111111111111',
        fileName: 'a.pdf',
        storagePath: '/tmp/a.pdf',
        contentType: 'application/pdf',
        pageCount: 3,
        byteSize: 1200,
        sortOrder: 0,
        createdAt,
      },
    ],
    payment: null,
    printJob: null,
  };
}

function makeService(findMany: ReturnType<typeof vi.fn>) {
  const db = {
    otpChallenge: { findMany },
    platformSetting: { findUnique: vi.fn(async () => null) },
  };
  return new OtpPrintService(
    db as unknown as DbClient,
    {} as AppConfig,
    { record: vi.fn() } as unknown as AuditService,
    {} as PrintingService,
    {} as ServicesCatalogService,
    {} as SmsClient,
  );
}

describe('OtpPrintService.listForCitizen', () => {
  it('returns the caller\'s recent sessions without OTP secrets', async () => {
    const findMany = vi.fn(async () => [challengeRow(ownerId)]);
    const service = makeService(findMany);

    const result = await service.listForCitizen(ownerId);

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId: ownerId },
        take: 50,
        orderBy: { createdAt: 'desc' },
      }),
    );
    expect(result.items).toHaveLength(1);
    expect(result.items[0]).toMatchObject({
      id: '11111111-1111-1111-1111-111111111111',
      status: 'pending',
      otpSent: true,
      documentLabel: 'Certificates',
      createdAt: createdAt.toISOString(),
      printJob: null,
    });
    expect(result.items[0]).not.toHaveProperty('codeHash');
    expect(result.items[0]).not.toHaveProperty('codeHint');
  });

  it('returns an empty list when the citizen has no sessions', async () => {
    const service = makeService(vi.fn(async () => []));
    const result = await service.listForCitizen(ownerId);
    expect(result.items).toEqual([]);
  });

  it('scopes the query to the requesting citizen', async () => {
    const findMany = vi.fn(async ({ where }: { where: { userId: string } }) => {
      expect(where.userId).toBe(ownerId);
      expect(where.userId).not.toBe(otherId);
      return [];
    });
    const service = makeService(findMany);
    await service.listForCitizen(ownerId);
    expect(findMany).toHaveBeenCalledTimes(1);
  });
});

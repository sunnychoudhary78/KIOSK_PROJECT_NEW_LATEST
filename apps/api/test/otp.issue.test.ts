import { OtpChallengeStatus, PaymentStatus } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { SmsClient } from '../src/infrastructure/external/sms.client.js';
import { AppError } from '../src/shared/errors.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { OtpPrintService } from '../src/modules/otp_print/otp_print.service.js';
import type { PrintingService } from '../src/modules/printing/printing.service.js';
import type { ServicesCatalogService } from '../src/modules/services/services.service.js';

const challengeId = '11111111-1111-1111-1111-111111111111';
const userId = '22222222-2222-2222-2222-222222222222';

function challenge(overrides: Record<string, unknown> = {}) {
  return {
    id: challengeId,
    userId,
    status: OtpChallengeStatus.awaiting_payment,
    codeHash: null as string | null,
    user: { phone: '9876543210' },
    payment: { status: PaymentStatus.PAID },
    ...overrides,
  };
}

function makeService(db: unknown, sms: SmsClient) {
  return new OtpPrintService(
    db as DbClient,
    { otp: { length: 4, ttlSeconds: 60 } } as AppConfig,
    { record: vi.fn(async () => undefined) } as unknown as AuditService,
    {} as PrintingService,
    {} as ServicesCatalogService,
    sms,
  );
}

describe('issueOtpAndNotify', () => {
  it('stays awaiting payment until the SMS succeeds, then becomes pending', async () => {
    const updates: Array<{ data: Record<string, unknown> }> = [];
    const db = {
      platformSetting: { findUnique: vi.fn(async () => null) },
      otpChallenge: {
        findUnique: vi.fn(async () => challenge()),
        updateMany: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
          updates.push({ data });
          return { count: 1 };
        }),
      },
    };
    const sms = { sendOtp: vi.fn(async () => undefined) } as unknown as SmsClient;
    const service = makeService(db, sms);

    const result = await service.issueOtpAndNotify(challengeId);

    expect(result).toEqual({ issued: true, alreadyIssued: false, challengeId });
    expect(updates[0]?.data).not.toHaveProperty('status');
    expect(updates[0]?.data).toEqual(
      expect.objectContaining({ codeHash: expect.any(String), codeHint: expect.any(String) }),
    );
    expect(updates[1]?.data).toEqual({ status: OtpChallengeStatus.pending });
    expect(sms.sendOtp).toHaveBeenCalledOnce();
  });

  it('clears the claimed code when the SMS fails and does not report it as issued', async () => {
    const updates: Array<{ data: Record<string, unknown> }> = [];
    const db = {
      platformSetting: { findUnique: vi.fn(async () => null) },
      otpChallenge: {
        findUnique: vi.fn(async () => challenge()),
        updateMany: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
          updates.push({ data });
          return { count: 1 };
        }),
      },
    };
    const sms = {
      sendOtp: vi.fn(async () => {
        throw new Error('gateway down');
      }),
    } as unknown as SmsClient;
    const service = makeService(db, sms);

    await expect(service.issueOtpAndNotify(challengeId)).rejects.toMatchObject({
      code: 'sms_failed',
    } satisfies Partial<AppError>);
    expect(updates[1]?.data).toMatchObject({
      codeHash: null,
      codeHint: null,
      status: OtpChallengeStatus.awaiting_payment,
    });
    expect(updates.some((update) => update.data.status === OtpChallengeStatus.pending)).toBe(false);
  });

  it('refuses a second send while a code claim is still in flight', async () => {
    const db = {
      platformSetting: { findUnique: vi.fn(async () => null) },
      otpChallenge: {
        findUnique: vi.fn(async () => challenge({ codeHash: 'held' })),
        updateMany: vi.fn(async () => ({ count: 0 })),
      },
    };
    const sms = { sendOtp: vi.fn(async () => undefined) } as unknown as SmsClient;
    const service = makeService(db, sms);

    await expect(service.issueOtpAndNotify(challengeId)).rejects.toMatchObject({
      code: 'otp_unavailable',
    } satisfies Partial<AppError>);
    expect(sms.sendOtp).not.toHaveBeenCalled();
  });
});

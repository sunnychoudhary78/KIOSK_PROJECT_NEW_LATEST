import { UserRole } from '@prisma/client';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { SmsClient } from '../src/infrastructure/external/sms.client.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { IdentityService } from '../src/modules/identity/identity.service.js';

vi.mock('node:fs/promises', () => ({
  rm: vi.fn(async () => undefined),
  unlink: vi.fn(async () => undefined),
}));

const userId = '22222222-2222-2222-2222-222222222222';
const challengeId = '11111111-1111-1111-1111-111111111111';
const printJobId = '33333333-3333-3333-3333-333333333333';

function makeService(db: DbClient, audit: AuditService) {
  return new IdentityService(db, {} as AppConfig, audit, {} as SmsClient);
}

describe('IdentityService.deleteCitizenAccount', () => {
  const paymentUpdate = vi.fn(async () => ({ count: 1 }));
  const printJobUpdate = vi.fn(async () => ({ count: 1 }));
  const ledgerDelete = vi.fn(async () => ({ count: 1 }));
  const sessionDelete = vi.fn(async () => ({ count: 1 }));
  const challengeDelete = vi.fn(async () => ({ count: 1 }));
  const userUpdate = vi.fn(async () => ({}));
  const auditRecord = vi.fn(async () => undefined);

  const tx = {
    payment: { updateMany: paymentUpdate },
    printJob: { updateMany: printJobUpdate },
    phoneFreePageLedger: { deleteMany: ledgerDelete },
    phoneOtpSession: { deleteMany: sessionDelete },
    otpChallenge: { deleteMany: challengeDelete },
    user: { update: userUpdate },
  };

  const db = {
    user: {
      findUnique: vi.fn(async () => ({
        id: userId,
        phone: '9876543210',
        role: UserRole.citizen,
        isActive: true,
      })),
    },
    otpChallenge: {
      findMany: vi.fn(async () => [
        {
          id: challengeId,
          printJob: { id: printJobId, payloadPath: '/tmp/job.pdf' },
        },
      ]),
    },
    $transaction: vi.fn(async (fn: (client: typeof tx) => Promise<void>) => fn(tx)),
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('detaches payments, removes documents, and deactivates the citizen', async () => {
    const { rm, unlink } = await import('node:fs/promises');
    const service = makeService(db as unknown as DbClient, {
      record: auditRecord,
    } as unknown as AuditService);

    const result = await service.deleteCitizenAccount(userId, 'corr-1');

    expect(result).toEqual({ deleted: true });
    expect(paymentUpdate).toHaveBeenCalledWith({
      where: { OR: [{ userId }, { challengeId: { in: [challengeId] } }] },
      data: { userId: null, challengeId: null },
    });
    expect(printJobUpdate).toHaveBeenCalledWith({
      where: { id: { in: [printJobId] } },
      data: { payloadPath: null, payloadUrl: null },
    });
    expect(ledgerDelete).toHaveBeenCalledWith({ where: { phone: '9876543210' } });
    expect(sessionDelete).toHaveBeenCalledWith({ where: { phone: '9876543210' } });
    expect(challengeDelete).toHaveBeenCalledWith({ where: { userId } });
    expect(userUpdate).toHaveBeenCalledWith({
      where: { id: userId },
      data: { phone: null, isActive: false, displayName: 'Deleted account' },
    });
    expect(paymentUpdate.mock.invocationCallOrder[0]).toBeLessThan(
      challengeDelete.mock.invocationCallOrder[0] ?? 0,
    );
    expect(rm).toHaveBeenCalled();
    expect(unlink).toHaveBeenCalledWith('/tmp/job.pdf');
    expect(auditRecord).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'auth.citizen_account_deleted',
        principalId: userId,
        resourceId: userId,
        correlationId: 'corr-1',
      }),
    );
    expect(JSON.stringify(auditRecord.mock.calls)).not.toContain('9876543210');
  });

  it('rejects non-citizen accounts', async () => {
    db.user.findUnique.mockResolvedValueOnce({
      id: userId,
      phone: '9876543210',
      role: UserRole.admin,
      isActive: true,
    });
    const service = makeService(db as unknown as DbClient, {
      record: auditRecord,
    } as unknown as AuditService);

    await expect(service.deleteCitizenAccount(userId)).rejects.toMatchObject({
      code: 'forbidden',
      statusCode: 403,
    });
    expect(db.$transaction).not.toHaveBeenCalled();
  });
});

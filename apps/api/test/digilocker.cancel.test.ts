import { describe, expect, it, vi } from 'vitest';
import { DigiLockerSessionStatus } from '@prisma/client';
import { DigiLockerService } from '../src/modules/digilocker/digilocker.service.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import type { PrintingService } from '../src/modules/printing/printing.service.js';
import type { ServicesCatalogService } from '../src/modules/services/services.service.js';
import type { DigiLockerClient } from '../src/infrastructure/external/digilocker.types.js';

describe('DigiLockerService.cancelSession', () => {
  const sessionId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const deviceId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  function setup(status: DigiLockerSessionStatus = DigiLockerSessionStatus.authorized) {
    const row = {
      id: sessionId,
      deviceId,
      status,
      authorizationUrl: 'https://example.test/auth',
      expiresAt: new Date(Date.now() + 60_000),
      authorizedAt: new Date(),
      accessToken: 'tok',
      idToken: 'idtok',
      tokenExpiresAt: new Date(Date.now() + 60_000),
    };
    const db = {
      digiLockerSession: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          ...row,
          ...data,
        })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DigiLockerService(
      db as unknown as DbClient,
      {} as DigiLockerClient,
      audit as unknown as AuditService,
      {} as PrintingService,
      {} as ServicesCatalogService,
    );
    return { service, db, audit, row };
  }

  it('marks the session expired and clears tokens', async () => {
    const { service, db, audit } = setup();
    const result = await service.cancelSession(sessionId, deviceId, 'corr-1');
    expect(result.status).toBe(DigiLockerSessionStatus.expired);
    expect(db.digiLockerSession.update).toHaveBeenCalledWith({
      where: { id: sessionId },
      data: {
        status: DigiLockerSessionStatus.expired,
        accessToken: null,
        idToken: null,
        tokenExpiresAt: null,
      },
    });
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'digilocker.session_cancelled',
        principalId: deviceId,
        resourceId: sessionId,
        correlationId: 'corr-1',
      }),
    );
  });

  it('is a no-op when already expired', async () => {
    const { service, db, audit } = setup(DigiLockerSessionStatus.expired);
    const result = await service.cancelSession(sessionId, deviceId);
    expect(result.status).toBe(DigiLockerSessionStatus.expired);
    expect(db.digiLockerSession.update).not.toHaveBeenCalled();
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('rejects another device', async () => {
    const { service } = setup();
    await expect(service.cancelSession(sessionId, 'other-device')).rejects.toMatchObject({
      code: 'forbidden',
      statusCode: 403,
    });
  });
});

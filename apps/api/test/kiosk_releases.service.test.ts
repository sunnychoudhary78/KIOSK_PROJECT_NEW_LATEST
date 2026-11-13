import { describe, expect, it, vi } from 'vitest';
import { KioskAppReleaseStatus } from '@prisma/client';
import { KioskReleasesService } from '../src/modules/kiosk_releases/kiosk_releases.service.js';
import { AppError } from '../src/shared/errors.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { ObjectStorageClient } from '../src/infrastructure/storage/s3.client.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';

const releaseId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const adminId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const objectKey = 'kiosk-releases/1.2.0/cccccccc-cccc-cccc-cccc-cccccccccccc.zip';
const sha256 = 'a'.repeat(64);

const baseRelease = {
  id: releaseId,
  version: '1.2.0',
  objectKey,
  contentType: 'application/zip',
  byteSize: BigInt(2048),
  sha256,
  status: KioskAppReleaseStatus.pending_upload,
  createdByAdminId: adminId,
  uploadedAt: null as Date | null,
  activatedAt: null as Date | null,
  createdAt: new Date('2026-04-10T12:00:00.000Z'),
  updatedAt: new Date('2026-04-10T12:00:00.000Z'),
};

function storageMock(overrides: Partial<ObjectStorageClient> = {}): ObjectStorageClient {
  return {
    isConfigured: () => true,
    presignPut: vi.fn(async () => ({
      url: 'https://r2.example/put',
      expiresAt: new Date('2026-04-10T13:00:00.000Z'),
    })),
    presignGet: vi.fn(async () => ({
      url: 'https://r2.example/get',
      expiresAt: new Date('2026-04-10T12:15:00.000Z'),
    })),
    headObject: vi.fn(async () => ({ contentLength: 2048 })),
    deleteObject: vi.fn(async () => undefined),
    ...overrides,
  };
}

describe('KioskReleasesService.complete', () => {
  it('marks uploaded after HeadObject size matches', async () => {
    const update = vi.fn(async () => ({
      ...baseRelease,
      status: KioskAppReleaseStatus.uploaded,
      uploadedAt: new Date('2026-04-10T12:05:00.000Z'),
    }));
    const audit = { record: vi.fn(async () => undefined) };
    const service = new KioskReleasesService(
      {
        kioskAppRelease: {
          findUnique: vi.fn(async () => baseRelease),
          update,
        },
      } as unknown as DbClient,
      storageMock(),
      audit as unknown as AuditService,
    );

    const result = await service.complete(releaseId, adminId, 'corr');
    expect(result.release.status).toBe(KioskAppReleaseStatus.uploaded);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'kiosk_release.completed' }),
    );
  });

  it('rejects when the object is missing', async () => {
    const service = new KioskReleasesService(
      {
        kioskAppRelease: {
          findUnique: vi.fn(async () => baseRelease),
        },
      } as unknown as DbClient,
      storageMock({ headObject: vi.fn(async () => null) }),
      { record: vi.fn() } as unknown as AuditService,
    );

    await expect(service.complete(releaseId, adminId)).rejects.toBeInstanceOf(AppError);
    await expect(service.complete(releaseId, adminId)).rejects.toMatchObject({
      code: 'upload_incomplete',
      statusCode: 409,
    });
  });

  it('rejects a size mismatch and deletes the bad object', async () => {
    const deleteObject = vi.fn(async () => undefined);
    const service = new KioskReleasesService(
      {
        kioskAppRelease: {
          findUnique: vi.fn(async () => baseRelease),
        },
      } as unknown as DbClient,
      storageMock({
        headObject: vi.fn(async () => ({ contentLength: 99 })),
        deleteObject,
      }),
      { record: vi.fn() } as unknown as AuditService,
    );

    await expect(service.complete(releaseId, adminId)).rejects.toMatchObject({
      code: 'size_mismatch',
      statusCode: 409,
    });
    expect(deleteObject).toHaveBeenCalledWith(objectKey);
  });
});

describe('KioskReleasesService.activate', () => {
  it('demotes the previous active release and activates the target', async () => {
    const uploaded = {
      ...baseRelease,
      status: KioskAppReleaseStatus.uploaded,
      uploadedAt: new Date('2026-04-10T12:05:00.000Z'),
    };
    const updateMany = vi.fn(async () => ({ count: 1 }));
    const update = vi.fn(async () => ({
      ...uploaded,
      status: KioskAppReleaseStatus.active,
      activatedAt: new Date('2026-04-10T12:10:00.000Z'),
    }));
    const audit = { record: vi.fn(async () => undefined) };
    const service = new KioskReleasesService(
      {
        kioskAppRelease: {
          findUnique: vi.fn(async () => uploaded),
        },
        $transaction: vi.fn(async (fn: (tx: unknown) => Promise<unknown>) =>
          fn({
            kioskAppRelease: { updateMany, update },
          }),
        ),
      } as unknown as DbClient,
      storageMock(),
      audit as unknown as AuditService,
    );

    const result = await service.activate(releaseId, adminId, 'corr');
    expect(result.release.status).toBe(KioskAppReleaseStatus.active);
    expect(updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { status: KioskAppReleaseStatus.active },
        data: { status: KioskAppReleaseStatus.uploaded, activatedAt: null },
      }),
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'kiosk_release.activated' }),
    );
  });

  it('rejects pending uploads', async () => {
    const service = new KioskReleasesService(
      {
        kioskAppRelease: {
          findUnique: vi.fn(async () => baseRelease),
        },
      } as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );

    await expect(service.activate(releaseId, adminId)).rejects.toMatchObject({
      code: 'invalid_state',
      statusCode: 409,
    });
  });
});

describe('KioskReleasesService.getCurrentUpdate', () => {
  it('returns 503 when the update key is empty', async () => {
    const service = new KioskReleasesService(
      {} as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.getCurrentUpdate('')).rejects.toMatchObject({
      code: 'update_key_not_configured',
      statusCode: 503,
    });
  });

  it('returns 404 when no active release exists', async () => {
    const service = new KioskReleasesService(
      {
        kioskAppRelease: {
          findFirst: vi.fn(async () => null),
        },
      } as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.getCurrentUpdate('secret')).rejects.toMatchObject({
      code: 'not_found',
      statusCode: 404,
    });
  });

  it('returns version and presigned download URL for the active release', async () => {
    const active = {
      ...baseRelease,
      status: KioskAppReleaseStatus.active,
      uploadedAt: new Date('2026-04-10T12:05:00.000Z'),
      activatedAt: new Date('2026-04-10T12:10:00.000Z'),
    };
    const storage = storageMock();
    const service = new KioskReleasesService(
      {
        kioskAppRelease: {
          findFirst: vi.fn(async () => active),
        },
      } as unknown as DbClient,
      storage,
      { record: vi.fn() } as unknown as AuditService,
    );

    const result = await service.getCurrentUpdate('secret');
    expect(result).toEqual({
      version: '1.2.0',
      downloadUrl: 'https://r2.example/get',
      sha256,
      byteSize: 2048,
      expiresAt: '2026-04-10T12:15:00.000Z',
    });
    expect(storage.presignGet).toHaveBeenCalledWith({ key: objectKey });
  });
});

describe('KioskReleasesService.remove', () => {
  it('blocks deleting the active release', async () => {
    const service = new KioskReleasesService(
      {
        kioskAppRelease: {
          findUnique: vi.fn(async () => ({
            ...baseRelease,
            status: KioskAppReleaseStatus.active,
          })),
        },
      } as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.remove(releaseId, adminId)).rejects.toMatchObject({
      code: 'invalid_state',
      statusCode: 409,
    });
  });
});

import { describe, expect, it, vi } from 'vitest';
import { SurveillanceSegmentStatus } from '@prisma/client';
import {
  SurveillanceService,
  surveillanceRetentionCutoff,
} from '../src/modules/surveillance/surveillance.service.js';
import { AppError } from '../src/shared/errors.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { ObjectStorageClient } from '../src/infrastructure/storage/s3.client.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { SURVEILLANCE_RETENTION_DAYS } from '../src/modules/surveillance/surveillance.constants.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const otherDevice = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const tenantId = '11111111-1111-1111-1111-111111111111';
const segmentId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const objectKey = `surveillance/${tenantId}/${deviceId}/2026-09-03/143052_abc.mp4`;
const adminId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

const body = {
  filename: '143052_abc.mp4',
  bytes: 2048,
  contentType: 'video/mp4' as const,
  recordedOn: '2026-09-03',
};

function storageMock(overrides: Partial<ObjectStorageClient> = {}): ObjectStorageClient {
  return {
    isConfigured: () => true,
    presignPut: vi.fn(async () => ({
      url: 'https://r2.example/put',
      expiresAt: new Date('2026-09-03T15:00:00.000Z'),
    })),
    presignGet: vi.fn(async () => ({
      url: 'https://r2.example/get',
      expiresAt: new Date('2026-09-03T15:15:00.000Z'),
    })),
    headObject: vi.fn(async () => ({ contentLength: 2048 })),
    deleteObject: vi.fn(async () => undefined),
    ...overrides,
  };
}

describe('SurveillanceService.createUploadUrl', () => {
  it('rejects a different device principal', async () => {
    const service = new SurveillanceService(
      {} as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.createUploadUrl(deviceId, otherDevice, body)).rejects.toMatchObject({
      code: 'forbidden',
      statusCode: 403,
    });
  });

  it('returns 503 when object storage is not configured', async () => {
    const service = new SurveillanceService(
      {} as DbClient,
      storageMock({ isConfigured: () => false }),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.createUploadUrl(deviceId, deviceId, body)).rejects.toBeInstanceOf(AppError);
    await expect(service.createUploadUrl(deviceId, deviceId, body)).rejects.toMatchObject({
      code: 'storage_not_configured',
      statusCode: 503,
    });
  });

  it('creates a pending row and returns a presigned PUT URL', async () => {
    const create = vi.fn(async () => ({
      id: segmentId,
      deviceId,
      objectKey,
      filename: body.filename,
      byteSize: BigInt(2048),
      status: SurveillanceSegmentStatus.pending_upload,
    }));
    const db = {
      device: { findUnique: vi.fn(async () => ({ id: deviceId, tenantId })) },
      surveillanceSegment: {
        findUnique: vi.fn(async () => null),
        create,
      },
    };
    const storage = storageMock();
    const audit = { record: vi.fn(async () => undefined) };
    const service = new SurveillanceService(
      db as unknown as DbClient,
      storage,
      audit as unknown as AuditService,
    );
    const result = await service.createUploadUrl(deviceId, deviceId, body, 'corr');
    expect(result).toMatchObject({
      segmentId,
      objectKey,
      uploadUrl: 'https://r2.example/put',
      alreadyUploaded: false,
    });
    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          recordedOn: new Date('2026-09-03T00:00:00.000Z'),
          startedAt: new Date('2026-09-03T14:30:52.000Z'),
        }),
      }),
    );
    expect(storage.presignPut).toHaveBeenCalledWith({
      key: objectKey,
      contentType: 'video/mp4',
    });
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'surveillance.upload_url' }),
    );
  });

  it('returns alreadyUploaded without a new PUT when the segment is stored', async () => {
    const storage = storageMock();
    const db = {
      device: { findUnique: vi.fn(async () => ({ id: deviceId, tenantId })) },
      surveillanceSegment: {
        findUnique: vi.fn(async () => ({
          id: segmentId,
          deviceId,
          objectKey,
          status: SurveillanceSegmentStatus.uploaded,
        })),
      },
    };
    const service = new SurveillanceService(
      db as unknown as DbClient,
      storage,
      { record: vi.fn() } as unknown as AuditService,
    );
    const result = await service.createUploadUrl(deviceId, deviceId, body);
    expect(result).toEqual({ segmentId, objectKey, alreadyUploaded: true });
    expect(storage.presignPut).not.toHaveBeenCalled();
  });

  it('reissues upload-url without clearing lastUploadError on pending rows', async () => {
    const update = vi.fn(async () => undefined);
    const storage = storageMock();
    const db = {
      device: { findUnique: vi.fn(async () => ({ id: deviceId, tenantId })) },
      surveillanceSegment: {
        findUnique: vi.fn(async () => ({
          id: segmentId,
          deviceId,
          objectKey,
          status: SurveillanceSegmentStatus.pending_upload,
          lastUploadError: 'upload_incomplete',
        })),
        update,
      },
    };
    const service = new SurveillanceService(
      db as unknown as DbClient,
      storage,
      { record: vi.fn() } as unknown as AuditService,
    );
    const result = await service.createUploadUrl(deviceId, deviceId, body);
    expect(result).toMatchObject({
      segmentId,
      uploadUrl: 'https://r2.example/put',
      alreadyUploaded: false,
    });
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: segmentId },
        data: expect.not.objectContaining({ lastUploadError: null }),
      }),
    );
    const data = update.mock.calls[0][0].data as Record<string, unknown>;
    expect(data).not.toHaveProperty('lastUploadError');
  });
});

describe('SurveillanceService.complete', () => {
  const pending = {
    id: segmentId,
    deviceId,
    objectKey,
    byteSize: BigInt(2048),
    status: SurveillanceSegmentStatus.pending_upload,
  };

  it('marks uploaded after HeadObject size matches', async () => {
    const db = {
      surveillanceSegment: {
        findUnique: vi.fn(async () => pending),
        update: vi.fn(async () => ({ ...pending, status: SurveillanceSegmentStatus.uploaded })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new SurveillanceService(
      db as unknown as DbClient,
      storageMock(),
      audit as unknown as AuditService,
    );
    const result = await service.complete(deviceId, deviceId, segmentId, 'corr');
    expect(result).toEqual({ ok: true, status: SurveillanceSegmentStatus.uploaded });
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'surveillance.segment_uploaded' }),
    );
  });

  it('rejects a size mismatch and deletes the bad object', async () => {
    const deleteObject = vi.fn(async () => undefined);
    const update = vi.fn(async () => pending);
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findUnique: vi.fn(async () => pending),
          update,
        },
      } as unknown as DbClient,
      storageMock({
        headObject: vi.fn(async () => ({ contentLength: 99 })),
        deleteObject,
      }),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.complete(deviceId, deviceId, segmentId)).rejects.toMatchObject({
      code: 'size_mismatch',
      statusCode: 400,
    });
    expect(deleteObject).toHaveBeenCalledWith(objectKey);
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { lastUploadError: 'size_mismatch' },
      }),
    );
  });

  it('is idempotent when already uploaded', async () => {
    const headObject = vi.fn();
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findUnique: vi.fn(async () => ({
            ...pending,
            status: SurveillanceSegmentStatus.uploaded,
          })),
        },
      } as unknown as DbClient,
      storageMock({ headObject }),
      { record: vi.fn() } as unknown as AuditService,
    );
    const result = await service.complete(deviceId, deviceId, segmentId);
    expect(result).toEqual({ ok: true, status: SurveillanceSegmentStatus.uploaded });
    expect(headObject).not.toHaveBeenCalled();
  });

  it('rejects another device completing this segment', async () => {
    const service = new SurveillanceService(
      {} as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.complete(deviceId, otherDevice, segmentId)).rejects.toMatchObject({
      code: 'forbidden',
      statusCode: 403,
    });
  });
});

describe('SurveillanceService.listSegments', () => {
  it('returns uploaded and pending segments for the day ordered by startedAt', async () => {
    const findMany = vi.fn(async () => [
      {
        id: segmentId,
        filename: '143052_abc.mp4',
        recordedOn: new Date('2026-09-03T00:00:00.000Z'),
        startedAt: new Date('2026-09-03T14:30:52.000Z'),
        byteSize: BigInt(1600),
        status: SurveillanceSegmentStatus.uploaded,
        uploadedAt: new Date('2026-09-03T14:41:00.000Z'),
        updatedAt: new Date('2026-09-03T14:41:00.000Z'),
        lastUploadError: null,
      },
      {
        id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
        filename: '144052_def.mp4',
        recordedOn: new Date('2026-09-03T00:00:00.000Z'),
        startedAt: new Date('2026-09-03T14:40:52.000Z'),
        byteSize: BigInt(2048),
        status: SurveillanceSegmentStatus.pending_upload,
        uploadedAt: null,
        updatedAt: new Date(),
        lastUploadError: 'size_mismatch',
      },
    ]);
    const db = {
      device: { findUnique: vi.fn(async () => ({ id: deviceId })) },
      surveillanceSegment: { findMany },
    };
    const service = new SurveillanceService(
      db as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );
    const result = await service.listSegments(deviceId, {
      recordedOn: '2026-09-03',
      status: 'all',
    });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          deviceId,
          recordedOn: new Date('2026-09-03T00:00:00.000Z'),
        },
        orderBy: { startedAt: 'asc' },
      }),
    );
    expect(result.items).toHaveLength(2);
    expect(result.items[0]).toMatchObject({
      id: segmentId,
      status: 'uploaded',
      lastUploadError: null,
    });
    expect(result.items[1]).toMatchObject({
      id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      status: 'pending_upload',
      lastUploadError: 'size_mismatch',
    });
  });

  it('returns 404 when device is missing', async () => {
    const service = new SurveillanceService(
      {
        device: { findUnique: vi.fn(async () => null) },
      } as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(
      service.listSegments(deviceId, { recordedOn: '2026-09-03', status: 'all' }),
    ).rejects.toMatchObject({ code: 'not_found', statusCode: 404 });
  });
});

describe('SurveillanceService.createPlaybackUrl', () => {
  it('returns a presigned GET URL for an uploaded segment', async () => {
    const storage = storageMock();
    const audit = { record: vi.fn(async () => undefined) };
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findUnique: vi.fn(async () => ({
            id: segmentId,
            deviceId,
            objectKey,
            status: SurveillanceSegmentStatus.uploaded,
          })),
        },
      } as unknown as DbClient,
      storage,
      audit as unknown as AuditService,
    );
    const result = await service.createPlaybackUrl(deviceId, segmentId, adminId, 'corr');
    expect(result).toEqual({
      url: 'https://r2.example/get',
      expiresAt: '2026-09-03T15:15:00.000Z',
    });
    expect(storage.headObject).toHaveBeenCalledWith(objectKey);
    expect(storage.presignGet).toHaveBeenCalledWith({ key: objectKey });
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'surveillance.playback', principalId: adminId }),
    );
  });

  it('rejects when the object is missing from storage', async () => {
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findUnique: vi.fn(async () => ({
            id: segmentId,
            deviceId,
            objectKey,
            status: SurveillanceSegmentStatus.uploaded,
          })),
        },
      } as unknown as DbClient,
      storageMock({ headObject: vi.fn(async () => null) }),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.createPlaybackUrl(deviceId, segmentId, adminId)).rejects.toMatchObject({
      code: 'object_missing',
      statusCode: 404,
    });
  });

  it('rejects pending segments', async () => {
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findUnique: vi.fn(async () => ({
            id: segmentId,
            deviceId,
            objectKey,
            status: SurveillanceSegmentStatus.pending_upload,
          })),
        },
      } as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.createPlaybackUrl(deviceId, segmentId, adminId)).rejects.toMatchObject({
      code: 'not_ready',
      statusCode: 409,
    });
  });

  it('rejects a segment from another device', async () => {
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findUnique: vi.fn(async () => ({
            id: segmentId,
            deviceId: otherDevice,
            objectKey,
            status: SurveillanceSegmentStatus.uploaded,
          })),
        },
      } as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.createPlaybackUrl(deviceId, segmentId, adminId)).rejects.toMatchObject({
      code: 'not_found',
      statusCode: 404,
    });
  });
});

describe('SurveillanceService.purgeOlderThan', () => {
  const oldId = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
  const oldKey = 'surveillance/t/d/2026-01-01/old.mp4';

  it('computes UTC cutoff as today minus retention days', () => {
    const now = new Date('2026-11-13T15:30:00.000Z');
    expect(surveillanceRetentionCutoff(SURVEILLANCE_RETENTION_DAYS, now)).toEqual(
      new Date('2026-11-06T00:00:00.000Z'),
    );
  });

  it('deletes R2 object then DB row for expired segments', async () => {
    const findMany = vi
      .fn()
      .mockResolvedValueOnce([{ id: oldId, objectKey: oldKey }])
      .mockResolvedValueOnce([]);
    const deleteMany = vi.fn(async () => ({ count: 1 }));
    const storage = storageMock();
    const service = new SurveillanceService(
      {
        surveillanceSegment: { findMany, deleteMany },
      } as unknown as DbClient,
      storage,
      { record: vi.fn() } as unknown as AuditService,
    );

    const result = await service.purgeOlderThan();
    expect(result).toEqual({ deleted: 1, failed: 0 });
    expect(storage.deleteObject).toHaveBeenCalledWith(oldKey);
    expect(deleteMany).toHaveBeenCalledWith({
      where: { id: { in: [oldId] } },
    });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { recordedOn: { lt: expect.any(Date) } },
      }),
    );
  });

  it('keeps the DB row when R2 delete fails', async () => {
    const deleteMany = vi.fn(async () => ({ count: 0 }));
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findMany: vi.fn(async () => [{ id: oldId, objectKey: oldKey }]),
          deleteMany,
        },
      } as unknown as DbClient,
      storageMock({
        deleteObject: vi.fn(async () => {
          throw new Error('r2 unavailable');
        }),
      }),
      { record: vi.fn() } as unknown as AuditService,
    );

    const result = await service.purgeOlderThan();
    expect(result).toEqual({ deleted: 0, failed: 1 });
    expect(deleteMany).not.toHaveBeenCalled();
  });

  it('removes the DB row when the object is already missing', async () => {
    const deleteMany = vi.fn(async () => ({ count: 1 }));
    const notFound = Object.assign(new Error('missing'), {
      name: 'NoSuchKey',
      $metadata: { httpStatusCode: 404 },
    });
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findMany: vi
            .fn()
            .mockResolvedValueOnce([{ id: oldId, objectKey: oldKey }])
            .mockResolvedValueOnce([]),
          deleteMany,
        },
      } as unknown as DbClient,
      storageMock({
        deleteObject: vi.fn(async () => {
          throw notFound;
        }),
      }),
      { record: vi.fn() } as unknown as AuditService,
    );

    const result = await service.purgeOlderThan();
    expect(result).toEqual({ deleted: 1, failed: 0 });
    expect(deleteMany).toHaveBeenCalledWith({
      where: { id: { in: [oldId] } },
    });
  });

  it('deletes DB rows only when object storage is not configured', async () => {
    const deleteMany = vi.fn(async () => ({ count: 1 }));
    const deleteObject = vi.fn(async () => undefined);
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findMany: vi
            .fn()
            .mockResolvedValueOnce([{ id: oldId, objectKey: oldKey }])
            .mockResolvedValueOnce([]),
          deleteMany,
        },
      } as unknown as DbClient,
      storageMock({
        isConfigured: () => false,
        deleteObject,
      }),
      { record: vi.fn() } as unknown as AuditService,
    );

    const result = await service.purgeOlderThan();
    expect(result).toEqual({ deleted: 1, failed: 0 });
    expect(deleteObject).not.toHaveBeenCalled();
    expect(deleteMany).toHaveBeenCalled();
  });
});

describe('SurveillanceService.dismissSegment', () => {
  const pendingRow = {
    id: segmentId,
    deviceId,
    objectKey,
    filename: body.filename,
    status: SurveillanceSegmentStatus.pending_upload,
    lastUploadError: 'size_mismatch',
  };

  it('deletes storage object and DB row for pending segment', async () => {
    const findUnique = vi.fn(async () => pendingRow);
    const del = vi.fn(async () => pendingRow);
    const record = vi.fn(async () => undefined);
    const storage = storageMock();
    const service = new SurveillanceService(
      { surveillanceSegment: { findUnique, delete: del } } as unknown as DbClient,
      storage,
      { record } as unknown as AuditService,
    );

    await expect(service.dismissSegment(deviceId, segmentId, adminId)).resolves.toEqual({
      ok: true,
    });
    expect(storage.deleteObject).toHaveBeenCalledWith(objectKey);
    expect(del).toHaveBeenCalledWith({ where: { id: segmentId } });
    expect(record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'surveillance.segment_dismiss',
        resourceId: segmentId,
        metadata: expect.objectContaining({
          filename: body.filename,
          objectKey,
          lastUploadError: 'size_mismatch',
        }),
      }),
    );
  });

  it('rejects uploaded segments with 409', async () => {
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findUnique: vi.fn(async () => ({
            ...pendingRow,
            status: SurveillanceSegmentStatus.uploaded,
            lastUploadError: null,
          })),
          delete: vi.fn(),
        },
      } as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );

    await expect(service.dismissSegment(deviceId, segmentId, adminId)).rejects.toMatchObject({
      code: 'already_uploaded',
      statusCode: 409,
    });
  });

  it('returns 404 for missing or wrong-device segment', async () => {
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findUnique: vi.fn(async () => ({ ...pendingRow, deviceId: otherDevice })),
          delete: vi.fn(),
        },
      } as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );

    await expect(service.dismissSegment(deviceId, segmentId, adminId)).rejects.toMatchObject({
      code: 'not_found',
      statusCode: 404,
    });
  });

  it('still deletes the DB row when storage delete fails', async () => {
    const del = vi.fn(async () => pendingRow);
    const service = new SurveillanceService(
      {
        surveillanceSegment: {
          findUnique: vi.fn(async () => pendingRow),
          delete: del,
        },
      } as unknown as DbClient,
      storageMock({
        deleteObject: vi.fn(async () => {
          throw new Error('r2 unavailable');
        }),
      }),
      { record: vi.fn() } as unknown as AuditService,
    );

    await expect(service.dismissSegment(deviceId, segmentId, adminId)).resolves.toEqual({
      ok: true,
    });
    expect(del).toHaveBeenCalled();
  });
});

describe('SurveillanceService.dismissOrphans', () => {
  it('dismisses only pending rows with lastUploadError and returns count', async () => {
    const orphanA = {
      id: 'orphan-a',
      objectKey: `${objectKey}.a`,
      filename: 'a.mp4',
      lastUploadError: 'size_mismatch',
    };
    const orphanB = {
      id: 'orphan-b',
      objectKey: `${objectKey}.b`,
      filename: 'b.mp4',
      lastUploadError: 'upload_incomplete',
    };
    const findMany = vi.fn(async () => [orphanA, orphanB]);
    const del = vi.fn(async () => undefined);
    const record = vi.fn(async () => undefined);
    const storage = storageMock();
    const service = new SurveillanceService(
      {
        device: { findUnique: vi.fn(async () => ({ id: deviceId })) },
        surveillanceSegment: { findMany, delete: del },
      } as unknown as DbClient,
      storage,
      { record } as unknown as AuditService,
    );

    await expect(
      service.dismissOrphans(deviceId, { recordedOn: '2026-09-03' }, adminId),
    ).resolves.toEqual({ ok: true, dismissed: 2 });

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          deviceId,
          status: SurveillanceSegmentStatus.pending_upload,
          lastUploadError: { not: null },
        }),
      }),
    );
    expect(storage.deleteObject).toHaveBeenCalledTimes(2);
    expect(del).toHaveBeenCalledTimes(2);
    expect(record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'surveillance.segments_dismiss_orphans',
        metadata: expect.objectContaining({
          recordedOn: '2026-09-03',
          dismissed: 2,
        }),
      }),
    );
  });

  it('returns dismissed 0 when no errored pending rows exist', async () => {
    const del = vi.fn();
    const service = new SurveillanceService(
      {
        device: { findUnique: vi.fn(async () => ({ id: deviceId })) },
        surveillanceSegment: { findMany: vi.fn(async () => []), delete: del },
      } as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );

    await expect(
      service.dismissOrphans(deviceId, { recordedOn: '2026-09-03' }, adminId),
    ).resolves.toEqual({ ok: true, dismissed: 0 });
    expect(del).not.toHaveBeenCalled();
  });

  it('returns 404 when device is missing', async () => {
    const service = new SurveillanceService(
      {
        device: { findUnique: vi.fn(async () => null) },
        surveillanceSegment: { findMany: vi.fn(), delete: vi.fn() },
      } as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );

    await expect(
      service.dismissOrphans(deviceId, { recordedOn: '2026-09-03' }, adminId),
    ).rejects.toMatchObject({
      code: 'not_found',
      statusCode: 404,
    });
  });
});

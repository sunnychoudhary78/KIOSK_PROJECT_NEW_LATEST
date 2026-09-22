import { describe, expect, it, vi } from 'vitest';
import { SurveillanceSegmentStatus } from '@prisma/client';
import { SurveillanceService } from '../src/modules/surveillance/surveillance.service.js';
import { AppError } from '../src/shared/errors.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { ObjectStorageClient } from '../src/infrastructure/storage/s3.client.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const otherDevice = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const tenantId = '11111111-1111-1111-1111-111111111111';
const segmentId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const objectKey = `surveillance/${tenantId}/${deviceId}/2026-09-03/143052_abc.mp4`;
const adminId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

const body = {
  filename: '143052_abc.mp4',
  bytes: 16,
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
    headObject: vi.fn(async () => ({ contentLength: 16 })),
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
      byteSize: BigInt(16),
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
});

describe('SurveillanceService.complete', () => {
  const pending = {
    id: segmentId,
    deviceId,
    objectKey,
    byteSize: BigInt(16),
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

  it('rejects a size mismatch', async () => {
    const service = new SurveillanceService(
      {
        surveillanceSegment: { findUnique: vi.fn(async () => pending) },
      } as unknown as DbClient,
      storageMock({ headObject: vi.fn(async () => ({ contentLength: 99 })) }),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.complete(deviceId, deviceId, segmentId)).rejects.toMatchObject({
      code: 'size_mismatch',
      statusCode: 400,
    });
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
  it('returns uploaded segments for the day ordered by startedAt', async () => {
    const findMany = vi.fn(async () => [
      {
        id: segmentId,
        filename: '143052_abc.mp4',
        recordedOn: new Date('2026-09-03T00:00:00.000Z'),
        startedAt: new Date('2026-09-03T14:30:52.000Z'),
        byteSize: BigInt(1600),
        uploadedAt: new Date('2026-09-03T14:41:00.000Z'),
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
    const result = await service.listSegments(deviceId, { recordedOn: '2026-09-03' });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          deviceId,
          recordedOn: new Date('2026-09-03T00:00:00.000Z'),
          status: SurveillanceSegmentStatus.uploaded,
        },
        orderBy: { startedAt: 'asc' },
      }),
    );
    expect(result).toEqual({
      items: [
        {
          id: segmentId,
          filename: '143052_abc.mp4',
          recordedOn: '2026-09-03',
          startedAt: '2026-09-03T14:30:52.000Z',
          byteSize: 1600,
          uploadedAt: '2026-09-03T14:41:00.000Z',
        },
      ],
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
      service.listSegments(deviceId, { recordedOn: '2026-09-03' }),
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
    expect(storage.presignGet).toHaveBeenCalledWith({ key: objectKey });
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'surveillance.playback', principalId: adminId }),
    );
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

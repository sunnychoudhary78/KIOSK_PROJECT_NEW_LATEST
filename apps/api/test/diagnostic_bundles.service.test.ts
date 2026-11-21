import { describe, expect, it, vi } from 'vitest';
import { DeviceDiagnosticBundleStatus } from '@prisma/client';
import { DiagnosticBundlesService } from '../src/modules/diagnostic_bundles/diagnostic_bundles.service.js';
import { AppError } from '../src/shared/errors.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { ObjectStorageClient } from '../src/infrastructure/storage/s3.client.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const otherDevice = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const tenantId = '11111111-1111-1111-1111-111111111111';
const commandId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
const bundleId = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
const adminId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

function storageMock(overrides: Partial<ObjectStorageClient> = {}): ObjectStorageClient {
  return {
    isConfigured: () => true,
    presignPut: vi.fn(async () => ({
      url: 'https://r2.example/put',
      expiresAt: new Date('2026-11-21T15:00:00.000Z'),
    })),
    presignGet: vi.fn(async () => ({
      url: 'https://r2.example/get',
      expiresAt: new Date('2026-11-21T15:15:00.000Z'),
    })),
    headObject: vi.fn(async () => ({ contentLength: 2048 })),
    deleteObject: vi.fn(async () => undefined),
    ...overrides,
  };
}

describe('DiagnosticBundlesService.createUploadUrl', () => {
  it('rejects a different device principal', async () => {
    const service = new DiagnosticBundlesService(
      {} as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(
      service.createUploadUrl(deviceId, otherDevice, {
        commandId,
        bytes: 2048,
        contentType: 'application/zip',
      }),
    ).rejects.toMatchObject({ code: 'forbidden', statusCode: 403 });
  });

  it('creates a pending bundle and returns a presigned PUT URL', async () => {
    const create = vi.fn(async ({ data }: { data: { id: string; objectKey: string } }) => ({
      id: data.id,
      deviceId,
      commandId,
      objectKey: data.objectKey,
      byteSize: BigInt(2048),
      contentType: 'application/zip',
      status: DeviceDiagnosticBundleStatus.pending_upload,
      uploadedAt: null,
      expiresAt: new Date('2026-11-28T00:00:00.000Z'),
      createdAt: new Date(),
      updatedAt: new Date(),
    }));
    const db = {
      device: { findUnique: vi.fn(async () => ({ id: deviceId, tenantId })) },
      deviceSurveillanceCommand: {
        findUnique: vi.fn(async () => ({
          id: commandId,
          deviceId,
          type: 'collect_diagnostics',
        })),
      },
      deviceDiagnosticBundle: {
        findMany: vi.fn(async () => []),
        create,
        delete: vi.fn(),
      },
    };
    const storage = storageMock();
    const record = vi.fn(async () => undefined);
    const service = new DiagnosticBundlesService(
      db as unknown as DbClient,
      storage,
      { record } as unknown as AuditService,
    );

    const result = await service.createUploadUrl(deviceId, deviceId, {
      commandId,
      bytes: 2048,
      contentType: 'application/zip',
    });

    expect(result.bundleId).toBeTruthy();
    expect(result.uploadUrl).toBe('https://r2.example/put');
    expect(result.objectKey).toContain(`diagnostics/${tenantId}/${deviceId}/`);
    expect(storage.presignPut).toHaveBeenCalled();
    expect(create).toHaveBeenCalled();
  });
});

describe('DiagnosticBundlesService.complete', () => {
  it('marks the bundle uploaded when size matches', async () => {
    const update = vi.fn(async () => ({
      id: bundleId,
      status: DeviceDiagnosticBundleStatus.uploaded,
    }));
    const db = {
      deviceDiagnosticBundle: {
        findUnique: vi.fn(async () => ({
          id: bundleId,
          deviceId,
          objectKey: `diagnostics/${tenantId}/${deviceId}/${bundleId}.zip`,
          byteSize: BigInt(2048),
          status: DeviceDiagnosticBundleStatus.pending_upload,
        })),
        update,
      },
    };
    const service = new DiagnosticBundlesService(
      db as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );

    await expect(service.complete(deviceId, deviceId, bundleId)).resolves.toEqual({
      ok: true,
      status: DeviceDiagnosticBundleStatus.uploaded,
    });
    expect(update).toHaveBeenCalled();
  });
});

describe('DiagnosticBundlesService.createDownloadUrl', () => {
  it('rejects expired bundles with 410', async () => {
    const service = new DiagnosticBundlesService(
      {
        deviceDiagnosticBundle: {
          findUnique: vi.fn(async () => ({
            id: bundleId,
            deviceId,
            objectKey: `diagnostics/${tenantId}/${deviceId}/${bundleId}.zip`,
            byteSize: BigInt(2048),
            status: DeviceDiagnosticBundleStatus.uploaded,
            expiresAt: new Date('2020-01-01T00:00:00.000Z'),
          })),
        },
      } as unknown as DbClient,
      storageMock(),
      { record: vi.fn() } as unknown as AuditService,
    );

    await expect(service.createDownloadUrl(deviceId, bundleId, adminId)).rejects.toBeInstanceOf(
      AppError,
    );
    await expect(service.createDownloadUrl(deviceId, bundleId, adminId)).rejects.toMatchObject({
      code: 'expired',
      statusCode: 410,
    });
  });

  it('returns a presigned GET URL for an uploaded bundle', async () => {
    const record = vi.fn(async () => undefined);
    const storage = storageMock();
    const service = new DiagnosticBundlesService(
      {
        deviceDiagnosticBundle: {
          findUnique: vi.fn(async () => ({
            id: bundleId,
            deviceId,
            objectKey: `diagnostics/${tenantId}/${deviceId}/${bundleId}.zip`,
            byteSize: BigInt(2048),
            status: DeviceDiagnosticBundleStatus.uploaded,
            expiresAt: new Date(Date.now() + 86_400_000),
          })),
        },
      } as unknown as DbClient,
      storage,
      { record } as unknown as AuditService,
    );

    const result = await service.createDownloadUrl(deviceId, bundleId, adminId);
    expect(result.url).toBe('https://r2.example/get');
    expect(result.byteSize).toBe(2048);
    expect(storage.presignGet).toHaveBeenCalled();
  });
});

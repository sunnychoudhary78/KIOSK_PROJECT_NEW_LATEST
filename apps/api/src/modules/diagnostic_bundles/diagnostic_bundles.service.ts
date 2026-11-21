import { randomUUID } from 'node:crypto';
import {
  DeviceDiagnosticBundleStatus,
  PrincipalType,
} from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { ObjectStorageClient } from '../../infrastructure/storage/s3.client.js';
import type { AuditService } from '../audit/audit.service.js';
import { AppError } from '../../shared/errors.js';
import {
  DIAGNOSTIC_BUNDLE_KEEP_PER_DEVICE,
  DIAGNOSTIC_BUNDLE_RETENTION_DAYS,
  MAX_DIAGNOSTIC_BUNDLE_BYTES,
} from './diagnostic_bundles.constants.js';
import type { DiagnosticBundleUploadUrlBody } from './diagnostic_bundles.schemas.js';

function assertSameDevice(deviceId: string, principalDeviceId: string): void {
  if (deviceId !== principalDeviceId) {
    throw new AppError('forbidden', 'Device identity mismatch', 403);
  }
}

function objectKeyFor(input: {
  tenantId: string;
  deviceId: string;
  bundleId: string;
}): string {
  return `diagnostics/${input.tenantId}/${input.deviceId}/${input.bundleId}.zip`;
}

function isMissingObjectError(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;
  const name = 'name' in error ? String(error.name) : '';
  const status =
    '$metadata' in error
      ? (error as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode
      : undefined;
  return name === 'NotFound' || name === 'NoSuchKey' || status === 404;
}

export class DiagnosticBundlesService {
  constructor(
    private readonly db: DbClient,
    private readonly storage: ObjectStorageClient,
    private readonly audit: AuditService,
  ) {}

  private async purgeOldBundles(deviceId: string): Promise<void> {
    const keep = DIAGNOSTIC_BUNDLE_KEEP_PER_DEVICE;
    const rows = await this.db.deviceDiagnosticBundle.findMany({
      where: { deviceId },
      orderBy: { createdAt: 'desc' },
      select: { id: true, objectKey: true },
    });
    if (rows.length <= keep) {
      return;
    }
    const toDelete = rows.slice(keep);
    for (const row of toDelete) {
      if (this.storage.isConfigured()) {
        try {
          await this.storage.deleteObject(row.objectKey);
        } catch (error) {
          if (!isMissingObjectError(error)) {
            // Best-effort; still drop the DB row.
          }
        }
      }
      await this.db.deviceDiagnosticBundle.delete({ where: { id: row.id } });
    }
  }

  async createUploadUrl(
    deviceId: string,
    principalDeviceId: string,
    body: DiagnosticBundleUploadUrlBody,
    correlationId?: string,
  ) {
    assertSameDevice(deviceId, principalDeviceId);
    if (!this.storage.isConfigured()) {
      throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
    }
    if (body.bytes > MAX_DIAGNOSTIC_BUNDLE_BYTES) {
      throw new AppError('bundle_too_large', 'Diagnostics bundle exceeds size limit', 400);
    }

    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true, tenantId: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const command = await this.db.deviceSurveillanceCommand.findUnique({
      where: { id: body.commandId },
    });
    if (!command || command.deviceId !== deviceId) {
      throw new AppError('not_found', 'Surveillance command not found', 404);
    }
    if (command.type !== 'collect_diagnostics') {
      throw new AppError('invalid_command', 'Command is not collect_diagnostics', 400);
    }

    await this.purgeOldBundles(deviceId);

    const now = new Date();
    const expiresAt = new Date(
      now.getTime() + DIAGNOSTIC_BUNDLE_RETENTION_DAYS * 24 * 60 * 60 * 1000,
    );
    const bundleId = randomUUID();
    const objectKey = objectKeyFor({
      tenantId: device.tenantId,
      deviceId: device.id,
      bundleId,
    });

    const bundle = await this.db.deviceDiagnosticBundle.create({
      data: {
        id: bundleId,
        deviceId,
        commandId: body.commandId,
        objectKey,
        byteSize: BigInt(body.bytes),
        contentType: body.contentType,
        status: DeviceDiagnosticBundleStatus.pending_upload,
        expiresAt,
      },
    });

    const signed = await this.storage.presignPut({
      key: objectKey,
      contentType: body.contentType,
    });

    await this.audit.record({
      action: 'diagnostics.bundle_upload_url',
      principalType: PrincipalType.device,
      principalId: deviceId,
      resourceType: 'device_diagnostic_bundle',
      resourceId: bundle.id,
      correlationId,
      metadata: { objectKey, bytes: body.bytes, commandId: body.commandId },
    });

    return {
      bundleId: bundle.id,
      objectKey,
      uploadUrl: signed.url,
      expiresAt: signed.expiresAt.toISOString(),
    };
  }

  async complete(
    deviceId: string,
    principalDeviceId: string,
    bundleId: string,
    correlationId?: string,
  ) {
    assertSameDevice(deviceId, principalDeviceId);
    if (!this.storage.isConfigured()) {
      throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
    }

    const bundle = await this.db.deviceDiagnosticBundle.findUnique({
      where: { id: bundleId },
    });
    if (!bundle || bundle.deviceId !== deviceId) {
      throw new AppError('not_found', 'Diagnostics bundle not found', 404);
    }
    if (bundle.status === DeviceDiagnosticBundleStatus.uploaded) {
      return { ok: true as const, status: bundle.status };
    }

    const head = await this.storage.headObject(bundle.objectKey);
    if (!head) {
      throw new AppError('upload_incomplete', 'Object was not found in storage', 409);
    }
    if (BigInt(head.contentLength) !== bundle.byteSize) {
      try {
        await this.storage.deleteObject(bundle.objectKey);
      } catch {
        // Best-effort.
      }
      throw new AppError('size_mismatch', 'Uploaded object size does not match', 400);
    }

    const updated = await this.db.deviceDiagnosticBundle.update({
      where: { id: bundle.id },
      data: {
        status: DeviceDiagnosticBundleStatus.uploaded,
        uploadedAt: new Date(),
      },
    });

    await this.audit.record({
      action: 'diagnostics.bundle_uploaded',
      principalType: PrincipalType.device,
      principalId: deviceId,
      resourceType: 'device_diagnostic_bundle',
      resourceId: bundle.id,
      correlationId,
      metadata: { objectKey: bundle.objectKey, byteSize: Number(bundle.byteSize) },
    });

    return { ok: true as const, status: updated.status };
  }

  async createDownloadUrl(
    deviceId: string,
    bundleId: string,
    adminUserId: string,
    correlationId?: string,
  ) {
    if (!this.storage.isConfigured()) {
      throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
    }

    const bundle = await this.db.deviceDiagnosticBundle.findUnique({
      where: { id: bundleId },
    });
    if (!bundle || bundle.deviceId !== deviceId) {
      throw new AppError('not_found', 'Diagnostics bundle not found', 404);
    }
    if (bundle.status !== DeviceDiagnosticBundleStatus.uploaded) {
      throw new AppError('not_ready', 'Diagnostics bundle is not uploaded yet', 409);
    }
    if (bundle.expiresAt.getTime() <= Date.now()) {
      throw new AppError('expired', 'Diagnostics bundle has expired', 410);
    }

    const head = await this.storage.headObject(bundle.objectKey);
    if (!head) {
      throw new AppError('object_missing', 'Diagnostics object is missing from storage', 404);
    }

    const signed = await this.storage.presignGet({ key: bundle.objectKey });

    await this.audit.record({
      action: 'diagnostics.bundle_download',
      principalType: PrincipalType.admin,
      principalId: adminUserId,
      resourceType: 'device_diagnostic_bundle',
      resourceId: bundle.id,
      correlationId,
      metadata: { deviceId, objectKey: bundle.objectKey },
    });

    return {
      url: signed.url,
      expiresAt: signed.expiresAt.toISOString(),
      byteSize: Number(bundle.byteSize),
    };
  }
}

import { randomUUID } from 'node:crypto';
import { KioskAppReleaseStatus, PrincipalType } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { ObjectStorageClient } from '../../infrastructure/storage/s3.client.js';
import type { AuditService } from '../audit/audit.service.js';
import { AppError } from '../../shared/errors.js';
import type { CreateKioskReleaseInput } from './kiosk_releases.schemas.js';

export function objectKeyForRelease(version: string): string {
  return `kiosk-releases/${version}/${randomUUID()}.zip`;
}

function mapRelease(row: {
  id: string;
  version: string;
  objectKey: string;
  contentType: string;
  byteSize: bigint;
  sha256: string;
  status: KioskAppReleaseStatus;
  createdByAdminId: string | null;
  uploadedAt: Date | null;
  activatedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: row.id,
    version: row.version,
    objectKey: row.objectKey,
    contentType: row.contentType,
    byteSize: Number(row.byteSize),
    sha256: row.sha256,
    status: row.status,
    createdByAdminId: row.createdByAdminId,
    uploadedAt: row.uploadedAt?.toISOString() ?? null,
    activatedAt: row.activatedAt?.toISOString() ?? null,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

export class KioskReleasesService {
  constructor(
    private readonly db: DbClient,
    private readonly storage: ObjectStorageClient,
    private readonly audit: AuditService,
  ) {}

  async list() {
    const rows = await this.db.kioskAppRelease.findMany({
      orderBy: { createdAt: 'desc' },
    });
    return { items: rows.map(mapRelease) };
  }

  async createUpload(
    input: CreateKioskReleaseInput,
    adminId: string,
    correlationId?: string,
  ) {
    if (!this.storage.isConfigured()) {
      throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
    }

    const existing = await this.db.kioskAppRelease.findUnique({
      where: { version: input.version },
    });
    if (existing) {
      throw new AppError('conflict', `Release version ${input.version} already exists`, 409);
    }

    const objectKey = objectKeyForRelease(input.version);
    const release = await this.db.kioskAppRelease.create({
      data: {
        version: input.version,
        objectKey,
        contentType: input.contentType,
        byteSize: BigInt(input.byteSize),
        sha256: input.sha256,
        status: KioskAppReleaseStatus.pending_upload,
        createdByAdminId: adminId,
      },
    });

    const signed = await this.storage.presignPut({
      key: objectKey,
      contentType: input.contentType,
    });

    await this.audit.record({
      action: 'kiosk_release.upload_url',
      principalType: PrincipalType.admin,
      principalId: adminId,
      resourceType: 'kiosk_app_release',
      resourceId: release.id,
      correlationId,
      metadata: { version: input.version, objectKey },
    });

    return {
      release: mapRelease(release),
      uploadUrl: signed.url,
      expiresAt: signed.expiresAt.toISOString(),
    };
  }

  async complete(releaseId: string, adminId: string, correlationId?: string) {
    if (!this.storage.isConfigured()) {
      throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
    }

    const release = await this.db.kioskAppRelease.findUnique({ where: { id: releaseId } });
    if (!release) {
      throw new AppError('not_found', 'Release not found', 404);
    }

    if (
      release.status === KioskAppReleaseStatus.uploaded ||
      release.status === KioskAppReleaseStatus.active
    ) {
      return { release: mapRelease(release) };
    }

    const head = await this.storage.headObject(release.objectKey);
    if (!head) {
      throw new AppError('upload_incomplete', 'Object was not found in storage', 409);
    }
    if (BigInt(head.contentLength) !== release.byteSize) {
      try {
        await this.storage.deleteObject(release.objectKey);
      } catch {
        // Best-effort cleanup of mismatched object.
      }
      throw new AppError(
        'size_mismatch',
        `Uploaded size ${head.contentLength} does not match expected ${release.byteSize}`,
        409,
      );
    }

    const updated = await this.db.kioskAppRelease.update({
      where: { id: release.id },
      data: {
        status: KioskAppReleaseStatus.uploaded,
        uploadedAt: new Date(),
        byteSize: BigInt(head.contentLength),
      },
    });

    await this.audit.record({
      action: 'kiosk_release.completed',
      principalType: PrincipalType.admin,
      principalId: adminId,
      resourceType: 'kiosk_app_release',
      resourceId: release.id,
      correlationId,
      metadata: { version: release.version, byteSize: head.contentLength },
    });

    return { release: mapRelease(updated) };
  }

  async activate(releaseId: string, adminId: string, correlationId?: string) {
    const release = await this.db.kioskAppRelease.findUnique({ where: { id: releaseId } });
    if (!release) {
      throw new AppError('not_found', 'Release not found', 404);
    }
    if (release.status === KioskAppReleaseStatus.pending_upload) {
      throw new AppError('invalid_state', 'Release upload is not complete', 409);
    }
    if (release.status === KioskAppReleaseStatus.active) {
      return { release: mapRelease(release) };
    }

    const updated = await this.db.$transaction(async (tx) => {
      await tx.kioskAppRelease.updateMany({
        where: { status: KioskAppReleaseStatus.active },
        data: { status: KioskAppReleaseStatus.uploaded, activatedAt: null },
      });
      return tx.kioskAppRelease.update({
        where: { id: release.id },
        data: {
          status: KioskAppReleaseStatus.active,
          activatedAt: new Date(),
        },
      });
    });

    await this.audit.record({
      action: 'kiosk_release.activated',
      principalType: PrincipalType.admin,
      principalId: adminId,
      resourceType: 'kiosk_app_release',
      resourceId: release.id,
      correlationId,
      metadata: { version: release.version },
    });

    return { release: mapRelease(updated) };
  }

  async remove(releaseId: string, adminId: string, correlationId?: string) {
    const release = await this.db.kioskAppRelease.findUnique({ where: { id: releaseId } });
    if (!release) {
      throw new AppError('not_found', 'Release not found', 404);
    }
    if (release.status === KioskAppReleaseStatus.active) {
      throw new AppError('invalid_state', 'Cannot delete the active release', 409);
    }

    if (this.storage.isConfigured()) {
      try {
        await this.storage.deleteObject(release.objectKey);
      } catch {
        // Row delete still proceeds; orphan objects can be cleaned later.
      }
    }

    await this.db.kioskAppRelease.delete({ where: { id: release.id } });

    await this.audit.record({
      action: 'kiosk_release.deleted',
      principalType: PrincipalType.admin,
      principalId: adminId,
      resourceType: 'kiosk_app_release',
      resourceId: release.id,
      correlationId,
      metadata: { version: release.version },
    });

    return { ok: true as const };
  }

  async getCurrentUpdate(kioskUpdateKey: string) {
    if (!kioskUpdateKey) {
      throw new AppError(
        'update_key_not_configured',
        'Kiosk update key is not configured',
        503,
      );
    }
    if (!this.storage.isConfigured()) {
      throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
    }

    const active = await this.db.kioskAppRelease.findFirst({
      where: { status: KioskAppReleaseStatus.active },
    });
    if (!active) {
      throw new AppError('not_found', 'No active kiosk release', 404);
    }

    const signed = await this.storage.presignGet({ key: active.objectKey });
    return {
      version: active.version,
      downloadUrl: signed.url,
      sha256: active.sha256,
      byteSize: Number(active.byteSize),
      expiresAt: signed.expiresAt.toISOString(),
    };
  }
}

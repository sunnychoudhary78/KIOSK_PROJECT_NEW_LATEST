import { PrincipalType, SurveillanceSegmentStatus } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { ObjectStorageClient } from '../../infrastructure/storage/s3.client.js';
import type { AuditService } from '../audit/audit.service.js';
import { AppError } from '../../shared/errors.js';
import type { ListSegmentsQuery, UploadUrlBody } from './surveillance.schemas.js';
import { formatRecordedOn, parseSegmentStart, recordedOnDate } from './surveillance.time.js';

function assertSameDevice(deviceId: string, principalDeviceId: string): void {
  if (deviceId !== principalDeviceId) {
    throw new AppError('forbidden', 'Device can only upload its own segments', 403);
  }
}

export function objectKeyFor(input: {
  tenantId: string;
  deviceId: string;
  recordedOn: string;
  filename: string;
}): string {
  return `surveillance/${input.tenantId}/${input.deviceId}/${input.recordedOn}/${input.filename}`;
}

function mapSegment(row: {
  id: string;
  filename: string;
  recordedOn: Date;
  startedAt: Date;
  byteSize: bigint;
  uploadedAt: Date | null;
}) {
  return {
    id: row.id,
    filename: row.filename,
    recordedOn: formatRecordedOn(row.recordedOn),
    startedAt: row.startedAt.toISOString(),
    byteSize: Number(row.byteSize),
    uploadedAt: row.uploadedAt?.toISOString() ?? null,
  };
}

export class SurveillanceService {
  constructor(
    private readonly db: DbClient,
    private readonly storage: ObjectStorageClient,
    private readonly audit: AuditService,
  ) {}

  async createUploadUrl(
    deviceId: string,
    principalDeviceId: string,
    body: UploadUrlBody,
    correlationId?: string,
  ) {
    assertSameDevice(deviceId, principalDeviceId);
    if (!this.storage.isConfigured()) {
      throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
    }

    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true, tenantId: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const startedAt = parseSegmentStart(body.recordedOn, body.filename);
    const recordedOn = recordedOnDate(body.recordedOn);

    const objectKey = objectKeyFor({
      tenantId: device.tenantId,
      deviceId: device.id,
      recordedOn: body.recordedOn,
      filename: body.filename,
    });

    const existing = await this.db.surveillanceSegment.findUnique({
      where: { deviceId_objectKey: { deviceId, objectKey } },
    });

    if (existing?.status === SurveillanceSegmentStatus.uploaded) {
      return {
        segmentId: existing.id,
        objectKey,
        alreadyUploaded: true as const,
      };
    }

    const segment =
      existing ??
      (await this.db.surveillanceSegment.create({
        data: {
          deviceId,
          objectKey,
          filename: body.filename,
          recordedOn,
          startedAt,
          byteSize: BigInt(body.bytes),
          contentType: body.contentType,
          status: SurveillanceSegmentStatus.pending_upload,
        },
      }));

    if (existing) {
      await this.db.surveillanceSegment.update({
        where: { id: existing.id },
        data: {
          byteSize: BigInt(body.bytes),
          contentType: body.contentType,
          recordedOn,
          startedAt,
        },
      });
    }

    const signed = await this.storage.presignPut({
      key: objectKey,
      contentType: body.contentType,
    });

    await this.audit.record({
      action: 'surveillance.upload_url',
      principalType: PrincipalType.device,
      principalId: deviceId,
      resourceType: 'surveillance_segment',
      resourceId: segment.id,
      correlationId,
      metadata: { objectKey, filename: body.filename },
    });

    return {
      segmentId: segment.id,
      objectKey,
      uploadUrl: signed.url,
      expiresAt: signed.expiresAt.toISOString(),
      alreadyUploaded: false as const,
    };
  }

  async complete(
    deviceId: string,
    principalDeviceId: string,
    segmentId: string,
    correlationId?: string,
  ) {
    assertSameDevice(deviceId, principalDeviceId);
    if (!this.storage.isConfigured()) {
      throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
    }

    const segment = await this.db.surveillanceSegment.findUnique({ where: { id: segmentId } });
    if (!segment || segment.deviceId !== deviceId) {
      throw new AppError('not_found', 'Segment not found', 404);
    }

    if (segment.status === SurveillanceSegmentStatus.uploaded) {
      return { ok: true, status: segment.status };
    }

    const head = await this.storage.headObject(segment.objectKey);
    if (!head) {
      throw new AppError('upload_incomplete', 'Object was not found in storage', 409);
    }
    if (BigInt(head.contentLength) !== segment.byteSize) {
      throw new AppError('size_mismatch', 'Uploaded object size does not match', 400);
    }

    const updated = await this.db.surveillanceSegment.update({
      where: { id: segment.id },
      data: {
        status: SurveillanceSegmentStatus.uploaded,
        uploadedAt: new Date(),
      },
    });

    await this.audit.record({
      action: 'surveillance.segment_uploaded',
      principalType: PrincipalType.device,
      principalId: deviceId,
      resourceType: 'surveillance_segment',
      resourceId: segment.id,
      correlationId,
      metadata: { objectKey: segment.objectKey, byteSize: Number(segment.byteSize) },
    });

    return { ok: true, status: updated.status };
  }

  async listSegments(deviceId: string, query: ListSegmentsQuery) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const day = recordedOnDate(query.recordedOn);
    const rows = await this.db.surveillanceSegment.findMany({
      where: {
        deviceId,
        recordedOn: day,
        status: SurveillanceSegmentStatus.uploaded,
      },
      orderBy: { startedAt: 'asc' },
      select: {
        id: true,
        filename: true,
        recordedOn: true,
        startedAt: true,
        byteSize: true,
        uploadedAt: true,
      },
    });

    return { items: rows.map(mapSegment) };
  }

  async createPlaybackUrl(
    deviceId: string,
    segmentId: string,
    principalId: string,
    correlationId?: string,
  ) {
    if (!this.storage.isConfigured()) {
      throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
    }

    const segment = await this.db.surveillanceSegment.findUnique({ where: { id: segmentId } });
    if (!segment || segment.deviceId !== deviceId) {
      throw new AppError('not_found', 'Segment not found', 404);
    }
    if (segment.status !== SurveillanceSegmentStatus.uploaded) {
      throw new AppError('not_ready', 'Segment is not uploaded yet', 409);
    }

    const signed = await this.storage.presignGet({ key: segment.objectKey });

    await this.audit.record({
      action: 'surveillance.playback',
      principalType: PrincipalType.admin,
      principalId,
      resourceType: 'surveillance_segment',
      resourceId: segment.id,
      correlationId,
      metadata: { deviceId, objectKey: segment.objectKey },
    });

    return {
      url: signed.url,
      expiresAt: signed.expiresAt.toISOString(),
    };
  }
}

import {
  DeviceStatus,
  PrincipalType,
  ScreenShareSessionStatus,
  type ScreenShareSession,
} from '@prisma/client';
import type { AppConfig } from '../../config/index.js';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import {
  SCREEN_SHARE_EXPIRE_BATCH_SIZE,
  SCREEN_SHARE_PENDING_TTL_MS,
} from './screen_share.constants.js';
import type { ScreenShareAckBody } from './screen_share.schemas.js';
import {
  deleteLiveKitRoom,
  isLiveKitConfigured,
  mintLiveKitToken,
} from './livekit_tokens.js';

const OPEN_STATUSES: ScreenShareSessionStatus[] = [
  ScreenShareSessionStatus.pending,
  ScreenShareSessionStatus.active,
];

function mapSession(row: ScreenShareSession) {
  return {
    id: row.id,
    deviceId: row.deviceId,
    roomName: row.roomName,
    status: row.status,
    requestedByUserId: row.requestedByUserId,
    requestedAt: row.requestedAt.toISOString(),
    startedAt: row.startedAt?.toISOString() ?? null,
    endedAt: row.endedAt?.toISOString() ?? null,
    expiresAt: row.expiresAt.toISOString(),
    lastError: row.lastError,
  };
}

function roomNameFor(deviceId: string, sessionId: string): string {
  return `kiosk-${deviceId}-${sessionId.replace(/-/g, '').slice(0, 12)}`;
}

export class ScreenShareService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
    private readonly config: AppConfig,
  ) {}

  private assertConfigured(): void {
    if (!isLiveKitConfigured(this.config)) {
      throw new AppError('livekit_not_configured', 'LiveKit is not configured', 503);
    }
  }

  private tokenTtlSeconds(expiresAt: Date, now = new Date()): number {
    const remaining = Math.floor((expiresAt.getTime() - now.getTime()) / 1000);
    // Give clients a little headroom past session end for clean disconnect.
    return Math.max(60, remaining + 120);
  }

  /** Mark open sessions past expiresAt as expired. Returns the refreshed row when updated. */
  private async expireIfNeeded(
    row: ScreenShareSession,
    now = new Date(),
  ): Promise<ScreenShareSession> {
    if (!OPEN_STATUSES.includes(row.status)) {
      return row;
    }
    if (row.expiresAt.getTime() > now.getTime()) {
      return row;
    }
    return this.db.screenShareSession.update({
      where: { id: row.id },
      data: {
        status: ScreenShareSessionStatus.expired,
        endedAt: now,
        lastError: row.status === ScreenShareSessionStatus.pending ? 'pending_timeout' : 'session_ttl',
      },
    });
  }

  async start(deviceId: string, adminUserId: string, correlationId?: string) {
    this.assertConfigured();

    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true, tenantId: true, status: true, name: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }
    if (device.status === DeviceStatus.inactive) {
      throw new AppError('device_inactive', 'Device is inactive', 409);
    }

    const existing = await this.db.screenShareSession.findFirst({
      where: { deviceId, status: { in: OPEN_STATUSES } },
      orderBy: { requestedAt: 'desc' },
    });
    if (existing) {
      const current = await this.expireIfNeeded(existing);
      if (OPEN_STATUSES.includes(current.status)) {
        throw new AppError(
          'screen_share_active',
          'A screen share session is already pending or active for this kiosk',
          409,
        );
      }
    }

    const now = new Date();
    const sessionId = crypto.randomUUID();
    const roomName = roomNameFor(deviceId, sessionId);
    const expiresAt = new Date(now.getTime() + SCREEN_SHARE_PENDING_TTL_MS);

    const row = await this.db.screenShareSession.create({
      data: {
        id: sessionId,
        tenantId: device.tenantId,
        deviceId,
        roomName,
        status: ScreenShareSessionStatus.pending,
        requestedByUserId: adminUserId,
        requestedAt: now,
        expiresAt,
      },
    });

    const token = await mintLiveKitToken({
      config: this.config,
      roomName,
      identity: `admin-${adminUserId}`,
      role: 'subscriber',
      ttlSeconds: this.tokenTtlSeconds(
        new Date(now.getTime() + this.config.screenShare.ttlSeconds * 1000),
      ),
    });

    await this.audit.record({
      action: 'device.screen_share_started',
      principalType: PrincipalType.admin,
      principalId: adminUserId,
      resourceType: 'device',
      resourceId: deviceId,
      correlationId,
      metadata: {
        sessionId: row.id,
        roomName,
        deviceName: device.name,
      },
    });

    return {
      session: mapSession(row),
      livekitUrl: this.config.livekit.url,
      token,
    };
  }

  async end(deviceId: string, adminUserId: string, correlationId?: string) {
    const existing = await this.db.screenShareSession.findFirst({
      where: { deviceId, status: { in: OPEN_STATUSES } },
      orderBy: { requestedAt: 'desc' },
    });
    if (!existing) {
      throw new AppError('not_found', 'No active screen share session', 404);
    }

    const now = new Date();
    const row = await this.db.screenShareSession.update({
      where: { id: existing.id },
      data: {
        status: ScreenShareSessionStatus.ended,
        endedAt: now,
      },
    });

    try {
      await deleteLiveKitRoom(this.config, row.roomName);
    } catch {
      // Best-effort; room may already be empty.
    }

    await this.audit.record({
      action: 'device.screen_share_ended',
      principalType: PrincipalType.admin,
      principalId: adminUserId,
      resourceType: 'device',
      resourceId: deviceId,
      correlationId,
      metadata: { sessionId: row.id, roomName: row.roomName },
    });

    return { session: mapSession(row) };
  }

  async getCurrent(deviceId: string) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const existing = await this.db.screenShareSession.findFirst({
      where: { deviceId, status: { in: OPEN_STATUSES } },
      orderBy: { requestedAt: 'desc' },
    });
    if (!existing) {
      return { session: null };
    }
    const row = await this.expireIfNeeded(existing);
    if (!OPEN_STATUSES.includes(row.status)) {
      return { session: mapSession(row) };
    }
    return { session: mapSession(row) };
  }

  async getPendingForDevice(deviceId: string, principalDeviceId: string) {
    if (deviceId !== principalDeviceId) {
      throw new AppError('forbidden', 'Device can only read its own screen share', 403);
    }

    const existing = await this.db.screenShareSession.findFirst({
      where: { deviceId, status: { in: OPEN_STATUSES } },
      orderBy: { requestedAt: 'desc' },
    });
    if (!existing) {
      return { session: null };
    }

    const row = await this.expireIfNeeded(existing);
    if (!OPEN_STATUSES.includes(row.status)) {
      return { session: mapSession(row), livekitUrl: null, token: null };
    }

    this.assertConfigured();
    const token = await mintLiveKitToken({
      config: this.config,
      roomName: row.roomName,
      identity: `kiosk-${deviceId}`,
      role: 'publisher',
      ttlSeconds: this.tokenTtlSeconds(row.expiresAt),
    });

    return {
      session: mapSession(row),
      livekitUrl: this.config.livekit.url,
      token,
    };
  }

  async ack(deviceId: string, principalDeviceId: string, body: ScreenShareAckBody) {
    if (deviceId !== principalDeviceId) {
      throw new AppError('forbidden', 'Device can only ack its own screen share', 403);
    }

    const row = await this.db.screenShareSession.findFirst({
      where: { id: body.sessionId, deviceId },
    });
    if (!row) {
      throw new AppError('not_found', 'Screen share session not found', 404);
    }

    const now = new Date();
    const current = await this.expireIfNeeded(row, now);

    if (body.result === 'started') {
      if (current.status !== ScreenShareSessionStatus.pending) {
        throw new AppError(
          'invalid_state',
          `Cannot start session in status ${current.status}`,
          409,
        );
      }
      const expiresAt = new Date(now.getTime() + this.config.screenShare.ttlSeconds * 1000);
      const updated = await this.db.screenShareSession.update({
        where: { id: current.id },
        data: {
          status: ScreenShareSessionStatus.active,
          startedAt: now,
          expiresAt,
          lastError: null,
        },
      });
      return { session: mapSession(updated) };
    }

    if (body.result === 'failed') {
      if (!OPEN_STATUSES.includes(current.status)) {
        return { session: mapSession(current) };
      }
      const updated = await this.db.screenShareSession.update({
        where: { id: current.id },
        data: {
          status: ScreenShareSessionStatus.failed,
          endedAt: now,
          lastError: body.error?.slice(0, 500) ?? 'kiosk_failed',
        },
      });
      await this.audit.record({
        action: 'device.screen_share_failed',
        principalType: PrincipalType.device,
        principalId: deviceId,
        resourceType: 'device',
        resourceId: deviceId,
        metadata: { sessionId: updated.id, error: updated.lastError },
      });
      try {
        await deleteLiveKitRoom(this.config, updated.roomName);
      } catch {
        // ignore
      }
      return { session: mapSession(updated) };
    }

    // ended
    if (!OPEN_STATUSES.includes(current.status)) {
      return { session: mapSession(current) };
    }
    const updated = await this.db.screenShareSession.update({
      where: { id: current.id },
      data: {
        status: ScreenShareSessionStatus.ended,
        endedAt: now,
      },
    });
    try {
      await deleteLiveKitRoom(this.config, updated.roomName);
    } catch {
      // ignore
    }
    return { session: mapSession(updated) };
  }

  /** Close open sessions past expiresAt. Used by the hourly/main sweep. */
  async expireStale(now = new Date()): Promise<number> {
    const stale = await this.db.screenShareSession.findMany({
      where: {
        status: { in: OPEN_STATUSES },
        expiresAt: { lte: now },
      },
      take: SCREEN_SHARE_EXPIRE_BATCH_SIZE,
      select: { id: true, status: true },
    });
    if (stale.length === 0) {
      return 0;
    }
    await this.db.screenShareSession.updateMany({
      where: { id: { in: stale.map((s) => s.id) } },
      data: {
        status: ScreenShareSessionStatus.expired,
        endedAt: now,
      },
    });
    return stale.length;
  }
}

import {
  DeviceStatus,
  DeviceSurveillanceCommandStatus,
  DeviceSurveillanceCommandType,
  PrincipalType,
  Prisma,
  type DeviceSurveillanceCommand,
} from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import {
  SURVEILLANCE_COMMAND_COLLECT_DIAGNOSTICS_TTL_MS,
  SURVEILLANCE_COMMAND_EXPIRE_BATCH_SIZE,
  SURVEILLANCE_COMMAND_PENDING_TTL_MS,
} from './surveillance_commands.constants.js';
import type {
  CreateSurveillanceCommandBody,
  SurveillanceCommandAckBody,
} from './surveillance_commands.schemas.js';

function ttlMsForCommandType(type: string): number {
  if (type === 'collect_diagnostics') {
    return SURVEILLANCE_COMMAND_COLLECT_DIAGNOSTICS_TTL_MS;
  }
  return SURVEILLANCE_COMMAND_PENDING_TTL_MS;
}

const OPEN_STATUSES: DeviceSurveillanceCommandStatus[] = [
  DeviceSurveillanceCommandStatus.pending,
  DeviceSurveillanceCommandStatus.running,
];

function mapCommand(row: DeviceSurveillanceCommand) {
  return {
    id: row.id,
    deviceId: row.deviceId,
    type: row.type,
    status: row.status,
    requestedByUserId: row.requestedByUserId,
    result: row.resultJson ?? null,
    lastError: row.lastError,
    createdAt: row.createdAt.toISOString(),
    expiresAt: row.expiresAt.toISOString(),
    ackedAt: row.ackedAt?.toISOString() ?? null,
  };
}

function assertSameDevice(deviceId: string, principalDeviceId: string): void {
  if (deviceId !== principalDeviceId) {
    throw new AppError('forbidden', 'Device identity mismatch', 403);
  }
}

export class SurveillanceCommandsService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {}

  private async expireIfNeeded(
    row: DeviceSurveillanceCommand,
    now = new Date(),
  ): Promise<DeviceSurveillanceCommand> {
    if (!OPEN_STATUSES.includes(row.status)) {
      return row;
    }
    if (row.expiresAt.getTime() > now.getTime()) {
      return row;
    }
    return this.db.deviceSurveillanceCommand.update({
      where: { id: row.id },
      data: {
        status: DeviceSurveillanceCommandStatus.expired,
        lastError: 'pending_timeout',
        ackedAt: now,
      },
    });
  }

  async create(
    deviceId: string,
    adminUserId: string,
    body: CreateSurveillanceCommandBody,
    correlationId?: string,
  ) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true, status: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }
    if (device.status === DeviceStatus.inactive) {
      throw new AppError('device_inactive', 'Device is inactive', 409);
    }

    const existing = await this.db.deviceSurveillanceCommand.findFirst({
      where: { deviceId, status: { in: OPEN_STATUSES } },
      orderBy: { createdAt: 'desc' },
    });
    if (existing) {
      const current = await this.expireIfNeeded(existing);
      if (OPEN_STATUSES.includes(current.status)) {
        throw new AppError(
          'surveillance_command_active',
          'A surveillance command is already pending for this kiosk',
          409,
        );
      }
    }

    const now = new Date();
    const row = await this.db.deviceSurveillanceCommand.create({
      data: {
        deviceId,
        type: body.type as DeviceSurveillanceCommandType,
        status: DeviceSurveillanceCommandStatus.pending,
        requestedByUserId: adminUserId,
        expiresAt: new Date(now.getTime() + ttlMsForCommandType(body.type)),
      },
    });

    await this.audit.record({
      action: 'surveillance.command_create',
      principalType: PrincipalType.admin,
      principalId: adminUserId,
      resourceType: 'device_surveillance_command',
      resourceId: row.id,
      correlationId,
      metadata: { deviceId, type: body.type },
    });

    return { command: mapCommand(row) };
  }

  async getLatest(deviceId: string) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const row = await this.db.deviceSurveillanceCommand.findFirst({
      where: { deviceId },
      orderBy: { createdAt: 'desc' },
    });
    if (!row) {
      return { command: null };
    }
    const current = await this.expireIfNeeded(row);
    return { command: mapCommand(current) };
  }

  async getPendingForDevice(deviceId: string, principalDeviceId: string) {
    assertSameDevice(deviceId, principalDeviceId);
    const now = new Date();

    const row = await this.db.deviceSurveillanceCommand.findFirst({
      where: {
        deviceId,
        status: {
          in: [DeviceSurveillanceCommandStatus.pending, DeviceSurveillanceCommandStatus.running],
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!row) {
      return { command: null };
    }

    const current = await this.expireIfNeeded(row, now);
    if (current.status === DeviceSurveillanceCommandStatus.expired) {
      return { command: null };
    }
    if (current.status === DeviceSurveillanceCommandStatus.running) {
      return { command: mapCommand(current) };
    }

    const claimed = await this.db.deviceSurveillanceCommand.update({
      where: { id: current.id },
      data: { status: DeviceSurveillanceCommandStatus.running },
    });
    return { command: mapCommand(claimed) };
  }

  async ack(
    deviceId: string,
    principalDeviceId: string,
    commandId: string,
    body: SurveillanceCommandAckBody,
  ) {
    assertSameDevice(deviceId, principalDeviceId);

    const row = await this.db.deviceSurveillanceCommand.findUnique({ where: { id: commandId } });
    if (!row || row.deviceId !== deviceId) {
      throw new AppError('not_found', 'Command not found', 404);
    }
    if (
      row.status !== DeviceSurveillanceCommandStatus.pending &&
      row.status !== DeviceSurveillanceCommandStatus.running
    ) {
      return { command: mapCommand(row) };
    }

    const now = new Date();
    const updated = await this.db.deviceSurveillanceCommand.update({
      where: { id: row.id },
      data: {
        status: body.ok
          ? DeviceSurveillanceCommandStatus.succeeded
          : DeviceSurveillanceCommandStatus.failed,
        resultJson:
          body.result === undefined
            ? undefined
            : (body.result as Prisma.InputJsonValue),
        lastError: body.ok ? null : (body.error ?? 'command_failed'),
        ackedAt: now,
      },
    });
    return { command: mapCommand(updated) };
  }

  async expireStale(now = new Date()): Promise<number> {
    const stale = await this.db.deviceSurveillanceCommand.findMany({
      where: {
        status: { in: OPEN_STATUSES },
        expiresAt: { lte: now },
      },
      take: SURVEILLANCE_COMMAND_EXPIRE_BATCH_SIZE,
      select: { id: true },
    });
    if (stale.length === 0) {
      return 0;
    }
    const result = await this.db.deviceSurveillanceCommand.updateMany({
      where: { id: { in: stale.map((row) => row.id) } },
      data: {
        status: DeviceSurveillanceCommandStatus.expired,
        lastError: 'pending_timeout',
        ackedAt: now,
      },
    });
    return result.count;
  }
}

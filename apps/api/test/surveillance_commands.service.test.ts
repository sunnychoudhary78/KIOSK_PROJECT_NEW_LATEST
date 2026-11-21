import { describe, expect, it, vi, beforeEach } from 'vitest';
import {
  DeviceStatus,
  DeviceSurveillanceCommandStatus,
  DeviceSurveillanceCommandType,
} from '@prisma/client';
import { SurveillanceCommandsService } from '../src/modules/surveillance_commands/surveillance_commands.service.js';
import { SURVEILLANCE_COMMAND_PENDING_TTL_MS } from '../src/modules/surveillance_commands/surveillance_commands.constants.js';
import { surveillanceCommandTypeSchema } from '../src/modules/surveillance_commands/surveillance_commands.schemas.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const adminId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const commandId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

function commandRow(
  overrides: Partial<{
    id: string;
    status: DeviceSurveillanceCommandStatus;
    type: DeviceSurveillanceCommandType;
    expiresAt: Date;
    lastError: string | null;
    resultJson: unknown;
  }> = {},
) {
  return {
    id: overrides.id ?? commandId,
    deviceId,
    type: overrides.type ?? DeviceSurveillanceCommandType.heal_queue,
    status: overrides.status ?? DeviceSurveillanceCommandStatus.pending,
    requestedByUserId: adminId,
    resultJson: overrides.resultJson ?? null,
    lastError: overrides.lastError ?? null,
    createdAt: new Date('2026-11-21T06:00:00.000Z'),
    expiresAt: overrides.expiresAt ?? new Date(Date.now() + SURVEILLANCE_COMMAND_PENDING_TTL_MS),
    ackedAt: null,
    updatedAt: new Date(),
  };
}

describe('SurveillanceCommandsService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('accepts phase-2 command types in the schema', () => {
    expect(surveillanceCommandTypeSchema.parse('restart_recording')).toBe('restart_recording');
    expect(surveillanceCommandTypeSchema.parse('flush_queue')).toBe('flush_queue');
  });

  it('creates a pending command', async () => {
    const create = vi.fn(async ({ data }: { data: Record<string, unknown> }) =>
      commandRow({
        type: data.type as DeviceSurveillanceCommandType,
      }),
    );
    const audit = { record: vi.fn(async () => undefined) };
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          id: deviceId,
          status: DeviceStatus.active,
        })),
      },
      deviceSurveillanceCommand: {
        findFirst: vi.fn(async () => null),
        create,
      },
    };
    const service = new SurveillanceCommandsService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    const result = await service.create(deviceId, adminId, { type: 'heal_queue' });
    expect(result.command.type).toBe('heal_queue');
    expect(result.command.status).toBe('pending');
    expect(create).toHaveBeenCalled();
    expect(audit.record).toHaveBeenCalled();
  });

  it('creates restart_recording and flush_queue commands', async () => {
    const create = vi.fn(async ({ data }: { data: Record<string, unknown> }) =>
      commandRow({
        type: data.type as DeviceSurveillanceCommandType,
      }),
    );
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          id: deviceId,
          status: DeviceStatus.active,
        })),
      },
      deviceSurveillanceCommand: {
        findFirst: vi.fn(async () => null),
        create,
      },
    };
    const service = new SurveillanceCommandsService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );

    const restart = await service.create(deviceId, adminId, { type: 'restart_recording' });
    expect(restart.command.type).toBe('restart_recording');
    const flush = await service.create(deviceId, adminId, { type: 'flush_queue' });
    expect(flush.command.type).toBe('flush_queue');
  });

  it('rejects when another command is already open', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          id: deviceId,
          status: DeviceStatus.active,
        })),
      },
      deviceSurveillanceCommand: {
        findFirst: vi.fn(async () => commandRow()),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) =>
          commandRow({ status: data.status as DeviceSurveillanceCommandStatus }),
        ),
      },
    };
    const service = new SurveillanceCommandsService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
    );

    await expect(service.create(deviceId, adminId, { type: 'prune_stubs' })).rejects.toMatchObject({
      code: 'surveillance_command_active',
      statusCode: 409,
    });
  });

  it('claims pending command as running for the device', async () => {
    const update = vi.fn(async () =>
      commandRow({ status: DeviceSurveillanceCommandStatus.running }),
    );
    const db = {
      deviceSurveillanceCommand: {
        findFirst: vi.fn(async () => commandRow()),
        update,
      },
    };
    const service = new SurveillanceCommandsService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
    );

    const result = await service.getPendingForDevice(deviceId, deviceId);
    expect(result.command?.status).toBe('running');
    expect(update).toHaveBeenCalled();
  });

  it('acks success with result payload', async () => {
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) =>
      commandRow({
        status: data.status as DeviceSurveillanceCommandStatus,
        resultJson: data.resultJson,
      }),
    );
    const db = {
      deviceSurveillanceCommand: {
        findUnique: vi.fn(async () =>
          commandRow({ status: DeviceSurveillanceCommandStatus.running }),
        ),
        update,
      },
    };
    const service = new SurveillanceCommandsService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
    );

    const result = await service.ack(deviceId, deviceId, commandId, {
      ok: true,
      result: { healed: 3 },
    });
    expect(result.command.status).toBe('succeeded');
    expect(result.command.result).toEqual({ healed: 3 });
  });

  it('forbids device identity mismatch', async () => {
    const service = new SurveillanceCommandsService(
      {} as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.getPendingForDevice(deviceId, 'other-device')).rejects.toMatchObject({
      code: 'forbidden',
      statusCode: 403,
    });
  });

  it('expireStale closes open past-due commands', async () => {
    const updateMany = vi.fn(async () => ({ count: 2 }));
    const db = {
      deviceSurveillanceCommand: {
        findMany: vi.fn(async () => [{ id: commandId }, { id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' }]),
        updateMany,
      },
    };
    const service = new SurveillanceCommandsService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
    );
    const count = await service.expireStale(new Date());
    expect(count).toBe(2);
  });
});

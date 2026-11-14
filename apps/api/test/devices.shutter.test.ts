import { describe, expect, it, vi } from 'vitest';
import { DeviceStatus } from '@prisma/client';
import { DevicesService } from '../src/modules/devices/devices.service.js';
import { SHUTTER_COMMAND_TTL_MS } from '../src/modules/devices/devices.schemas.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

function deviceRow(
  overrides: Partial<{
    status: DeviceStatus;
    shutterCommand: string | null;
    shutterCommandRequestedAt: Date | null;
  }> = {},
) {
  return {
    id: deviceId,
    name: 'Lobby',
    deviceKey: 'dk_test',
    status: overrides.status ?? DeviceStatus.active,
    latitude: 28.6,
    longitude: 77.2,
    address: null,
    lastHeartbeatAt: null,
    surveillanceEnabled: false,
    shutterCommand: overrides.shutterCommand ?? null,
    shutterCommandRequestedAt: overrides.shutterCommandRequestedAt ?? null,
    site: { name: 'HQ' },
  };
}

describe('DevicesService shutter commands', () => {
  it('enqueues open/close and overwrites the previous pending command', async () => {
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...deviceRow(),
      ...data,
    }));
    const audit = { record: vi.fn(async () => undefined) };
    const db = {
      device: {
        findUnique: vi.fn(async () => deviceRow()),
        update,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    const first = await service.requestShutterCommand(deviceId, { action: 'open' }, 'admin-1');
    expect(first.action).toBe('open');
    expect(Date.parse(first.requestedAt)).not.toBeNaN();

    const second = await service.requestShutterCommand(deviceId, { action: 'close' }, 'admin-1', 'corr');
    expect(second.action).toBe('close');
    expect(update).toHaveBeenLastCalledWith({
      where: { id: deviceId },
      data: {
        shutterCommand: 'close',
        shutterCommandRequestedAt: expect.any(Date),
      },
    });
    expect(audit.record).toHaveBeenLastCalledWith(
      expect.objectContaining({
        action: 'device.shutter_command',
        metadata: expect.objectContaining({ action: 'close' }),
      }),
    );
  });

  it('returns pending shutter with expired flag after TTL', async () => {
    const requestedAt = new Date(Date.now() - SHUTTER_COMMAND_TTL_MS - 1000);
    const db = {
      device: {
        findUnique: vi.fn(async () =>
          deviceRow({
            shutterCommand: 'open',
            shutterCommandRequestedAt: requestedAt,
          }),
        ),
        update: vi.fn(),
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );

    const pending = await service.getPendingShutterCommand(deviceId, deviceId);
    expect(pending).toEqual({
      action: 'open',
      requestedAt: requestedAt.toISOString(),
      expired: true,
    });
    expect(db.device.update).not.toHaveBeenCalled();
  });

  it('clears pending shutter only when ack requestedAt matches', async () => {
    const requestedAt = new Date('2026-11-14T07:00:00.000Z');
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...deviceRow({
        shutterCommand: 'close',
        shutterCommandRequestedAt: requestedAt,
      }),
      ...data,
    }));
    const db = {
      device: {
        findUnique: vi.fn(async () =>
          deviceRow({
            shutterCommand: 'close',
            shutterCommandRequestedAt: requestedAt,
          }),
        ),
        update,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );

    const mismatch = await service.ackShutterCommand(deviceId, deviceId, {
      requestedAt: '2026-11-14T06:00:00.000Z',
      result: 'applied',
    });
    expect(mismatch.cleared).toBe(false);
    expect(update).not.toHaveBeenCalled();

    const match = await service.ackShutterCommand(deviceId, deviceId, {
      requestedAt: requestedAt.toISOString(),
      result: 'applied',
    });
    expect(match.cleared).toBe(true);
    expect(update).toHaveBeenCalledWith({
      where: { id: deviceId },
      data: { shutterCommand: null, shutterCommandRequestedAt: null },
    });
  });
});

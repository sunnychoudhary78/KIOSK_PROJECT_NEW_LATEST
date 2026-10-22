import { describe, expect, it, vi } from 'vitest';
import { DeviceStatus } from '@prisma/client';
import { DevicesService } from '../src/modules/devices/devices.service.js';
import { assertActiveDevice } from '../src/shared/device-guard.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import type { NextFunction, Request, Response } from 'express';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

function deviceRow(status: DeviceStatus) {
  return {
    id: deviceId,
    name: 'Lobby',
    deviceKey: 'dk_test',
    status,
    latitude: 28.6,
    longitude: 77.2,
    address: null,
    lastHeartbeatAt: null,
    surveillanceEnabled: false,
    site: { name: 'HQ' },
  };
}

describe('DevicesService.setStatus', () => {
  it('marks a kiosk inactive and audits deactivation', async () => {
    const row = deviceRow(DeviceStatus.active);
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async ({ data }: { data: { status: DeviceStatus } }) => ({
          ...row,
          ...data,
        })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );
    const result = await service.setStatus(deviceId, 'inactive', 'admin-1', 'corr');
    expect(result.status).toBe(DeviceStatus.inactive);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'device.deactivated',
        principalId: 'admin-1',
        resourceId: deviceId,
      }),
    );
  });

  it('starts a stopped kiosk', async () => {
    const row = deviceRow(DeviceStatus.inactive);
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async ({ data }: { data: { status: DeviceStatus } }) => ({
          ...row,
          ...data,
        })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );
    const result = await service.setStatus(deviceId, 'active', 'admin-1');
    expect(result.status).toBe(DeviceStatus.active);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'device.activated' }),
    );
  });
});

describe('DevicesService.setSurveillance', () => {
  it('starts surveillance and audits', async () => {
    const row = deviceRow(DeviceStatus.active);
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async ({ data }: { data: { surveillanceEnabled: boolean } }) => ({
          ...row,
          ...data,
        })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );
    const result = await service.setSurveillance(deviceId, true, 'admin-1', 'corr');
    expect(result.surveillanceEnabled).toBe(true);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'device.surveillance_started',
        principalId: 'admin-1',
        resourceId: deviceId,
      }),
    );
  });

  it('stops surveillance and audits', async () => {
    const row = { ...deviceRow(DeviceStatus.active), surveillanceEnabled: true };
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async ({ data }: { data: { surveillanceEnabled: boolean } }) => ({
          ...row,
          ...data,
        })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );
    const result = await service.setSurveillance(deviceId, false, 'admin-1');
    expect(result.surveillanceEnabled).toBe(false);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'device.surveillance_stopped' }),
    );
  });
});

describe('DevicesService.heartbeat', () => {
  it('does not resurrect an inactive device', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => deviceRow(DeviceStatus.inactive)),
        update: vi.fn(),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );
    await expect(service.heartbeat(deviceId, deviceId)).rejects.toMatchObject({
      code: 'device_inactive',
      statusCode: 403,
    });
    expect(db.device.update).not.toHaveBeenCalled();
  });

  it('updates lastHeartbeatAt without flipping an already-active device', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => deviceRow(DeviceStatus.active)),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          ...deviceRow(DeviceStatus.active),
          ...data,
        })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );
    await service.heartbeat(deviceId, deviceId);
    expect(db.device.update).toHaveBeenCalledWith({
      where: { id: deviceId },
      data: { lastHeartbeatAt: expect.any(Date) },
    });
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('returns the surveillance flag', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          ...deviceRow(DeviceStatus.active),
          surveillanceEnabled: true,
        })),
        update: vi.fn(async () => ({
          ...deviceRow(DeviceStatus.active),
          surveillanceEnabled: true,
        })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );
    await expect(service.heartbeat(deviceId, deviceId)).resolves.toEqual({
      surveillanceEnabled: true,
    });
  });

  it('persists surveillance health from the heartbeat body', async () => {
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...deviceRow(DeviceStatus.active),
      ...data,
    }));
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          ...deviceRow(DeviceStatus.active),
          surveillanceEnabled: true,
        })),
        update,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );
    const health = {
      state: 'camera_error' as const,
      recording: false,
      queuePending: 2,
      lastErrorCode: 'CAMERA_ERROR',
    };
    await service.heartbeat(deviceId, deviceId, { surveillance: health });
    expect(update).toHaveBeenCalledWith({
      where: { id: deviceId },
      data: {
        lastHeartbeatAt: expect.any(Date),
        surveillanceHealth: health,
        surveillanceHealthAt: expect.any(Date),
      },
    });
  });

  it('persists printer health from the heartbeat body', async () => {
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...deviceRow(DeviceStatus.active),
      ...data,
    }));
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          ...deviceRow(DeviceStatus.active),
          surveillanceEnabled: false,
        })),
        update,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );
    const printer = {
      state: 'jam' as const,
      online: true,
      printerName: 'Brother HL-L3280CDW',
      model: 'Brother HL-L3280CDW',
      pageCounter: 12045,
      snmpOk: true,
      trays: [{ name: 'Tray 1', levelPercent: 40, status: 'ok' }],
      supplies: [{ name: 'Black Toner', color: 'black', levelPercent: 55 }],
      lastErrorCode: 'PAPER_JAM',
    };
    await service.heartbeat(deviceId, deviceId, { printer });
    expect(update).toHaveBeenCalledWith({
      where: { id: deviceId },
      data: {
        lastHeartbeatAt: expect.any(Date),
        printerHealth: printer,
        printerHealthAt: expect.any(Date),
      },
    });
  });
});

describe('assertActiveDevice', () => {
  it('rejects inactive device JWTs', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => ({ status: DeviceStatus.inactive })),
      },
    };
    const next = vi.fn() as NextFunction;
    await assertActiveDevice(db as unknown as DbClient)(
      { principal: { type: 'device', id: deviceId, deviceId } } as Request,
      {} as Response,
      next,
    );
    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ code: 'device_inactive', statusCode: 403 }),
    );
  });

  it('skips non-device principals', async () => {
    const db = { device: { findUnique: vi.fn() } };
    const next = vi.fn() as NextFunction;
    await assertActiveDevice(db as unknown as DbClient)(
      { principal: { type: 'admin', id: 'a1' } } as Request,
      {} as Response,
      next,
    );
    expect(db.device.findUnique).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledWith();
  });
});

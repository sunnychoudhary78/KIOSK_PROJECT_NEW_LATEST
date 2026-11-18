import { describe, expect, it, vi, beforeEach } from 'vitest';
import { DeviceStatus, ScreenShareSessionStatus } from '@prisma/client';
import { ScreenShareService } from '../src/modules/screen_share/screen_share.service.js';
import { SCREEN_SHARE_PENDING_TTL_MS } from '../src/modules/screen_share/screen_share.constants.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import type { AppConfig } from '../src/config/index.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const tenantId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const adminId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

vi.mock('../src/modules/screen_share/livekit_tokens.js', () => ({
  isLiveKitConfigured: (config: AppConfig) =>
    Boolean(config.livekit.url && config.livekit.apiKey && config.livekit.apiSecret),
  mintLiveKitToken: vi.fn(async () => 'test-jwt-token'),
  deleteLiveKitRoom: vi.fn(async () => undefined),
}));

function baseConfig(overrides: Partial<AppConfig['livekit']> = {}): AppConfig {
  return {
    livekit: {
      url: 'wss://example.livekit.cloud',
      apiKey: 'key',
      apiSecret: 'secret',
      ...overrides,
    },
    screenShare: { ttlSeconds: 900 },
  } as AppConfig;
}

function sessionRow(
  overrides: Partial<{
    id: string;
    status: ScreenShareSessionStatus;
    expiresAt: Date;
    startedAt: Date | null;
    lastError: string | null;
  }> = {},
) {
  const id = overrides.id ?? 'dddddddd-dddd-dddd-dddd-dddddddddddd';
  return {
    id,
    tenantId,
    deviceId,
    roomName: `kiosk-${deviceId}-dddddddddddd`,
    status: overrides.status ?? ScreenShareSessionStatus.pending,
    requestedByUserId: adminId,
    requestedAt: new Date('2026-11-18T06:00:00.000Z'),
    startedAt: overrides.startedAt ?? null,
    endedAt: null,
    expiresAt: overrides.expiresAt ?? new Date(Date.now() + SCREEN_SHARE_PENDING_TTL_MS),
    lastError: overrides.lastError ?? null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

describe('ScreenShareService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('rejects start when LiveKit is not configured', async () => {
    const service = new ScreenShareService(
      { device: { findUnique: vi.fn() } } as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
      baseConfig({ url: '', apiKey: '', apiSecret: '' }),
    );
    await expect(service.start(deviceId, adminId)).rejects.toMatchObject({
      code: 'livekit_not_configured',
      statusCode: 503,
    });
  });

  it('creates a pending session and returns viewer token', async () => {
    const create = vi.fn(async ({ data }: { data: Record<string, unknown> }) =>
      sessionRow({ id: data.id as string }),
    );
    const audit = { record: vi.fn(async () => undefined) };
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          id: deviceId,
          tenantId,
          status: DeviceStatus.active,
          name: 'Lobby',
        })),
      },
      screenShareSession: {
        findFirst: vi.fn(async () => null),
        create,
      },
    };
    const service = new ScreenShareService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
      baseConfig(),
    );

    const result = await service.start(deviceId, adminId, 'corr-1');
    expect(result.token).toBe('test-jwt-token');
    expect(result.livekitUrl).toBe('wss://example.livekit.cloud');
    expect(result.session.status).toBe('pending');
    expect(create).toHaveBeenCalled();
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'device.screen_share_started' }),
    );
  });

  it('blocks a second open session', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          id: deviceId,
          tenantId,
          status: DeviceStatus.active,
          name: 'Lobby',
        })),
      },
      screenShareSession: {
        findFirst: vi.fn(async () => sessionRow()),
        update: vi.fn(),
      },
    };
    const service = new ScreenShareService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
      baseConfig(),
    );
    await expect(service.start(deviceId, adminId)).rejects.toMatchObject({
      code: 'screen_share_active',
      statusCode: 409,
    });
  });

  it('expires pending sessions on read after pending TTL', async () => {
    const expiredAt = new Date(Date.now() - 1000);
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) =>
      sessionRow({
        status: data.status as ScreenShareSessionStatus,
        expiresAt: expiredAt,
        lastError: data.lastError as string,
      }),
    );
    const db = {
      device: { findUnique: vi.fn(async () => ({ id: deviceId })) },
      screenShareSession: {
        findFirst: vi.fn(async () =>
          sessionRow({ status: ScreenShareSessionStatus.pending, expiresAt: expiredAt }),
        ),
        update,
      },
    };
    const service = new ScreenShareService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
      baseConfig(),
    );
    const result = await service.getCurrent(deviceId);
    expect(result.session?.status).toBe('expired');
    expect(update).toHaveBeenCalled();
  });

  it('acks started and extends expiresAt', async () => {
    const pending = sessionRow();
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...pending,
      ...data,
      status: ScreenShareSessionStatus.active,
    }));
    const db = {
      screenShareSession: {
        findFirst: vi.fn(async () => pending),
        update,
      },
    };
    const service = new ScreenShareService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
      baseConfig(),
    );
    const result = await service.ack(deviceId, deviceId, {
      sessionId: pending.id,
      result: 'started',
    });
    expect(result.session.status).toBe('active');
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: ScreenShareSessionStatus.active,
          startedAt: expect.any(Date),
          expiresAt: expect.any(Date),
        }),
      }),
    );
  });

  it('returns publisher token for pending device poll', async () => {
    const pending = sessionRow();
    const db = {
      screenShareSession: {
        findFirst: vi.fn(async () => pending),
        update: vi.fn(),
      },
    };
    const service = new ScreenShareService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
      baseConfig(),
    );
    const result = await service.getPendingForDevice(deviceId, deviceId);
    expect(result.token).toBe('test-jwt-token');
    expect(result.session?.status).toBe('pending');
  });

  it('expireStale closes overdue open sessions', async () => {
    const updateMany = vi.fn(async () => ({ count: 1 }));
    const db = {
      screenShareSession: {
        findMany: vi.fn(async () => [{ id: 'x', status: ScreenShareSessionStatus.pending }]),
        updateMany,
      },
    };
    const service = new ScreenShareService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
      baseConfig(),
    );
    const n = await service.expireStale(new Date());
    expect(n).toBe(1);
    expect(updateMany).toHaveBeenCalled();
  });
});

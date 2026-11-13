import { describe, expect, it, vi } from 'vitest';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import {
  listDiagnosticLogsQuerySchema,
  parseLevelsCsv,
  reportDiagnosticLogsSchema,
} from '../src/modules/diagnostic_logs/diagnostic_logs.schemas.js';
import {
  DAILY_LOG_CAP,
  DiagnosticLogsService,
  MAX_LIST_RANGE_MS,
} from '../src/modules/diagnostic_logs/diagnostic_logs.service.js';
import { AppError } from '../src/shared/errors.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

describe('reportDiagnosticLogsSchema', () => {
  it('accepts a valid batch', () => {
    const parsed = reportDiagnosticLogsSchema.safeParse({
      logs: [
        {
          level: 'error',
          category: 'printer',
          event: 'printer.print_failed',
          message: 'Spooler job failed',
        },
        {
          level: 'info',
          category: 'astrology',
          event: 'astrology.today.submit_ok',
          message: 'Today periods ready',
          occurredAt: '2026-11-13T10:00:00.000Z',
          metadata: { feature: 'today' },
        },
      ],
    });
    expect(parsed.success).toBe(true);
  });

  it('rejects invalid category', () => {
    const parsed = reportDiagnosticLogsSchema.safeParse({
      logs: [
        {
          level: 'info',
          category: 'unknown',
          event: 'x.y',
          message: 'nope',
        },
      ],
    });
    expect(parsed.success).toBe(false);
  });

  it('rejects empty batches and oversized batches', () => {
    expect(reportDiagnosticLogsSchema.safeParse({ logs: [] }).success).toBe(
      false,
    );
    const logs = Array.from({ length: 51 }, (_, i) => ({
      level: 'info' as const,
      category: 'app' as const,
      event: 'app.tick',
      message: `m${i}`,
    }));
    expect(reportDiagnosticLogsSchema.safeParse({ logs }).success).toBe(false);
  });
});

describe('listDiagnosticLogsQuerySchema', () => {
  it('parses limit and keeps levels as string', () => {
    const parsed = listDiagnosticLogsQuerySchema.safeParse({
      levels: 'error,warn',
      limit: '50',
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.levels).toBe('error,warn');
      expect(parsed.data.limit).toBe(50);
    }
  });

  it('parseLevelsCsv accepts and rejects', () => {
    expect(parseLevelsCsv('error,warn')).toEqual(['error', 'warn']);
    expect(() => parseLevelsCsv('error,fatal')).toThrow(/Invalid level/);
  });
});

describe('DiagnosticLogsService.ingest', () => {
  it('createMany within daily budget', async () => {
    const createMany = vi.fn(async () => ({ count: 2 }));
    const count = vi.fn(async () => 10);
    const db = {
      device: { findUnique: vi.fn(async () => ({ id: deviceId })) },
      deviceDiagnosticLog: { createMany, count },
    };
    const service = new DiagnosticLogsService(db as unknown as DbClient);

    const result = await service.ingest(deviceId, {
      logs: [
        {
          level: 'error',
          category: 'printer',
          event: 'printer.fail',
          message: 'fail',
        },
        {
          level: 'warn',
          category: 'printer',
          event: 'printer.paper',
          message: 'paper',
          occurredAt: '2026-11-13T12:00:00.000Z',
        },
      ],
    });

    expect(result).toEqual({ accepted: 2, dropped: 0 });
    expect(createMany).toHaveBeenCalledOnce();
  });

  it('truncates to remaining daily cap', async () => {
    const createMany = vi.fn(async () => ({ count: 1 }));
    const count = vi.fn(async () => DAILY_LOG_CAP - 1);
    const db = {
      device: { findUnique: vi.fn(async () => ({ id: deviceId })) },
      deviceDiagnosticLog: { createMany, count },
    };
    const service = new DiagnosticLogsService(db as unknown as DbClient);

    const result = await service.ingest(deviceId, {
      logs: [
        {
          level: 'info',
          category: 'app',
          event: 'app.a',
          message: 'a',
        },
        {
          level: 'info',
          category: 'app',
          event: 'app.b',
          message: 'b',
        },
        {
          level: 'info',
          category: 'app',
          event: 'app.c',
          message: 'c',
        },
      ],
    });

    expect(result).toEqual({ accepted: 1, dropped: 2 });
    const arg = createMany.mock.calls[0]?.[0] as { data: unknown[] };
    expect(arg.data).toHaveLength(1);
  });

  it('drops entire batch when cap reached', async () => {
    const createMany = vi.fn();
    const db = {
      device: { findUnique: vi.fn(async () => ({ id: deviceId })) },
      deviceDiagnosticLog: {
        createMany,
        count: vi.fn(async () => DAILY_LOG_CAP),
      },
    };
    const service = new DiagnosticLogsService(db as unknown as DbClient);

    const result = await service.ingest(deviceId, {
      logs: [
        {
          level: 'info',
          category: 'app',
          event: 'app.a',
          message: 'a',
        },
      ],
    });

    expect(result).toEqual({ accepted: 0, dropped: 1 });
    expect(createMany).not.toHaveBeenCalled();
  });

  it('throws not_found for missing device', async () => {
    const db = {
      device: { findUnique: vi.fn(async () => null) },
      deviceDiagnosticLog: { createMany: vi.fn(), count: vi.fn() },
    };
    const service = new DiagnosticLogsService(db as unknown as DbClient);
    await expect(
      service.ingest(deviceId, {
        logs: [
          {
            level: 'info',
            category: 'app',
            event: 'app.a',
            message: 'a',
          },
        ],
      }),
    ).rejects.toBeInstanceOf(AppError);
  });
});

describe('DiagnosticLogsService.listForDevice', () => {
  it('clamps range to 7 days', async () => {
    const findMany = vi.fn(async () => []);
    const db = {
      device: { findUnique: vi.fn(async () => ({ id: deviceId })) },
      deviceDiagnosticLog: { findMany },
    };
    const service = new DiagnosticLogsService(db as unknown as DbClient);

    const to = '2026-11-13T12:00:00.000Z';
    const from = '2026-10-01T12:00:00.000Z';
    const result = await service.listForDevice(deviceId, { from, to });

    const expectedFrom = new Date(
      new Date(to).getTime() - MAX_LIST_RANGE_MS,
    ).toISOString();
    expect(result.from).toBe(expectedFrom);
    expect(result.to).toBe(to);
    expect(findMany).toHaveBeenCalledOnce();
  });

  it('throws not_found when device is missing', async () => {
    const db = {
      device: { findUnique: vi.fn(async () => null) },
      deviceDiagnosticLog: { findMany: vi.fn() },
    };
    const service = new DiagnosticLogsService(db as unknown as DbClient);
    await expect(service.listForDevice(deviceId, {})).rejects.toBeInstanceOf(
      AppError,
    );
  });
});

describe('DiagnosticLogsService.purgeOlderThan', () => {
  it('deletes in batches until empty', async () => {
    const ids1 = Array.from({ length: 2 }, (_, i) => ({
      id: `00000000-0000-0000-0000-00000000000${i + 1}`,
    }));
    const findMany = vi
      .fn()
      .mockResolvedValueOnce(ids1)
      .mockResolvedValueOnce([]);
    const deleteMany = vi.fn(async () => ({ count: 2 }));
    const db = {
      deviceDiagnosticLog: { findMany, deleteMany },
    };
    const service = new DiagnosticLogsService(db as unknown as DbClient);

    const deleted = await service.purgeOlderThan(7);
    expect(deleted).toBe(2);
    expect(deleteMany).toHaveBeenCalledOnce();
  });
});

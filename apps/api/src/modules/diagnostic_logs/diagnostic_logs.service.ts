import type { Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type {
  ListDiagnosticLogsQuery,
  ReportDiagnosticLogsInput,
} from './diagnostic_logs.schemas.js';
import { parseLevelsCsv } from './diagnostic_logs.schemas.js';

export const DAILY_LOG_CAP = 2000;
export const DEFAULT_LIST_LIMIT = 100;
export const MAX_LIST_RANGE_MS = 7 * 24 * 60 * 60 * 1000;
export const DEFAULT_LIST_RANGE_MS = 24 * 60 * 60 * 1000;
export const PURGE_BATCH_SIZE = 5000;
export const RETENTION_DAYS = 7;

function startOfUtcDay(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

export class DiagnosticLogsService {
  constructor(private readonly db: DbClient) {}

  async ingest(deviceId: string, input: ReportDiagnosticLogsInput) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const dayStart = startOfUtcDay(new Date());
    const usedToday = await this.db.deviceDiagnosticLog.count({
      where: {
        deviceId,
        occurredAt: { gte: dayStart },
      },
    });
    const remaining = Math.max(0, DAILY_LOG_CAP - usedToday);
    if (remaining === 0) {
      return { accepted: 0, dropped: input.logs.length };
    }

    const acceptedLogs = input.logs.slice(0, remaining);
    const dropped = input.logs.length - acceptedLogs.length;

    const data = acceptedLogs.map((log) => ({
      deviceId,
      level: log.level,
      category: log.category,
      event: log.event,
      message: log.message,
      occurredAt: log.occurredAt ? new Date(log.occurredAt) : new Date(),
      correlationId: log.correlationId ?? null,
      metadata: (log.metadata as Prisma.InputJsonValue) ?? undefined,
    }));

    await this.db.deviceDiagnosticLog.createMany({ data });
    return { accepted: data.length, dropped };
  }

  async listForDevice(deviceId: string, query: ListDiagnosticLogsQuery) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const to = query.to ? new Date(query.to) : new Date();
    let from = query.from
      ? new Date(query.from)
      : new Date(to.getTime() - DEFAULT_LIST_RANGE_MS);

    if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
      throw new AppError('validation_error', 'Invalid from/to datetime', 400);
    }
    if (from > to) {
      throw new AppError('validation_error', '`from` must be before `to`', 400);
    }

    const span = to.getTime() - from.getTime();
    if (span > MAX_LIST_RANGE_MS) {
      from = new Date(to.getTime() - MAX_LIST_RANGE_MS);
    }

    const limit = Math.min(query.limit ?? DEFAULT_LIST_LIMIT, 200);
    let levels;
    try {
      levels =
        parseLevelsCsv(query.levels) ??
        (query.level != null ? [query.level] : undefined);
    } catch {
      throw new AppError('validation_error', 'Invalid levels filter', 400);
    }

    const and: Prisma.DeviceDiagnosticLogWhereInput[] = [
      { deviceId },
      { occurredAt: { gte: from, lte: to } },
    ];
    if (query.category) {
      and.push({ category: query.category });
    }
    if (levels && levels.length > 0) {
      and.push({ level: { in: levels } });
    }
    if (query.before) {
      const beforeAt = new Date(query.before);
      if (Number.isNaN(beforeAt.getTime())) {
        throw new AppError('validation_error', 'Invalid before datetime', 400);
      }
      if (query.beforeId) {
        and.push({
          OR: [
            { occurredAt: { lt: beforeAt } },
            { occurredAt: beforeAt, id: { lt: query.beforeId } },
          ],
        });
      } else {
        and.push({ occurredAt: { lt: beforeAt } });
      }
    }
    const where: Prisma.DeviceDiagnosticLogWhereInput = { AND: and };

    const rows = await this.db.deviceDiagnosticLog.findMany({
      where,
      orderBy: [{ occurredAt: 'desc' }, { id: 'desc' }],
      take: limit,
      select: {
        id: true,
        occurredAt: true,
        level: true,
        category: true,
        event: true,
        message: true,
        correlationId: true,
        metadata: true,
      },
    });

    const items = rows.map((row) => ({
      id: row.id,
      occurredAt: row.occurredAt.toISOString(),
      level: row.level,
      category: row.category,
      event: row.event,
      message: row.message,
      correlationId: row.correlationId,
      metadata: row.metadata,
    }));

    const last = items[items.length - 1];
    return {
      deviceId,
      from: from.toISOString(),
      to: to.toISOString(),
      items,
      nextBefore: last?.occurredAt ?? null,
      nextBeforeId: last?.id ?? null,
      hasMore: items.length === limit,
    };
  }

  /** Deletes rows older than retention; returns total deleted. */
  async purgeOlderThan(days = RETENTION_DAYS): Promise<number> {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    let total = 0;
    for (;;) {
      const batch = await this.db.deviceDiagnosticLog.findMany({
        where: { occurredAt: { lt: cutoff } },
        select: { id: true },
        take: PURGE_BATCH_SIZE,
      });
      if (batch.length === 0) break;
      const result = await this.db.deviceDiagnosticLog.deleteMany({
        where: { id: { in: batch.map((r) => r.id) } },
      });
      total += result.count;
      if (batch.length < PURGE_BATCH_SIZE) break;
    }
    return total;
  }
}

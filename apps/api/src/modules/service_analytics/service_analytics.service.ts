import type { Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type {
  ReportServiceEventsInput,
  ServiceAnalyticsQuery,
} from './service_analytics.schemas.js';

const DEFAULT_RANGE_DAYS = 30;

export class ServiceAnalyticsService {
  constructor(private readonly db: DbClient) {}

  async reportEvents(deviceId: string, input: ReportServiceEventsInput) {
    const data = input.events.map((event) => ({
      deviceId,
      eventKey: event.eventKey,
      occurredAt: event.occurredAt ? new Date(event.occurredAt) : new Date(),
      metadata: (event.metadata as Prisma.InputJsonValue) ?? undefined,
    }));
    await this.db.serviceNavigationEvent.createMany({ data });
    return { accepted: data.length };
  }

  async analyticsForDevice(deviceId: string, query: ServiceAnalyticsQuery) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const to = query.to ? new Date(query.to) : new Date();
    const from = query.from
      ? new Date(query.from)
      : new Date(to.getTime() - DEFAULT_RANGE_DAYS * 24 * 60 * 60 * 1000);

    if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
      throw new AppError('validation_error', 'Invalid from/to datetime', 400);
    }
    if (from > to) {
      throw new AppError('validation_error', '`from` must be before `to`', 400);
    }

    const rows = await this.db.serviceNavigationEvent.groupBy({
      by: ['eventKey'],
      where: {
        deviceId,
        occurredAt: { gte: from, lte: to },
      },
      _count: { _all: true },
    });

    const items = rows
      .map((row) => ({
        eventKey: row.eventKey,
        count: row._count._all,
      }))
      .sort((a, b) => b.count - a.count || a.eventKey.localeCompare(b.eventKey));

    return {
      deviceId,
      from: from.toISOString(),
      to: to.toISOString(),
      items,
    };
  }
}

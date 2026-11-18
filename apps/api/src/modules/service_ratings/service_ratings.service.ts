import type { Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type {
  ReportServiceRatingsInput,
  ServiceRatingsQuery,
} from './service_ratings.schemas.js';

const DEFAULT_RANGE_DAYS = 30;

export class ServiceRatingsService {
  constructor(private readonly db: DbClient) {}

  async reportRatings(deviceId: string, input: ReportServiceRatingsInput) {
    const data = input.ratings.map((rating) => ({
      deviceId,
      serviceKey: rating.serviceKey,
      stars: rating.stars,
      occurredAt: rating.occurredAt ? new Date(rating.occurredAt) : new Date(),
      metadata: (rating.metadata as Prisma.InputJsonValue) ?? undefined,
    }));
    await this.db.serviceRating.createMany({ data });
    return { accepted: data.length };
  }

  async ratingsForDevice(deviceId: string, query: ServiceRatingsQuery) {
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

    const rows = await this.db.serviceRating.groupBy({
      by: ['serviceKey'],
      where: {
        deviceId,
        occurredAt: { gte: from, lte: to },
      },
      _count: { _all: true },
      _avg: { stars: true },
    });

    const items = rows
      .map((row) => ({
        serviceKey: row.serviceKey,
        count: row._count._all,
        avgStars: Math.round((row._avg.stars ?? 0) * 10) / 10,
      }))
      .sort(
        (a, b) =>
          b.count - a.count || a.serviceKey.localeCompare(b.serviceKey),
      );

    return {
      deviceId,
      from: from.toISOString(),
      to: to.toISOString(),
      items,
    };
  }
}

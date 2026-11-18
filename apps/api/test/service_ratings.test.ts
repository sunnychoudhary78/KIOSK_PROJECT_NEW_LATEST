import { describe, expect, it, vi } from 'vitest';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import {
  reportServiceRatingsSchema,
  serviceRatingsQuerySchema,
} from '../src/modules/service_ratings/service_ratings.schemas.js';
import { ServiceRatingsService } from '../src/modules/service_ratings/service_ratings.service.js';
import { AppError } from '../src/shared/errors.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

describe('reportServiceRatingsSchema', () => {
  it('accepts a valid batch', () => {
    const parsed = reportServiceRatingsSchema.safeParse({
      ratings: [
        { serviceKey: 'print.otp_print', stars: 5 },
        {
          serviceKey: 'home.charging',
          stars: 4,
          occurredAt: '2026-11-18T10:00:00.000Z',
        },
      ],
    });
    expect(parsed.success).toBe(true);
  });

  it('rejects stars outside 1-5', () => {
    expect(
      reportServiceRatingsSchema.safeParse({
        ratings: [{ serviceKey: 'print.otp_print', stars: 0 }],
      }).success,
    ).toBe(false);
    expect(
      reportServiceRatingsSchema.safeParse({
        ratings: [{ serviceKey: 'print.otp_print', stars: 6 }],
      }).success,
    ).toBe(false);
  });

  it('rejects invalid service keys', () => {
    const parsed = reportServiceRatingsSchema.safeParse({
      ratings: [{ serviceKey: 'Print.OTP', stars: 3 }],
    });
    expect(parsed.success).toBe(false);
  });

  it('rejects empty batches', () => {
    expect(reportServiceRatingsSchema.safeParse({ ratings: [] }).success).toBe(
      false,
    );
  });
});

describe('serviceRatingsQuerySchema', () => {
  it('allows empty query', () => {
    expect(serviceRatingsQuerySchema.safeParse({}).success).toBe(true);
  });

  it('rejects bad datetimes', () => {
    expect(
      serviceRatingsQuerySchema.safeParse({ from: 'yesterday' }).success,
    ).toBe(false);
  });
});

describe('ServiceRatingsService', () => {
  it('createMany on reportRatings and returns accepted count', async () => {
    const createMany = vi.fn(async () => ({ count: 2 }));
    const db = {
      serviceRating: { createMany },
    };
    const service = new ServiceRatingsService(db as unknown as DbClient);

    const result = await service.reportRatings(deviceId, {
      ratings: [
        { serviceKey: 'print.otp_print', stars: 5 },
        {
          serviceKey: 'home.charging',
          stars: 3,
          occurredAt: '2026-11-18T12:00:00.000Z',
        },
      ],
    });

    expect(result).toEqual({ accepted: 2 });
    expect(createMany).toHaveBeenCalledOnce();
    const arg = createMany.mock.calls[0]?.[0] as {
      data: Array<{
        deviceId: string;
        serviceKey: string;
        stars: number;
        occurredAt: Date;
      }>;
    };
    expect(arg.data).toHaveLength(2);
    expect(arg.data[0]).toMatchObject({
      deviceId,
      serviceKey: 'print.otp_print',
      stars: 5,
    });
    expect(arg.data[1]).toMatchObject({
      deviceId,
      serviceKey: 'home.charging',
      stars: 3,
      occurredAt: new Date('2026-11-18T12:00:00.000Z'),
    });
  });

  it('aggregates avg and count for a device in range', async () => {
    const findUnique = vi.fn(async () => ({ id: deviceId }));
    const groupBy = vi.fn(async () => [
      { serviceKey: 'print.otp_print', _count: { _all: 4 }, _avg: { stars: 4.25 } },
      { serviceKey: 'home.charging', _count: { _all: 2 }, _avg: { stars: 5 } },
    ]);
    const db = {
      device: { findUnique },
      serviceRating: { groupBy },
    };
    const service = new ServiceRatingsService(db as unknown as DbClient);

    const result = await service.ratingsForDevice(deviceId, {
      from: '2026-10-01T00:00:00.000Z',
      to: '2026-11-01T00:00:00.000Z',
    });

    expect(result.deviceId).toBe(deviceId);
    expect(result.from).toBe('2026-10-01T00:00:00.000Z');
    expect(result.to).toBe('2026-11-01T00:00:00.000Z');
    expect(result.items).toEqual([
      { serviceKey: 'print.otp_print', count: 4, avgStars: 4.3 },
      { serviceKey: 'home.charging', count: 2, avgStars: 5 },
    ]);
    expect(groupBy).toHaveBeenCalledOnce();
  });

  it('throws not_found when device is missing', async () => {
    const db = {
      device: { findUnique: vi.fn(async () => null) },
      serviceRating: { groupBy: vi.fn() },
    };
    const service = new ServiceRatingsService(db as unknown as DbClient);

    await expect(service.ratingsForDevice(deviceId, {})).rejects.toBeInstanceOf(
      AppError,
    );
  });
});

import { describe, expect, it, vi } from 'vitest';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import {
  reportServiceEventsSchema,
  serviceAnalyticsQuerySchema,
} from '../src/modules/service_analytics/service_analytics.schemas.js';
import { ServiceAnalyticsService } from '../src/modules/service_analytics/service_analytics.service.js';
import { AppError } from '../src/shared/errors.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

describe('reportServiceEventsSchema', () => {
  it('accepts a valid batch', () => {
    const parsed = reportServiceEventsSchema.safeParse({
      events: [
        { eventKey: 'home.print' },
        {
          eventKey: 'print.digilocker_print',
          occurredAt: '2026-11-04T10:00:00.000Z',
          metadata: { source: 'route' },
        },
      ],
    });
    expect(parsed.success).toBe(true);
  });

  it('rejects invalid event keys', () => {
    const parsed = reportServiceEventsSchema.safeParse({
      events: [{ eventKey: 'Home.Print' }],
    });
    expect(parsed.success).toBe(false);
  });

  it('rejects empty batches', () => {
    const parsed = reportServiceEventsSchema.safeParse({ events: [] });
    expect(parsed.success).toBe(false);
  });
});

describe('serviceAnalyticsQuerySchema', () => {
  it('allows empty query', () => {
    expect(serviceAnalyticsQuerySchema.safeParse({}).success).toBe(true);
  });

  it('rejects bad datetimes', () => {
    expect(
      serviceAnalyticsQuerySchema.safeParse({ from: 'yesterday' }).success,
    ).toBe(false);
  });
});

describe('ServiceAnalyticsService', () => {
  it('createMany on reportEvents and returns accepted count', async () => {
    const createMany = vi.fn(async () => ({ count: 2 }));
    const db = {
      serviceNavigationEvent: { createMany },
    };
    const service = new ServiceAnalyticsService(db as unknown as DbClient);

    const result = await service.reportEvents(deviceId, {
      events: [
        { eventKey: 'home.print' },
        { eventKey: 'print.otp_print', occurredAt: '2026-11-04T12:00:00.000Z' },
      ],
    });

    expect(result).toEqual({ accepted: 2 });
    expect(createMany).toHaveBeenCalledOnce();
    const arg = createMany.mock.calls[0]?.[0] as {
      data: Array<{ deviceId: string; eventKey: string; occurredAt: Date }>;
    };
    expect(arg.data).toHaveLength(2);
    expect(arg.data[0]).toMatchObject({ deviceId, eventKey: 'home.print' });
    expect(arg.data[1]).toMatchObject({
      deviceId,
      eventKey: 'print.otp_print',
      occurredAt: new Date('2026-11-04T12:00:00.000Z'),
    });
  });

  it('aggregates counts for a device in range', async () => {
    const findUnique = vi.fn(async () => ({ id: deviceId }));
    const groupBy = vi.fn(async () => [
      { eventKey: 'home.print', _count: { _all: 5 } },
      { eventKey: 'print.digilocker_print', _count: { _all: 12 } },
      { eventKey: 'astrology.kundali', _count: { _all: 3 } },
    ]);
    const db = {
      device: { findUnique },
      serviceNavigationEvent: { groupBy },
    };
    const service = new ServiceAnalyticsService(db as unknown as DbClient);

    const result = await service.analyticsForDevice(deviceId, {
      from: '2026-10-01T00:00:00.000Z',
      to: '2026-11-01T00:00:00.000Z',
    });

    expect(result.deviceId).toBe(deviceId);
    expect(result.from).toBe('2026-10-01T00:00:00.000Z');
    expect(result.to).toBe('2026-11-01T00:00:00.000Z');
    expect(result.items).toEqual([
      { eventKey: 'print.digilocker_print', count: 12 },
      { eventKey: 'home.print', count: 5 },
      { eventKey: 'astrology.kundali', count: 3 },
    ]);
    expect(groupBy).toHaveBeenCalledOnce();
  });

  it('throws not_found when device is missing', async () => {
    const db = {
      device: { findUnique: vi.fn(async () => null) },
      serviceNavigationEvent: { groupBy: vi.fn() },
    };
    const service = new ServiceAnalyticsService(db as unknown as DbClient);

    await expect(service.analyticsForDevice(deviceId, {})).rejects.toBeInstanceOf(
      AppError,
    );
  });
});

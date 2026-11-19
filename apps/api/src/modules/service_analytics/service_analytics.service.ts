import type { Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type {
  ReportServiceEventsInput,
  ServiceAnalyticsQuery,
} from './service_analytics.schemas.js';

const DEFAULT_RANGE_DAYS = 30;
const TZ = 'Asia/Kolkata';

function pctDelta(current: number, previous: number): number | null {
  if (previous === 0) {
    // 0 → 0 is flat; 0 → N is treated as +100% so the UI can show a clear uplift.
    if (current === 0) return 0;
    return 100;
  }
  return Math.round(((current - previous) / previous) * 1000) / 10;
}

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

  private resolveRange(query: ServiceAnalyticsQuery) {
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
    return { from, to };
  }

  async analyticsForDevice(deviceId: string, query: ServiceAnalyticsQuery) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true, name: true, site: { select: { name: true } } },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const { from, to } = this.resolveRange(query);
    const durationMs = Math.max(to.getTime() - from.getTime(), 1);
    const previousFrom = new Date(from.getTime() - durationMs);
    const previousTo = new Date(to.getTime() - durationMs);

    const [rows, previousRows, dailyRaw, hourlyRaw] = await Promise.all([
      this.db.serviceNavigationEvent.groupBy({
        by: ['eventKey'],
        where: {
          deviceId,
          occurredAt: { gte: from, lte: to },
        },
        _count: { _all: true },
      }),
      this.db.serviceNavigationEvent.groupBy({
        by: ['eventKey'],
        where: {
          deviceId,
          occurredAt: { gte: previousFrom, lte: previousTo },
        },
        _count: { _all: true },
      }),
      this.db.$queryRaw<Array<{ day: Date; count: bigint }>>`
        SELECT date_trunc('day', occurred_at AT TIME ZONE 'Asia/Kolkata')::date AS day,
               COUNT(*)::bigint AS count
        FROM service_navigation_events
        WHERE device_id = ${deviceId}::uuid
          AND occurred_at >= ${from}
          AND occurred_at <= ${to}
        GROUP BY 1
        ORDER BY 1 ASC
      `,
      this.db.$queryRaw<Array<{ hour: number; count: bigint }>>`
        SELECT EXTRACT(HOUR FROM occurred_at AT TIME ZONE 'Asia/Kolkata')::int AS hour,
               COUNT(*)::bigint AS count
        FROM service_navigation_events
        WHERE device_id = ${deviceId}::uuid
          AND occurred_at >= ${from}
          AND occurred_at <= ${to}
        GROUP BY 1
        ORDER BY 1 ASC
      `,
    ]);

    const items = rows
      .map((row) => ({
        eventKey: row.eventKey,
        count: row._count._all,
      }))
      .sort((a, b) => b.count - a.count || a.eventKey.localeCompare(b.eventKey));

    const previousTotalClicks = previousRows.reduce(
      (sum, row) => sum + row._count._all,
      0,
    );
    const previousUniqueServices = previousRows.length;

    const dailyMap = new Map(
      dailyRaw.map((row) => {
        const iso =
          row.day instanceof Date
            ? row.day.toISOString().slice(0, 10)
            : String(row.day).slice(0, 10);
        return [iso, Number(row.count)] as const;
      }),
    );
    const dayFmt = new Intl.DateTimeFormat('en-CA', {
      timeZone: TZ,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    const dayKeys: string[] = [];
    const seenDays = new Set<string>();
    for (let t = from.getTime(); t <= to.getTime(); t += 12 * 60 * 60 * 1000) {
      const key = dayFmt.format(new Date(t));
      if (!seenDays.has(key)) {
        seenDays.add(key);
        dayKeys.push(key);
      }
    }
    const daily = dayKeys.map((date) => ({ date, count: dailyMap.get(date) ?? 0 }));

    const hourlyMap = new Map(
      hourlyRaw.map((row) => [Number(row.hour), Number(row.count)] as const),
    );
    const hourly = Array.from({ length: 24 }, (_, hour) => ({
      hour,
      count: hourlyMap.get(hour) ?? 0,
    }));

    const totalClicks = items.reduce((sum, item) => sum + item.count, 0);
    const homeItems = items.filter((item) => item.eventKey.startsWith('home.'));

    return {
      deviceId,
      kioskName: device.name,
      siteName: device.site?.name ?? null,
      from: from.toISOString(),
      to: to.toISOString(),
      totalClicks,
      uniqueServices: items.length,
      topEventKey: homeItems[0]?.eventKey ?? items[0]?.eventKey ?? null,
      topEventCount: homeItems[0]?.count ?? items[0]?.count ?? 0,
      items,
      daily,
      hourly,
      previous: {
        from: previousFrom.toISOString(),
        to: previousTo.toISOString(),
        totalClicks: previousTotalClicks,
        uniqueServices: previousUniqueServices,
      },
      comparison: {
        totalClicksDelta: totalClicks - previousTotalClicks,
        totalClicksDeltaPct: pctDelta(totalClicks, previousTotalClicks),
        uniqueServicesDelta: items.length - previousUniqueServices,
        uniqueServicesDeltaPct: pctDelta(items.length, previousUniqueServices),
      },
    };
  }

  /** Fleet rollup: clicks per kiosk for the selected range. */
  async analyticsByDevice(query: ServiceAnalyticsQuery) {
    const { from, to } = this.resolveRange(query);

    const devices = await this.db.device.findMany({
      select: {
        id: true,
        name: true,
        status: true,
        site: { select: { name: true } },
      },
      orderBy: { name: 'asc' },
    });

    const rows = await this.db.serviceNavigationEvent.groupBy({
      by: ['deviceId', 'eventKey'],
      where: {
        occurredAt: { gte: from, lte: to },
      },
      _count: { _all: true },
    });

    const byDevice = new Map<string, Array<{ eventKey: string; count: number }>>();
    for (const row of rows) {
      const list = byDevice.get(row.deviceId) ?? [];
      list.push({ eventKey: row.eventKey, count: row._count._all });
      byDevice.set(row.deviceId, list);
    }

    const items = devices.map((device) => {
      const events = (byDevice.get(device.id) ?? []).sort(
        (a, b) => b.count - a.count || a.eventKey.localeCompare(b.eventKey),
      );
      const totalClicks = events.reduce((sum, event) => sum + event.count, 0);
      const homeEvents = events.filter((event) => event.eventKey.startsWith('home.'));
      const top = homeEvents[0] ?? events[0] ?? null;
      return {
        deviceId: device.id,
        name: device.name,
        siteName: device.site?.name ?? null,
        status: device.status,
        totalClicks,
        activeEventKeys: events.filter((event) => event.count > 0).length,
        topEventKey: top?.eventKey ?? null,
        topEventCount: top?.count ?? 0,
      };
    });

    items.sort((a, b) => b.totalClicks - a.totalClicks || a.name.localeCompare(b.name));

    const siteMap = new Map<
      string,
      { siteName: string; kiosks: number; totalClicks: number; activeKiosks: number }
    >();
    for (const item of items) {
      const siteName = item.siteName?.trim() || 'Unassigned';
      const bucket = siteMap.get(siteName) ?? {
        siteName,
        kiosks: 0,
        totalClicks: 0,
        activeKiosks: 0,
      };
      bucket.kiosks += 1;
      bucket.totalClicks += item.totalClicks;
      if (item.totalClicks > 0) bucket.activeKiosks += 1;
      siteMap.set(siteName, bucket);
    }
    const sites = [...siteMap.values()].sort(
      (a, b) => b.totalClicks - a.totalClicks || a.siteName.localeCompare(b.siteName),
    );

    const idleKiosks = items
      .filter((item) => item.totalClicks === 0)
      .map((item) => ({
        deviceId: item.deviceId,
        name: item.name,
        siteName: item.siteName,
        status: item.status,
      }));

    return {
      from: from.toISOString(),
      to: to.toISOString(),
      fleetTotalClicks: items.reduce((sum, item) => sum + item.totalClicks, 0),
      activeKiosks: items.filter((item) => item.totalClicks > 0).length,
      idleKiosks,
      sites,
      items,
    };
  }
}

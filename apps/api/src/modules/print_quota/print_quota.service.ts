import {
  FreePageLedgerStatus,
  PrintColorMode,
  type Prisma,
} from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import { normalizePhone } from '../../shared/otp.js';
import type { DevicePrintLimits } from '../devices/device_print_limits.js';
import { printLimitsFromDevice } from '../devices/device_print_limits.js';
import type { PrintColorMode as QuoteColorMode } from '../otp_print/otp_print.quote.js';
import type { PrintFreeQuotaConfig } from '../platform_settings/platform_settings.defaults.js';
import { PlatformSettingsService } from '../platform_settings/platform_settings.service.js';
import type { AuditService } from '../audit/audit.service.js';
import { isWithinLocalTimeWindow, periodKeyFor } from './print_quota.time.js';
import { quoteWithEffectiveFree } from './print_quota.quote.js';

type TxClient = Prisma.TransactionClient;

export type QuotaDeviceSlice = Partial<DevicePrintLimits> & {
  freeDisabledFromLocal?: string | null;
  freeDisabledToLocal?: string | null;
};

export type EffectiveFreeResult = {
  freePages: number;
  remainingBefore: number;
  periodLimit: number;
  periodKey: string;
  freeDisabledNow: boolean;
  kioskCap: number;
  phone: string | null;
};

function toPrismaColorMode(mode: QuoteColorMode): PrintColorMode {
  return mode === 'color' ? PrintColorMode.color : PrintColorMode.bw;
}

type ResolvedQuota = {
  config: PrintFreeQuotaConfig;
  society: boolean;
};

type RemainingQuota = {
  remaining: number;
  used: number;
  periodLimit: number;
  periodKey: string;
  period: PrintFreeQuotaConfig['period'];
  society: boolean;
};

function isQuotaExhausted(
  bwUsed: number,
  bwLimit: number,
  colorUsed: number,
  colorLimit: number,
  combined = false,
  combinedLimit = 0,
): boolean {
  if (combined) {
    const limit = Math.max(0, combinedLimit);
    if (limit <= 0) {
      return bwUsed + colorUsed > 0;
    }
    return bwUsed + colorUsed >= limit;
  }
  const hasBw = bwLimit > 0;
  const hasColor = colorLimit > 0;
  if (!hasBw && !hasColor) {
    return bwUsed + colorUsed > 0;
  }
  return (!hasBw || bwUsed >= bwLimit) && (!hasColor || colorUsed >= colorLimit);
}

function combinedPoolLimit(config: PrintFreeQuotaConfig): number {
  if (config.combined) {
    return Math.max(0, Math.floor(config.freePages ?? config.freeBwPages));
  }
  return 0;
}

export class PrintQuotaService {
  private readonly settings: PlatformSettingsService;

  constructor(
    private readonly db: DbClient,
    audit: AuditService,
  ) {
    this.settings = new PlatformSettingsService(db, audit);
  }

  isFreeDisabledNow(device: QuotaDeviceSlice, now: Date = new Date()): boolean {
    const limits = printLimitsFromDevice(device);
    return isWithinLocalTimeWindow(
      now,
      limits.freeDisabledFromLocal ?? device.freeDisabledFromLocal,
      limits.freeDisabledToLocal ?? device.freeDisabledToLocal,
    );
  }

  private async resolveQuota(phone: string, db: DbClient | TxClient): Promise<ResolvedQuota> {
    const globalConfig = await this.settings.getPrintFreeQuotaConfig();
    const normalized = normalizePhone(phone);
    const listed = await db.societyPhone.findUnique({
      where: { phone: normalized },
      select: { id: true },
    });
    if (!listed) {
      return { config: globalConfig, society: false };
    }
    return {
      config: await this.settings.getSocietyFreeQuotaConfig(),
      society: true,
    };
  }

  async getRemaining(
    phone: string,
    mode: QuoteColorMode,
    now: Date = new Date(),
    tx?: TxClient,
  ): Promise<RemainingQuota> {
    const db = tx ?? this.db;
    const { config, society } = await this.resolveQuota(phone, db);
    const periodKey = periodKeyFor(now, config.period);
    const combined = Boolean(config.combined || society);
    const periodLimit = combined
      ? combinedPoolLimit({ ...config, combined: true })
      : mode === 'color'
        ? config.freeColorPages
        : config.freeBwPages;
    const normalized = normalizePhone(phone);
    const colorMode = toPrismaColorMode(mode);

    const rows = await db.phoneFreePageLedger.findMany({
      where: {
        phone: normalized,
        ...(combined ? {} : { printColorMode: colorMode }),
        periodKey,
        status: { in: [FreePageLedgerStatus.reserved, FreePageLedgerStatus.consumed] },
      },
      select: { pages: true },
    });
    const used = rows.reduce((sum, row) => sum + row.pages, 0);
    return {
      remaining: Math.max(0, periodLimit - used),
      used,
      periodLimit,
      periodKey,
      period: config.period,
      society,
    };
  }

  async computeEffectiveFree(input: {
    phone?: string | null;
    device: QuotaDeviceSlice;
    mode: QuoteColorMode;
    pageCount: number;
    now?: Date;
    tx?: TxClient;
  }): Promise<EffectiveFreeResult> {
    const now = input.now ?? new Date();
    const limits = printLimitsFromDevice(input.device);
    const freeDisabledNow = this.isFreeDisabledNow(input.device, now);

    if (!input.phone) {
      const config = await this.settings.getPrintFreeQuotaConfig();
      const periodLimit = input.mode === 'color' ? config.freeColorPages : config.freeBwPages;
      const kioskCap =
        input.mode === 'color' ? limits.freeColorPagesPerSession : limits.freePagesPerSession;
      return {
        freePages: 0,
        remainingBefore: periodLimit,
        periodLimit,
        periodKey: periodKeyFor(now, config.period),
        freeDisabledNow,
        kioskCap,
        phone: null,
      };
    }

    const quota = await this.getRemaining(input.phone, input.mode, now, input.tx);
    // Society combined pool may be spent on either B/W or color; use the higher session free cap.
    const kioskCap = quota.society
      ? Math.max(limits.freePagesPerSession, limits.freeColorPagesPerSession)
      : input.mode === 'color'
        ? limits.freeColorPagesPerSession
        : limits.freePagesPerSession;
    const freePages = freeDisabledNow
      ? 0
      : Math.min(quota.remaining, kioskCap, Math.max(0, input.pageCount));
    return {
      freePages,
      remainingBefore: quota.remaining,
      periodLimit: quota.periodLimit,
      periodKey: quota.periodKey,
      freeDisabledNow,
      kioskCap,
      phone: normalizePhone(input.phone),
    };
  }

  async buildQuote(input: {
    phone?: string | null;
    device: QuotaDeviceSlice;
    mode: QuoteColorMode;
    pageCount: number;
    now?: Date;
    tx?: TxClient;
  }) {
    const effective = await this.computeEffectiveFree(input);
    const limits = printLimitsFromDevice(input.device);
    const quote = quoteWithEffectiveFree(
      input.pageCount,
      limits,
      input.mode,
      effective.freePages,
    );
    return { quote, effective };
  }

  async reserveFreePages(input: {
    phone: string;
    mode: QuoteColorMode;
    pages: number;
    periodKey: string;
    otpChallengeId?: string;
    quickPrintSessionId?: string;
    printJobId?: string;
    tx?: TxClient;
  }): Promise<void> {
    if (input.pages <= 0) return;
    const db = input.tx ?? this.db;
    const phone = normalizePhone(input.phone);

    if (input.otpChallengeId) {
      const existing = await db.phoneFreePageLedger.findUnique({
        where: { otpChallengeId: input.otpChallengeId },
      });
      if (existing) return;
    }
    if (input.quickPrintSessionId) {
      const existing = await db.phoneFreePageLedger.findUnique({
        where: { quickPrintSessionId: input.quickPrintSessionId },
      });
      if (existing) return;
    }
    if (input.printJobId) {
      const existing = await db.phoneFreePageLedger.findUnique({
        where: { printJobId: input.printJobId },
      });
      if (existing) return;
    }

    await db.phoneFreePageLedger.create({
      data: {
        phone,
        printColorMode: toPrismaColorMode(input.mode),
        pages: input.pages,
        status: FreePageLedgerStatus.reserved,
        periodKey: input.periodKey,
        otpChallengeId: input.otpChallengeId,
        quickPrintSessionId: input.quickPrintSessionId,
        printJobId: input.printJobId,
      },
    });
  }

  async attachPrintJob(
    input: {
      printJobId: string;
      otpChallengeId?: string;
      quickPrintSessionId?: string;
    },
    tx?: TxClient,
  ): Promise<void> {
    const db = tx ?? this.db;
    if (input.otpChallengeId) {
      await db.phoneFreePageLedger.updateMany({
        where: { otpChallengeId: input.otpChallengeId, printJobId: null },
        data: { printJobId: input.printJobId },
      });
      return;
    }
    if (input.quickPrintSessionId) {
      await db.phoneFreePageLedger.updateMany({
        where: { quickPrintSessionId: input.quickPrintSessionId, printJobId: null },
        data: { printJobId: input.printJobId },
      });
    }
  }

  async consumeForPrintJob(printJobId: string, tx?: TxClient): Promise<void> {
    const db = tx ?? this.db;
    await db.phoneFreePageLedger.updateMany({
      where: { printJobId, status: FreePageLedgerStatus.reserved },
      data: { status: FreePageLedgerStatus.consumed },
    });
  }

  async releaseForPrintJob(printJobId: string, tx?: TxClient): Promise<void> {
    const db = tx ?? this.db;
    await db.phoneFreePageLedger.updateMany({
      where: { printJobId, status: FreePageLedgerStatus.reserved },
      data: { status: FreePageLedgerStatus.released },
    });
  }

  async releaseForChallenge(otpChallengeId: string, tx?: TxClient): Promise<void> {
    const db = tx ?? this.db;
    await db.phoneFreePageLedger.updateMany({
      where: { otpChallengeId, status: FreePageLedgerStatus.reserved },
      data: { status: FreePageLedgerStatus.released },
    });
  }

  async releaseForSession(quickPrintSessionId: string, tx?: TxClient): Promise<void> {
    const db = tx ?? this.db;
    await db.phoneFreePageLedger.updateMany({
      where: { quickPrintSessionId, status: FreePageLedgerStatus.reserved },
      data: { status: FreePageLedgerStatus.released },
    });
  }

  async getPublicQuotaSnapshot(input: {
    phone?: string | null;
    device: QuotaDeviceSlice;
    mode?: QuoteColorMode;
    now?: Date;
  }) {
    const mode = input.mode ?? 'bw';
    const now = input.now ?? new Date();
    const freeDisabledNow = this.isFreeDisabledNow(input.device, now);
    if (!input.phone) {
      const config = await this.settings.getPrintFreeQuotaConfig();
      return {
        phoneVerified: false,
        freeDisabledNow,
        period: config.period,
        remainingBw: null as number | null,
        remainingColor: null as number | null,
      };
    }
    const [bw, color] = await Promise.all([
      this.getRemaining(input.phone, 'bw', now),
      this.getRemaining(input.phone, 'color', now),
    ]);
    return {
      phoneVerified: true,
      freeDisabledNow,
      period: bw.period,
      remainingBw: freeDisabledNow ? 0 : bw.remaining,
      remainingColor: freeDisabledNow ? 0 : color.remaining,
      // hint for current mode UI
      remainingForMode: freeDisabledNow
        ? 0
        : mode === 'color'
          ? color.remaining
          : bw.remaining,
    };
  }

  requireNormalizedPhone(phone: string): string {
    try {
      return normalizePhone(phone);
    } catch {
      throw new AppError('invalid_phone', 'Enter a valid 10-digit Indian mobile number', 400);
    }
  }

  async listUsage(
    input: {
      q?: string;
      limit?: number;
      audience?: 'all' | 'society' | 'public';
      usage?: 'all' | 'has_remaining' | 'exhausted' | 'used_bw' | 'used_color';
      /** `current` = active quota window; `all` = every stored period. */
      scope?: 'current' | 'all';
      /** Exact ledger period key (e.g. 2026-11-20). Overrides scope. */
      periodKey?: string;
      now?: Date;
    } = {},
  ) {
    const now = input.now ?? new Date();
    const limit = Math.min(1000, Math.max(1, Math.floor(input.limit ?? 500)));
    const config = await this.settings.getPrintFreeQuotaConfig();
    const currentPeriodKey = periodKeyFor(now, config.period);
    const societyRows = await this.db.societyPhone.findMany({ select: { phone: true } });
    const societySet = new Set(societyRows.map((row) => row.phone));
    const societyConfig = societySet.size
      ? await this.settings.getSocietyFreeQuotaConfig()
      : config;
    const currentSocietyKey = societySet.size
      ? periodKeyFor(now, societyConfig.period)
      : currentPeriodKey;

    const requestedKey = input.periodKey?.trim() || null;
    const scope: 'current' | 'all' | 'period' = requestedKey
      ? 'period'
      : input.scope === 'all'
        ? 'all'
        : 'current';

    const availablePeriodKeys = await this.listAvailablePeriodKeys();

    const ledgerWhere =
      scope === 'all'
        ? {
            status: {
              in: [FreePageLedgerStatus.reserved, FreePageLedgerStatus.consumed],
            },
          }
        : scope === 'period'
          ? {
              periodKey: requestedKey!,
              status: {
                in: [FreePageLedgerStatus.reserved, FreePageLedgerStatus.consumed],
              },
            }
          : {
              periodKey:
                currentPeriodKey === currentSocietyKey
                  ? currentPeriodKey
                  : { in: [currentPeriodKey, currentSocietyKey] },
              status: {
                in: [FreePageLedgerStatus.reserved, FreePageLedgerStatus.consumed],
              },
            };

    const rows = await this.db.phoneFreePageLedger.findMany({
      where: ledgerWhere,
      select: {
        phone: true,
        printColorMode: true,
        pages: true,
        periodKey: true,
        updatedAt: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    type Agg = {
      phone: string;
      periodKey: string;
      bwUsed: number;
      colorUsed: number;
      lastActivityAt: Date | null;
      society: boolean;
    };

    const byKey = new Map<string, Agg>();

    for (const row of rows) {
      const society = societySet.has(row.phone);
      if (scope === 'current') {
        const expected = society ? currentSocietyKey : currentPeriodKey;
        if (row.periodKey !== expected) continue;
      }
      // Current/period views collapse to one row per phone; all-history keeps phone+period.
      const mapKey =
        scope === 'all' ? `${row.phone}::${row.periodKey}` : row.phone;
      let entry = byKey.get(mapKey);
      if (!entry) {
        entry = {
          phone: row.phone,
          periodKey: scope === 'all' ? row.periodKey : requestedKey ?? (society ? currentSocietyKey : currentPeriodKey),
          bwUsed: 0,
          colorUsed: 0,
          lastActivityAt: null,
          society,
        };
        byKey.set(mapKey, entry);
      }
      if (row.printColorMode === PrintColorMode.color) {
        entry.colorUsed += row.pages;
      } else {
        entry.bwUsed += row.pages;
      }
      if (!entry.lastActivityAt || row.updatedAt > entry.lastActivityAt) {
        entry.lastActivityAt = row.updatedAt;
      }
    }

    const searchDigits = (input.q ?? '').replace(/\D/g, '');
    const allItems = Array.from(byKey.values()).map((stats) => {
      const limits = stats.society ? societyConfig : config;
      const combined = Boolean(limits.combined || stats.society);
      const pool = combined ? combinedPoolLimit({ ...limits, combined: true }) : 0;
      const totalUsed = stats.bwUsed + stats.colorUsed;
      const sharedRemaining = combined ? Math.max(0, pool - totalUsed) : null;
      const bwRemaining = combined
        ? sharedRemaining!
        : Math.max(0, limits.freeBwPages - stats.bwUsed);
      const colorRemaining = combined
        ? sharedRemaining!
        : Math.max(0, limits.freeColorPages - stats.colorUsed);
      return {
        phone: stats.phone,
        periodKey: stats.periodKey,
        society: stats.society,
        combined,
        bwUsed: stats.bwUsed,
        bwRemaining,
        colorUsed: stats.colorUsed,
        colorRemaining,
        bwLimit: combined ? pool : limits.freeBwPages,
        colorLimit: combined ? pool : limits.freeColorPages,
        pagesLimit: combined ? pool : null,
        pagesRemaining: sharedRemaining,
        totalUsed,
        exhausted: isQuotaExhausted(
          stats.bwUsed,
          limits.freeBwPages,
          stats.colorUsed,
          limits.freeColorPages,
          combined,
          pool,
        ),
        lastActivityAt: stats.lastActivityAt?.toISOString() ?? null,
      };
    });

    const summary = {
      phones: new Set(allItems.map((item) => item.phone)).size,
      society: allItems.filter((item) => item.society).length,
      public: allItems.filter((item) => !item.society).length,
      exhausted: allItems.filter((item) => item.exhausted).length,
      bwPages: allItems.reduce((sum, item) => sum + item.bwUsed, 0),
      colorPages: allItems.reduce((sum, item) => sum + item.colorUsed, 0),
    };

    let items = allItems;
    if (searchDigits) {
      items = items.filter((item) => item.phone.replace(/\D/g, '').includes(searchDigits));
    }
    if (input.audience === 'society') {
      items = items.filter((item) => item.society);
    } else if (input.audience === 'public') {
      items = items.filter((item) => !item.society);
    }
    if (input.usage === 'has_remaining') {
      items = items.filter((item) => !item.exhausted);
    } else if (input.usage === 'exhausted') {
      items = items.filter((item) => item.exhausted);
    } else if (input.usage === 'used_bw') {
      items = items.filter((item) => item.bwUsed > 0);
    } else if (input.usage === 'used_color') {
      items = items.filter((item) => item.colorUsed > 0);
    }

    items.sort((a, b) => {
      const aTime = a.lastActivityAt ? Date.parse(a.lastActivityAt) : 0;
      const bTime = b.lastActivityAt ? Date.parse(b.lastActivityAt) : 0;
      if (bTime !== aTime) return bTime - aTime;
      return b.periodKey.localeCompare(a.periodKey);
    });

    const total = items.length;
    const sliced = items.slice(0, limit);
    const selectedPeriodKey =
      scope === 'period'
        ? requestedKey!
        : scope === 'all'
          ? 'all'
          : currentPeriodKey;

    return {
      scope,
      period: config.period,
      periodKey: selectedPeriodKey,
      currentPeriodKey,
      societyPeriod: societyConfig.period,
      societyPeriodKey: scope === 'period' ? requestedKey! : currentSocietyKey,
      availablePeriodKeys,
      limits: {
        freeBwPages: config.freeBwPages,
        freeColorPages: config.freeColorPages,
      },
      societyLimits: {
        freeBwPages: societyConfig.freeBwPages,
        freeColorPages: societyConfig.freeColorPages,
        freePages: combinedPoolLimit({ ...societyConfig, combined: true }),
        combined: true as const,
      },
      summary,
      total,
      truncated: total > sliced.length,
      items: sliced,
    };
  }

  private async listAvailablePeriodKeys(): Promise<string[]> {
    const grouped = await this.db.phoneFreePageLedger.groupBy({
      by: ['periodKey'],
      orderBy: { periodKey: 'desc' },
      take: 120,
    });
    return grouped.map((row) => row.periodKey);
  }

  async getPhoneUsageDetail(
    phoneRaw: string,
    input: { periodKey?: string | 'all'; now?: Date } = {},
  ) {
    const now = input.now ?? new Date();
    const phone = this.requireNormalizedPhone(phoneRaw);
    const [bw, color] = await Promise.all([
      this.getRemaining(phone, 'bw', now),
      this.getRemaining(phone, 'color', now),
    ]);

    const requestedKey = input.periodKey?.trim();
    const useAll = requestedKey === 'all';
    const periodKey = useAll
      ? 'all'
      : requestedKey && requestedKey.length > 0
        ? requestedKey
        : bw.periodKey;

    const entries = await this.db.phoneFreePageLedger.findMany({
      where: useAll ? { phone } : { phone, periodKey },
      orderBy: { updatedAt: 'desc' },
      take: useAll ? 500 : 200,
      select: {
        id: true,
        printColorMode: true,
        pages: true,
        status: true,
        periodKey: true,
        otpChallengeId: true,
        quickPrintSessionId: true,
        printJobId: true,
        printJob: { select: { title: true, source: true } },
        createdAt: true,
        updatedAt: true,
      },
    });

    const active = entries.filter(
      (entry) =>
        entry.status === FreePageLedgerStatus.reserved ||
        entry.status === FreePageLedgerStatus.consumed,
    );
    const bwUsed = active
      .filter((entry) => entry.printColorMode !== PrintColorMode.color)
      .reduce((sum, entry) => sum + entry.pages, 0);
    const colorUsed = active
      .filter((entry) => entry.printColorMode === PrintColorMode.color)
      .reduce((sum, entry) => sum + entry.pages, 0);

    const combined = bw.society;
    const pagesLimit = combined ? bw.periodLimit : null;
    const offCurrent =
      useAll || periodKey !== bw.periodKey || periodKey !== color.periodKey;
    // Split usage always comes from ledger rows for the selected period.
    const detailBwUsed = offCurrent ? bwUsed : (combined ? bwUsed : bw.used);
    const detailColorUsed = offCurrent
      ? colorUsed
      : combined
        ? colorUsed
        : color.used;
    // Combined remaining uses total pages; getRemaining.used is already the pool total.
    const pagesUsed = combined
      ? offCurrent
        ? detailBwUsed + detailColorUsed
        : bw.used
      : detailBwUsed + detailColorUsed;
    const sharedRemaining = combined
      ? Math.max(0, bw.periodLimit - pagesUsed)
      : null;

    return {
      phone,
      society: bw.society,
      combined,
      period: bw.period,
      periodKey,
      limits: {
        freeBwPages: bw.periodLimit,
        freeColorPages: color.periodLimit,
        ...(combined
          ? { freePages: bw.periodLimit, combined: true as const }
          : {}),
      },
      summary: {
        bwUsed: detailBwUsed,
        bwRemaining: combined
          ? sharedRemaining!
          : offCurrent
            ? Math.max(0, bw.periodLimit - bwUsed)
            : bw.remaining,
        colorUsed: detailColorUsed,
        colorRemaining: combined
          ? sharedRemaining!
          : offCurrent
            ? Math.max(0, color.periodLimit - colorUsed)
            : color.remaining,
        ...(combined
          ? {
              pagesUsed,
              pagesRemaining: sharedRemaining!,
              pagesLimit: pagesLimit!,
            }
          : {}),
      },
      entries: entries.map((entry) => ({
        id: entry.id,
        printColorMode: entry.printColorMode === PrintColorMode.color ? 'color' : 'bw',
        pages: entry.pages,
        status: entry.status,
        periodKey: entry.periodKey,
        title: entry.printJob?.title ?? null,
        source:
          entry.printJob?.source ??
          (entry.otpChallengeId
            ? 'otp_print'
            : entry.quickPrintSessionId
              ? 'quick_print'
              : 'unknown'),
        otpChallengeId: entry.otpChallengeId,
        quickPrintSessionId: entry.quickPrintSessionId,
        printJobId: entry.printJobId,
        createdAt: entry.createdAt.toISOString(),
        updatedAt: entry.updatedAt.toISOString(),
      })),
    };
  }
}

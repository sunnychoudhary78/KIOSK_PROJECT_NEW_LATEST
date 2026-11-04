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
  periodLimit: number;
  periodKey: string;
  period: PrintFreeQuotaConfig['period'];
  society: boolean;
};

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
    const periodLimit = mode === 'color' ? config.freeColorPages : config.freeBwPages;
    const normalized = normalizePhone(phone);
    const colorMode = toPrismaColorMode(mode);

    const rows = await db.phoneFreePageLedger.findMany({
      where: {
        phone: normalized,
        printColorMode: colorMode,
        periodKey,
        status: { in: [FreePageLedgerStatus.reserved, FreePageLedgerStatus.consumed] },
      },
      select: { pages: true },
    });
    const used = rows.reduce((sum, row) => sum + row.pages, 0);
    return {
      remaining: Math.max(0, periodLimit - used),
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
    const kioskCap =
      input.mode === 'color' ? limits.freeColorPagesPerSession : limits.freePagesPerSession;
    const freeDisabledNow = this.isFreeDisabledNow(input.device, now);

    if (!input.phone) {
      const config = await this.settings.getPrintFreeQuotaConfig();
      const periodLimit = input.mode === 'color' ? config.freeColorPages : config.freeBwPages;
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

  async listUsage(input: { q?: string; limit?: number; now?: Date } = {}) {
    const now = input.now ?? new Date();
    const limit = Math.min(200, Math.max(1, Math.floor(input.limit ?? 50)));
    const config = await this.settings.getPrintFreeQuotaConfig();
    const periodKey = periodKeyFor(now, config.period);
    const societyRows = await this.db.societyPhone.findMany({ select: { phone: true } });
    const societySet = new Set(societyRows.map((row) => row.phone));
    const societyConfig = societySet.size
      ? await this.settings.getSocietyFreeQuotaConfig()
      : config;
    const societyKey = societySet.size ? periodKeyFor(now, societyConfig.period) : periodKey;
    const periodKeys = [...new Set([periodKey, societyKey])];

    const rows = await this.db.phoneFreePageLedger.findMany({
      where: {
        periodKey: periodKeys.length === 1 ? (periodKeys[0] ?? periodKey) : { in: periodKeys },
        status: { in: [FreePageLedgerStatus.reserved, FreePageLedgerStatus.consumed] },
      },
      select: {
        phone: true,
        printColorMode: true,
        pages: true,
        periodKey: true,
        updatedAt: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    const byPhone = new Map<
      string,
      { bwUsed: number; colorUsed: number; lastActivityAt: Date | null; society: boolean }
    >();

    for (const row of rows) {
      const society = societySet.has(row.phone);
      if (row.periodKey !== (society ? societyKey : periodKey)) continue;
      let entry = byPhone.get(row.phone);
      if (!entry) {
        entry = { bwUsed: 0, colorUsed: 0, lastActivityAt: null, society };
        byPhone.set(row.phone, entry);
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
    let items = Array.from(byPhone.entries()).map(([phone, stats]) => {
      const limits = stats.society ? societyConfig : config;
      return {
        phone,
        society: stats.society,
        bwUsed: stats.bwUsed,
        bwRemaining: Math.max(0, limits.freeBwPages - stats.bwUsed),
        colorUsed: stats.colorUsed,
        colorRemaining: Math.max(0, limits.freeColorPages - stats.colorUsed),
        bwLimit: limits.freeBwPages,
        colorLimit: limits.freeColorPages,
        lastActivityAt: stats.lastActivityAt?.toISOString() ?? null,
      };
    });

    if (searchDigits) {
      items = items.filter((item) => item.phone.replace(/\D/g, '').includes(searchDigits));
    }

    items.sort((a, b) => {
      const aTime = a.lastActivityAt ? Date.parse(a.lastActivityAt) : 0;
      const bTime = b.lastActivityAt ? Date.parse(b.lastActivityAt) : 0;
      return bTime - aTime;
    });

    return {
      period: config.period,
      periodKey,
      limits: {
        freeBwPages: config.freeBwPages,
        freeColorPages: config.freeColorPages,
      },
      items: items.slice(0, limit),
    };
  }

  async getPhoneUsageDetail(phoneRaw: string, now: Date = new Date()) {
    const phone = this.requireNormalizedPhone(phoneRaw);
    const [bw, color] = await Promise.all([
      this.getRemaining(phone, 'bw', now),
      this.getRemaining(phone, 'color', now),
    ]);

    const entries = await this.db.phoneFreePageLedger.findMany({
      where: { phone, periodKey: bw.periodKey },
      orderBy: { updatedAt: 'desc' },
      take: 50,
      select: {
        id: true,
        printColorMode: true,
        pages: true,
        status: true,
        periodKey: true,
        otpChallengeId: true,
        quickPrintSessionId: true,
        printJobId: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    return {
      phone,
      society: bw.society,
      period: bw.period,
      periodKey: bw.periodKey,
      limits: {
        freeBwPages: bw.periodLimit,
        freeColorPages: color.periodLimit,
      },
      summary: {
        bwUsed: bw.periodLimit - bw.remaining,
        bwRemaining: bw.remaining,
        colorUsed: color.periodLimit - color.remaining,
        colorRemaining: color.remaining,
      },
      entries: entries.map((entry) => ({
        id: entry.id,
        printColorMode: entry.printColorMode === PrintColorMode.color ? 'color' : 'bw',
        pages: entry.pages,
        status: entry.status,
        periodKey: entry.periodKey,
        source: entry.otpChallengeId
          ? 'otp_print'
          : entry.quickPrintSessionId
            ? 'quick_print'
            : 'unknown',
        otpChallengeId: entry.otpChallengeId,
        quickPrintSessionId: entry.quickPrintSessionId,
        printJobId: entry.printJobId,
        createdAt: entry.createdAt.toISOString(),
        updatedAt: entry.updatedAt.toISOString(),
      })),
    };
  }
}

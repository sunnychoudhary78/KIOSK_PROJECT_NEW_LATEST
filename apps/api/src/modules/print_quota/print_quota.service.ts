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

  async getRemaining(
    phone: string,
    mode: QuoteColorMode,
    now: Date = new Date(),
    tx?: TxClient,
  ): Promise<{ remaining: number; periodLimit: number; periodKey: string }> {
    const db = tx ?? this.db;
    const config = await this.settings.getPrintFreeQuotaConfig();
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
    const config = await this.settings.getPrintFreeQuotaConfig();
    const periodKey = periodKeyFor(now, config.period);
    const periodLimit = input.mode === 'color' ? config.freeColorPages : config.freeBwPages;

    if (freeDisabledNow || !input.phone) {
      return {
        freePages: 0,
        remainingBefore: input.phone
          ? (await this.getRemaining(input.phone, input.mode, now, input.tx)).remaining
          : periodLimit,
        periodLimit,
        periodKey,
        freeDisabledNow,
        kioskCap,
        phone: input.phone ? normalizePhone(input.phone) : null,
      };
    }

    const { remaining, periodKey: key } = await this.getRemaining(
      input.phone,
      input.mode,
      now,
      input.tx,
    );
    const freePages = Math.min(remaining, kioskCap, Math.max(0, input.pageCount));
    return {
      freePages,
      remainingBefore: remaining,
      periodLimit,
      periodKey: key,
      freeDisabledNow: false,
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

    await db.phoneFreePageLedger.create({
      data: {
        phone,
        printColorMode: toPrismaColorMode(input.mode),
        pages: input.pages,
        status: FreePageLedgerStatus.reserved,
        periodKey: input.periodKey,
        otpChallengeId: input.otpChallengeId,
        quickPrintSessionId: input.quickPrintSessionId,
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
    const config = await this.settings.getPrintFreeQuotaConfig();
    return {
      phoneVerified: true,
      freeDisabledNow,
      period: config.period,
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
}

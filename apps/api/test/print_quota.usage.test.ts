import { describe, expect, it, vi } from 'vitest';
import { FreePageLedgerStatus, PrintColorMode } from '@prisma/client';
import { PrintQuotaService } from '../src/modules/print_quota/print_quota.service.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { AppError } from '../src/shared/errors.js';
import { periodKeyFor } from '../src/modules/print_quota/print_quota.time.js';

const NOW = new Date('2026-04-15T10:00:00.000Z');
const PERIOD_KEY = periodKeyFor(NOW, 'daily');

const PHONE_A = '+919876543210';
const PHONE_B = '+919123456789';

function setup(
  ledgerRows: Array<{
    phone: string;
    printColorMode: PrintColorMode;
    pages: number;
    updatedAt: Date;
    status?: FreePageLedgerStatus;
    id?: string;
    periodKey?: string;
    otpChallengeId?: string | null;
    quickPrintSessionId?: string | null;
    printJobId?: string | null;
    createdAt?: Date;
  }> = [],
  options: {
    societyPhones?: string[];
    societyConfig?: { period: 'daily' | 'weekly' | 'monthly'; freeBwPages: number; freeColorPages: number };
  } = {},
) {
  const globalConfig = {
    settingKey: 'print_free_quota_config',
    settingValue: {
      period: 'daily' as const,
      freeBwPages: 5,
      freeColorPages: 2,
    },
  };
  const societyConfig = {
    settingKey: 'society_free_quota_config',
    settingValue: options.societyConfig ?? {
      period: 'daily' as const,
      freeBwPages: 5,
      freeColorPages: 0,
    },
  };
  const societyPhones = new Set(options.societyPhones ?? []);

  const findMany = vi.fn(async (args: { where?: { phone?: string; periodKey?: string | { in: string[] }; status?: unknown } }) => {
    let rows = ledgerRows.map((row) => ({
      id: row.id ?? 'ledger-1',
      phone: row.phone,
      printColorMode: row.printColorMode,
      pages: row.pages,
      status: row.status ?? FreePageLedgerStatus.consumed,
      periodKey: row.periodKey ?? PERIOD_KEY,
      otpChallengeId: row.otpChallengeId ?? null,
      quickPrintSessionId: row.quickPrintSessionId ?? null,
      printJobId: row.printJobId ?? null,
      createdAt: row.createdAt ?? row.updatedAt,
      updatedAt: row.updatedAt,
    }));

    const periodKey = args.where?.periodKey;
    if (typeof periodKey === 'string') {
      rows = rows.filter((r) => r.periodKey === periodKey);
    } else if (periodKey && typeof periodKey === 'object' && 'in' in periodKey) {
      rows = rows.filter((r) => periodKey.in.includes(r.periodKey));
    }
    if (args.where?.phone) {
      rows = rows.filter((r) => r.phone === args.where!.phone);
    }
    if (args.where?.status && typeof args.where.status === 'object' && 'in' in args.where.status) {
      const allowed = (args.where.status as { in: FreePageLedgerStatus[] }).in;
      rows = rows.filter((r) => allowed.includes(r.status));
    }
    return rows;
  });

  const db = {
    platformSetting: {
      findUnique: vi.fn(async (args: { where?: { settingKey?: string } }) => {
        if (args.where?.settingKey === 'society_free_quota_config') return societyConfig;
        if (args.where?.settingKey === 'print_free_quota_config') return globalConfig;
        return null;
      }),
    },
    societyPhone: {
      findUnique: vi.fn(async (args: { where?: { phone?: string } }) => {
        const phone = args.where?.phone;
        return phone && societyPhones.has(phone) ? { id: 'society-1', phone } : null;
      }),
      findMany: vi.fn(async () => [...societyPhones].map((phone) => ({ phone }))),
    },
    phoneFreePageLedger: {
      findMany,
    },
  };

  const audit = { record: vi.fn(async () => undefined) };
  const service = new PrintQuotaService(db as unknown as DbClient, audit as unknown as AuditService);
  return { service, findMany };
}

describe('PrintQuotaService.listUsage', () => {
  it('returns empty list when no usage', async () => {
    const { service } = setup([]);
    const result = await service.listUsage({ now: NOW });
    expect(result.period).toBe('daily');
    expect(result.periodKey).toBe(PERIOD_KEY);
    expect(result.limits).toEqual({ freeBwPages: 5, freeColorPages: 2 });
    expect(result.items).toEqual([]);
  });

  it('aggregates used and remaining by phone', async () => {
    const { service } = setup([
      {
        phone: PHONE_A,
        printColorMode: PrintColorMode.bw,
        pages: 2,
        status: FreePageLedgerStatus.reserved,
        updatedAt: new Date('2026-04-15T09:00:00.000Z'),
      },
      {
        phone: PHONE_A,
        printColorMode: PrintColorMode.bw,
        pages: 1,
        status: FreePageLedgerStatus.consumed,
        updatedAt: new Date('2026-04-15T09:30:00.000Z'),
      },
      {
        phone: PHONE_B,
        printColorMode: PrintColorMode.color,
        pages: 1,
        status: FreePageLedgerStatus.consumed,
        updatedAt: new Date('2026-04-15T08:00:00.000Z'),
      },
      {
        phone: PHONE_A,
        printColorMode: PrintColorMode.bw,
        pages: 2,
        status: FreePageLedgerStatus.released,
        updatedAt: new Date('2026-04-15T09:45:00.000Z'),
      },
    ]);

    const result = await service.listUsage({ now: NOW });
    expect(result.items).toHaveLength(2);

    const a = result.items.find((i) => i.phone === PHONE_A)!;
    const b = result.items.find((i) => i.phone === PHONE_B)!;
    expect(a.bwUsed).toBe(3);
    expect(a.bwRemaining).toBe(2);
    expect(a.colorUsed).toBe(0);
    expect(a.colorRemaining).toBe(2);
    expect(a.lastActivityAt).toBe(new Date('2026-04-15T09:30:00.000Z').toISOString());

    expect(b.bwUsed).toBe(0);
    expect(b.bwRemaining).toBe(5);
    expect(b.colorUsed).toBe(1);
    expect(b.colorRemaining).toBe(1);

    // newest activity first
    expect(result.items[0]?.phone).toBe(PHONE_A);
  });

  it('filters by phone search digits', async () => {
    const { service } = setup([
      {
        phone: PHONE_A,
        printColorMode: PrintColorMode.bw,
        pages: 1,
        updatedAt: new Date('2026-04-15T09:00:00.000Z'),
      },
      {
        phone: PHONE_B,
        printColorMode: PrintColorMode.bw,
        pages: 1,
        updatedAt: new Date('2026-04-15T08:00:00.000Z'),
      },
    ]);

    const result = await service.listUsage({ q: '9876', now: NOW });
    expect(result.items).toHaveLength(1);
    expect(result.items[0]?.phone).toBe(PHONE_A);
  });

  it('counts a society phone against its own period limit', async () => {
    const monthlyKey = periodKeyFor(NOW, 'monthly');
    const { service } = setup(
      [
        {
          phone: PHONE_A,
          printColorMode: PrintColorMode.bw,
          pages: 2,
          periodKey: monthlyKey,
          updatedAt: new Date('2026-04-15T09:00:00.000Z'),
        },
        {
          phone: PHONE_A,
          printColorMode: PrintColorMode.bw,
          pages: 10,
          periodKey: PERIOD_KEY,
          updatedAt: new Date('2026-04-15T09:10:00.000Z'),
        },
        {
          phone: PHONE_B,
          printColorMode: PrintColorMode.bw,
          pages: 1,
          periodKey: PERIOD_KEY,
          updatedAt: new Date('2026-04-15T08:00:00.000Z'),
        },
      ],
      {
        societyPhones: [PHONE_A],
        societyConfig: { period: 'monthly', freeBwPages: 30, freeColorPages: 1 },
      },
    );

    const result = await service.listUsage({ now: NOW });
    expect(result.period).toBe('daily');
    expect(result.limits).toEqual({ freeBwPages: 5, freeColorPages: 2 });
    const society = result.items.find((item) => item.phone === PHONE_A);
    const publicPhone = result.items.find((item) => item.phone === PHONE_B);
    expect(society?.society).toBe(true);
    expect(society?.bwUsed).toBe(2);
    expect(society?.bwRemaining).toBe(28);
    expect(society?.bwLimit).toBe(30);
    expect(publicPhone?.society).toBe(false);
    expect(publicPhone?.bwRemaining).toBe(4);
  });
});

describe('PrintQuotaService.getPhoneUsageDetail', () => {
  it('returns ledger entries and summary for a phone', async () => {
    const { service } = setup([
      {
        id: 'e1',
        phone: PHONE_A,
        printColorMode: PrintColorMode.bw,
        pages: 2,
        status: FreePageLedgerStatus.consumed,
        otpChallengeId: 'chal-1',
        updatedAt: new Date('2026-04-15T09:00:00.000Z'),
      },
    ]);

    const detail = await service.getPhoneUsageDetail(PHONE_A, NOW);
    expect(detail.phone).toBe(PHONE_A);
    expect(detail.periodKey).toBe(PERIOD_KEY);
    expect(detail.summary.bwUsed).toBe(2);
    expect(detail.summary.bwRemaining).toBe(3);
    expect(detail.entries).toHaveLength(1);
    expect(detail.entries[0]?.source).toBe('otp_print');
    expect(detail.society).toBe(false);
  });

  it('uses the society limit and period for a listed phone', async () => {
    const monthlyKey = periodKeyFor(NOW, 'monthly');
    const { service } = setup(
      [
        {
          id: 'e-society',
          phone: PHONE_A,
          printColorMode: PrintColorMode.bw,
          pages: 4,
          periodKey: monthlyKey,
          status: FreePageLedgerStatus.consumed,
          updatedAt: new Date('2026-04-15T09:00:00.000Z'),
        },
        {
          id: 'e-other-period',
          phone: PHONE_A,
          printColorMode: PrintColorMode.bw,
          pages: 9,
          periodKey: PERIOD_KEY,
          status: FreePageLedgerStatus.consumed,
          updatedAt: new Date('2026-04-15T08:00:00.000Z'),
        },
      ],
      {
        societyPhones: [PHONE_A],
        societyConfig: { period: 'monthly', freeBwPages: 30, freeColorPages: 4 },
      },
    );

    const detail = await service.getPhoneUsageDetail(PHONE_A, NOW);
    expect(detail.society).toBe(true);
    expect(detail.period).toBe('monthly');
    expect(detail.periodKey).toBe(monthlyKey);
    expect(detail.limits).toEqual({ freeBwPages: 30, freeColorPages: 4 });
    expect(detail.summary.bwUsed).toBe(4);
    expect(detail.summary.bwRemaining).toBe(26);
    expect(detail.entries).toHaveLength(1);
    expect(detail.entries[0]?.periodKey).toBe(monthlyKey);
  });

  it('rejects invalid phone', async () => {
    const { service } = setup([]);
    await expect(service.getPhoneUsageDetail('not-a-phone', NOW)).rejects.toBeInstanceOf(AppError);
  });
});

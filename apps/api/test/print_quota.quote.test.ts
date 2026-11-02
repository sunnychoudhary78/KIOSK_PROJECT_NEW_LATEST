import { describe, expect, it, vi } from 'vitest';
import { PrintQuotaService } from '../src/modules/print_quota/print_quota.service.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { periodKeyFor } from '../src/modules/print_quota/print_quota.time.js';
import { quoteWithEffectiveFree } from '../src/modules/print_quota/print_quota.quote.js';

describe('quoteWithEffectiveFree', () => {
  const rates = { extraPageChargeRupees: 10, extraColorPageChargeRupees: 20 };

  it('applies effective free cap for bw', () => {
    const quote = quoteWithEffectiveFree(8, rates, 'bw', 3);
    expect(quote.freePages).toBe(3);
    expect(quote.extraPages).toBe(5);
    expect(quote.amountPaise).toBe(5000);
    expect(quote.paymentRequired).toBe(true);
  });

  it('applies effective free cap for color', () => {
    const quote = quoteWithEffectiveFree(4, rates, 'color', 1);
    expect(quote.freePages).toBe(1);
    expect(quote.extraPages).toBe(3);
    expect(quote.chargePerPageRupees).toBe(20);
    expect(quote.amountPaise).toBe(6000);
  });

  it('zero free means fully paid', () => {
    const quote = quoteWithEffectiveFree(2, rates, 'bw', 0);
    expect(quote.freePages).toBe(0);
    expect(quote.extraPages).toBe(2);
    expect(quote.paymentRequired).toBe(true);
  });

  it('free covering all pages needs no payment', () => {
    const quote = quoteWithEffectiveFree(3, rates, 'bw', 5);
    expect(quote.freePages).toBe(5);
    expect(quote.extraPages).toBe(0);
    expect(quote.paymentRequired).toBe(false);
  });
});

const NOW = new Date('2026-04-15T10:00:00.000Z');
const LISTED = '+919876543210';
const UNLISTED = '+919123456789';

function quotaService(societyPhones: string[]) {
  const listed = new Set(societyPhones);
  const db = {
    platformSetting: {
      findUnique: vi.fn(async (args: { where?: { settingKey?: string } }) => {
        if (args.where?.settingKey === 'society_free_quota_config') {
          return {
            settingValue: { period: 'monthly', freeBwPages: 100, freeColorPages: 10 },
          };
        }
        if (args.where?.settingKey === 'print_free_quota_config') {
          return {
            settingValue: { period: 'daily', freeBwPages: 5, freeColorPages: 0 },
          };
        }
        return null;
      }),
    },
    societyPhone: {
      findUnique: vi.fn(async (args: { where?: { phone?: string } }) => {
        const phone = args.where?.phone;
        return phone && listed.has(phone) ? { id: 'society-1' } : null;
      }),
    },
    phoneFreePageLedger: {
      findMany: vi.fn(async () => []),
    },
  };
  return new PrintQuotaService(db as unknown as DbClient, { record: vi.fn() } as unknown as AuditService);
}

const kiosk = {
  maxPagesPerSession: 50,
  freePagesPerSession: 5,
  extraPageChargeRupees: 10,
  freeColorPagesPerSession: 0,
  extraColorPageChargeRupees: 20,
  freeDisabledFromLocal: null,
  freeDisabledToLocal: null,
};

describe('PrintQuotaService society quota', () => {
  it('uses the society limit for a listed phone and the global limit otherwise', async () => {
    const service = quotaService([LISTED]);
    const listed = await service.computeEffectiveFree({
      phone: LISTED,
      device: kiosk,
      mode: 'bw',
      pageCount: 8,
      now: NOW,
    });
    const unlisted = await service.computeEffectiveFree({
      phone: UNLISTED,
      device: kiosk,
      mode: 'bw',
      pageCount: 8,
      now: NOW,
    });

    expect(listed.periodLimit).toBe(100);
    expect(listed.periodKey).toBe(periodKeyFor(NOW, 'monthly'));
    expect(listed.freePages).toBe(5);
    expect(unlisted.periodLimit).toBe(5);
    expect(unlisted.periodKey).toBe(periodKeyFor(NOW, 'daily'));
    expect(unlisted.freePages).toBe(5);
  });

  it('keeps the kiosk session cap when the society allowance is larger', async () => {
    const service = quotaService([LISTED]);
    const result = await service.computeEffectiveFree({
      phone: LISTED,
      device: kiosk,
      mode: 'bw',
      pageCount: 20,
      now: NOW,
    });
    expect(result.periodLimit).toBe(100);
    expect(result.kioskCap).toBe(5);
    expect(result.freePages).toBe(5);
    expect(result.freeDisabledNow).toBe(false);
  });

  it('grants no free pages during the kiosk night window', async () => {
    const service = quotaService([LISTED]);
    const result = await service.computeEffectiveFree({
      phone: LISTED,
      device: {
        ...kiosk,
        freeDisabledFromLocal: '00:00',
        freeDisabledToLocal: '23:59',
      },
      mode: 'bw',
      pageCount: 4,
      now: NOW,
    });
    expect(result.freeDisabledNow).toBe(true);
    expect(result.freePages).toBe(0);
    expect(result.periodLimit).toBe(100);
  });
});

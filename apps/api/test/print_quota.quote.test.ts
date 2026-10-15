import { describe, expect, it } from 'vitest';
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

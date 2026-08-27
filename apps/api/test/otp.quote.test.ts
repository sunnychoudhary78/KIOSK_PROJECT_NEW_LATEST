import { describe, expect, it } from 'vitest';
import { quoteOtpPrintPages } from '../src/modules/otp_print/otp_print.quote.js';

describe('quoteOtpPrintPages', () => {
  const config = { freePagesPerSession: 5, extraPageChargeRupees: 10 };

  it('is free when pages are within the allowance', () => {
    const quote = quoteOtpPrintPages(5, config);
    expect(quote.extraPages).toBe(0);
    expect(quote.amountPaise).toBe(0);
    expect(quote.paymentRequired).toBe(false);
  });

  it('charges only extra pages', () => {
    const quote = quoteOtpPrintPages(8, config);
    expect(quote.freePages).toBe(5);
    expect(quote.extraPages).toBe(3);
    expect(quote.amountPaise).toBe(3000);
    expect(quote.paymentRequired).toBe(true);
  });

  it('treats zero per-page charge as free even with extra pages', () => {
    const quote = quoteOtpPrintPages(8, { freePagesPerSession: 5, extraPageChargeRupees: 0 });
    expect(quote.extraPages).toBe(3);
    expect(quote.paymentRequired).toBe(false);
    expect(quote.amountPaise).toBe(0);
  });

  it('treats zero free pages as fully paid', () => {
    const quote = quoteOtpPrintPages(2, { freePagesPerSession: 0, extraPageChargeRupees: 5 });
    expect(quote.extraPages).toBe(2);
    expect(quote.amountPaise).toBe(1000);
    expect(quote.paymentRequired).toBe(true);
  });
});

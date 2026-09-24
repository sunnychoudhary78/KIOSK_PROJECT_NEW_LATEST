import { describe, expect, it } from 'vitest';
import { quoteOtpPrintPages } from '../src/modules/otp_print/otp_print.quote.js';

describe('quoteOtpPrintPages', () => {
  const config = {
    freePagesPerSession: 5,
    extraPageChargeRupees: 10,
    freeColorPagesPerSession: 0,
    extraColorPageChargeRupees: 20,
  };

  it('is free when B/W pages are within the allowance', () => {
    const quote = quoteOtpPrintPages(5, config);
    expect(quote.printColorMode).toBe('bw');
    expect(quote.extraPages).toBe(0);
    expect(quote.amountPaise).toBe(0);
    expect(quote.paymentRequired).toBe(false);
  });

  it('charges only extra B/W pages', () => {
    const quote = quoteOtpPrintPages(8, config);
    expect(quote.printColorMode).toBe('bw');
    expect(quote.freePages).toBe(5);
    expect(quote.extraPages).toBe(3);
    expect(quote.chargePerPageRupees).toBe(10);
    expect(quote.amountPaise).toBe(3000);
    expect(quote.paymentRequired).toBe(true);
  });

  it('uses color free pages and color extra-page rate', () => {
    const quote = quoteOtpPrintPages(3, config, 'color');
    expect(quote.printColorMode).toBe('color');
    expect(quote.freePages).toBe(0);
    expect(quote.extraPages).toBe(3);
    expect(quote.chargePerPageRupees).toBe(20);
    expect(quote.amountPaise).toBe(6000);
    expect(quote.paymentRequired).toBe(true);
  });

  it('treats color pages within the color allowance as free', () => {
    const quote = quoteOtpPrintPages(2, { ...config, freeColorPagesPerSession: 2 }, 'color');
    expect(quote.extraPages).toBe(0);
    expect(quote.paymentRequired).toBe(false);
    expect(quote.amountPaise).toBe(0);
  });

  it('treats zero per-page charge as free even with extra pages', () => {
    const quote = quoteOtpPrintPages(8, { ...config, extraPageChargeRupees: 0 });
    expect(quote.extraPages).toBe(3);
    expect(quote.paymentRequired).toBe(false);
    expect(quote.amountPaise).toBe(0);
  });

  it('treats zero free pages as fully paid', () => {
    const quote = quoteOtpPrintPages(2, { ...config, freePagesPerSession: 0, extraPageChargeRupees: 5 });
    expect(quote.extraPages).toBe(2);
    expect(quote.amountPaise).toBe(1000);
    expect(quote.paymentRequired).toBe(true);
  });
});

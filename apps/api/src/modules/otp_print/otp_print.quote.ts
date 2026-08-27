import type { OtpPrintConfig } from '../platform_settings/platform_settings.defaults.js';

export type PrintQuote = {
  pageCount: number;
  freePages: number;
  extraPages: number;
  chargePerPageRupees: number;
  amountPaise: number;
  currency: 'INR';
  paymentRequired: boolean;
};

export function quoteOtpPrintPages(
  pageCount: number,
  config: Pick<OtpPrintConfig, 'freePagesPerSession' | 'extraPageChargeRupees'>,
): PrintQuote {
  const freePages = Math.max(0, config.freePagesPerSession);
  const extraPages = Math.max(0, pageCount - freePages);
  const chargePerPageRupees = Math.max(0, config.extraPageChargeRupees);
  const amountPaise = extraPages * chargePerPageRupees * 100;
  return {
    pageCount,
    freePages,
    extraPages,
    chargePerPageRupees,
    amountPaise,
    currency: 'INR',
    paymentRequired: extraPages > 0 && chargePerPageRupees > 0 && amountPaise > 0,
  };
}

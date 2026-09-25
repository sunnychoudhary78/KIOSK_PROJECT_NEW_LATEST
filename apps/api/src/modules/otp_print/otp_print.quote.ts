import type { DevicePrintLimits } from '../devices/device_print_limits.js';

export type PrintColorMode = 'bw' | 'color';

export type PrintQuote = {
  printColorMode: PrintColorMode;
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
  config: Pick<
    DevicePrintLimits,
    | 'freePagesPerSession'
    | 'extraPageChargeRupees'
    | 'freeColorPagesPerSession'
    | 'extraColorPageChargeRupees'
  >,
  printColorMode: PrintColorMode = 'bw',
): PrintQuote {
  const color = printColorMode === 'color';
  const freePages = Math.max(
    0,
    color ? config.freeColorPagesPerSession : config.freePagesPerSession,
  );
  const extraPages = Math.max(0, pageCount - freePages);
  const chargePerPageRupees = Math.max(
    0,
    color ? config.extraColorPageChargeRupees : config.extraPageChargeRupees,
  );
  const amountPaise = extraPages * chargePerPageRupees * 100;
  return {
    printColorMode: color ? 'color' : 'bw',
    pageCount,
    freePages,
    extraPages,
    chargePerPageRupees,
    amountPaise,
    currency: 'INR',
    paymentRequired: extraPages > 0 && chargePerPageRupees > 0 && amountPaise > 0,
  };
}

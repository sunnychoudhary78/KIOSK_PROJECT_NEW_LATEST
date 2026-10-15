import type { DevicePrintLimits } from '../devices/device_print_limits.js';
import type { PrintColorMode, PrintQuote } from '../otp_print/otp_print.quote.js';
import { quoteOtpPrintPages } from '../otp_print/otp_print.quote.js';

/** Quote using an already-computed effective free-page cap (global + night + kiosk). */
export function quoteWithEffectiveFree(
  pageCount: number,
  config: Pick<
    DevicePrintLimits,
    'extraPageChargeRupees' | 'extraColorPageChargeRupees'
  >,
  printColorMode: PrintColorMode,
  effectiveFreePages: number,
): PrintQuote {
  const color = printColorMode === 'color';
  const freeCap = Math.max(0, Math.floor(effectiveFreePages));
  return quoteOtpPrintPages(
    pageCount,
    {
      freePagesPerSession: color ? 0 : freeCap,
      freeColorPagesPerSession: color ? freeCap : 0,
      extraPageChargeRupees: config.extraPageChargeRupees,
      extraColorPageChargeRupees: config.extraColorPageChargeRupees,
    },
    printColorMode,
  );
}

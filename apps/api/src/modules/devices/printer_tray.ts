export type TrayLoadMode = 'add' | 'replace';

export function usbPagesTotal(health: unknown): number | null {
  if (health == null || typeof health !== 'object') return null;
  const maintenance = (health as { maintenance?: unknown }).maintenance;
  if (maintenance == null || typeof maintenance !== 'object') return null;
  const pages = (maintenance as { pages?: unknown }).pages;
  if (pages == null || typeof pages !== 'object') return null;
  const total = (pages as { total?: unknown }).total;
  if (typeof total !== 'number' || !Number.isInteger(total) || total < 0) return null;
  return total;
}

/** Pages still credited. Null until a load is stored and a USB total is present. */
export function pagesLeft(
  trayPages: number | null | undefined,
  trayBaselinePages: number | null | undefined,
  usbTotal: number | null,
): number | null {
  if (trayPages == null || trayBaselinePages == null || usbTotal == null) return null;
  const used = Math.max(0, usbTotal - trayBaselinePages);
  return Math.max(0, trayPages - used);
}

export function applyTrayLoad(input: {
  mode: TrayLoadMode;
  pages: number;
  trayPages: number | null;
  trayBaselinePages: number | null;
  usbTotal: number;
}): { trayPages: number; trayBaselinePages: number } {
  if (input.mode === 'replace') {
    return { trayPages: input.pages, trayBaselinePages: input.usbTotal };
  }
  const previous =
    pagesLeft(input.trayPages, input.trayBaselinePages, input.usbTotal) ?? 0;
  return { trayPages: previous + input.pages, trayBaselinePages: input.usbTotal };
}

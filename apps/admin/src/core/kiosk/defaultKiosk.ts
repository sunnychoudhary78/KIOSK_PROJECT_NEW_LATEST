/** Preferred lab/production kiosk shown by default in admin filters. */
export const DEFAULT_KIOSK_NAME_HINT = 'Park Avenue';

function haystack(name: string, siteName?: string | null): string {
  return `${name} ${siteName ?? ''}`.toLowerCase();
}

function scoreKioskName(name: string, siteName?: string | null): number {
  const hay = haystack(name, siteName);
  let score = 0;
  if (hay.includes('park avenue')) score += 4;
  if (hay.includes('gaur city') || hay.includes('guar city')) score += 3;
  if (hay.includes('city 1') || /(?:^|\s)1(?:\s|$)/.test(hay)) score += 1;
  return score;
}

/**
 * Pick the preferred kiosk device id (Park Avenue · Gaur/Guar City 1 when present).
 * Keeps `current` if it still exists in the list.
 */
export function pickDefaultDeviceId<T extends { id: string; name: string; siteName?: string | null }>(
  devices: T[],
  current?: string | null,
): string {
  if (current && devices.some((device) => device.id === current)) {
    return current;
  }
  if (devices.length === 0) return '';

  let best = devices[0]!;
  let bestScore = scoreKioskName(best.name, best.siteName);
  for (const device of devices.slice(1)) {
    const score = scoreKioskName(device.name, device.siteName);
    if (score > bestScore) {
      best = device;
      bestScore = score;
    }
  }
  return best.id;
}

/**
 * Pick a preferred kiosk display name for name-based filters (e.g. Support).
 * Falls back to `all` only when the list is empty.
 */
export function pickDefaultKioskName(names: string[], current?: string | null): string {
  if (current && current !== 'all' && names.includes(current)) {
    return current;
  }
  if (names.length === 0) return 'all';

  let best = names[0]!;
  let bestScore = scoreKioskName(best);
  for (const name of names.slice(1)) {
    const score = scoreKioskName(name);
    if (score > bestScore) {
      best = name;
      bestScore = score;
    }
  }
  return bestScore > 0 ? best : names[0]!;
}

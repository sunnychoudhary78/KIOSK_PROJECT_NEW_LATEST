export type ServiceAnalyticsItem = {
  eventKey: string;
  count: number;
};

export type UsageRow = {
  key: string;
  label: string;
  count: number;
  depth: 0 | 1;
};

const HOME_ORDER = [
  'home.print',
  'home.local_services',
  'home.well_being',
  'home.charging',
  'home.astrology',
  'home.fuel_stations',
  'home.emergency',
  'home.support',
] as const;

const CHILD_PREFIX: Record<(typeof HOME_ORDER)[number], string | null> = {
  'home.print': 'print.',
  'home.local_services': 'local_services.',
  'home.well_being': 'well_being.',
  'home.charging': null,
  'home.astrology': 'astrology.',
  'home.fuel_stations': 'fuel_stations.',
  'home.emergency': null,
  'home.support': 'support.',
};

/** Inner options that stay visible even when nobody has tapped them yet. */
const KNOWN_CHILDREN: Partial<Record<(typeof HOME_ORDER)[number], readonly string[]>> = {
  'home.print': ['print.quick_print', 'print.otp_print', 'print.digilocker_print'],
  'home.well_being': ['well_being.path.oxygen', 'well_being.path.temperature'],
  'home.astrology': [
    'astrology.kundali',
    'astrology.palm',
    'astrology.match',
    'astrology.today',
  ],
};

const LABELS: Record<string, string> = {
  'home.print': 'Print',
  'home.local_services': 'Find services',
  'home.well_being': 'Well Being',
  'home.charging': 'Phone Charging',
  'home.astrology': 'Astrology',
  'home.fuel_stations': 'Fuel stations',
  'home.emergency': 'Emergency',
  'home.support': 'Support',
  'support.submit': 'Message sent',
  'support.category.print': 'Category · Print',
  'support.category.charging': 'Category · Charging',
  'support.category.sensors': 'Category · Sensors',
  'support.category.payment': 'Category · Payment',
  'support.category.other': 'Category · Other',
  'print.quick_print': 'Quick Print',
  'print.otp_print': 'OTP Print',
  'print.digilocker_print': 'DigiLocker Print',
  'astrology.kundali': 'My Kundali',
  'astrology.palm': 'Palm Insights',
  'astrology.match': 'Match Kundalis',
  'astrology.today': 'Today & Periods',
  'well_being.path.oxygen': 'Oxygen / SpO₂',
  'well_being.path.temperature': 'Temperature',
  'fuel_stations.filter.all': 'Filter · All',
  'fuel_stations.filter.fuel': 'Filter · Petrol/Diesel',
  'fuel_stations.filter.cng': 'Filter · CNG',
  'fuel_stations.filter.ev': 'Filter · EV',
  'fuel_stations.directions': 'Directions opened',
};

function humanizeSlug(slug: string): string {
  return slug
    .split(/[._-]/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

export function labelForEventKey(eventKey: string): string {
  if (LABELS[eventKey]) {
    return LABELS[eventKey];
  }
  if (eventKey.startsWith('local_services.')) {
    return humanizeSlug(eventKey.slice('local_services.'.length));
  }
  return humanizeSlug(eventKey);
}

export function buildUsageRows(items: ServiceAnalyticsItem[]): UsageRow[] {
  const counts = new Map(items.map((item) => [item.eventKey, item.count]));
  const claimed = new Set<string>();
  const rows: UsageRow[] = [];

  for (const homeKey of HOME_ORDER) {
    const prefix = CHILD_PREFIX[homeKey];
    const known = KNOWN_CHILDREN[homeKey] ?? [];
    const knownSet = new Set<string>(known);
    const tapped = prefix
      ? items
          .map((item) => item.eventKey)
          .filter((key) => key.startsWith(prefix) && !knownSet.has(key))
          .sort((a, b) => (counts.get(b) ?? 0) - (counts.get(a) ?? 0) || a.localeCompare(b))
      : [];
    const childKeys = [...known, ...tapped];

    claimed.add(homeKey);
    rows.push({
      key: homeKey,
      label: labelForEventKey(homeKey),
      count: counts.get(homeKey) ?? 0,
      depth: 0,
    });

    for (const childKey of childKeys) {
      claimed.add(childKey);
      rows.push({
        key: childKey,
        label: labelForEventKey(childKey),
        count: counts.get(childKey) ?? 0,
        depth: 1,
      });
    }
  }

  const leftovers = items
    .map((item) => item.eventKey)
    .filter((key) => !claimed.has(key))
    .sort((a, b) => (counts.get(b) ?? 0) - (counts.get(a) ?? 0) || a.localeCompare(b));

  for (const key of leftovers) {
    rows.push({
      key,
      label: labelForEventKey(key),
      count: counts.get(key) ?? 0,
      depth: 0,
    });
  }

  return rows;
}

export type UsageRangePreset = 'today' | '7' | '30' | 'custom';

export const USAGE_RANGE_FILTERS: Array<{ value: UsageRangePreset; label: string }> = [
  { value: 'today', label: 'Today' },
  { value: '7', label: '7 days' },
  { value: '30', label: '30 days' },
  { value: 'custom', label: 'Custom' },
];

export const USAGE_SERVICE_FILTERS = [
  { value: 'all', label: 'All services' },
  ...HOME_ORDER.map((key) => ({ value: key, label: LABELS[key] ?? labelForEventKey(key) })),
];

function pad2(n: number) {
  return String(n).padStart(2, '0');
}

/** Local `YYYY-MM-DDTHH:mm` for `<input type="datetime-local">`. */
export function toDatetimeLocalValue(date: Date): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}T${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

export function fromDatetimeLocalValue(value: string): Date | null {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

export function rangeIso(days: 7 | 30): { from: string; to: string } {
  const to = new Date();
  const from = new Date(to.getTime() - days * 24 * 60 * 60 * 1000);
  return { from: from.toISOString(), to: to.toISOString() };
}

export function rangeForPreset(preset: Exclude<UsageRangePreset, 'custom'>): {
  fromIso: string;
  toIso: string;
  fromLocal: string;
  toLocal: string;
} {
  const to = new Date();
  const from = new Date(to);
  if (preset === 'today') {
    from.setHours(0, 0, 0, 0);
  } else {
    const days = preset === '7' ? 7 : 30;
    from.setTime(to.getTime() - days * 24 * 60 * 60 * 1000);
  }
  return {
    fromIso: from.toISOString(),
    toIso: to.toISOString(),
    fromLocal: toDatetimeLocalValue(from),
    toLocal: toDatetimeLocalValue(to),
  };
}

export function filterUsageRows(
  rows: UsageRow[],
  opts: { service: string; search: string; hideZero: boolean },
): UsageRow[] {
  let next = rows;

  if (opts.service !== 'all') {
    const parentIdx = next.findIndex((row) => row.key === opts.service);
    if (parentIdx < 0) {
      next = [];
    } else {
      const kept: UsageRow[] = [next[parentIdx]!];
      for (let i = parentIdx + 1; i < next.length; i += 1) {
        if (next[i]!.depth === 0) break;
        kept.push(next[i]!);
      }
      next = kept;
    }
  }

  if (opts.hideZero) {
    next = next.filter((row) => row.count > 0);
  }

  const q = opts.search.trim().toLowerCase();
  if (q) {
    next = next.filter(
      (row) => row.label.toLowerCase().includes(q) || row.key.toLowerCase().includes(q),
    );
  }

  return next;
}

export function usageSummary(rows: UsageRow[]) {
  const parents = rows.filter((row) => row.depth === 0);
  const totalClicks = rows.reduce((sum, row) => sum + row.count, 0);
  const active = rows.filter((row) => row.count > 0).length;
  const top = parents.reduce<UsageRow | null>(
    (best, row) => (!best || row.count > best.count ? row : best),
    null,
  );
  return { totalClicks, active, top };
}

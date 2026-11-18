export type ServiceRatingItem = {
  serviceKey: string;
  count: number;
  avgStars: number;
};

export type ServiceRatingRow = {
  serviceKey: string;
  label: string;
  count: number;
  avgStars: number;
};

const RATING_LABELS: Record<string, string> = {
  'print.otp_print': 'OTP Print',
  'print.quick_print': 'Quick Print',
  'print.digilocker_print': 'DigiLocker Print',
  'well_being.print': 'Well Being print',
  'well_being.session': 'Well Being session',
  'astrology.print': 'Astrology print',
  'astrology.session': 'Astrology session',
  'home.charging': 'Phone Charging',
};

const RATING_ORDER = [
  'print.otp_print',
  'print.quick_print',
  'print.digilocker_print',
  'well_being.print',
  'well_being.session',
  'astrology.print',
  'astrology.session',
  'home.charging',
] as const;

export function labelForRatingKey(serviceKey: string): string {
  return RATING_LABELS[serviceKey] ?? serviceKey;
}

export function buildRatingRows(items: ServiceRatingItem[]): ServiceRatingRow[] {
  const byKey = new Map(items.map((item) => [item.serviceKey, item]));
  const known = RATING_ORDER.map((serviceKey) => {
    const item = byKey.get(serviceKey);
    return {
      serviceKey,
      label: labelForRatingKey(serviceKey),
      count: item?.count ?? 0,
      avgStars: item?.avgStars ?? 0,
    };
  });
  const extras = items
    .filter((item) => !(RATING_ORDER as readonly string[]).includes(item.serviceKey))
    .map((item) => ({
      serviceKey: item.serviceKey,
      label: labelForRatingKey(item.serviceKey),
      count: item.count,
      avgStars: item.avgStars,
    }))
    .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label));
  return [...known, ...extras].filter((row) => row.count > 0);
}

export function formatAvgStars(avg: number): string {
  return avg.toFixed(1);
}

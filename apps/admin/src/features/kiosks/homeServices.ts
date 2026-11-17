export type PlatformServiceItem = {
  code: string;
  name: string;
  description?: string;
  enabled: boolean;
};

export type HomeServiceToggleId =
  | 'print_documents'
  | 'local_services'
  | 'well_being'
  | 'phone_charging'
  | 'astrology'
  | 'fuel_stations';

export type HomeServiceToggle = {
  id: HomeServiceToggleId;
  label: string;
  description: string;
  codes: string[];
};

/** Six home-screen services; Print syncs the three print channel codes together. */
export const HOME_SERVICE_TOGGLES: HomeServiceToggle[] = [
  {
    id: 'print_documents',
    label: 'Print Documents',
    description: 'Phone, OTP, and DigiLocker print',
    codes: ['otp_print', 'quick_print', 'digilocker_print'],
  },
  {
    id: 'local_services',
    label: 'Find Services',
    description: 'Local trades and contacts',
    codes: ['local_services'],
  },
  {
    id: 'well_being',
    label: 'Well Being',
    description: 'Heart rate, blood oxygen, and temperature',
    codes: ['well_being'],
  },
  {
    id: 'phone_charging',
    label: 'Phone Charging',
    description: 'Watch a short message, then charge',
    codes: ['phone_charging'],
  },
  {
    id: 'astrology',
    label: 'Astrology',
    description: 'Kundali, palm, match, and today',
    codes: ['astrology'],
  },
  {
    id: 'fuel_stations',
    label: 'Fuel Stations',
    description: 'Nearby petrol, diesel, CNG, and EV',
    codes: ['fuel_stations'],
  },
];

export function isHomeServiceEnabled(
  toggle: HomeServiceToggle,
  byCode: Map<string, boolean>,
): boolean {
  return toggle.codes.every((code) => byCode.get(code) === true);
}

export function enablementMapFromItems(
  items: PlatformServiceItem[],
): Map<string, boolean> {
  return new Map(items.map((item) => [item.code, item.enabled]));
}

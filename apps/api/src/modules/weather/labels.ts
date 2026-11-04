/**
 * Map Google Weather API condition types to synthetic WMO-like codes so the
 * kiosk can keep using its existing icon ranges.
 */
export function weatherCodeFromGoogleType(type: string | null | undefined): number | null {
  if (type == null || typeof type !== 'string') {
    return null;
  }
  const t = type.trim().toUpperCase();
  if (!t || t === 'TYPE_UNSPECIFIED') {
    return null;
  }
  if (t === 'CLEAR') {
    return 0;
  }
  if (t === 'MOSTLY_CLEAR' || t === 'PARTLY_CLOUDY') {
    return 2;
  }
  if (t === 'MOSTLY_CLOUDY' || t === 'CLOUDY' || t === 'OVERCAST' || t === 'WINDY') {
    return 3;
  }
  if (t.includes('FOG') || t.includes('HAZE') || t.includes('MIST')) {
    return 45;
  }
  if (t.includes('THUNDER')) {
    return 95;
  }
  if (
    t.includes('SNOW') ||
    t.includes('BLIZZARD') ||
    t.includes('ICE') ||
    t === 'HAIL' ||
    t === 'HAIL_SHOWERS'
  ) {
    return t.includes('SHOWER') ? 85 : 71;
  }
  if (t.includes('DRIZZLE')) {
    return 51;
  }
  if (t.includes('SHOWER') || t.includes('RAIN')) {
    return t.includes('SHOWER') ? 80 : 61;
  }
  return null;
}

/** India CPCB / NAAQI band labels when Google omits category. */
export function aqiLabelFromIndiaAqi(aqi: number | null | undefined): string | null {
  if (aqi == null || !Number.isFinite(aqi)) {
    return null;
  }
  const v = Math.round(aqi);
  if (v <= 50) {
    return 'Good';
  }
  if (v <= 100) {
    return 'Satisfactory';
  }
  if (v <= 200) {
    return 'Moderate';
  }
  if (v <= 300) {
    return 'Poor';
  }
  if (v <= 400) {
    return 'Very Poor';
  }
  return 'Severe';
}

export function normalizeAqiCategory(category: string | null | undefined): string | null {
  if (category == null || typeof category !== 'string') {
    return null;
  }
  const trimmed = category.trim();
  if (!trimmed) {
    return null;
  }
  // Google often returns "Good air quality" — shorten for the chip tooltip.
  return trimmed.replace(/\s+air quality$/i, '').trim() || trimmed;
}

/** Normalize Google dominant pollutant codes for kiosk display. */
export function formatDominantPollutant(code: string | null | undefined): string | null {
  if (code == null || typeof code !== 'string') {
    return null;
  }
  const key = code.trim().toLowerCase();
  if (!key) {
    return null;
  }
  const known: Record<string, string> = {
    pm25: 'PM2.5',
    pm2_5: 'PM2.5',
    'pm2.5': 'PM2.5',
    pm10: 'PM10',
    no2: 'NO2',
    o3: 'O3',
    co: 'CO',
    so2: 'SO2',
  };
  return known[key] ?? code.trim().toUpperCase();
}

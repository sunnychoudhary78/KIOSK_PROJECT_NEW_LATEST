/** WMO weather interpretation codes → short kiosk label. */
export function weatherLabelFromCode(code: number | null | undefined): string | null {
  if (code == null || !Number.isFinite(code)) {
    return null;
  }
  const c = Math.trunc(code);
  if (c === 0) {
    return 'Clear';
  }
  if (c === 1 || c === 2) {
    return 'Partly cloudy';
  }
  if (c === 3) {
    return 'Overcast';
  }
  if (c === 45 || c === 48) {
    return 'Fog';
  }
  if (c >= 51 && c <= 57) {
    return 'Drizzle';
  }
  if (c >= 61 && c <= 67) {
    return 'Rain';
  }
  if (c >= 71 && c <= 77) {
    return 'Snow';
  }
  if (c >= 80 && c <= 82) {
    return 'Showers';
  }
  if (c >= 85 && c <= 86) {
    return 'Snow showers';
  }
  if (c >= 95 && c <= 99) {
    return 'Thunderstorm';
  }
  return 'Unknown';
}

/** US AQI band labels (EPA-style). */
export function aqiLabelFromUsAqi(aqi: number | null | undefined): string | null {
  if (aqi == null || !Number.isFinite(aqi)) {
    return null;
  }
  const v = Math.round(aqi);
  if (v <= 50) {
    return 'Good';
  }
  if (v <= 100) {
    return 'Moderate';
  }
  if (v <= 150) {
    return 'Unhealthy for sensitive';
  }
  if (v <= 200) {
    return 'Unhealthy';
  }
  if (v <= 300) {
    return 'Very unhealthy';
  }
  return 'Hazardous';
}

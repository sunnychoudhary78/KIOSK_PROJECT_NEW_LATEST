export const config = {
  apiBaseUrl: import.meta.env.VITE_SKP_API_BASE_URL ?? 'http://localhost:3000/v1',
  appName: import.meta.env.VITE_SKP_APP_NAME ?? 'Smart Kiosk Admin',
} as const;

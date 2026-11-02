const TOKEN_KEY = 'skp_admin_token';
const REFRESH_KEY = 'skp_admin_refresh_token';
const EMAIL_KEY = 'skp_admin_email';

export function getAccessToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setAccessToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearAccessToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

export function getRefreshToken(): string | null {
  return localStorage.getItem(REFRESH_KEY);
}

export function setRefreshToken(token: string): void {
  localStorage.setItem(REFRESH_KEY, token);
}

export function clearRefreshToken(): void {
  localStorage.removeItem(REFRESH_KEY);
}

export function getAdminEmail(): string | null {
  return localStorage.getItem(EMAIL_KEY);
}

export function setAdminEmail(email: string): void {
  localStorage.setItem(EMAIL_KEY, email);
}

export function clearAdminEmail(): void {
  localStorage.removeItem(EMAIL_KEY);
}

export function isAuthenticated(): boolean {
  return Boolean(getAccessToken());
}

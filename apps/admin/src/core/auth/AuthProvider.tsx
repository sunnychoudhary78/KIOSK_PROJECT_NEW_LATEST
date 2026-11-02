import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { apiRequest, setAccessTokenListener } from '../api/client';
import {
  clearAccessToken,
  clearAdminEmail,
  clearRefreshToken,
  getAccessToken,
  getAdminEmail,
  setAccessToken,
  setAdminEmail,
  setRefreshToken,
} from './session';
import { AuthContext } from './auth-context';

type TokenResponse = {
  accessToken: string;
  refreshToken?: string;
};

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() => getAccessToken());
  const [email, setEmail] = useState<string | null>(() => getAdminEmail());

  useEffect(() => {
    setAccessTokenListener(setToken);
    return () => setAccessTokenListener(null);
  }, []);

  const value = useMemo(
    () => ({
      token,
      email,
      async login(nextEmail: string, password: string) {
        const result = await apiRequest<TokenResponse>('/auth/admin/login', {
          method: 'POST',
          body: { email: nextEmail, password },
        });
        setAccessToken(result.accessToken);
        if (result.refreshToken) setRefreshToken(result.refreshToken);
        else clearRefreshToken();
        setAdminEmail(nextEmail);
        setToken(result.accessToken);
        setEmail(nextEmail);
      },
      logout() {
        clearAccessToken();
        clearRefreshToken();
        clearAdminEmail();
        setToken(null);
        setEmail(null);
      },
    }),
    [token, email],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

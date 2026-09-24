import { useMemo, useState, type ReactNode } from 'react';
import { apiRequest } from '../api/client';
import {
  clearAccessToken,
  clearAdminEmail,
  getAccessToken,
  getAdminEmail,
  setAccessToken,
  setAdminEmail,
} from './session';
import { AuthContext } from './auth-context';

type TokenResponse = {
  accessToken: string;
};

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() => getAccessToken());
  const [email, setEmail] = useState<string | null>(() => getAdminEmail());

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
        setAdminEmail(nextEmail);
        setToken(result.accessToken);
        setEmail(nextEmail);
      },
      logout() {
        clearAccessToken();
        clearAdminEmail();
        setToken(null);
        setEmail(null);
      },
    }),
    [token, email],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

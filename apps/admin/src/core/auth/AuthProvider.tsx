import { useMemo, useState, type ReactNode } from 'react';
import { apiRequest } from '../api/client';
import { clearAccessToken, getAccessToken, setAccessToken } from './session';
import { AuthContext } from './auth-context';

type TokenResponse = {
  accessToken: string;
};

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() => getAccessToken());

  const value = useMemo(
    () => ({
      token,
      async login(email: string, password: string) {
        const result = await apiRequest<TokenResponse>('/auth/admin/login', {
          method: 'POST',
          body: { email, password },
        });
        setAccessToken(result.accessToken);
        setToken(result.accessToken);
      },
      logout() {
        clearAccessToken();
        setToken(null);
      },
    }),
    [token],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

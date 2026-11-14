import type { FormEvent } from 'react';
import { useState } from 'react';
import { Navigate, useSearchParams } from 'react-router-dom';
import { Eye, EyeOff } from 'lucide-react';
import { useAuth } from '../../core/auth/auth-context';
import { Button } from '../../core/ui/primitives';
import { ApiError } from '../../core/errors/api-error';
import { config } from '../../core/config';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

export function LoginPage() {
  const auth = useAuth();
  const [searchParams] = useSearchParams();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const notice =
    error ?? (searchParams.get('reason') === 'expired' ? 'Your session expired. Sign in again.' : null);

  if (auth.token) {
    return <Navigate to="/" replace />;
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(null);
    try {
      await auth.login(email, password);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="grid h-full min-h-full overflow-y-auto lg:grid-cols-[1fr_1.1fr]">
      <section className="hidden border-r border-border bg-muted/30 px-12 py-16 lg:flex lg:flex-col lg:justify-between">
        <div>
          <p className="text-sm font-medium">{config.appName}</p>
          <p className="mt-1 text-sm text-muted-foreground">Admin</p>
        </div>
        <div className="max-w-sm space-y-3">
          <p className="text-2xl font-medium tracking-tight">Operate the kiosk fleet from one place.</p>
          <p className="text-sm leading-relaxed text-muted-foreground">
            Devices, print jobs, ads, and support — without the noise.
          </p>
        </div>
        <p className="text-xs text-muted-foreground">Local console</p>
      </section>

      <section className="flex items-center justify-center px-6 py-12">
        <div className="w-full max-w-sm">
          <div className="mb-8 lg:hidden">
            <p className="text-base font-medium">{config.appName}</p>
            <p className="text-sm text-muted-foreground">Admin</p>
          </div>
          <h1 className="text-xl font-medium tracking-tight">Sign in</h1>
          <p className="mt-1 text-sm text-muted-foreground">Admin or operator account</p>

          <form className="mt-8 space-y-4" onSubmit={onSubmit}>
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="username"
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <div className="relative">
                <Input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                  className="pr-10"
                  required
                />
                <button
                  type="button"
                  className="absolute top-1/2 right-2 -translate-y-1/2 rounded-sm p-1 text-muted-foreground hover:text-foreground focus-visible:outline-none focus-visible:ring-0"
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  aria-pressed={showPassword}
                  onClick={() => setShowPassword((current) => !current)}
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>
            {notice ? (
              <Alert variant="destructive">
                <AlertDescription>{notice}</AlertDescription>
              </Alert>
            ) : null}
            <Button type="submit" className="w-full" disabled={loading}>
              {loading ? 'Signing in…' : 'Sign in'}
            </Button>
          </form>
        </div>
      </section>
    </main>
  );
}

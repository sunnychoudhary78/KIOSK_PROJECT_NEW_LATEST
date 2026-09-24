import type { FormEvent } from 'react';
import { useState } from 'react';
import { Navigate } from 'react-router-dom';
import { Monitor } from 'lucide-react';
import { useAuth } from '../../core/auth/auth-context';
import { Button } from '../../core/ui/primitives';
import { ApiError } from '../../core/errors/api-error';
import { config } from '../../core/config';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

export function LoginPage() {
  const auth = useAuth();
  const [email, setEmail] = useState('admin@smartkiosk.local');
  const [password, setPassword] = useState('Admin@12345');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

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
    <main className="grid min-h-screen lg:grid-cols-2">
      <section className="relative hidden overflow-hidden bg-sidebar px-12 py-16 text-sidebar-foreground lg:flex lg:flex-col lg:justify-between">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(45,180,150,0.28),transparent_42%)]" />
        <div className="relative flex items-center gap-3">
          <div className="grid h-10 w-10 place-items-center rounded-xl bg-sidebar-primary text-sidebar">
            <Monitor className="h-5 w-5" />
          </div>
          <div>
            <p className="font-semibold">{config.appName}</p>
            <p className="text-sm text-sidebar-foreground/60">Operator console</p>
          </div>
        </div>
        <div className="relative max-w-md space-y-4">
          <p className="text-3xl font-semibold tracking-tight">Run kiosks, ads, and civic services from one desk.</p>
          <p className="text-sm leading-relaxed text-sidebar-foreground/65">
            Monitor devices, print jobs, DigiLocker sessions, and campaigns without leaving the admin
            console.
          </p>
        </div>
        <p className="relative text-xs text-sidebar-foreground/40">Smart Kiosk Platform</p>
      </section>

      <section className="flex items-center justify-center px-6 py-12">
        <div className="w-full max-w-sm">
          <div className="mb-8 lg:hidden">
            <p className="text-lg font-semibold">{config.appName}</p>
            <p className="text-sm text-muted-foreground">Operator console</p>
          </div>
          <h1 className="text-2xl font-semibold tracking-tight">Sign in</h1>
          <p className="mt-1 text-sm text-muted-foreground">Use your admin or operator account.</p>

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
              <Input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
                required
              />
            </div>
            {error ? (
              <Alert variant="destructive">
                <AlertDescription>{error}</AlertDescription>
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

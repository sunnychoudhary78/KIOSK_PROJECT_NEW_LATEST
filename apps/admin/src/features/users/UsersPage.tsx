import { Link } from 'react-router-dom';
import { ShieldCheck, Users } from 'lucide-react';
import { PageHeader, Panel } from '../../core/ui/primitives';

export function UsersPage() {
  return (
    <div>
      <PageHeader title="Users" subtitle="Admin and operator accounts" />
      <Panel>
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start">
          <div className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-accent text-accent-foreground">
            <Users className="h-5 w-5" />
          </div>
          <div className="space-y-3">
            <div>
              <h2 className="text-base font-semibold">Seeded operator account</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                User management APIs can be added later without changing this layout. Until then,
                sign in with the seeded admin.
              </p>
            </div>
            <div className="inline-flex items-center gap-2 rounded-lg border border-border bg-muted/50 px-3 py-2 text-sm">
              <ShieldCheck className="h-4 w-4 text-primary" />
              <code>admin@smartkiosk.local</code>
            </div>
            <p className="text-sm text-muted-foreground">
              Sign-in activity appears in{' '}
              <Link to="/audit-logs" className="font-medium text-primary hover:underline">
                Audit logs
              </Link>
              .
            </p>
          </div>
        </div>
      </Panel>
    </div>
  );
}

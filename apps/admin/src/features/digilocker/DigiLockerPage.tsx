import { Link } from 'react-router-dom';
import { Fingerprint, Printer, ScrollText } from 'lucide-react';
import { PageHeader, Panel } from '../../core/ui/primitives';

export function DigiLockerPage() {
  return (
    <div>
      <PageHeader title="DigiLocker" subtitle="Session visibility for DigiLocker print flows" />
      <Panel>
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start">
          <div className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-accent text-accent-foreground">
            <Fingerprint className="h-5 w-5" />
          </div>
          <div className="space-y-3">
            <div>
              <h2 className="text-base font-semibold">Sessions start on kiosk devices</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Citizens authorize DigiLocker on the kiosk, pick a document, and print it. A
                dedicated session list can be added here when ops needs it.
              </p>
            </div>
            <div className="grid gap-3 sm:grid-cols-2">
              <Link
                to="/print-jobs"
                className="flex items-center gap-3 rounded-lg border border-border px-3 py-3 text-sm hover:bg-muted/60"
              >
                <Printer className="h-4 w-4 text-primary" />
                <div>
                  <p className="font-medium">Print jobs</p>
                  <p className="text-muted-foreground">See DigiLocker print requests</p>
                </div>
              </Link>
              <Link
                to="/audit-logs"
                className="flex items-center gap-3 rounded-lg border border-border px-3 py-3 text-sm hover:bg-muted/60"
              >
                <ScrollText className="h-4 w-4 text-primary" />
                <div>
                  <p className="font-medium">Audit logs</p>
                  <p className="text-muted-foreground">Trace session start and print events</p>
                </div>
              </Link>
            </div>
          </div>
        </div>
      </Panel>
    </div>
  );
}

import { useCallback, useEffect, useMemo, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, EmptyState, PageHeader, Panel, StatusBadge } from '../../core/ui/primitives';

type PrintJob = {
  id: string;
  status: string;
  source: string;
  title: string;
  printColorMode?: 'bw' | 'color';
  deviceId?: string | null;
  needsAdminReview?: boolean;
  reconcileDetail?: string | null;
  pagesExpected?: number;
  createdAt: string;
};

const OPEN = new Set(['created', 'ready', 'printing']);

function roleFromToken(token: string | null) {
  if (!token) return null;
  const part = token.split('.')[1];
  if (!part) return null;
  try {
    const json = JSON.parse(atob(part.replace(/-/g, '+').replace(/_/g, '/'))) as { role?: string };
    return json.role ?? null;
  } catch {
    return null;
  }
}

export function PrintJobsPage() {
  const { token } = useAuth();
  const canClose = roleFromToken(token) === 'admin' || roleFromToken(token) === 'operator';
  const [items, setItems] = useState<PrintJob[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [openOnly, setOpenOnly] = useState(true);
  const [closingId, setClosingId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const result = await apiRequest<{ items: PrintJob[] }>('/print-jobs', { token });
      setItems(result.items);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load print jobs');
    }
  }, [token]);

  useEffect(() => {
    void load();
  }, [load]);

  const visible = useMemo(
    () => (openOnly ? items.filter((job) => OPEN.has(job.status)) : items),
    [items, openOnly],
  );

  async function markFailed(jobId: string) {
    if (!canClose || closingId) return;
    setClosingId(jobId);
    try {
      await apiRequest(`/print-jobs/${jobId}/admin-close`, { method: 'POST', token });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to clear print job');
    } finally {
      setClosingId(null);
    }
  }

  return (
    <div>
      <PageHeader title="Print jobs" subtitle="OTP, Quick Print, and DigiLocker activity" />
      <Panel>
        <div className="mb-3 flex flex-wrap items-center gap-3">
          <label className="flex items-center gap-2 text-sm text-muted-foreground">
            <input
              type="checkbox"
              checked={openOnly}
              onChange={(e) => setOpenOnly(e.target.checked)}
            />
            Open jobs only (created / ready / printing)
          </label>
          <Button type="button" variant="secondary" onClick={() => void load()}>
            Refresh
          </Button>
        </div>
        {error ? <p className="error">{error}</p> : null}
        {visible.length === 0 && !error ? (
          <EmptyState
            title={openOnly ? 'No open print jobs' : 'No print jobs yet'}
            description={
              openOnly
                ? 'Stuck tray reservations would appear here as open jobs.'
                : 'OTP, Quick Print, and DigiLocker jobs will appear here when a kiosk queues them.'
            }
          />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Title</th>
                <th>Source</th>
                <th>Device</th>
                <th>Color</th>
                <th>Status</th>
                <th>Created</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {visible.map((job) => (
                <tr key={job.id}>
                  <td className="font-medium">
                    {job.title}
                    {job.needsAdminReview ? (
                      <span className="ml-2 text-xs font-medium text-amber-700">Review</span>
                    ) : null}
                  </td>
                  <td className="capitalize">{job.source.replace(/_/g, ' ')}</td>
                  <td className="font-mono text-xs text-muted-foreground">
                    {job.deviceId ? job.deviceId.slice(0, 8) : '—'}
                  </td>
                  <td>{job.printColorMode === 'color' ? 'Color' : 'B/W'}</td>
                  <td>
                    <StatusBadge status={job.status} />
                  </td>
                  <td className="text-muted-foreground">
                    {new Date(job.createdAt).toLocaleString()}
                  </td>
                  <td>
                    {canClose && OPEN.has(job.status) ? (
                      <Button
                        type="button"
                        variant="secondary"
                        disabled={closingId === job.id}
                        onClick={() => void markFailed(job.id)}
                      >
                        {closingId === job.id ? 'Clearing…' : 'Mark failed'}
                      </Button>
                    ) : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}

import { useCallback, useEffect, useMemo, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  EmptyState,
  FilterChips,
  PageHeader,
  Panel,
  Select,
  StatusBadge,
  Toolbar,
} from '../../core/ui/primitives';

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

const STATUS_FILTERS = [
  { value: 'open', label: 'Open' },
  { value: 'all', label: 'All' },
  { value: 'completed', label: 'Completed' },
  { value: 'failed', label: 'Failed' },
];

const SOURCE_FILTERS = [
  { value: 'all', label: 'All sources' },
  { value: 'otp_print', label: 'OTP Print' },
  { value: 'digilocker_print', label: 'DigiLocker' },
  { value: 'quick_print', label: 'Quick Print' },
];

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
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('open');
  const [sourceFilter, setSourceFilter] = useState('all');
  const [colorFilter, setColorFilter] = useState('all');
  const [reviewOnly, setReviewOnly] = useState(false);
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

  const sources = useMemo(() => {
    const known = new Set(SOURCE_FILTERS.map((item) => item.value).filter((value) => value !== 'all'));
    const extras = Array.from(new Set(items.map((job) => job.source))).filter((source) => !known.has(source));
    return [
      ...SOURCE_FILTERS,
      ...extras.map((source) => ({
        value: source,
        label: source.replace(/_/g, ' '),
      })),
    ];
  }, [items]);

  const visible = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter((job) => {
      if (statusFilter === 'open' && !OPEN.has(job.status)) return false;
      if (statusFilter !== 'all' && statusFilter !== 'open' && job.status !== statusFilter) return false;
      if (sourceFilter !== 'all' && job.source !== sourceFilter) return false;
      if (colorFilter !== 'all' && (job.printColorMode ?? 'bw') !== colorFilter) return false;
      if (reviewOnly && !job.needsAdminReview) return false;
      if (!q) return true;
      const haystack = [
        job.title,
        job.source,
        job.status,
        job.deviceId ?? '',
        job.reconcileDetail ?? '',
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [items, search, statusFilter, sourceFilter, colorFilter, reviewOnly]);

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
        <Toolbar
          search={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search title, source, device"
          actions={
            <Button type="button" variant="secondary" onClick={() => void load()}>
              Refresh
            </Button>
          }
        >
          <FilterChips options={STATUS_FILTERS} value={statusFilter} onChange={setStatusFilter} />
          <Select
            aria-label="Filter by source"
            className="max-w-40"
            value={sourceFilter}
            onChange={(event) => setSourceFilter(event.target.value)}
          >
            {sources.map((source) => (
              <option key={source.value} value={source.value}>
                {source.label}
              </option>
            ))}
          </Select>
          <Select
            aria-label="Filter by color"
            className="max-w-28"
            value={colorFilter}
            onChange={(event) => setColorFilter(event.target.value)}
          >
            <option value="all">All colors</option>
            <option value="bw">B/W</option>
            <option value="color">Color</option>
          </Select>
          <label className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <input
              type="checkbox"
              checked={reviewOnly}
              onChange={(event) => setReviewOnly(event.target.checked)}
            />
            Needs review
          </label>
        </Toolbar>
        {error ? <p className="error">{error}</p> : null}
        {visible.length === 0 && !error ? (
          <EmptyState
            title={items.length === 0 ? 'No print jobs yet' : 'No matches'}
            description={
              items.length === 0
                ? 'OTP, Quick Print, and DigiLocker jobs will appear here when a kiosk queues them.'
                : 'Adjust filters or search.'
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

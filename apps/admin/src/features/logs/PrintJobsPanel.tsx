import { useCallback, useEffect, useMemo, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  EmptyState,
  FilterChips,
  Modal,
  PaginationBar,
  Panel,
  Select,
  StatusBadge,
  Toolbar,
  paginateItems,
} from '../../core/ui/primitives';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

type PrintJob = {
  id: string;
  status: string;
  source: string;
  title: string;
  printColorMode?: 'bw' | 'color';
  deviceId?: string | null;
  kioskName?: string | null;
  siteName?: string | null;
  needsAdminReview?: boolean;
  reconcileDetail?: string | null;
  errorMessage?: string | null;
  pageCount?: number;
  copies?: number;
  pagesExpected?: number;
  freePagesGranted?: number;
  billing?: 'free' | 'paid' | 'awaiting_payment' | 'unpaid' | 'mixed';
  amountPaise?: number;
  paymentStatus?: string | null;
  freePages?: number;
  paidPages?: number;
  createdAt: string;
};

const OPEN = new Set(['created', 'ready', 'printing']);

const STATUS_FILTERS = [
  { value: 'all', label: 'All' },
  { value: 'open', label: 'Open' },
  { value: 'completed', label: 'Completed' },
  { value: 'failed', label: 'Failed' },
];

const SOURCE_FILTERS = [
  { value: 'all', label: 'All sources' },
  { value: 'otp_print', label: 'OTP Print' },
  { value: 'digilocker_print', label: 'DigiLocker' },
  { value: 'quick_print', label: 'Quick Print' },
  { value: 'well_being_print', label: 'Well Being' },
  { value: 'astrology_print', label: 'Astrology' },
];

function rupees(amountPaise: number) {
  return `₹${(amountPaise / 100).toFixed(amountPaise % 100 === 0 ? 0 : 2)}`;
}

function sourceLabel(source: string) {
  return SOURCE_FILTERS.find((item) => item.value === source)?.label ?? source.replace(/_/g, ' ');
}

function billingBadge(job: PrintJob) {
  const billing = job.billing ?? 'free';
  if (billing === 'paid') {
    return {
      label: job.amountPaise && job.amountPaise > 0 ? `Paid ${rupees(job.amountPaise)}` : 'Paid',
      variant: 'success' as const,
    };
  }
  if (billing === 'awaiting_payment') {
    return {
      label:
        job.amountPaise && job.amountPaise > 0
          ? `Awaiting ${rupees(job.amountPaise)}`
          : 'Awaiting pay',
      variant: 'warning' as const,
    };
  }
  if (billing === 'unpaid') {
    return { label: 'Unpaid', variant: 'destructive' as const };
  }
  if (billing === 'mixed') {
    return {
      label: `Mixed · ${job.freePages ?? 0} free`,
      variant: 'warning' as const,
    };
  }
  return { label: 'Free', variant: 'secondary' as const };
}

function pagesLabel(job: PrintJob) {
  const pages = job.pageCount ?? job.pagesExpected ?? 0;
  const copies = job.copies && job.copies > 1 ? ` · ×${job.copies}` : '';
  const color = job.printColorMode === 'color' ? 'Color' : 'B/W';
  const free = job.freePages ?? job.freePagesGranted ?? 0;
  if (free > 0 && free < pages) return `${pages} pg${copies} · ${color} · ${free} free`;
  if ((job.billing ?? 'free') === 'free') return `${pages} pg${copies} · ${color} · free`;
  if (job.paidPages && job.paidPages > 0) {
    return `${pages} pg${copies} · ${color} · ${job.paidPages} paid`;
  }
  return `${pages} pg${copies} · ${color}`;
}

function kioskLabel(job: PrintJob) {
  if (job.kioskName) return job.kioskName;
  if (job.deviceId) return job.deviceId.slice(0, 8);
  return '—';
}

function ClearStuckDetails({ job }: { job: PrintJob }) {
  const billing = billingBadge(job);
  return (
    <div className="space-y-3 text-sm">
      <p>
        This closes the job as <strong>failed</strong> with reason “admin cleared stuck job”.
        It frees reserved tray pages so the kiosk can continue printing.
      </p>
      <dl className="grid gap-2 rounded-md border border-border bg-muted/30 p-3 text-muted-foreground">
        <div>
          Document: <span className="text-foreground">{job.title}</span>
        </div>
        <div>
          Kiosk: <span className="text-foreground">{kioskLabel(job)}</span>
        </div>
        <div className="flex items-center gap-2">
          Status: <StatusBadge status={job.status} />
        </div>
        <div className="flex items-center gap-2">
          Billing: <Badge variant={billing.variant}>{billing.label}</Badge>
        </div>
      </dl>
      <p className="text-muted-foreground">
        It does not refund a payment. Use Payments / Support if money needs follow-up.
      </p>
    </div>
  );
}

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

export function PrintJobsPanel() {
  const { token } = useAuth();
  const canClose = roleFromToken(token) === 'admin' || roleFromToken(token) === 'operator';
  const [items, setItems] = useState<PrintJob[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [billingFilter, setBillingFilter] = useState('all');
  const [sourceFilter, setSourceFilter] = useState('all');
  const [colorFilter, setColorFilter] = useState('all');
  const [reviewOnly, setReviewOnly] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);
  const [closingId, setClosingId] = useState<string | null>(null);
  const [clearJob, setClearJob] = useState<PrintJob | null>(null);

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
    const extras = Array.from(new Set(items.map((job) => job.source))).filter(
      (source) => !known.has(source),
    );
    return [
      ...SOURCE_FILTERS,
      ...extras.map((source) => ({
        value: source,
        label: source.replace(/_/g, ' '),
      })),
    ];
  }, [items]);

  const counts = useMemo(() => {
    const open = items.filter((job) => OPEN.has(job.status)).length;
    const free = items.filter((job) => (job.billing ?? 'free') === 'free').length;
    const paid = items.filter((job) => job.billing === 'paid').length;
    const awaiting = items.filter((job) => job.billing === 'awaiting_payment').length;
    const review = items.filter((job) => job.needsAdminReview).length;
    return { open, free, paid, awaiting, review };
  }, [items]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter((job) => {
      if (statusFilter === 'open' && !OPEN.has(job.status)) return false;
      if (statusFilter !== 'all' && statusFilter !== 'open' && job.status !== statusFilter)
        return false;
      if (billingFilter !== 'all' && (job.billing ?? 'free') !== billingFilter) return false;
      if (sourceFilter !== 'all' && job.source !== sourceFilter) return false;
      if (colorFilter !== 'all' && (job.printColorMode ?? 'bw') !== colorFilter) return false;
      if (reviewOnly && !job.needsAdminReview) return false;
      if (!q) return true;
      const haystack = [
        job.title,
        job.source,
        job.status,
        job.billing ?? '',
        job.kioskName ?? '',
        job.siteName ?? '',
        job.deviceId ?? '',
        job.reconcileDetail ?? '',
        job.errorMessage ?? '',
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [items, search, statusFilter, billingFilter, sourceFilter, colorFilter, reviewOnly]);

  useEffect(() => {
    setPage(1);
  }, [search, statusFilter, billingFilter, sourceFilter, colorFilter, reviewOnly, pageSize]);

  const paged = useMemo(
    () => paginateItems(filtered, page, pageSize),
    [filtered, page, pageSize],
  );

  async function confirmClearStuck() {
    if (!canClose || !clearJob || closingId) return;
    const jobId = clearJob.id;
    setClosingId(jobId);
    setError(null);
    try {
      await apiRequest(`/print-jobs/${jobId}/admin-close`, { method: 'POST', token });
      setClearJob(null);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to clear print job');
    } finally {
      setClosingId(null);
    }
  }

  return (
    <div>
      <div className="mb-4 flex justify-end">
        <Button type="button" variant="secondary" onClick={() => void load()}>
          Refresh
        </Button>
      </div>

      <div className="mb-4 grid gap-3 sm:grid-cols-4">
        <button
          type="button"
          className={cn(
            'stat-card text-left transition-colors',
            statusFilter === 'open' && 'border-primary/30 ring-1 ring-primary/20',
          )}
          onClick={() => setStatusFilter('open')}
        >
          <strong>{counts.open}</strong>
          <span>Open now</span>
        </button>
        <button
          type="button"
          className={cn(
            'stat-card text-left transition-colors',
            billingFilter === 'free' && 'border-primary/30 ring-1 ring-primary/20',
          )}
          onClick={() => setBillingFilter((current) => (current === 'free' ? 'all' : 'free'))}
        >
          <strong>{counts.free}</strong>
          <span>Free jobs</span>
        </button>
        <button
          type="button"
          className={cn(
            'stat-card text-left transition-colors',
            billingFilter === 'paid' && 'border-primary/30 ring-1 ring-primary/20',
          )}
          onClick={() => setBillingFilter((current) => (current === 'paid' ? 'all' : 'paid'))}
        >
          <strong>{counts.paid}</strong>
          <span>Paid jobs</span>
        </button>
        <button
          type="button"
          className={cn(
            'stat-card text-left transition-colors',
            (billingFilter === 'awaiting_payment' || reviewOnly) &&
              'border-primary/30 ring-1 ring-primary/20',
          )}
          onClick={() => {
            if (counts.awaiting > 0) {
              setBillingFilter((current) =>
                current === 'awaiting_payment' ? 'all' : 'awaiting_payment',
              );
              return;
            }
            setReviewOnly((current) => !current);
          }}
        >
          <strong>{counts.awaiting > 0 ? counts.awaiting : counts.review}</strong>
          <span>{counts.awaiting > 0 ? 'Awaiting pay' : 'Needs review'}</span>
        </button>
      </div>

      <Panel>
        <Toolbar
          search={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search title, kiosk, source"
        >
          <FilterChips options={STATUS_FILTERS} value={statusFilter} onChange={setStatusFilter} />
          <Select
            aria-label="Filter by billing"
            className="max-w-40"
            value={billingFilter}
            onChange={(event) => setBillingFilter(event.target.value)}
          >
            <option value="all">All billing</option>
            <option value="free">Free</option>
            <option value="paid">Paid</option>
            <option value="awaiting_payment">Awaiting pay</option>
            <option value="unpaid">Unpaid</option>
            <option value="mixed">Mixed</option>
          </Select>
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

        {filtered.length === 0 && !error ? (
          <EmptyState
            title={items.length === 0 ? 'No print jobs yet' : 'No matches'}
            description={
              items.length === 0
                ? 'OTP, Quick Print, and DigiLocker jobs will appear here when a kiosk queues them.'
                : 'Adjust filters or search.'
            }
          />
        ) : (
          <>
            <table className="table">
              <thead>
                <tr>
                  <th>Document</th>
                  <th>Kiosk</th>
                  <th>Billing</th>
                  <th>Pages</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {paged.items.map((job) => {
                  const billing = billingBadge(job);
                  return (
                    <tr key={job.id}>
                      <td>
                        <div className="min-w-0">
                          <div className="flex flex-wrap items-center gap-2">
                            <span className="font-medium">{job.title}</span>
                            {(job.copies ?? 1) > 1 ? (
                              <span className="text-xs font-medium text-muted-foreground">
                                ×{job.copies}
                              </span>
                            ) : null}
                            {job.needsAdminReview ? (
                              <Badge variant="warning">Review</Badge>
                            ) : null}
                          </div>
                          <p className="mt-0.5 text-xs text-muted-foreground">
                            {sourceLabel(job.source)}
                          </p>
                        </div>
                      </td>
                      <td>
                        <div className="min-w-0">
                          <div className="font-medium">{kioskLabel(job)}</div>
                          {job.siteName ? (
                            <p className="text-xs text-muted-foreground">{job.siteName}</p>
                          ) : null}
                        </div>
                      </td>
                      <td>
                        <Badge variant={billing.variant}>{billing.label}</Badge>
                      </td>
                      <td className="text-sm text-muted-foreground">{pagesLabel(job)}</td>
                      <td>
                        <div className="space-y-1">
                          <StatusBadge status={job.status} />
                          {job.errorMessage ? (
                            <p className="max-w-[16rem] text-xs text-destructive">
                              {job.errorMessage}
                            </p>
                          ) : null}
                          {!job.errorMessage && job.reconcileDetail ? (
                            <p className="max-w-[16rem] text-xs text-muted-foreground">
                              {job.reconcileDetail}
                            </p>
                          ) : null}
                        </div>
                      </td>
                      <td className="whitespace-nowrap text-muted-foreground">
                        {new Date(job.createdAt).toLocaleString()}
                      </td>
                      <td>
                        {canClose && OPEN.has(job.status) ? (
                          <Button
                            type="button"
                            variant="ghost"
                            title="Clear a stuck job so the kiosk can print again"
                            disabled={closingId === job.id}
                            onClick={() => setClearJob(job)}
                          >
                            Clear stuck
                          </Button>
                        ) : null}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            <PaginationBar
              page={paged.page}
              pageSize={pageSize}
              total={filtered.length}
              onPageChange={setPage}
              onPageSizeChange={setPageSize}
            />
          </>
        )}
      </Panel>

      <Modal
        open={clearJob != null}
        title={clearJob ? `Clear stuck job · ${clearJob.title}` : 'Clear stuck job'}
        description="Use this only when a job is stuck as created, ready, or printing and blocking the kiosk."
        onClose={() => {
          if (!closingId) setClearJob(null);
        }}
        footer={
          <>
            <Button
              type="button"
              variant="ghost"
              disabled={Boolean(closingId)}
              onClick={() => setClearJob(null)}
            >
              Cancel
            </Button>
            <Button
              type="button"
              disabled={Boolean(closingId)}
              onClick={() => void confirmClearStuck()}
            >
              {closingId ? 'Clearing…' : 'Clear stuck job'}
            </Button>
          </>
        }
      >
        {clearJob ? <ClearStuckDetails job={clearJob} /> : null}
      </Modal>
    </div>
  );
}

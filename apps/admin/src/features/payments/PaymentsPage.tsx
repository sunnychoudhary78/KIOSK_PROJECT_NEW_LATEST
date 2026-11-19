import { useCallback, useEffect, useMemo, useState } from 'react';
import { CreditCard, IndianRupee, Receipt } from 'lucide-react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  EmptyState,
  FilterChips,
  Input,
  PageHeader,
  Panel,
  Select,
  StatusBadge,
  Toolbar,
} from '../../core/ui/primitives';

type PaymentService =
  | 'otp_print'
  | 'quick_print'
  | 'digilocker_print'
  | 'well_being_print'
  | 'astrology_print'
  | 'unknown';

type PaymentRow = {
  id: string;
  status: string;
  service: PaymentService;
  amountPaise: number;
  currency: string;
  pageCount: number;
  freePages: number;
  extraPages: number;
  printColorMode: 'bw' | 'color';
  razorpayOrderId: string | null;
  razorpayPaymentId: string | null;
  failureReason: string | null;
  phone: string | null;
  kioskName: string | null;
  siteName: string | null;
  printJobTitle: string | null;
  paidAt: string | null;
  createdAt: string;
};

type PaymentsSummary = {
  totalCount: number;
  paidCount: number;
  totalAmountPaise: number;
  totalPaidPaise: number;
  byStatus: Record<string, { count: number; amountPaise: number }>;
  byService: Array<{
    service: PaymentService;
    count: number;
    paidPaise: number;
    amountPaise: number;
  }>;
};

type DayPreset = 'today' | '7d' | '30d' | 'all' | 'custom';

const STATUS_FILTERS = [
  { value: 'PAID', label: 'Paid' },
  { value: 'all', label: 'All' },
  { value: 'PENDING', label: 'Pending' },
  { value: 'FAILED', label: 'Failed' },
  { value: 'EXPIRED', label: 'Expired' },
];

const SERVICE_FILTERS = [
  { value: 'all', label: 'All services' },
  { value: 'otp_print', label: 'OTP Print' },
  { value: 'quick_print', label: 'Quick Print' },
  { value: 'digilocker_print', label: 'DigiLocker' },
  { value: 'well_being_print', label: 'Well Being' },
  { value: 'astrology_print', label: 'Astrology' },
  { value: 'unknown', label: 'Other' },
];

function formatLocalDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function addLocalDays(isoDate: string, days: number): string {
  const [y, m, d] = isoDate.split('-').map(Number);
  const dt = new Date(y, m - 1, d + days);
  return formatLocalDate(dt);
}

function todayLocal(): string {
  return formatLocalDate(new Date());
}

function rupees(amountPaise: number): string {
  return `₹${(amountPaise / 100).toFixed(amountPaise % 100 === 0 ? 0 : 2)}`;
}

function serviceLabel(service: string): string {
  return SERVICE_FILTERS.find((item) => item.value === service)?.label ?? service.replace(/_/g, ' ');
}

function rangeForPreset(preset: DayPreset): { from?: string; to?: string } {
  const today = todayLocal();
  if (preset === 'today') return { from: today, to: today };
  if (preset === '7d') return { from: addLocalDays(today, -6), to: today };
  if (preset === '30d') return { from: addLocalDays(today, -29), to: today };
  return {};
}

export function PaymentsPage() {
  const { token } = useAuth();
  const [items, setItems] = useState<PaymentRow[]>([]);
  const [summary, setSummary] = useState<PaymentsSummary | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('PAID');
  const [serviceFilter, setServiceFilter] = useState('all');
  const [dayPreset, setDayPreset] = useState<DayPreset>('30d');
  const [from, setFrom] = useState(() => rangeForPreset('30d').from ?? '');
  const [to, setTo] = useState(() => rangeForPreset('30d').to ?? '');

  const filterParams = useMemo(() => {
    const params = new URLSearchParams();
    if (statusFilter !== 'all') params.set('status', statusFilter);
    if (serviceFilter !== 'all') params.set('service', serviceFilter);
    if (from) params.set('from', from);
    if (to) params.set('to', to);
    if (search.trim()) params.set('q', search.trim());
    return params;
  }, [statusFilter, serviceFilter, from, to, search]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const listParams = new URLSearchParams(filterParams);
      listParams.set('limit', '200');
      const summaryQs = filterParams.toString();
      const [list, rollup] = await Promise.all([
        apiRequest<{ items: PaymentRow[] }>(`/payments?${listParams}`, { token }),
        apiRequest<PaymentsSummary>(
          `/payments/summary${summaryQs ? `?${summaryQs}` : ''}`,
          { token },
        ),
      ]);
      setItems(list.items);
      setSummary(rollup);
    } catch (err) {
      setItems([]);
      setSummary(null);
      setError(err instanceof Error ? err.message : 'Failed to load payments');
    } finally {
      setLoading(false);
    }
  }, [token, filterParams]);

  useEffect(() => {
    void load();
  }, [load]);

  function applyPreset(preset: DayPreset) {
    setDayPreset(preset);
    if (preset === 'custom') return;
    const range = rangeForPreset(preset);
    setFrom(range.from ?? '');
    setTo(range.to ?? '');
  }

  return (
    <div>
      <PageHeader
        title="Payments"
        subtitle="Track how much was paid for each kiosk service"
        actions={
          <Button type="button" variant="secondary" onClick={() => void load()} disabled={loading}>
            Refresh
          </Button>
        }
      />

      <div className="mb-5 grid gap-4 sm:grid-cols-3">
        <div className="stat-card">
          <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-foreground">
            <IndianRupee className="h-4 w-4" />
          </div>
          <strong>{summary ? rupees(summary.totalPaidPaise) : '—'}</strong>
          <span>Collected (paid)</span>
        </div>
        <div className="stat-card">
          <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-foreground">
            <Receipt className="h-4 w-4" />
          </div>
          <strong>{summary?.paidCount ?? '—'}</strong>
          <span>Successful payments</span>
        </div>
        <div className="stat-card">
          <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-foreground">
            <CreditCard className="h-4 w-4" />
          </div>
          <strong>{summary?.totalCount ?? '—'}</strong>
          <span>All payment attempts</span>
        </div>
      </div>

      <Panel title="Revenue by service" className="mb-5">
        {!summary || summary.byService.length === 0 ? (
          <p className="muted text-sm">No payment totals for this filter yet.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Service</th>
                <th>Payments</th>
                <th>Collected</th>
                <th>All attempts</th>
              </tr>
            </thead>
            <tbody>
              {summary.byService.map((row) => (
                <tr key={row.service}>
                  <td>{serviceLabel(row.service)}</td>
                  <td>{row.count}</td>
                  <td>{rupees(row.paidPaise)}</td>
                  <td>{rupees(row.amountPaise)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>

      <Panel title="Payment ledger">
        <Toolbar
          search={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search phone, order id, payment id"
        >
          <FilterChips options={STATUS_FILTERS} value={statusFilter} onChange={setStatusFilter} />
          <Select
            aria-label="Service"
            className="max-w-44"
            value={serviceFilter}
            onChange={(event) => setServiceFilter(event.target.value)}
          >
            {SERVICE_FILTERS.map((item) => (
              <option key={item.value} value={item.value}>
                {item.label}
              </option>
            ))}
          </Select>
          <FilterChips
            options={[
              { value: 'today', label: 'Today' },
              { value: '7d', label: '7 days' },
              { value: '30d', label: '30 days' },
              { value: 'all', label: 'All time' },
            ]}
            value={dayPreset === 'custom' ? '' : dayPreset}
            onChange={(value) => applyPreset(value as DayPreset)}
          />
          <Input
            type="date"
            aria-label="From date"
            className="w-auto"
            value={from}
            onChange={(event) => {
              setDayPreset('custom');
              setFrom(event.target.value);
            }}
          />
          <Input
            type="date"
            aria-label="To date"
            className="w-auto"
            value={to}
            onChange={(event) => {
              setDayPreset('custom');
              setTo(event.target.value);
            }}
          />
        </Toolbar>

        {error ? <p className="error">{error}</p> : null}
        {loading ? <p className="muted mb-3">Loading…</p> : null}

        {!loading && items.length === 0 && !error ? (
          <EmptyState
            title="No payments found"
            description="Try a wider date range or clear the service filter."
          />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>When</th>
                <th>Service</th>
                <th>Kiosk</th>
                <th>Phone</th>
                <th>Amount</th>
                <th>Pages</th>
                <th>Status</th>
                <th>Order</th>
              </tr>
            </thead>
            <tbody>
              {items.map((item) => (
                <tr key={item.id}>
                  <td className="whitespace-nowrap text-muted-foreground">
                    {new Date(item.paidAt ?? item.createdAt).toLocaleString()}
                  </td>
                  <td>{serviceLabel(item.service)}</td>
                  <td>
                    {item.kioskName || '—'}
                    {item.siteName ? (
                      <span className="block text-xs text-muted-foreground">{item.siteName}</span>
                    ) : null}
                  </td>
                  <td>{item.phone || '—'}</td>
                  <td>{rupees(item.amountPaise)}</td>
                  <td>
                    {item.pageCount}
                    {item.printColorMode === 'color' ? ' · color' : ' · B/W'}
                    {item.extraPages > 0 ? ` · ${item.extraPages} paid` : ''}
                  </td>
                  <td>
                    <div className="flex flex-col gap-1">
                      <StatusBadge status={item.status} />
                      {item.failureReason ? (
                        <span className="text-xs text-muted-foreground">{item.failureReason}</span>
                      ) : null}
                    </div>
                  </td>
                  <td className="font-mono text-xs">
                    {item.razorpayOrderId || item.razorpayPaymentId || '—'}
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

import { useEffect, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, EmptyState, PageHeader, Panel, Select, StatusBadge, Toolbar } from '../../core/ui/primitives';

type SupportQuery = {
  id: string;
  status: string;
  message: string;
  phone: string;
  amountPaise: number;
  razorpayOrderId?: string | null;
  failureReason?: string | null;
  paymentReference?: string | null;
  paymentStatus: string | null;
  challengeId?: string | null;
  kioskName?: string | null;
  printJobId?: string | null;
  printJobStatus?: string | null;
  pagesExpected?: number | null;
  pagesReported?: number | null;
  printJobError?: string | null;
  source?: string;
  resolution?: string | null;
  createdAt: string;
  resolvedAt?: string | null;
};

type SupportList = {
  items: SupportQuery[];
  openCount: number;
};

const RESOLUTIONS = [
  { value: 'no_action', label: 'No action needed' },
  { value: 'reprinted', label: 'Reprinted' },
  { value: 'refunded', label: 'Refunded' },
] as const;

function rupees(amountPaise: number) {
  return `₹${(amountPaise / 100).toFixed(amountPaise % 100 === 0 ? 0 : 2)}`;
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

function resolutionLabel(value: string) {
  if (value === 'otp_sent') return 'OTP sent';
  if (value === 'session_ready') return 'Session ready';
  return RESOLUTIONS.find((item) => item.value === value)?.label ?? value.replace(/_/g, ' ');
}

export function SupportPage() {
  const { token } = useAuth();
  const [items, setItems] = useState<SupportQuery[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [resolving, setResolving] = useState(false);
  const [resending, setResending] = useState(false);
  const [resolution, setResolution] = useState<(typeof RESOLUTIONS)[number]['value']>('no_action');
  const [status, setStatus] = useState<'open' | 'resolved' | 'all'>('open');
  const [source, setSource] = useState<'all' | 'payment' | 'print'>('all');
  const [kiosk, setKiosk] = useState('all');
  const canResolve = roleFromToken(token) === 'admin' || roleFromToken(token) === 'operator';
  const selected = items.find((item) => item.id === selectedId) ?? null;
  const kiosks = Array.from(
    new Set(items.map((item) => item.kioskName).filter((name): name is string => Boolean(name))),
  ).sort();
  const kioskFilter = kiosks.includes(kiosk) ? kiosk : 'all';
  const visible = kioskFilter === 'all' ? items : items.filter((item) => item.kioskName === kioskFilter);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      setError(null);
      try {
        const params = new URLSearchParams();
        if (status !== 'all') params.set('status', status);
        if (source !== 'all') params.set('source', source);
        const query = params.toString();
        const result = await apiRequest<SupportList>(`/support-queries${query ? `?${query}` : ''}`, {
          token,
        });
        if (cancelled) return;
        setItems(result.items);
        window.dispatchEvent(new Event('skp-support-changed'));
      } catch (err) {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : 'Failed to load support messages');
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token, status, source]);

  function applyUpdate(updated: SupportQuery) {
    setItems((current) => {
      const next = current.map((item) => (item.id === updated.id ? updated : item));
      if (status !== 'all' && updated.status !== status) {
        return next.filter((item) => item.id !== updated.id);
      }
      return next.sort((a, b) => {
        if (a.status !== b.status) return a.status === 'open' ? -1 : 1;
        return b.createdAt.localeCompare(a.createdAt);
      });
    });
    if (status !== 'all' && updated.status !== status) {
      setSelectedId(null);
    }
    window.dispatchEvent(new Event('skp-support-changed'));
  }

  async function markResolved() {
    if (!selected || selected.status === 'resolved') return;
    setResolving(true);
    setError(null);
    try {
      const updated = await apiRequest<SupportQuery>(`/support-queries/${selected.id}/resolve`, {
        method: 'POST',
        token,
        body: { resolution },
      });
      applyUpdate(updated);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not mark this resolved');
    } finally {
      setResolving(false);
    }
  }

  async function resendOtp() {
    if (!selected) return;
    setResending(true);
    setError(null);
    try {
      const updated = await apiRequest<SupportQuery>(`/support-queries/${selected.id}/resend-otp`, {
        method: 'POST',
        token,
      });
      applyUpdate(updated);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not resend the OTP');
    } finally {
      setResending(false);
    }
  }

  return (
    <div>
      <PageHeader
        title="Support"
        subtitle="Payment notes and print notes from the kiosk"
      />
      <Panel>
        <Toolbar>
          <Select
            aria-label="Status"
            className="max-w-40"
            value={status}
            onChange={(event) => setStatus(event.target.value as 'open' | 'resolved' | 'all')}
          >
            <option value="open">Open</option>
            <option value="resolved">Resolved</option>
            <option value="all">All statuses</option>
          </Select>
          <Select
            aria-label="Source"
            className="max-w-40"
            value={source}
            onChange={(event) => setSource(event.target.value as 'all' | 'payment' | 'print')}
          >
            <option value="all">All sources</option>
            <option value="payment">Payment</option>
            <option value="print">Print</option>
          </Select>
          <Select
            aria-label="Kiosk"
            className="max-w-52"
            value={kioskFilter}
            onChange={(event) => setKiosk(event.target.value)}
          >
            <option value="all">All kiosks</option>
            {kiosks.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </Select>
        </Toolbar>
        {error ? <p className="error">{error}</p> : null}
        {visible.length === 0 && !error ? (
          <EmptyState
            title="No support messages"
            description="A message appears here when a payment or a print needs staff."
          />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Time</th>
                <th>Source</th>
                <th>Kiosk</th>
                <th>Phone</th>
                <th>Amount</th>
                <th>Order</th>
                <th>Message</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {visible.map((item) => (
                <tr
                  key={item.id}
                  className="cursor-pointer"
                  onClick={() => setSelectedId(item.id)}
                >
                  <td className="text-muted-foreground whitespace-nowrap">
                    {new Date(item.createdAt).toLocaleString()}
                  </td>
                  <td>{item.source === 'print' ? 'Print' : 'Payment'}</td>
                  <td>{item.kioskName || '—'}</td>
                  <td>{item.phone || '—'}</td>
                  <td>
                    {item.amountPaise === 0 && !item.razorpayOrderId ? '—' : rupees(item.amountPaise)}
                  </td>
                  <td className="font-mono text-xs">{item.razorpayOrderId || '—'}</td>
                  <td className="max-w-xs truncate">{item.message}</td>
                  <td>
                    <StatusBadge status={item.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
      {selected ? (
        <Panel title="Message" className="mt-6">
          <p className="whitespace-pre-wrap">{selected.message}</p>
          <dl className="mt-4 grid gap-2 text-sm text-muted-foreground">
            <div>Kiosk: {selected.kioskName || '—'}</div>
            <div>Phone: {selected.phone || '—'}</div>
            <div>
              {selected.source === 'print' ? 'Print job' : 'Payment status:'}{' '}
              {selected.paymentStatus ? <StatusBadge status={selected.paymentStatus} /> : '—'}
              {selected.failureReason ? ` · ${selected.failureReason}` : ''}
            </div>
            {selected.razorpayOrderId ? (
              <div className="font-mono text-xs">Order: {selected.razorpayOrderId}</div>
            ) : null}
            {selected.paymentReference ? <div>Payment reference: {selected.paymentReference}</div> : null}
            {selected.printJobId ? (
              <div>
                Job {selected.printJobStatus || '—'}
                {selected.pagesExpected != null
                  ? ` · ${selected.pagesReported ?? '—'}/${selected.pagesExpected} pages`
                  : ''}
                {selected.printJobError ? ` · ${selected.printJobError}` : ''}
              </div>
            ) : null}
            {selected.resolution ? <div>Outcome: {resolutionLabel(selected.resolution)}</div> : null}
          </dl>
          {canResolve && selected.status === 'open' ? (
            <div className="mt-4 flex flex-wrap items-center gap-3">
              {selected.source !== 'print' &&
              selected.paymentStatus === 'PAID' &&
              selected.challengeId ? (
                <Button type="button" variant="secondary" disabled={resending} onClick={() => void resendOtp()}>
                  {resending ? 'Sending…' : 'Resend OTP'}
                </Button>
              ) : null}
              <Select
                aria-label="Outcome"
                className="max-w-56"
                value={resolution}
                onChange={(event) =>
                  setResolution(event.target.value as (typeof RESOLUTIONS)[number]['value'])
                }
              >
                {RESOLUTIONS.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </Select>
              <Button type="button" disabled={resolving} onClick={() => void markResolved()}>
                {resolving ? 'Saving…' : 'Mark resolved'}
              </Button>
            </div>
          ) : null}
        </Panel>
      ) : null}
    </div>
  );
}

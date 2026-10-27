import { useEffect, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, EmptyState, PageHeader, Panel, StatusBadge } from '../../core/ui/primitives';

type SupportQuery = {
  id: string;
  status: string;
  message: string;
  phone: string;
  amountPaise: number;
  razorpayOrderId?: string | null;
  failureReason?: string | null;
  paymentStatus: string;
  createdAt: string;
  resolvedAt?: string | null;
};

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

export function SupportPage() {
  const { token } = useAuth();
  const [items, setItems] = useState<SupportQuery[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [resolving, setResolving] = useState(false);
  const canResolve = roleFromToken(token) === 'admin' || roleFromToken(token) === 'operator';
  const selected = items.find((item) => item.id === selectedId) ?? null;

  async function load() {
    const result = await apiRequest<{ items: SupportQuery[] }>('/support-queries', { token });
    setItems(result.items);
  }

  useEffect(() => {
    void (async () => {
      try {
        await load();
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load support messages');
      }
    })();
  }, [token]);

  async function markResolved() {
    if (!selected || selected.status === 'resolved') return;
    setResolving(true);
    setError(null);
    try {
      const updated = await apiRequest<SupportQuery>(`/support-queries/${selected.id}/resolve`, {
        method: 'POST',
        token,
      });
      setItems((current) =>
        current
          .map((item) => (item.id === updated.id ? updated : item))
          .sort((a, b) => {
            if (a.status !== b.status) return a.status === 'open' ? -1 : 1;
            return b.createdAt.localeCompare(a.createdAt);
          }),
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not mark this resolved');
    } finally {
      setResolving(false);
    }
  }

  return (
    <div>
      <PageHeader
        title="Support"
        subtitle="Notes from people whose payment did not produce an OTP"
      />
      <Panel>
        {error ? <p className="error">{error}</p> : null}
        {items.length === 0 && !error ? (
          <EmptyState
            title="No support messages"
            description="A message appears here when someone reports a payment that left their account without an OTP."
          />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Time</th>
                <th>Phone</th>
                <th>Amount</th>
                <th>Order</th>
                <th>Message</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {items.map((item) => (
                <tr
                  key={item.id}
                  className="cursor-pointer"
                  onClick={() => setSelectedId(item.id)}
                >
                  <td className="text-muted-foreground whitespace-nowrap">
                    {new Date(item.createdAt).toLocaleString()}
                  </td>
                  <td>{item.phone || '—'}</td>
                  <td>{rupees(item.amountPaise)}</td>
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
          <p className="mt-4 text-sm text-muted-foreground">
            Payment status: <StatusBadge status={selected.paymentStatus} />
            {selected.failureReason ? ` · ${selected.failureReason}` : ''}
          </p>
          {canResolve && selected.status === 'open' ? (
            <div className="mt-4">
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

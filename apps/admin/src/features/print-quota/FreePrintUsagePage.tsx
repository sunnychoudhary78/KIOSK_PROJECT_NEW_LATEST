import { Fragment, useCallback, useEffect, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, EmptyState, Input, PageHeader, Panel, StatusBadge } from '../../core/ui/primitives';

type UsageItem = {
  phone: string;
  bwUsed: number;
  bwRemaining: number;
  colorUsed: number;
  colorRemaining: number;
  lastActivityAt: string | null;
};

type UsageListResponse = {
  period: 'daily' | 'weekly' | 'monthly';
  periodKey: string;
  limits: { freeBwPages: number; freeColorPages: number };
  items: UsageItem[];
};

type UsageEntry = {
  id: string;
  printColorMode: 'bw' | 'color';
  pages: number;
  status: string;
  periodKey: string;
  source: string;
  otpChallengeId: string | null;
  quickPrintSessionId: string | null;
  printJobId: string | null;
  createdAt: string;
  updatedAt: string;
};

type UsageDetailResponse = {
  phone: string;
  period: string;
  periodKey: string;
  limits: { freeBwPages: number; freeColorPages: number };
  summary: {
    bwUsed: number;
    bwRemaining: number;
    colorUsed: number;
    colorRemaining: number;
  };
  entries: UsageEntry[];
};

function periodLabel(period: string): string {
  if (period === 'weekly') return 'Weekly';
  if (period === 'monthly') return 'Monthly';
  return 'Daily';
}

export function FreePrintUsagePage() {
  const { token } = useAuth();
  const [query, setQuery] = useState('');
  const [search, setSearch] = useState('');
  const [data, setData] = useState<UsageListResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [expandedPhone, setExpandedPhone] = useState<string | null>(null);
  const [detail, setDetail] = useState<UsageDetailResponse | null>(null);
  const [detailError, setDetailError] = useState<string | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const qs = search.trim() ? `?q=${encodeURIComponent(search.trim())}` : '';
      const result = await apiRequest<UsageListResponse>(`/print-quota/usage${qs}`, { token });
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load free print usage');
      setData(null);
    } finally {
      setLoading(false);
    }
  }, [token, search]);

  useEffect(() => {
    void load();
  }, [load]);

  async function toggleDetail(phone: string) {
    if (expandedPhone === phone) {
      setExpandedPhone(null);
      setDetail(null);
      setDetailError(null);
      return;
    }
    setExpandedPhone(phone);
    setDetail(null);
    setDetailError(null);
    setDetailLoading(true);
    try {
      const result = await apiRequest<UsageDetailResponse>(
        `/print-quota/usage/${encodeURIComponent(phone)}`,
        { token },
      );
      setDetail(result);
    } catch (err) {
      setDetailError(err instanceof Error ? err.message : 'Failed to load activity');
    } finally {
      setDetailLoading(false);
    }
  }

  const subtitle = data
    ? `${periodLabel(data.period)} period · ${data.periodKey} · B/W ${data.limits.freeBwPages} · Color ${data.limits.freeColorPages}`
    : 'Phones that used free pages in the current quota period';

  return (
    <div>
      <PageHeader title="Free print usage" subtitle={subtitle} />
      <Panel>
        <form
          className="mb-4 flex flex-col gap-2 sm:flex-row sm:items-center"
          onSubmit={(e) => {
            e.preventDefault();
            setSearch(query.trim());
            setExpandedPhone(null);
            setDetail(null);
          }}
        >
          <Input
            placeholder="Search by phone digits"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="sm:max-w-xs"
          />
          <Button type="submit" disabled={loading}>
            {loading ? 'Loading…' : 'Search'}
          </Button>
        </form>

        {error ? <p className="error">{error}</p> : null}

        {!loading && !error && (data?.items.length ?? 0) === 0 ? (
          <EmptyState
            title="No free-page usage yet"
            description="Phones appear here after they reserve or consume free pages via OTP print or Quick Print."
          />
        ) : null}

        {data && data.items.length > 0 ? (
          <table className="table">
            <thead>
              <tr>
                <th>Phone</th>
                <th>B/W used</th>
                <th>B/W left</th>
                <th>Color used</th>
                <th>Color left</th>
                <th>Last activity</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {data.items.map((item) => (
                <Fragment key={item.phone}>
                  <tr>
                    <td className="font-medium font-mono text-sm">{item.phone}</td>
                    <td>{item.bwUsed}</td>
                    <td>{item.bwRemaining}</td>
                    <td>{item.colorUsed}</td>
                    <td>{item.colorRemaining}</td>
                    <td className="text-muted-foreground">
                      {item.lastActivityAt
                        ? new Date(item.lastActivityAt).toLocaleString()
                        : '—'}
                    </td>
                    <td>
                      <Button
                        type="button"
                        variant="ghost"
                        onClick={() => void toggleDetail(item.phone)}
                      >
                        {expandedPhone === item.phone ? 'Hide' : 'Activity'}
                      </Button>
                    </td>
                  </tr>
                  {expandedPhone === item.phone ? (
                    <tr>
                      <td colSpan={7} className="bg-muted/30">
                        {detailLoading ? <p className="text-sm text-muted-foreground">Loading…</p> : null}
                        {detailError ? <p className="error">{detailError}</p> : null}
                        {detail && detail.phone === item.phone ? (
                          detail.entries.length === 0 ? (
                            <p className="text-sm text-muted-foreground">No ledger entries this period.</p>
                          ) : (
                            <table className="table">
                              <thead>
                                <tr>
                                  <th>When</th>
                                  <th>Mode</th>
                                  <th>Pages</th>
                                  <th>Status</th>
                                  <th>Source</th>
                                </tr>
                              </thead>
                              <tbody>
                                {detail.entries.map((entry) => (
                                  <tr key={entry.id}>
                                    <td className="text-muted-foreground text-sm">
                                      {new Date(entry.updatedAt).toLocaleString()}
                                    </td>
                                    <td>{entry.printColorMode === 'color' ? 'Color' : 'B/W'}</td>
                                    <td>{entry.pages}</td>
                                    <td>
                                      <StatusBadge status={entry.status} />
                                    </td>
                                    <td className="capitalize text-sm">
                                      {entry.source.replace(/_/g, ' ')}
                                    </td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                          )
                        ) : null}
                      </td>
                    </tr>
                  ) : null}
                </Fragment>
              ))}
            </tbody>
          </table>
        ) : null}
      </Panel>
    </div>
  );
}

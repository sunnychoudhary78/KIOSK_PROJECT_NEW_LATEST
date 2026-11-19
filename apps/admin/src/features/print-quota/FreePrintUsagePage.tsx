import { Fragment, useCallback, useEffect, useMemo, useState } from 'react';
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
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

type UsageItem = {
  phone: string;
  society?: boolean;
  bwUsed: number;
  bwRemaining: number;
  colorUsed: number;
  colorRemaining: number;
  bwLimit?: number;
  colorLimit?: number;
  totalUsed?: number;
  exhausted?: boolean;
  lastActivityAt: string | null;
};

type UsageListResponse = {
  period: 'daily' | 'weekly' | 'monthly';
  periodKey: string;
  societyPeriod?: 'daily' | 'weekly' | 'monthly';
  societyPeriodKey?: string;
  limits: { freeBwPages: number; freeColorPages: number };
  societyLimits?: { freeBwPages: number; freeColorPages: number };
  total?: number;
  truncated?: boolean;
  items: UsageItem[];
};

type UsageEntry = {
  id: string;
  printColorMode: 'bw' | 'color';
  pages: number;
  status: string;
  periodKey: string;
  source: string;
  title?: string | null;
  otpChallengeId: string | null;
  quickPrintSessionId: string | null;
  printJobId: string | null;
  createdAt: string;
  updatedAt: string;
};

type UsageDetailResponse = {
  phone: string;
  society?: boolean;
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

type AudienceFilter = 'all' | 'society' | 'public';
type UsageFilter = 'all' | 'has_remaining' | 'exhausted' | 'used_bw' | 'used_color';
type SortKey = 'recent' | 'used_desc' | 'bw_left' | 'color_left';

function periodLabel(period: string): string {
  if (period === 'weekly') return 'Weekly';
  if (period === 'monthly') return 'Monthly';
  return 'Daily';
}

function sourceLabel(source: string) {
  return source.replace(/_/g, ' ');
}

function UsageBar({ used, limit, label }: { used: number; limit: number; label: string }) {
  const safeLimit = Math.max(limit, 0);
  const pct = safeLimit > 0 ? Math.min(100, Math.round((used / safeLimit) * 100)) : used > 0 ? 100 : 0;
  return (
    <div className="min-w-[7rem]">
      <div className="mb-1 flex items-baseline justify-between gap-2 text-xs">
        <span className="font-medium text-foreground">
          {used}/{safeLimit || '—'}
        </span>
        <span className="text-muted-foreground">{label}</span>
      </div>
      <div className="h-1.5 overflow-hidden rounded-full bg-muted">
        <div
          className={cn(
            'h-full rounded-full transition-all',
            pct >= 100 ? 'bg-destructive' : pct >= 70 ? 'bg-warning' : 'bg-primary',
          )}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
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
  const [audienceFilter, setAudienceFilter] = useState<AudienceFilter>('all');
  const [usageFilter, setUsageFilter] = useState<UsageFilter>('all');
  const [sortKey, setSortKey] = useState<SortKey>('recent');
  const [entryStatusFilter, setEntryStatusFilter] = useState<'all' | string>('all');

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams();
      params.set('limit', '1000');
      if (search.trim()) params.set('q', search.trim());
      if (audienceFilter !== 'all') params.set('audience', audienceFilter);
      if (usageFilter !== 'all') params.set('usage', usageFilter);
      const result = await apiRequest<UsageListResponse>(`/print-quota/usage?${params}`, { token });
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load free print usage');
      setData(null);
    } finally {
      setLoading(false);
    }
  }, [token, search, audienceFilter, usageFilter]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    const handle = window.setTimeout(() => {
      setSearch(query.trim());
      setExpandedPhone(null);
      setDetail(null);
    }, 300);
    return () => window.clearTimeout(handle);
  }, [query]);

  async function toggleDetail(phone: string) {
    if (expandedPhone === phone) {
      setExpandedPhone(null);
      setDetail(null);
      setDetailError(null);
      setEntryStatusFilter('all');
      return;
    }
    setExpandedPhone(phone);
    setDetail(null);
    setDetailError(null);
    setEntryStatusFilter('all');
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

  const visible = useMemo(() => {
    const items = [...(data?.items ?? [])];
    items.sort((a, b) => {
      if (sortKey === 'used_desc') {
        return (b.totalUsed ?? b.bwUsed + b.colorUsed) - (a.totalUsed ?? a.bwUsed + a.colorUsed);
      }
      if (sortKey === 'bw_left') return a.bwRemaining - b.bwRemaining;
      if (sortKey === 'color_left') return a.colorRemaining - b.colorRemaining;
      const aTime = a.lastActivityAt ? Date.parse(a.lastActivityAt) : 0;
      const bTime = b.lastActivityAt ? Date.parse(b.lastActivityAt) : 0;
      return bTime - aTime;
    });
    return items;
  }, [data, sortKey]);

  const counts = useMemo(() => {
    const items = data?.items ?? [];
    return {
      phones: data?.total ?? items.length,
      society: items.filter((item) => item.society).length,
      public: items.filter((item) => !item.society).length,
      exhausted: items.filter((item) => item.exhausted || (item.bwRemaining === 0 && item.colorRemaining === 0))
        .length,
      bwPages: items.reduce((sum, item) => sum + item.bwUsed, 0),
      colorPages: items.reduce((sum, item) => sum + item.colorUsed, 0),
    };
  }, [data]);

  const subtitle = data
    ? `${periodLabel(data.period)} · ${data.periodKey} · Public free B/W ${data.limits.freeBwPages} / Color ${data.limits.freeColorPages}`
    : 'Phones that used free pages in the current quota period';

  const detailEntries = useMemo(() => {
    if (!detail) return [];
    if (entryStatusFilter === 'all') return detail.entries;
    return detail.entries.filter((entry) => entry.status === entryStatusFilter);
  }, [detail, entryStatusFilter]);

  return (
    <div>
      <PageHeader
        title="Free print usage"
        subtitle={subtitle}
        actions={
          <Button type="button" variant="secondary" disabled={loading} onClick={() => void load()}>
            {loading ? 'Loading…' : 'Refresh'}
          </Button>
        }
      />

      <div className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <button
          type="button"
          className={cn('stat-card text-left', audienceFilter === 'all' && 'border-primary/30 ring-1 ring-primary/20')}
          onClick={() => setAudienceFilter('all')}
        >
          <strong>{counts.phones}</strong>
          <span>Phones this period{data?.truncated ? '+' : ''}</span>
        </button>
        <button
          type="button"
          className={cn(
            'stat-card text-left',
            audienceFilter === 'society' && 'border-primary/30 ring-1 ring-primary/20',
          )}
          onClick={() => setAudienceFilter((current) => (current === 'society' ? 'all' : 'society'))}
        >
          <strong>{counts.society}</strong>
          <span>Society phones</span>
        </button>
        <button
          type="button"
          className={cn(
            'stat-card text-left',
            usageFilter === 'exhausted' && 'border-primary/30 ring-1 ring-primary/20',
          )}
          onClick={() =>
            setUsageFilter((current) => (current === 'exhausted' ? 'all' : 'exhausted'))
          }
        >
          <strong>{counts.exhausted}</strong>
          <span>Quota exhausted</span>
        </button>
        <div className="stat-card">
          <strong>
            {counts.bwPages} / {counts.colorPages}
          </strong>
          <span>B/W · Color pages used</span>
        </div>
      </div>

      <Panel>
        <Toolbar
          search={query}
          onSearchChange={setQuery}
          searchPlaceholder="Search phone digits"
        >
          <FilterChips
            options={[
              { value: 'all', label: 'All phones' },
              { value: 'society', label: 'Society' },
              { value: 'public', label: 'Public' },
            ]}
            value={audienceFilter}
            onChange={(value) => setAudienceFilter(value as AudienceFilter)}
          />
          <Select
            aria-label="Usage filter"
            className="max-w-44"
            value={usageFilter}
            onChange={(event) => setUsageFilter(event.target.value as UsageFilter)}
          >
            <option value="all">All usage</option>
            <option value="has_remaining">Has remaining</option>
            <option value="exhausted">Exhausted</option>
            <option value="used_bw">Used B/W</option>
            <option value="used_color">Used color</option>
          </Select>
          <Select
            aria-label="Sort"
            className="max-w-40"
            value={sortKey}
            onChange={(event) => setSortKey(event.target.value as SortKey)}
          >
            <option value="recent">Newest activity</option>
            <option value="used_desc">Most pages used</option>
            <option value="bw_left">Least B/W left</option>
            <option value="color_left">Least color left</option>
          </Select>
        </Toolbar>

        {data?.societyLimits ? (
          <p className="mb-3 text-xs text-muted-foreground">
            Society quota: {periodLabel(data.societyPeriod ?? data.period)} · {data.societyPeriodKey} ·
            B/W {data.societyLimits.freeBwPages} · Color {data.societyLimits.freeColorPages}
            {data.truncated ? ` · Showing first ${data.items.length} of ${data.total}` : null}
          </p>
        ) : null}

        {error ? <p className="error">{error}</p> : null}

        {!loading && !error && visible.length === 0 ? (
          <EmptyState
            title={data?.items.length ? 'No matches' : 'No free-page usage yet'}
            description={
              data?.items.length
                ? 'Adjust audience, usage filter, or search.'
                : 'Phones appear here after they reserve or consume free pages via OTP print or Quick Print.'
            }
          />
        ) : null}

        {visible.length > 0 ? (
          <table className="table">
            <thead>
              <tr>
                <th>Phone</th>
                <th>B/W</th>
                <th>Color</th>
                <th>Last activity</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {visible.map((item) => {
                const bwLimit = item.bwLimit ?? item.bwUsed + item.bwRemaining;
                const colorLimit = item.colorLimit ?? item.colorUsed + item.colorRemaining;
                const exhausted =
                  item.exhausted ?? (item.bwRemaining === 0 && item.colorRemaining === 0);
                return (
                  <Fragment key={item.phone}>
                    <tr>
                      <td>
                        <div className="font-mono text-sm font-medium">{item.phone}</div>
                        <div className="mt-1 flex flex-wrap items-center gap-1.5">
                          <Badge variant={item.society ? 'success' : 'secondary'}>
                            {item.society ? 'Society' : 'Public'}
                          </Badge>
                          {exhausted ? <Badge variant="warning">Exhausted</Badge> : null}
                        </div>
                      </td>
                      <td>
                        <UsageBar used={item.bwUsed} limit={bwLimit} label="left" />
                        <p className="mt-1 text-xs text-muted-foreground">{item.bwRemaining} left</p>
                      </td>
                      <td>
                        <UsageBar used={item.colorUsed} limit={colorLimit} label="left" />
                        <p className="mt-1 text-xs text-muted-foreground">{item.colorRemaining} left</p>
                      </td>
                      <td className="whitespace-nowrap text-muted-foreground">
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
                          {expandedPhone === item.phone ? 'Hide activity' : 'Show activity'}
                        </Button>
                      </td>
                    </tr>
                    {expandedPhone === item.phone ? (
                      <tr>
                        <td colSpan={5} className="bg-muted/30">
                          {detailLoading ? (
                            <p className="text-sm text-muted-foreground">Loading activity…</p>
                          ) : null}
                          {detailError ? <p className="error">{detailError}</p> : null}
                          {detail && detail.phone === item.phone ? (
                            <div className="space-y-3 py-1">
                              <div className="flex flex-wrap items-center gap-2">
                                <p className="text-sm font-medium">
                                  Ledger · {detail.periodKey} · {detail.entries.length} entries
                                </p>
                                <Select
                                  aria-label="Entry status"
                                  className="max-w-36"
                                  value={entryStatusFilter}
                                  onChange={(event) => setEntryStatusFilter(event.target.value)}
                                >
                                  <option value="all">All statuses</option>
                                  <option value="consumed">Consumed</option>
                                  <option value="reserved">Reserved</option>
                                  <option value="released">Released</option>
                                </Select>
                              </div>
                              {detailEntries.length === 0 ? (
                                <p className="text-sm text-muted-foreground">
                                  No ledger entries for this filter.
                                </p>
                              ) : (
                                <table className="table">
                                  <thead>
                                    <tr>
                                      <th>When</th>
                                      <th>Document / source</th>
                                      <th>Mode</th>
                                      <th>Pages</th>
                                      <th>Status</th>
                                    </tr>
                                  </thead>
                                  <tbody>
                                    {detailEntries.map((entry) => (
                                      <tr key={entry.id}>
                                        <td className="whitespace-nowrap text-sm text-muted-foreground">
                                          {new Date(entry.updatedAt).toLocaleString()}
                                        </td>
                                        <td>
                                          <div className="text-sm font-medium">
                                            {entry.title || sourceLabel(entry.source)}
                                          </div>
                                          <p className="text-xs capitalize text-muted-foreground">
                                            {sourceLabel(entry.source)}
                                          </p>
                                        </td>
                                        <td>{entry.printColorMode === 'color' ? 'Color' : 'B/W'}</td>
                                        <td>{entry.pages}</td>
                                        <td>
                                          <StatusBadge status={entry.status} />
                                        </td>
                                      </tr>
                                    ))}
                                  </tbody>
                                </table>
                              )}
                            </div>
                          ) : null}
                        </td>
                      </tr>
                    ) : null}
                  </Fragment>
                );
              })}
            </tbody>
          </table>
        ) : null}
      </Panel>
    </div>
  );
}

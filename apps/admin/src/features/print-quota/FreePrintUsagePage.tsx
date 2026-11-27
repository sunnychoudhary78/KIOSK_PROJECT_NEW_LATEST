import { Fragment, useCallback, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
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
  periodKey?: string;
  society?: boolean;
  combined?: boolean;
  bwUsed: number;
  bwRemaining: number;
  colorUsed: number;
  colorRemaining: number;
  bwLimit?: number;
  colorLimit?: number;
  pagesLimit?: number | null;
  pagesRemaining?: number | null;
  totalUsed?: number;
  exhausted?: boolean;
  lastActivityAt: string | null;
};

type UsageSummary = {
  phones: number;
  society: number;
  public: number;
  exhausted: number;
  bwPages: number;
  colorPages: number;
};

type UsageListResponse = {
  scope?: 'current' | 'all' | 'period';
  period: 'daily' | 'weekly' | 'monthly';
  periodKey: string;
  currentPeriodKey?: string;
  societyPeriod?: 'daily' | 'weekly' | 'monthly';
  societyPeriodKey?: string;
  availablePeriodKeys?: string[];
  limits: { freeBwPages: number; freeColorPages: number };
  societyLimits?: {
    freeBwPages: number;
    freeColorPages: number;
    freePages?: number;
    combined?: boolean;
  };
  summary?: UsageSummary;
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
/** `current` | `all` | exact period key */
type PeriodFilter = string;

function periodLabel(period: string): string {
  if (period === 'weekly') return 'Weekly';
  if (period === 'monthly') return 'Monthly';
  return 'Daily';
}

function sourceLabel(source: string) {
  return source.replace(/_/g, ' ');
}

function UsageBar({
  used,
  limit,
  tone = 'bw',
}: {
  used: number;
  limit: number;
  tone?: 'bw' | 'color';
}) {
  const safeLimit = Math.max(0, limit);
  const remaining = Math.max(0, safeLimit - used);
  const pct = safeLimit > 0 ? Math.min(100, Math.round((used / safeLimit) * 100)) : used > 0 ? 100 : 0;
  return (
    <div className="min-w-[7rem]">
      <div className="mb-1 flex items-baseline justify-between gap-2 text-xs">
        <span className="font-medium text-foreground">
          {used} / {safeLimit}
        </span>
        <span className="text-muted-foreground">used</span>
      </div>
      <div className="h-1.5 overflow-hidden rounded-full bg-muted">
        <div
          className={cn(
            'h-full rounded-full transition-all',
            pct >= 100
              ? 'bg-rose-500'
              : pct >= 70
                ? 'bg-amber-500'
                : tone === 'color'
                  ? 'bg-rose-400'
                  : 'bg-slate-500',
          )}
          style={{ width: `${pct}%` }}
        />
      </div>
      <p className="mt-1 text-xs text-muted-foreground">{remaining} left</p>
    </div>
  );
}

type FreePrintUsagePageProps = {
  /** Hide page chrome when nested inside Free Print hub */
  embedded?: boolean;
};

function parseAudience(value: string | null): AudienceFilter {
  if (value === 'society' || value === 'public') return value;
  return 'all';
}

function parseUsage(value: string | null): UsageFilter {
  if (
    value === 'has_remaining' ||
    value === 'exhausted' ||
    value === 'used_bw' ||
    value === 'used_color'
  ) {
    return value;
  }
  return 'all';
}

export function FreePrintUsagePage({ embedded = false }: FreePrintUsagePageProps = {}) {
  const { token } = useAuth();
  const [searchParams] = useSearchParams();
  const initialQ = searchParams.get('q')?.trim() ?? '';
  const [query, setQuery] = useState(initialQ);
  const [search, setSearch] = useState(initialQ);
  const [data, setData] = useState<UsageListResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [expandedPhone, setExpandedPhone] = useState<string | null>(null);
  const [detail, setDetail] = useState<UsageDetailResponse | null>(null);
  const [detailError, setDetailError] = useState<string | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [audienceFilter, setAudienceFilter] = useState<AudienceFilter>(() =>
    parseAudience(searchParams.get('audience')),
  );
  const [usageFilter, setUsageFilter] = useState<UsageFilter>(() =>
    parseUsage(searchParams.get('usage')),
  );
  const [sortKey, setSortKey] = useState<SortKey>('recent');
  const [entryStatusFilter, setEntryStatusFilter] = useState<'all' | string>('all');
  const [periodFilter, setPeriodFilter] = useState<PeriodFilter>('current');

  useEffect(() => {
    const nextQ = searchParams.get('q')?.trim() ?? '';
    const nextAudience = parseAudience(searchParams.get('audience'));
    const nextUsage = parseUsage(searchParams.get('usage'));
    setQuery(nextQ);
    setSearch(nextQ);
    setAudienceFilter(nextAudience);
    setUsageFilter(nextUsage);
    setExpandedPhone(null);
    setDetail(null);
  }, [searchParams]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams();
      params.set('limit', '1000');
      if (search.trim()) params.set('q', search.trim());
      if (audienceFilter !== 'all') params.set('audience', audienceFilter);
      if (usageFilter !== 'all') params.set('usage', usageFilter);
      if (periodFilter === 'all') {
        params.set('scope', 'all');
      } else if (periodFilter !== 'current') {
        params.set('periodKey', periodFilter);
      }
      const result = await apiRequest<UsageListResponse>(`/print-quota/usage?${params}`, { token });
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load free print usage');
      setData(null);
    } finally {
      setLoading(false);
    }
  }, [token, search, audienceFilter, usageFilter, periodFilter]);

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

  async function toggleDetail(phone: string, rowPeriodKey?: string) {
    const detailKey = `${phone}::${rowPeriodKey ?? periodFilter}`;
    if (expandedPhone === detailKey) {
      setExpandedPhone(null);
      setDetail(null);
      setDetailError(null);
      setEntryStatusFilter('all');
      return;
    }
    setExpandedPhone(detailKey);
    setDetail(null);
    setDetailError(null);
    setEntryStatusFilter('all');
    setDetailLoading(true);
    try {
      const params = new URLSearchParams();
      if (periodFilter === 'all') {
        params.set('periodKey', rowPeriodKey && rowPeriodKey !== 'all' ? rowPeriodKey : 'all');
      } else if (periodFilter !== 'current') {
        params.set('periodKey', periodFilter);
      } else if (rowPeriodKey) {
        params.set('periodKey', rowPeriodKey);
      }
      const qs = params.toString();
      const result = await apiRequest<UsageDetailResponse>(
        `/print-quota/usage/${encodeURIComponent(phone)}${qs ? `?${qs}` : ''}`,
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
      if (bTime !== aTime) return bTime - aTime;
      return (b.periodKey ?? '').localeCompare(a.periodKey ?? '');
    });
    return items;
  }, [data, sortKey]);

  const counts = useMemo(() => {
    if (data?.summary) return data.summary;
    const items = data?.items ?? [];
    return {
      phones: data?.total ?? items.length,
      society: items.filter((item) => item.society).length,
      public: items.filter((item) => !item.society).length,
      exhausted: items.filter(
        (item) => item.exhausted || (item.bwRemaining === 0 && item.colorRemaining === 0),
      ).length,
      bwPages: items.reduce((sum, item) => sum + item.bwUsed, 0),
      colorPages: items.reduce((sum, item) => sum + item.colorUsed, 0),
    };
  }, [data]);

  const periodOptions = useMemo(() => {
    const current = data?.currentPeriodKey ?? data?.periodKey;
    const keys = data?.availablePeriodKeys ?? [];
    const unique = Array.from(new Set([...(current ? [current] : []), ...keys]));
    return unique;
  }, [data]);

  const showPeriodColumn = periodFilter === 'all';

  const subtitle = data
    ? [
        periodFilter === 'all'
          ? 'All history'
          : periodFilter === 'current'
            ? `${periodLabel(data.period)} · ${data.currentPeriodKey ?? data.periodKey}`
            : `${periodLabel(data.period)} · ${data.periodKey}`,
        `Public free B/W ${data.limits.freeBwPages} / Color ${data.limits.freeColorPages}`,
        data.societyLimits
          ? `Society ${data.societyLimits.freePages ?? data.societyLimits.freeBwPages} pages combined`
          : null,
      ]
        .filter(Boolean)
        .join(' · ')
    : 'Phones that used free pages — pick a period to browse history';

  const detailEntries = useMemo(() => {
    if (!detail) return [];
    if (entryStatusFilter === 'all') return detail.entries;
    return detail.entries.filter((entry) => entry.status === entryStatusFilter);
  }, [detail, entryStatusFilter]);

  return (
    <div>
      {embedded ? (
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <p className="text-sm text-muted-foreground">{subtitle}</p>
          <Button type="button" variant="secondary" disabled={loading} onClick={() => void load()}>
            {loading ? 'Loading…' : 'Refresh'}
          </Button>
        </div>
      ) : (
        <PageHeader
          title="Free print usage"
          subtitle={subtitle}
          actions={
            <Button type="button" variant="secondary" disabled={loading} onClick={() => void load()}>
              {loading ? 'Loading…' : 'Refresh'}
            </Button>
          }
        />
      )}

      <div className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <button
          type="button"
          className={cn(
            'stat-card text-left border-teal-500/25 bg-gradient-to-br from-teal-500/10 via-card to-card',
            audienceFilter === 'all' && 'ring-1 ring-teal-500/30',
          )}
          onClick={() => setAudienceFilter('all')}
        >
          <strong className="text-teal-800 dark:text-teal-200">{counts.phones}</strong>
          <span>
            {periodFilter === 'all' ? 'Phones in history' : 'Phones this period'}
            {data?.truncated ? '+' : ''}
          </span>
        </button>
        <button
          type="button"
          className={cn(
            'stat-card text-left border-emerald-500/25 bg-gradient-to-br from-emerald-500/10 via-card to-card',
            audienceFilter === 'society' && 'ring-1 ring-emerald-500/30',
          )}
          onClick={() => setAudienceFilter((current) => (current === 'society' ? 'all' : 'society'))}
        >
          <strong className="text-emerald-800 dark:text-emerald-200">{counts.society}</strong>
          <span>Society phones</span>
        </button>
        <button
          type="button"
          className={cn(
            'stat-card text-left border-rose-500/30 bg-gradient-to-br from-rose-500/12 via-card to-card',
            usageFilter === 'exhausted' && 'ring-1 ring-rose-500/30',
          )}
          onClick={() =>
            setUsageFilter((current) => (current === 'exhausted' ? 'all' : 'exhausted'))
          }
        >
          <strong className="text-rose-800 dark:text-rose-200">{counts.exhausted}</strong>
          <span>Quota exhausted</span>
        </button>
        <div className="stat-card border-amber-500/30 bg-gradient-to-br from-amber-500/12 via-card to-card">
          <strong>
            <span className="text-slate-800 dark:text-slate-200">{counts.bwPages}</span>
            <span className="mx-1 text-muted-foreground">/</span>
            <span className="text-rose-700 dark:text-rose-300">{counts.colorPages}</span>
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
          <Select
            aria-label="Period"
            className="max-w-52"
            value={periodFilter}
            onChange={(event) => {
              setPeriodFilter(event.target.value);
              setExpandedPhone(null);
              setDetail(null);
            }}
          >
            <option value="current">Current period</option>
            <option value="all">All history</option>
            {periodOptions.map((key) => (
              <option key={key} value={key}>
                Period · {key}
                {key === data?.currentPeriodKey ? ' (current)' : ''}
              </option>
            ))}
          </Select>
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

        <p className="mb-3 text-xs text-muted-foreground">
          {periodFilter === 'all'
            ? 'Showing every stored quota period. Pick a specific period to focus one day/week/month.'
            : periodFilter === 'current'
              ? `Current ${periodLabel(data?.period ?? 'daily').toLowerCase()} window${
                  data?.currentPeriodKey ? ` · ${data.currentPeriodKey}` : ''
                }.`
              : `Historical period · ${periodFilter}.`}
          {data?.societyLimits
            ? ` Society quota: ${periodLabel(data.societyPeriod ?? data.period)} · ${data.societyLimits.freePages ?? data.societyLimits.freeBwPages} pages combined (B/W + color).`
            : null}
          {data?.truncated ? ` Showing first ${data.items.length} of ${data.total}.` : null}
        </p>

        {error ? <p className="error">{error}</p> : null}

        {!loading && !error && visible.length === 0 ? (
          <EmptyState
            title={data?.items.length ? 'No matches' : 'No free-page usage for this filter'}
            description={
              data?.items.length
                ? 'Adjust period, audience, usage filter, or search.'
                : 'Try All history or another period. Phones appear after free OTP / Quick Print pages are reserved or consumed.'
            }
          />
        ) : null}

        {visible.length > 0 ? (
          <table className="table">
            <thead>
              <tr>
                <th>Phone</th>
                {showPeriodColumn ? <th>Period</th> : null}
                <th>B/W</th>
                <th>Color</th>
                <th>Last activity</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {visible.map((item) => {
                const combined = item.combined || item.society;
                const pagesLimit =
                  item.pagesLimit ??
                  item.bwLimit ??
                  item.bwUsed + item.colorUsed + (item.pagesRemaining ?? item.bwRemaining);
                const bwLimit = combined
                  ? pagesLimit
                  : (item.bwLimit ?? item.bwUsed + item.bwRemaining);
                const colorLimit = combined
                  ? pagesLimit
                  : (item.colorLimit ?? item.colorUsed + item.colorRemaining);
                const exhausted =
                  item.exhausted ??
                  (combined
                    ? item.bwUsed + item.colorUsed >= pagesLimit
                    : item.bwRemaining === 0 && item.colorRemaining === 0);
                const rowKey = `${item.phone}::${item.periodKey ?? periodFilter}`;
                return (
                  <Fragment key={rowKey}>
                    <tr>
                      <td>
                        <div className="font-mono text-sm font-medium">{item.phone}</div>
                        <div className="mt-1 flex flex-wrap items-center gap-1.5">
                          <Badge variant={item.society ? 'success' : 'secondary'}>
                            {item.society ? 'Society' : 'Public'}
                          </Badge>
                          {combined ? (
                            <Badge variant="secondary">
                              {(item.totalUsed ?? item.bwUsed + item.colorUsed)}/{pagesLimit}{' '}
                              combined
                            </Badge>
                          ) : null}
                          {exhausted ? <Badge variant="warning">Exhausted</Badge> : null}
                        </div>
                      </td>
                      {showPeriodColumn ? (
                        <td className="whitespace-nowrap text-sm text-muted-foreground">
                          {item.periodKey ?? '—'}
                        </td>
                      ) : null}
                      <td>
                        <UsageBar used={item.bwUsed} limit={bwLimit} tone="bw" />
                      </td>
                      <td>
                        <UsageBar used={item.colorUsed} limit={colorLimit} tone="color" />
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
                          onClick={() => void toggleDetail(item.phone, item.periodKey)}
                        >
                          {expandedPhone === rowKey ? 'Hide activity' : 'Show activity'}
                        </Button>
                      </td>
                    </tr>
                    {expandedPhone === rowKey ? (
                      <tr>
                        <td colSpan={showPeriodColumn ? 6 : 5} className="bg-muted/30">
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
                                      <th>Period</th>
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
                                        <td className="whitespace-nowrap text-xs text-muted-foreground">
                                          {entry.periodKey}
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

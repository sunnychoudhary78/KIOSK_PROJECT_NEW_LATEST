import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type FormEvent,
  type ReactNode,
} from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import {
  AlertTriangle,
  Gauge,
  Phone,
  Settings2,
  LayoutDashboard,
  RefreshCw,
  Plus,
  Upload,
  Users,
  Globe2,
  Printer,
  Palette,
  CalendarDays,
} from 'lucide-react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, Input, PageHeader, Panel, Select } from '../../core/ui/primitives';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import { FreePrintUsagePage } from './FreePrintUsagePage';
import { SocietyPhonesPage } from '../society-phones/SocietyPhonesPage';

type QuotaPeriod = 'daily' | 'weekly' | 'monthly';

type FreeQuotaForm = {
  period: QuotaPeriod;
  freeBwPages: number | '';
  freeColorPages: number | '';
};

type PlatformSetting = {
  settingKey: string;
  settingValue: FreeQuotaForm;
};

type UsageSummary = {
  phones: number;
  society: number;
  public: number;
  exhausted: number;
  bwPages: number;
  colorPages: number;
};

type UsageItem = {
  phone: string;
  society?: boolean;
  bwUsed: number;
  colorUsed: number;
  bwRemaining: number;
  colorRemaining: number;
  bwLimit?: number;
  colorLimit?: number;
  exhausted?: boolean;
  lastActivityAt: string | null;
};

type UsageListResponse = {
  period: QuotaPeriod;
  periodKey: string;
  currentPeriodKey?: string;
  societyPeriod?: QuotaPeriod;
  societyPeriodKey?: string;
  limits: { freeBwPages: number; freeColorPages: number };
  societyLimits?: { freeBwPages: number; freeColorPages: number };
  summary?: UsageSummary;
  total?: number;
  items: UsageItem[];
};

type SocietyList = {
  total: number;
};

type HubTab = 'overview' | 'limits' | 'society' | 'usage';

const DEFAULT_QUOTA: FreeQuotaForm = {
  period: 'daily',
  freeBwPages: 5,
  freeColorPages: 0,
};

const TABS: Array<{
  id: HubTab;
  label: string;
  icon: typeof Gauge;
  hint: string;
  active: string;
  chip: string;
}> = [
  {
    id: 'overview',
    label: 'Overview',
    icon: LayoutDashboard,
    hint: 'Monitor',
    active: 'border-teal-500/40 bg-teal-500/10 text-teal-900 dark:text-teal-100',
    chip: 'bg-teal-500/15 text-teal-700 dark:text-teal-300',
  },
  {
    id: 'limits',
    label: 'Free limits',
    icon: Settings2,
    hint: 'Update',
    active: 'border-sky-500/40 bg-sky-500/10 text-sky-900 dark:text-sky-100',
    chip: 'bg-sky-500/15 text-sky-700 dark:text-sky-300',
  },
  {
    id: 'society',
    label: 'Society numbers',
    icon: Phone,
    hint: 'Manage',
    active: 'border-emerald-500/40 bg-emerald-500/10 text-emerald-900 dark:text-emerald-100',
    chip: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300',
  },
  {
    id: 'usage',
    label: 'Usage & ledger',
    icon: Gauge,
    hint: 'Track',
    active: 'border-amber-500/40 bg-amber-500/10 text-amber-950 dark:text-amber-100',
    chip: 'bg-amber-500/15 text-amber-800 dark:text-amber-300',
  },
];

const AUTO_REFRESH_MS = 60_000;

type Accent = 'teal' | 'emerald' | 'sky' | 'amber' | 'rose' | 'slate';

const ACCENT: Record<
  Accent,
  { card: string; icon: string; value: string; bar: string }
> = {
  teal: {
    card: 'border-teal-500/25 bg-gradient-to-br from-teal-500/10 via-card to-card',
    icon: 'bg-teal-500/15 text-teal-700 dark:text-teal-300',
    value: 'text-teal-800 dark:text-teal-200',
    bar: 'bg-teal-500',
  },
  emerald: {
    card: 'border-emerald-500/25 bg-gradient-to-br from-emerald-500/10 via-card to-card',
    icon: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300',
    value: 'text-emerald-800 dark:text-emerald-200',
    bar: 'bg-emerald-500',
  },
  sky: {
    card: 'border-sky-500/25 bg-gradient-to-br from-sky-500/10 via-card to-card',
    icon: 'bg-sky-500/15 text-sky-700 dark:text-sky-300',
    value: 'text-sky-800 dark:text-sky-200',
    bar: 'bg-sky-500',
  },
  amber: {
    card: 'border-amber-500/30 bg-gradient-to-br from-amber-500/15 via-card to-card',
    icon: 'bg-amber-500/15 text-amber-800 dark:text-amber-300',
    value: 'text-amber-900 dark:text-amber-200',
    bar: 'bg-amber-500',
  },
  rose: {
    card: 'border-rose-500/30 bg-gradient-to-br from-rose-500/12 via-card to-card',
    icon: 'bg-rose-500/15 text-rose-700 dark:text-rose-300',
    value: 'text-rose-800 dark:text-rose-200',
    bar: 'bg-rose-500',
  },
  slate: {
    card: 'border-slate-400/30 bg-gradient-to-br from-slate-500/10 via-card to-card',
    icon: 'bg-slate-500/15 text-slate-700 dark:text-slate-300',
    value: 'text-slate-800 dark:text-slate-200',
    bar: 'bg-slate-500',
  },
};

function periodLabel(period: string) {
  if (period === 'weekly') return 'Weekly';
  if (period === 'monthly') return 'Monthly';
  return 'Daily';
}

function clampPages(value: unknown, fallback: number) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(0, Math.min(500, n));
}

function quotasEqual(a: FreeQuotaForm, b: FreeQuotaForm) {
  return (
    a.period === b.period &&
    a.freeBwPages === b.freeBwPages &&
    a.freeColorPages === b.freeColorPages
  );
}

function MiniBar({
  used,
  limit,
  tone = 'teal',
}: {
  used: number;
  limit: number;
  tone?: Accent;
}) {
  const safeLimit = Math.max(0, limit);
  const pct = safeLimit > 0 ? Math.min(100, Math.round((used / safeLimit) * 100)) : used > 0 ? 100 : 0;
  return (
    <div className="min-w-[5.5rem]">
      <div className="mb-0.5 flex justify-between gap-1 text-[11px] tabular-nums">
        <span className="font-medium">
          {used}/{safeLimit}
        </span>
      </div>
      <div className="h-1.5 overflow-hidden rounded-full bg-muted">
        <div
          className={cn(
            'h-full rounded-full transition-all',
            pct >= 100 ? 'bg-rose-500' : pct >= 70 ? 'bg-amber-500' : ACCENT[tone].bar,
          )}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}

function MetricCard({
  label,
  value,
  accent,
  icon: Icon,
  onClick,
  highlight,
}: {
  label: string;
  value: ReactNode;
  accent: Accent;
  icon: typeof Gauge;
  onClick: () => void;
  highlight?: boolean;
}) {
  const styles = ACCENT[accent];
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'flex items-center gap-2.5 rounded-lg border px-3 py-2 text-left transition-colors hover:bg-muted/40',
        styles.card,
        highlight && 'ring-1 ring-rose-400/40',
      )}
    >
      <div className={cn('flex h-7 w-7 shrink-0 items-center justify-center rounded-md', styles.icon)}>
        <Icon className="h-3.5 w-3.5" />
      </div>
      <div className="min-w-0">
        <strong className={cn('block text-base font-semibold tabular-nums leading-none', styles.value)}>
          {value}
        </strong>
        <span className="mt-0.5 block truncate text-[11px] leading-tight text-muted-foreground">
          {label}
        </span>
      </div>
    </button>
  );
}

function QuotaEditor({
  title,
  description,
  value,
  onChange,
  accent,
}: {
  title: string;
  description: string;
  value: FreeQuotaForm;
  onChange: (next: FreeQuotaForm) => void;
  accent: 'sky' | 'emerald';
}) {
  const styles = ACCENT[accent];
  return (
    <div className={cn('space-y-4 rounded-xl border p-4', styles.card)}>
      <div className="flex items-start gap-3">
        <div className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-lg', styles.icon)}>
          {accent === 'emerald' ? <Users className="h-4 w-4" /> : <Globe2 className="h-4 w-4" />}
        </div>
        <div>
          <h3 className="text-sm font-semibold">{title}</h3>
          <p className="mt-1 text-xs text-muted-foreground">{description}</p>
        </div>
      </div>
      <div className="settings-row">
        <label>
          Period
          <Select
            value={value.period}
            onChange={(e) => onChange({ ...value, period: e.target.value as QuotaPeriod })}
          >
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
            <option value="monthly">Monthly</option>
          </Select>
        </label>
        <label>
          Free B/W pages
          <Input
            type="number"
            min={0}
            max={500}
            value={value.freeBwPages}
            onChange={(e) => {
              const raw = e.target.value;
              onChange({
                ...value,
                freeBwPages: raw === '' ? '' : Math.max(0, Math.min(500, Number(raw) || 0)),
              });
            }}
          />
        </label>
        <label>
          Free color pages
          <Input
            type="number"
            min={0}
            max={500}
            value={value.freeColorPages}
            onChange={(e) => {
              const raw = e.target.value;
              onChange({
                ...value,
                freeColorPages: raw === '' ? '' : Math.max(0, Math.min(500, Number(raw) || 0)),
              });
            }}
          />
        </label>
      </div>
      <div className="flex flex-wrap gap-2 text-xs">
        <span className="inline-flex items-center gap-1.5 rounded-full bg-slate-500/10 px-2.5 py-1 text-slate-700 dark:text-slate-300">
          <Printer className="h-3 w-3" />
          B/W {value.freeBwPages === '' ? '—' : value.freeBwPages}
        </span>
        <span className="inline-flex items-center gap-1.5 rounded-full bg-rose-500/10 px-2.5 py-1 text-rose-700 dark:text-rose-300">
          <Palette className="h-3 w-3" />
          Color {value.freeColorPages === '' ? '—' : value.freeColorPages}
        </span>
        <span className="inline-flex items-center gap-1.5 rounded-full bg-amber-500/10 px-2.5 py-1 text-amber-800 dark:text-amber-300">
          <CalendarDays className="h-3 w-3" />
          {periodLabel(value.period)}
        </span>
      </div>
    </div>
  );
}

export function FreePrintHubPage() {
  const { token } = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const tabParam = searchParams.get('tab');
  const tab: HubTab =
    tabParam === 'limits' || tabParam === 'society' || tabParam === 'usage' || tabParam === 'overview'
      ? tabParam
      : 'overview';

  const [publicQuota, setPublicQuota] = useState<FreeQuotaForm>(DEFAULT_QUOTA);
  const [societyQuota, setSocietyQuota] = useState<FreeQuotaForm>(DEFAULT_QUOTA);
  const [savedPublicQuota, setSavedPublicQuota] = useState<FreeQuotaForm>(DEFAULT_QUOTA);
  const [savedSocietyQuota, setSavedSocietyQuota] = useState<FreeQuotaForm>(DEFAULT_QUOTA);
  const [quotaError, setQuotaError] = useState<string | null>(null);
  const [quotaSaved, setQuotaSaved] = useState<string | null>(null);
  const [savingQuota, setSavingQuota] = useState(false);

  const [usage, setUsage] = useState<UsageListResponse | null>(null);
  const [societyTotal, setSocietyTotal] = useState<number | null>(null);
  const [overviewError, setOverviewError] = useState<string | null>(null);
  const [overviewLoading, setOverviewLoading] = useState(false);
  const [lastRefreshedAt, setLastRefreshedAt] = useState<Date | null>(null);

  const [quickPhone, setQuickPhone] = useState('');
  const [quickName, setQuickName] = useState('');
  const [quickSocietyName, setQuickSocietyName] = useState('');
  const [quickAddError, setQuickAddError] = useState<string | null>(null);
  const [quickAddOk, setQuickAddOk] = useState<string | null>(null);
  const [quickAdding, setQuickAdding] = useState(false);

  const setTab = useCallback(
    (next: HubTab, extra?: Record<string, string>) => {
      const params = new URLSearchParams();
      if (next !== 'overview') params.set('tab', next);
      if (extra) {
        for (const [key, value] of Object.entries(extra)) {
          if (value) params.set(key, value);
        }
      }
      setSearchParams(params, { replace: true });
    },
    [setSearchParams],
  );

  const loadQuotas = useCallback(async () => {
    const result = await apiRequest<{ items: PlatformSetting[] }>('/platform-settings', { token });
    let nextPublic = DEFAULT_QUOTA;
    let nextSociety = DEFAULT_QUOTA;
    for (const item of result.items) {
      if (item.settingKey === 'print_free_quota_config') {
        nextPublic = { ...DEFAULT_QUOTA, ...item.settingValue };
      }
      if (item.settingKey === 'society_free_quota_config') {
        nextSociety = { ...DEFAULT_QUOTA, ...item.settingValue };
      }
    }
    setPublicQuota(nextPublic);
    setSocietyQuota(nextSociety);
    setSavedPublicQuota(nextPublic);
    setSavedSocietyQuota(nextSociety);
  }, [token]);

  const loadOverview = useCallback(async () => {
    setOverviewLoading(true);
    setOverviewError(null);
    try {
      const [usageResult, societyResult] = await Promise.all([
        apiRequest<UsageListResponse>('/print-quota/usage?limit=1000', { token }),
        apiRequest<SocietyList>('/society-phones', { token }),
      ]);
      setUsage(usageResult);
      setSocietyTotal(societyResult.total);
      setLastRefreshedAt(new Date());
    } catch (err) {
      setOverviewError(err instanceof Error ? err.message : 'Failed to load free-print overview');
    } finally {
      setOverviewLoading(false);
    }
  }, [token]);

  const refreshAll = useCallback(async () => {
    await Promise.all([
      loadQuotas().catch((err: unknown) => {
        setQuotaError(err instanceof Error ? err.message : 'Failed to load free limits');
      }),
      loadOverview(),
    ]);
  }, [loadOverview, loadQuotas]);

  useEffect(() => {
    void refreshAll();
  }, [refreshAll]);

  useEffect(() => {
    const id = window.setInterval(() => {
      void loadOverview();
    }, AUTO_REFRESH_MS);
    return () => window.clearInterval(id);
  }, [loadOverview]);

  const limitsDirty =
    !quotasEqual(publicQuota, savedPublicQuota) || !quotasEqual(societyQuota, savedSocietyQuota);

  async function saveQuotas(event: FormEvent) {
    event.preventDefault();
    setSavingQuota(true);
    setQuotaError(null);
    setQuotaSaved(null);
    try {
      const nextPublic = {
        period: publicQuota.period,
        freeBwPages: clampPages(publicQuota.freeBwPages, DEFAULT_QUOTA.freeBwPages),
        freeColorPages: clampPages(publicQuota.freeColorPages, DEFAULT_QUOTA.freeColorPages),
      };
      const nextSociety = {
        period: societyQuota.period,
        freeBwPages: clampPages(societyQuota.freeBwPages, DEFAULT_QUOTA.freeBwPages),
        freeColorPages: clampPages(societyQuota.freeColorPages, DEFAULT_QUOTA.freeColorPages),
      };
      await Promise.all([
        apiRequest('/platform-settings/print_free_quota_config', {
          method: 'PUT',
          token,
          body: { settingValue: nextPublic },
        }),
        apiRequest('/platform-settings/society_free_quota_config', {
          method: 'PUT',
          token,
          body: { settingValue: nextSociety },
        }),
      ]);
      setPublicQuota(nextPublic);
      setSocietyQuota(nextSociety);
      setSavedPublicQuota(nextPublic);
      setSavedSocietyQuota(nextSociety);
      setQuotaSaved('Public and society free limits saved.');
      await loadOverview();
    } catch (err) {
      setQuotaError(err instanceof Error ? err.message : 'Failed to save free limits');
    } finally {
      setSavingQuota(false);
    }
  }

  async function quickAddPhone(event: FormEvent) {
    event.preventDefault();
    if (!quickName.trim()) {
      setQuickAddError('Enter the person name');
      return;
    }
    if (!quickSocietyName.trim()) {
      setQuickAddError('Enter the society name');
      return;
    }
    setQuickAdding(true);
    setQuickAddError(null);
    setQuickAddOk(null);
    try {
      await apiRequest('/society-phones', {
        method: 'POST',
        token,
        body: {
          phone: quickPhone.trim(),
          name: quickName.trim(),
          societyName: quickSocietyName.trim(),
        },
      });
      setQuickAddOk(
        `${quickName.trim()} · ${quickSocietyName.trim()} · ${quickPhone.trim()} added.`,
      );
      setQuickPhone('');
      setQuickName('');
      setQuickSocietyName('');
      await loadOverview();
    } catch (err) {
      setQuickAddError(err instanceof Error ? err.message : 'Failed to add number');
    } finally {
      setQuickAdding(false);
    }
  }

  const summary = useMemo(() => {
    if (usage?.summary) return usage.summary;
    const items = usage?.items ?? [];
    return {
      phones: usage?.total ?? items.length,
      society: items.filter((item) => item.society).length,
      public: items.filter((item) => !item.society).length,
      exhausted: items.filter(
        (item) => item.exhausted || (item.bwRemaining === 0 && item.colorRemaining === 0),
      ).length,
      bwPages: items.reduce((sum, item) => sum + item.bwUsed, 0),
      colorPages: items.reduce((sum, item) => sum + item.colorUsed, 0),
    };
  }, [usage]);

  const exhaustedItems = useMemo(() => {
    return (usage?.items ?? [])
      .filter((item) => item.exhausted || (item.bwRemaining === 0 && item.colorRemaining === 0))
      .sort((a, b) => {
        const aTime = a.lastActivityAt ? Date.parse(a.lastActivityAt) : 0;
        const bTime = b.lastActivityAt ? Date.parse(b.lastActivityAt) : 0;
        return bTime - aTime;
      })
      .slice(0, 6);
  }, [usage]);

  const recentActivity = useMemo(() => {
    const items = [...(usage?.items ?? [])];
    items.sort((a, b) => {
      const aTime = a.lastActivityAt ? Date.parse(a.lastActivityAt) : 0;
      const bTime = b.lastActivityAt ? Date.parse(b.lastActivityAt) : 0;
      return bTime - aTime;
    });
    return items.slice(0, 8);
  }, [usage]);

  const periodCaption = usage
    ? `${periodLabel(usage.period)} · ${usage.currentPeriodKey ?? usage.periodKey}`
    : 'Current period';

  return (
    <div className="space-y-5">
      <PageHeader
        title="Free print"
        subtitle="Monitor usage, update public & society limits, manage society numbers, and track the ledger."
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs text-muted-foreground">
              {periodCaption}
              {usage?.societyPeriod ? ` · Society ${periodLabel(usage.societyPeriod)}` : null}
              {lastRefreshedAt ? ` · Updated ${lastRefreshedAt.toLocaleTimeString()}` : null}
            </span>
            <Button
              type="button"
              variant="secondary"
              disabled={overviewLoading}
              onClick={() => void refreshAll()}
            >
              <RefreshCw className={cn('mr-1.5 h-3.5 w-3.5', overviewLoading && 'animate-spin')} />
              {overviewLoading ? 'Refreshing…' : 'Refresh'}
            </Button>
          </div>
        }
      />

      <div className="grid grid-cols-2 gap-2 md:grid-cols-3 xl:grid-cols-6">
        <MetricCard
          label="Society numbers"
          value={societyTotal ?? '—'}
          accent="emerald"
          icon={Phone}
          onClick={() => setTab('society')}
        />
        <MetricCard
          label="Society using free"
          value={summary.society}
          accent="teal"
          icon={Users}
          onClick={() => setTab('usage', { audience: 'society' })}
        />
        <MetricCard
          label="Public using free"
          value={summary.public}
          accent="sky"
          icon={Globe2}
          onClick={() => setTab('usage', { audience: 'public' })}
        />
        <MetricCard
          label="Quota exhausted"
          value={summary.exhausted}
          accent="rose"
          icon={AlertTriangle}
          highlight={summary.exhausted > 0}
          onClick={() => setTab('usage', { usage: 'exhausted' })}
        />
        <MetricCard
          label="B/W · Color used"
          value={
            <span className="flex items-baseline gap-1">
              <span className="text-slate-800 dark:text-slate-200">{summary.bwPages}</span>
              <span className="text-xs font-normal text-muted-foreground">/</span>
              <span className="text-rose-700 dark:text-rose-300">{summary.colorPages}</span>
            </span>
          }
          accent="amber"
          icon={Palette}
          onClick={() => setTab('usage')}
        />
        <MetricCard
          label="Soc / Pub period"
          value={`${periodLabel(societyQuota.period).slice(0, 1)}/${periodLabel(publicQuota.period).slice(0, 1)}`}
          accent="slate"
          icon={CalendarDays}
          onClick={() => setTab('limits')}
        />
      </div>

      <div className="flex flex-wrap gap-2 rounded-xl border border-border/80 bg-card/80 p-2">
        {TABS.map((item) => {
          const Icon = item.icon;
          const active = tab === item.id;
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => setTab(item.id)}
              className={cn(
                'inline-flex items-center gap-2 rounded-lg border px-3 py-2 text-sm font-medium transition-colors',
                active
                  ? item.active
                  : 'border-transparent text-muted-foreground hover:bg-muted/60 hover:text-foreground',
              )}
            >
              <Icon className="h-4 w-4" />
              <span>{item.label}</span>
              <span
                className={cn(
                  'rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide',
                  active ? item.chip : 'bg-muted text-muted-foreground',
                )}
              >
                {item.hint}
              </span>
            </button>
          );
        })}
      </div>

      {tab === 'overview' ? (
        <div className="space-y-5">
          {overviewError ? <p className="error">{overviewError}</p> : null}

          {summary.exhausted > 0 ? (
            <div className="rounded-xl border border-rose-500/30 bg-gradient-to-br from-rose-500/10 via-card to-card p-4">
              <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-rose-500/15 text-rose-700 dark:text-rose-300">
                    <AlertTriangle className="h-4 w-4" />
                  </div>
                  <h3 className="text-sm font-semibold">Needs attention</h3>
                </div>
                <button
                  type="button"
                  className="text-sm font-medium text-rose-700 hover:underline dark:text-rose-300"
                  onClick={() => setTab('usage', { usage: 'exhausted' })}
                >
                  View all exhausted
                </button>
              </div>
              <div className="mb-3 rounded-md border border-rose-500/20 bg-rose-500/5 px-3 py-2 text-sm">
                <strong>{summary.exhausted}</strong> phone
                {summary.exhausted === 1 ? '' : 's'} have used their free quota for this period.
              </div>
              <table className="table">
                <thead>
                  <tr>
                    <th>Phone</th>
                    <th>Audience</th>
                    <th>B/W</th>
                    <th>Color</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {exhaustedItems.map((item) => (
                    <tr key={`ex-${item.phone}`}>
                      <td className="font-mono text-sm font-medium">{item.phone}</td>
                      <td>
                        <Badge variant={item.society ? 'success' : 'secondary'}>
                          {item.society ? 'Society' : 'Public'}
                        </Badge>
                      </td>
                      <td>
                        <MiniBar
                          used={item.bwUsed}
                          limit={item.bwLimit ?? item.bwUsed + item.bwRemaining}
                          tone="slate"
                        />
                      </td>
                      <td>
                        <MiniBar
                          used={item.colorUsed}
                          limit={item.colorLimit ?? item.colorUsed + item.colorRemaining}
                          tone="rose"
                        />
                      </td>
                      <td>
                        <Button
                          type="button"
                          variant="ghost"
                          onClick={() => setTab('usage', { q: item.phone })}
                        >
                          Open
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : null}

          <div className="grid gap-4 lg:grid-cols-3">
            <div className={cn('rounded-xl border p-4', ACCENT.sky.card)}>
              <div className="mb-3 flex items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <div className={cn('flex h-8 w-8 items-center justify-center rounded-lg', ACCENT.sky.icon)}>
                    <Globe2 className="h-4 w-4" />
                  </div>
                  <h3 className="text-sm font-semibold">Public free limit</h3>
                </div>
                <button
                  type="button"
                  className="text-sm font-medium text-sky-700 hover:underline dark:text-sky-300"
                  onClick={() => setTab('limits')}
                >
                  Edit
                </button>
              </div>
              <p className="text-2xl font-semibold tracking-tight">
                <span className="text-slate-800 dark:text-slate-100">{publicQuota.freeBwPages}</span>
                <span className="text-base font-normal text-muted-foreground"> B/W</span>
                <span className="mx-2 text-muted-foreground">·</span>
                <span className="text-rose-700 dark:text-rose-300">{publicQuota.freeColorPages}</span>
                <span className="text-base font-normal text-muted-foreground"> Color</span>
              </p>
              <p className="mt-2 text-sm text-muted-foreground">
                {periodLabel(publicQuota.period)} reset · OTP Print & Quick Print (non-society)
              </p>
            </div>

            <div className={cn('rounded-xl border p-4', ACCENT.emerald.card)}>
              <div className="mb-3 flex items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <div
                    className={cn(
                      'flex h-8 w-8 items-center justify-center rounded-lg',
                      ACCENT.emerald.icon,
                    )}
                  >
                    <Users className="h-4 w-4" />
                  </div>
                  <h3 className="text-sm font-semibold">Society free limit</h3>
                </div>
                <button
                  type="button"
                  className="text-sm font-medium text-emerald-700 hover:underline dark:text-emerald-300"
                  onClick={() => setTab('limits')}
                >
                  Edit
                </button>
              </div>
              <p className="text-2xl font-semibold tracking-tight">
                <span className="text-slate-800 dark:text-slate-100">{societyQuota.freeBwPages}</span>
                <span className="text-base font-normal text-muted-foreground"> B/W</span>
                <span className="mx-2 text-muted-foreground">·</span>
                <span className="text-rose-700 dark:text-rose-300">{societyQuota.freeColorPages}</span>
                <span className="text-base font-normal text-muted-foreground"> Color</span>
              </p>
              <p className="mt-2 text-sm text-muted-foreground">
                {periodLabel(societyQuota.period)} reset · Also DigiLocker / Wellbeing / Astrology
              </p>
            </div>

            <div className={cn('rounded-xl border p-4', ACCENT.teal.card)}>
              <div className="mb-3 flex items-center gap-2">
                <div className={cn('flex h-8 w-8 items-center justify-center rounded-lg', ACCENT.teal.icon)}>
                  <Plus className="h-4 w-4" />
                </div>
                <h3 className="text-sm font-semibold">Quick add society number</h3>
              </div>
              <form className="space-y-3" onSubmit={(event) => void quickAddPhone(event)}>
                <Input
                  value={quickName}
                  onChange={(e) => setQuickName(e.target.value)}
                  placeholder="Person name"
                  required
                />
                <Input
                  value={quickSocietyName}
                  onChange={(e) => setQuickSocietyName(e.target.value)}
                  placeholder="Society name"
                  required
                />
                <Input
                  value={quickPhone}
                  onChange={(e) => setQuickPhone(e.target.value)}
                  placeholder="10-digit mobile"
                  required
                />
                <div className="flex flex-wrap gap-2">
                  <Button
                    type="submit"
                    disabled={
                      quickAdding ||
                      quickPhone.trim().length === 0 ||
                      quickName.trim().length === 0 ||
                      quickSocietyName.trim().length === 0
                    }
                  >
                    <Plus className="mr-1.5 h-3.5 w-3.5" />
                    {quickAdding ? 'Adding…' : 'Add number'}
                  </Button>
                  <Button type="button" variant="secondary" onClick={() => setTab('society')}>
                    <Upload className="mr-1.5 h-3.5 w-3.5" />
                    Bulk import
                  </Button>
                </div>
                {quickAddError ? <p className="error">{quickAddError}</p> : null}
                {quickAddOk ? <p className="text-sm text-muted-foreground">{quickAddOk}</p> : null}
              </form>
            </div>
          </div>

          <Panel
            title="Recent free-page activity"
            actions={
              <button
                type="button"
                className="text-sm font-medium text-primary hover:underline"
                onClick={() => setTab('usage')}
              >
                Open full ledger
              </button>
            }
          >
            {recentActivity.length === 0 ? (
              <p className="muted">No free-page usage in the current period yet.</p>
            ) : (
              <table className="table">
                <thead>
                  <tr>
                    <th>Phone</th>
                    <th>Audience</th>
                    <th>B/W</th>
                    <th>Color</th>
                    <th>Last activity</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {recentActivity.map((item) => {
                    const exhausted =
                      item.exhausted ?? (item.bwRemaining === 0 && item.colorRemaining === 0);
                    return (
                      <tr key={item.phone}>
                        <td className="font-mono text-sm font-medium">{item.phone}</td>
                        <td>
                          <div className="flex flex-wrap items-center gap-1.5">
                            <Badge variant={item.society ? 'success' : 'secondary'}>
                              {item.society ? 'Society' : 'Public'}
                            </Badge>
                            {exhausted ? <Badge variant="warning">Exhausted</Badge> : null}
                          </div>
                        </td>
                        <td>
                          <MiniBar
                            used={item.bwUsed}
                            limit={item.bwLimit ?? item.bwUsed + item.bwRemaining}
                            tone="slate"
                          />
                        </td>
                        <td>
                          <MiniBar
                            used={item.colorUsed}
                            limit={item.colorLimit ?? item.colorUsed + item.colorRemaining}
                            tone="rose"
                          />
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
                            onClick={() => setTab('usage', { q: item.phone })}
                          >
                            Track
                          </Button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </Panel>

          <div className="rounded-xl border border-border bg-card p-4">
            <h3 className="mb-3 text-sm font-semibold">Related settings</h3>
            <div className="flex flex-wrap gap-3 text-sm">
              <Link
                to="/kiosks"
                className="rounded-lg border border-amber-500/25 bg-amber-500/10 px-3 py-2 text-amber-900 hover:bg-amber-500/15 dark:text-amber-200"
              >
                Kiosk session caps & night free window
              </Link>
              <Link
                to="/usage"
                className="rounded-lg border border-sky-500/25 bg-sky-500/10 px-3 py-2 text-sky-900 hover:bg-sky-500/15 dark:text-sky-200"
              >
                Usage analytics
              </Link>
              <Link
                to="/platform-settings"
                className="rounded-lg border border-slate-400/30 bg-slate-500/10 px-3 py-2 text-slate-800 hover:bg-slate-500/15 dark:text-slate-200"
              >
                Platform settings
              </Link>
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'limits' ? (
        <Panel
          title="Update free limits"
          actions={
            limitsDirty ? <Badge variant="warning">Unsaved changes</Badge> : (
              <Badge variant="secondary">Saved</Badge>
            )
          }
        >
          <form className="space-y-6" onSubmit={(event) => void saveQuotas(event)}>
            <div className="grid gap-4 lg:grid-cols-2">
              <QuotaEditor
                title="Public (non-society)"
                description="OTP Print and Quick Print for phones not on the society list."
                value={publicQuota}
                onChange={setPublicQuota}
                accent="sky"
              />
              <QuotaEditor
                title="Society list"
                description="Listed numbers. Also gates free DigiLocker / Wellbeing / Astrology when the full job fits."
                value={societyQuota}
                onChange={setSocietyQuota}
                accent="emerald"
              />
            </div>

            <p className="text-sm text-muted-foreground">
              Periods use Asia/Kolkata. Each kiosk still applies its own per-session free cap and
              optional night free-disabled window.
            </p>
            {quotaError ? <p className="error">{quotaError}</p> : null}
            {quotaSaved ? <p className="text-sm text-muted-foreground">{quotaSaved}</p> : null}
            <div className="flex flex-wrap gap-2">
              <Button type="submit" disabled={savingQuota || !limitsDirty}>
                {savingQuota ? 'Saving…' : 'Save both limits'}
              </Button>
              <Button
                type="button"
                variant="secondary"
                disabled={!limitsDirty || savingQuota}
                onClick={() => {
                  setPublicQuota(savedPublicQuota);
                  setSocietyQuota(savedSocietyQuota);
                  setQuotaSaved(null);
                  setQuotaError(null);
                }}
              >
                Reset
              </Button>
            </div>
          </form>
        </Panel>
      ) : null}

      {tab === 'society' ? <SocietyPhonesPage embedded showQuota={false} /> : null}

      {tab === 'usage' ? <FreePrintUsagePage embedded /> : null}
    </div>
  );
}

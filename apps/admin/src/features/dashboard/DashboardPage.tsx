import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Clapperboard, Gauge, Megaphone, Phone, PlayCircle } from 'lucide-react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { PageHeader, Panel, StatusBadge } from '../../core/ui/primitives';

type Campaign = {
  id: string;
  name: string;
  status: string;
  advertiserName?: string;
  eventCount?: number;
};

type FreeQuotaForm = {
  period: 'daily' | 'weekly' | 'monthly';
  freeBwPages: number;
  freeColorPages: number;
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

type UsageListResponse = {
  period: string;
  periodKey: string;
  currentPeriodKey?: string;
  limits: { freeBwPages: number; freeColorPages: number };
  societyLimits?: { freeBwPages: number; freeColorPages: number };
  summary?: UsageSummary;
  total?: number;
  items: Array<{
    society?: boolean;
    bwUsed: number;
    colorUsed: number;
    bwRemaining: number;
    colorRemaining: number;
    exhausted?: boolean;
  }>;
};

type SocietyList = {
  total: number;
};

function periodLabel(period: string) {
  if (period === 'weekly') return 'Weekly';
  if (period === 'monthly') return 'Monthly';
  return 'Daily';
}

export function DashboardPage() {
  const { token } = useAuth();
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [error, setError] = useState<string | null>(null);

  const [societyTotal, setSocietyTotal] = useState<number | null>(null);
  const [usage, setUsage] = useState<UsageListResponse | null>(null);
  const [publicQuota, setPublicQuota] = useState<FreeQuotaForm | null>(null);
  const [societyQuota, setSocietyQuota] = useState<FreeQuotaForm | null>(null);
  const [freePrintError, setFreePrintError] = useState<string | null>(null);

  useEffect(() => {
    void apiRequest<{ items: Campaign[] }>('/ads/campaigns', { token })
      .then((result) => {
        setCampaigns(result.items);
        setError(null);
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : 'Could not load campaign stats');
      });
  }, [token]);

  useEffect(() => {
    void Promise.all([
      apiRequest<UsageListResponse>('/print-quota/usage?limit=1000', { token }),
      apiRequest<SocietyList>('/society-phones', { token }),
      apiRequest<{ items: PlatformSetting[] }>('/platform-settings', { token }),
    ])
      .then(([usageResult, societyResult, settingsResult]) => {
        setUsage(usageResult);
        setSocietyTotal(societyResult.total);
        for (const item of settingsResult.items) {
          if (item.settingKey === 'print_free_quota_config') {
            setPublicQuota(item.settingValue);
          }
          if (item.settingKey === 'society_free_quota_config') {
            setSocietyQuota(item.settingValue);
          }
        }
        setFreePrintError(null);
      })
      .catch((err) => {
        setFreePrintError(
          err instanceof Error ? err.message : 'Could not load free-print snapshot',
        );
      });
  }, [token]);

  const active = campaigns.filter((c) => c.status === 'active');
  const totalEvents = campaigns.reduce((sum, c) => sum + (c.eventCount ?? 0), 0);

  const freeSummary = useMemo(() => {
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

  return (
    <div className="space-y-6">
      <PageHeader
        title="Dashboard"
        subtitle="Ads delivery, free-print snapshot, and shortcuts to manage society numbers and quotas"
        actions={
          <div className="flex flex-wrap items-center gap-3">
            <Link to="/free-print" className="text-sm font-medium text-primary hover:underline">
              Open free print
            </Link>
            <Link
              to="/fleet-health"
              className="text-sm font-medium text-primary hover:underline"
            >
              Open fleet health
            </Link>
          </div>
        }
      />

      {error ? <p className="error">{error}</p> : null}
      {freePrintError ? <p className="error">{freePrintError}</p> : null}

      <div className="grid gap-4 sm:grid-cols-3">
        <div className="stat-card">
          <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-foreground">
            <Clapperboard className="h-4 w-4" />
          </div>
          <strong>{active.length}</strong>
          <span>Active campaigns</span>
        </div>
        <div className="stat-card">
          <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-foreground">
            <Megaphone className="h-4 w-4" />
          </div>
          <strong>{campaigns.length}</strong>
          <span>Total campaigns</span>
        </div>
        <div className="stat-card">
          <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-foreground">
            <PlayCircle className="h-4 w-4" />
          </div>
          <strong>{totalEvents}</strong>
          <span>Playback events</span>
        </div>
      </div>

      <Panel
        title="Free print snapshot"
        actions={
          <div className="flex flex-wrap items-center gap-3">
            {usage?.currentPeriodKey || usage?.periodKey ? (
              <span className="text-xs text-muted-foreground">
                {periodLabel(usage.period)} · {usage.currentPeriodKey ?? usage.periodKey}
              </span>
            ) : null}
            <Link to="/free-print" className="text-sm font-medium text-primary hover:underline">
              Open free print hub
            </Link>
          </div>
        }
      >
        <div className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Link
            to="/free-print?tab=society"
            className="stat-card border-emerald-500/25 bg-gradient-to-br from-emerald-500/10 via-card to-card transition-all hover:-translate-y-0.5"
          >
            <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-emerald-500/15 text-emerald-700 dark:text-emerald-300">
              <Phone className="h-4 w-4" />
            </div>
            <strong className="text-emerald-800 dark:text-emerald-200">{societyTotal ?? '—'}</strong>
            <span>Society numbers</span>
          </Link>
          <Link
            to="/free-print?tab=usage"
            className="stat-card border-teal-500/25 bg-gradient-to-br from-teal-500/10 via-card to-card transition-all hover:-translate-y-0.5"
          >
            <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-teal-500/15 text-teal-700 dark:text-teal-300">
              <Gauge className="h-4 w-4" />
            </div>
            <strong className="text-teal-800 dark:text-teal-200">{freeSummary.phones}</strong>
            <span>Phones using free pages</span>
          </Link>
          <Link
            to="/free-print?tab=usage&usage=exhausted"
            className="stat-card border-rose-500/30 bg-gradient-to-br from-rose-500/12 via-card to-card transition-all hover:-translate-y-0.5"
          >
            <strong className="text-rose-800 dark:text-rose-200">{freeSummary.exhausted}</strong>
            <span>Quota exhausted</span>
          </Link>
          <Link
            to="/free-print?tab=usage"
            className="stat-card border-amber-500/30 bg-gradient-to-br from-amber-500/12 via-card to-card transition-all hover:-translate-y-0.5"
          >
            <strong>
              <span className="text-slate-800 dark:text-slate-200">{freeSummary.bwPages}</span>
              <span className="mx-1 text-muted-foreground">/</span>
              <span className="text-rose-700 dark:text-rose-300">{freeSummary.colorPages}</span>
            </strong>
            <span>B/W · Color free used</span>
          </Link>
        </div>

        <div className="mb-4 grid gap-3 sm:grid-cols-2">
          <div className="rounded-xl border border-sky-500/25 bg-gradient-to-br from-sky-500/10 via-card to-card p-3 text-sm">
            <p className="font-medium text-sky-900 dark:text-sky-100">Public limit</p>
            <p className="mt-1 text-2xl font-semibold tracking-tight">
              {publicQuota ? (
                <>
                  <span className="text-slate-800 dark:text-slate-100">{publicQuota.freeBwPages}</span>
                  <span className="text-sm font-normal text-muted-foreground"> B/W</span>
                  <span className="mx-2 text-muted-foreground">·</span>
                  <span className="text-rose-700 dark:text-rose-300">{publicQuota.freeColorPages}</span>
                  <span className="text-sm font-normal text-muted-foreground"> Color</span>
                </>
              ) : (
                '—'
              )}
            </p>
            <p className="mt-1 text-xs text-muted-foreground">
              {publicQuota ? `${periodLabel(publicQuota.period)} reset` : 'Loading…'}
            </p>
            <Link
              to="/free-print?tab=limits"
              className="mt-2 inline-block text-sm font-medium text-sky-700 hover:underline dark:text-sky-300"
            >
              Update limits
            </Link>
          </div>
          <div className="rounded-xl border border-emerald-500/25 bg-gradient-to-br from-emerald-500/10 via-card to-card p-3 text-sm">
            <p className="font-medium text-emerald-900 dark:text-emerald-100">Society limit</p>
            <p className="mt-1 text-2xl font-semibold tracking-tight">
              {societyQuota ? (
                <>
                  <span className="text-slate-800 dark:text-slate-100">{societyQuota.freeBwPages}</span>
                  <span className="text-sm font-normal text-muted-foreground"> B/W</span>
                  <span className="mx-2 text-muted-foreground">·</span>
                  <span className="text-rose-700 dark:text-rose-300">{societyQuota.freeColorPages}</span>
                  <span className="text-sm font-normal text-muted-foreground"> Color</span>
                </>
              ) : (
                '—'
              )}
            </p>
            <p className="mt-1 text-xs text-muted-foreground">
              {societyQuota ? `${periodLabel(societyQuota.period)} reset` : 'Loading…'}
            </p>
            <Link
              to="/free-print?tab=society"
              className="mt-2 inline-block text-sm font-medium text-emerald-700 hover:underline dark:text-emerald-300"
            >
              Manage society numbers
            </Link>
          </div>
        </div>

        <div className="flex flex-wrap gap-2">
          <Link
            to="/free-print?tab=usage&audience=society"
            className="rounded-full border border-emerald-500/25 bg-emerald-500/10 px-3 py-1.5 text-xs font-medium text-emerald-800 hover:bg-emerald-500/15 dark:text-emerald-200"
          >
            Society usage ({freeSummary.society})
          </Link>
          <Link
            to="/free-print?tab=usage&audience=public"
            className="rounded-full border border-sky-500/25 bg-sky-500/10 px-3 py-1.5 text-xs font-medium text-sky-800 hover:bg-sky-500/15 dark:text-sky-200"
          >
            Public usage ({freeSummary.public})
          </Link>
          <Link
            to="/free-print?tab=usage&usage=exhausted"
            className="rounded-full border border-rose-500/25 bg-rose-500/10 px-3 py-1.5 text-xs font-medium text-rose-800 hover:bg-rose-500/15 dark:text-rose-200"
          >
            Exhausted ({freeSummary.exhausted})
          </Link>
        </div>
      </Panel>

      <Panel
        title="Active campaigns"
        actions={
          <Link to="/campaigns" className="text-sm font-medium text-primary hover:underline">
            View all
          </Link>
        }
      >
        {active.length === 0 ? (
          <p className="muted">
            No campaigns are live. Start one from Campaigns when creatives and targets are ready.
          </p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Campaign</th>
                <th>Advertiser</th>
                <th>Status</th>
                <th>Events</th>
              </tr>
            </thead>
            <tbody>
              {active.map((c) => (
                <tr key={c.id}>
                  <td className="font-medium">
                    <Link to={`/campaigns/${c.id}`}>{c.name}</Link>
                  </td>
                  <td>{c.advertiserName ?? '—'}</td>
                  <td>
                    <StatusBadge status={c.status} />
                  </td>
                  <td>{c.eventCount ?? 0}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}

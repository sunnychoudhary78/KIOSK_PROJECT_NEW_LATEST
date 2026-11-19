import { useCallback, useEffect, useId, useMemo, useState } from 'react';
import {
  Activity,
  ArrowDownRight,
  ArrowUpRight,
  CalendarRange,
  CreditCard,
  Download,
  IndianRupee,
  Minus,
  MousePointerClick,
  Printer,
  RefreshCw,
  Sparkles,
  TrendingUp,
} from 'lucide-react';
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
} from '../../core/ui/primitives';
import { cn } from '@/lib/utils';
import {
  USAGE_RANGE_FILTERS,
  USAGE_SERVICE_FILTERS,
  USAGE_SORT_FILTERS,
  buildUsageRows,
  filterUsageRows,
  fromDatetimeLocalValue,
  labelForEventKey,
  rangeForPreset,
  usageSummary,
  type ServiceAnalyticsItem,
  type UsageRangePreset,
  type UsageSort,
} from '../kiosks/serviceUsage';

type DeviceOption = {
  id: string;
  name: string;
  siteName: string;
  status: string;
};

type DeviceUsageResponse = {
  deviceId: string;
  kioskName?: string;
  siteName?: string | null;
  from: string;
  to: string;
  totalClicks?: number;
  uniqueServices?: number;
  topEventKey?: string | null;
  topEventCount?: number;
  items: ServiceAnalyticsItem[];
  daily?: Array<{ date: string; count: number }>;
  hourly?: Array<{ hour: number; count: number }>;
  previous?: {
    from: string;
    to: string;
    totalClicks: number;
    uniqueServices: number;
  };
  comparison?: {
    totalClicksDelta: number;
    totalClicksDeltaPct: number | null;
    uniqueServicesDelta: number;
    uniqueServicesDeltaPct: number | null;
  };
};

type FleetItem = {
  deviceId: string;
  name: string;
  siteName: string | null;
  status: string;
  totalClicks: number;
  activeEventKeys: number;
  topEventKey: string | null;
  topEventCount: number;
};

type FleetResponse = {
  from: string;
  to: string;
  fleetTotalClicks: number;
  activeKiosks: number;
  idleKiosks?: Array<{
    deviceId: string;
    name: string;
    siteName: string | null;
    status: string;
  }>;
  sites?: Array<{
    siteName: string;
    kiosks: number;
    totalClicks: number;
    activeKiosks: number;
  }>;
  items: FleetItem[];
};

type PaymentsSummary = {
  totalCount: number;
  paidCount: number;
  totalAmountPaise: number;
  totalPaidPaise: number;
  pageCount?: number;
  freePages?: number;
  paidPages?: number;
};

type PrintSummary = {
  jobs: number;
  pages: number;
  freePages: number;
  paidPages: number;
  freeJobs: number;
  paidJobs: number;
  mixedJobs: number;
};

function formatDeltaPct(pct: number | null | undefined): string | null {
  if (pct == null || Number.isNaN(pct)) return null;
  if (pct === 0) return '0%';
  const sign = pct > 0 ? '+' : '';
  return `${sign}${pct}%`;
}

function toDateOnly(iso: string) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(iso));
}

function rupees(amountPaise: number) {
  return `₹${(amountPaise / 100).toFixed(amountPaise % 100 === 0 ? 0 : 2)}`;
}

const SERVICE_COLORS = [
  'oklch(0.55 0.14 255)',
  'oklch(0.58 0.12 210)',
  'oklch(0.62 0.11 175)',
  'oklch(0.66 0.12 145)',
  'oklch(0.7 0.12 95)',
  'oklch(0.62 0.14 55)',
  'oklch(0.58 0.13 30)',
  'oklch(0.52 0.08 280)',
];

function downloadCsv(filename: string, rows: string[][]) {
  const body = rows
    .map((row) =>
      row
        .map((cell) => {
          const value = String(cell ?? '');
          if (/[",\n]/.test(value)) return `"${value.replace(/"/g, '""')}"`;
          return value;
        })
        .join(','),
    )
    .join('\n');
  const blob = new Blob([body], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}

function formatRangeLabel(fromIso: string, toIso: string) {
  const from = new Date(fromIso);
  const to = new Date(toIso);
  const opts: Intl.DateTimeFormatOptions = {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  };
  return `${from.toLocaleDateString(undefined, opts)} – ${to.toLocaleDateString(undefined, opts)}`;
}

function MetricCard({
  label,
  value,
  hint,
  deltaPct,
  icon: Icon,
  tone = 'primary',
}: {
  label: string;
  value: string;
  hint?: string;
  deltaPct?: number | null;
  icon: typeof Activity;
  tone?: 'primary' | 'success' | 'warning' | 'slate';
}) {
  const toneClass =
    tone === 'success'
      ? 'border-emerald-200/70 bg-emerald-50/50'
      : tone === 'warning'
        ? 'border-amber-200/70 bg-amber-50/50'
        : tone === 'slate'
          ? 'border-border bg-slate-50/60'
          : 'border-sky-200/70 bg-sky-50/50';
  const iconClass =
    tone === 'success'
      ? 'bg-emerald-100 text-emerald-700'
      : tone === 'warning'
        ? 'bg-amber-100 text-amber-800'
        : tone === 'slate'
          ? 'bg-slate-100 text-slate-700'
          : 'bg-sky-100 text-sky-700';

  const deltaLabel = formatDeltaPct(deltaPct);
  const deltaUp = (deltaPct ?? 0) > 0;
  const deltaDown = (deltaPct ?? 0) < 0;

  return (
    <div className={cn('flex items-center gap-3 rounded-lg border px-3 py-2.5', toneClass)}>
      <div className={cn('flex h-8 w-8 shrink-0 items-center justify-center rounded-md', iconClass)}>
        <Icon className="h-3.5 w-3.5" />
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline justify-between gap-2">
          <div className="truncate text-lg font-semibold leading-tight tracking-tight">{value}</div>
          {deltaLabel ? (
            <span
              className={cn(
                'inline-flex shrink-0 items-center gap-0.5 text-[10px] font-medium tabular-nums',
                deltaUp && 'text-emerald-700',
                deltaDown && 'text-rose-700',
                !deltaUp && !deltaDown && 'text-muted-foreground',
              )}
              title="vs previous period"
            >
              {deltaUp ? (
                <ArrowUpRight className="h-3 w-3" />
              ) : deltaDown ? (
                <ArrowDownRight className="h-3 w-3" />
              ) : (
                <Minus className="h-3 w-3" />
              )}
              {deltaLabel}
            </span>
          ) : null}
        </div>
        <div className="truncate text-[11px] text-muted-foreground">
          {label}
          {hint ? ` · ${hint}` : ''}
        </div>
      </div>
    </div>
  );
}

function HourHeatmap({ hours }: { hours: Array<{ hour: number; count: number }> }) {
  const max = Math.max(1, ...hours.map((h) => h.count));
  const peak = hours.reduce(
    (best, row) => (!best || row.count > best.count ? row : best),
    null as { hour: number; count: number } | null,
  );

  function cellColor(count: number) {
    if (count <= 0) return 'bg-slate-100 text-slate-400';
    const t = count / max;
    if (t >= 0.75) return 'bg-sky-600 text-white';
    if (t >= 0.5) return 'bg-sky-500 text-white';
    if (t >= 0.25) return 'bg-sky-300 text-sky-950';
    return 'bg-sky-100 text-sky-800';
  }

  function labelHour(hour: number) {
    const suffix = hour < 12 ? 'a' : 'p';
    const h12 = hour % 12 === 0 ? 12 : hour % 12;
    return `${h12}${suffix}`;
  }

  return (
    <div>
      <div className="mb-2 flex items-center justify-between gap-2 text-[11px] text-muted-foreground">
        <span>IST · 24h pattern</span>
        <span>
          {peak && peak.count > 0
            ? `Peak ${labelHour(peak.hour)} · ${peak.count}`
            : 'No peak yet'}
        </span>
      </div>
      <div className="grid grid-cols-8 gap-1 sm:grid-cols-12">
        {hours.map((row) => (
          <div
            key={row.hour}
            title={`${String(row.hour).padStart(2, '0')}:00 — ${row.count} clicks`}
            className={cn(
              'flex aspect-square flex-col items-center justify-center rounded-md text-[10px] font-medium tabular-nums',
              cellColor(row.count),
            )}
          >
            <span className="leading-none opacity-80">{labelHour(row.hour)}</span>
            <span className="mt-0.5 leading-none">{row.count || '·'}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function LineChart({ points }: { points: Array<{ date: string; count: number }> }) {
  const gradientId = useId();
  const width = 720;
  const height = 220;
  const pad = { top: 16, right: 12, bottom: 34, left: 36 };
  const max = Math.max(1, ...points.map((p) => p.count));
  const innerW = width - pad.left - pad.right;
  const innerH = height - pad.top - pad.bottom;

  if (points.length === 0) {
    return (
      <div className="flex h-48 items-center justify-center rounded-lg border border-dashed border-border bg-muted/20">
        <p className="text-sm text-muted-foreground">No clicks in this range</p>
      </div>
    );
  }

  const coords = points.map((p, i) => {
    const x =
      points.length === 1
        ? pad.left + innerW / 2
        : pad.left + (i / (points.length - 1)) * innerW;
    const y = pad.top + innerH - (p.count / max) * innerH;
    return { ...p, x, y };
  });
  const line = coords.map((c, i) => `${i === 0 ? 'M' : 'L'} ${c.x} ${c.y}`).join(' ');
  const area = `${line} L ${coords[coords.length - 1]!.x} ${pad.top + innerH} L ${coords[0]!.x} ${pad.top + innerH} Z`;
  const labelEvery = Math.max(1, Math.ceil(points.length / 7));

  return (
    <svg viewBox={`0 0 ${width} ${height}`} className="h-52 w-full">
      <defs>
        <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="oklch(0.55 0.14 255)" stopOpacity="0.28" />
          <stop offset="100%" stopColor="oklch(0.55 0.14 255)" stopOpacity="0.02" />
        </linearGradient>
      </defs>
      {[0, 0.25, 0.5, 0.75, 1].map((t) => {
        const y = pad.top + innerH - t * innerH;
        return (
          <g key={t}>
            <line
              x1={pad.left}
              x2={width - pad.right}
              y1={y}
              y2={y}
              stroke="oklch(0.9 0.01 250)"
              strokeDasharray="4 4"
            />
            <text
              x={pad.left - 10}
              y={y + 3}
              textAnchor="end"
              fill="oklch(0.5 0.02 260)"
              fontSize="10"
            >
              {Math.round(max * t)}
            </text>
          </g>
        );
      })}
      <path d={area} fill={`url(#${gradientId})`} />
      <path
        d={line}
        fill="none"
        stroke="oklch(0.5 0.14 255)"
        strokeWidth="2.5"
        strokeLinejoin="round"
        strokeLinecap="round"
      />
      {coords.map((c) => (
        <g key={c.date}>
          <title>
            {c.date}: {c.count} clicks
          </title>
          <circle cx={c.x} cy={c.y} r="3.5" fill="oklch(0.5 0.14 255)" />
          <circle cx={c.x} cy={c.y} r="7" fill="oklch(0.5 0.14 255)" fillOpacity="0.12" />
        </g>
      ))}
      {coords.map((c, i) =>
        i % labelEvery === 0 || i === coords.length - 1 ? (
          <text
            key={`label-${c.date}`}
            x={c.x}
            y={height - 14}
            textAnchor="middle"
            fill="oklch(0.5 0.02 260)"
            fontSize="10"
          >
            {c.date.slice(5)}
          </text>
        ) : null,
      )}
    </svg>
  );
}

function ServiceBars({
  rows,
}: {
  rows: Array<{ key: string; label: string; count: number }>;
}) {
  const max = Math.max(1, ...rows.map((r) => r.count));
  const total = rows.reduce((sum, row) => sum + row.count, 0) || 1;
  if (rows.length === 0) {
    return (
      <div className="flex h-56 items-center justify-center rounded-lg border border-dashed border-border bg-muted/20">
        <p className="text-sm text-muted-foreground">No service activity yet</p>
      </div>
    );
  }
  return (
    <div className="space-y-3">
      {rows.map((row, index) => {
        const pct = Math.round((row.count / max) * 100);
        const share = Math.round((row.count / total) * 100);
        const color = SERVICE_COLORS[index % SERVICE_COLORS.length]!;
        return (
          <div key={row.key} className="group">
            <div className="mb-1.5 flex items-center justify-between gap-3 text-sm">
              <div className="flex min-w-0 items-center gap-2">
                <span
                  className="h-2.5 w-2.5 shrink-0 rounded-sm"
                  style={{ backgroundColor: color }}
                />
                <span className="truncate font-medium">{row.label}</span>
              </div>
              <div className="shrink-0 tabular-nums text-muted-foreground">
                <span className="font-medium text-foreground">{row.count}</span>
                <span className="ml-2 text-xs">{share}%</span>
              </div>
            </div>
            <div className="h-2.5 overflow-hidden rounded-md bg-slate-100">
              <div
                className="h-full rounded-md transition-all duration-500"
                style={{ width: `${pct}%`, backgroundColor: color }}
              />
            </div>
          </div>
        );
      })}
    </div>
  );
}

function DonutChart({
  rows,
}: {
  rows: Array<{ key: string; label: string; count: number }>;
}) {
  const total = rows.reduce((sum, row) => sum + row.count, 0);
  const size = 168;
  const stroke = 22;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  if (total === 0) {
    return (
      <div className="flex h-44 items-center justify-center">
        <div className="text-center">
          <div className="mx-auto mb-2 flex h-24 w-24 items-center justify-center rounded-full border-[10px] border-slate-100 text-sm text-muted-foreground">
            0
          </div>
          <p className="text-xs text-muted-foreground">No distribution</p>
        </div>
      </div>
    );
  }

  let offset = 0;
  return (
    <div className="flex flex-col items-center gap-4 sm:flex-row sm:items-start">
      <svg viewBox={`0 0 ${size} ${size}`} className="h-40 w-40 shrink-0">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="oklch(0.94 0.008 250)"
          strokeWidth={stroke}
        />
        {rows.map((row, index) => {
          const portion = row.count / total;
          const dash = portion * circumference;
          const circle = (
            <circle
              key={row.key}
              cx={size / 2}
              cy={size / 2}
              r={radius}
              fill="none"
              stroke={SERVICE_COLORS[index % SERVICE_COLORS.length]}
              strokeWidth={stroke}
              strokeDasharray={`${dash} ${circumference - dash}`}
              strokeDashoffset={-offset}
              strokeLinecap="butt"
              transform={`rotate(-90 ${size / 2} ${size / 2})`}
            >
              <title>
                {row.label}: {row.count}
              </title>
            </circle>
          );
          offset += dash;
          return circle;
        })}
        <text
          x="50%"
          y="48%"
          textAnchor="middle"
          className="fill-foreground"
          fontSize="22"
          fontWeight="600"
        >
          {total}
        </text>
        <text
          x="50%"
          y="60%"
          textAnchor="middle"
          fill="oklch(0.5 0.02 260)"
          fontSize="10"
        >
          clicks
        </text>
      </svg>
      <div className="min-w-0 flex-1 space-y-2">
        {rows.slice(0, 6).map((row, index) => (
          <div key={row.key} className="flex items-center justify-between gap-2 text-xs">
            <div className="flex min-w-0 items-center gap-2">
              <span
                className="h-2.5 w-2.5 shrink-0 rounded-sm"
                style={{ backgroundColor: SERVICE_COLORS[index % SERVICE_COLORS.length] }}
              />
              <span className="truncate">{row.label}</span>
            </div>
            <span className="tabular-nums text-muted-foreground">
              {Math.round((row.count / total) * 100)}%
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

export function UsagePage() {
  const { token } = useAuth();
  const initialRange = rangeForPreset('30');

  const [devices, setDevices] = useState<DeviceOption[]>([]);
  const [deviceId, setDeviceId] = useState('');
  const [rangePreset, setRangePreset] = useState<UsageRangePreset>('30');
  const [fromLocal, setFromLocal] = useState(initialRange.fromLocal);
  const [toLocal, setToLocal] = useState(initialRange.toLocal);
  const [fromIso, setFromIso] = useState(initialRange.fromIso);
  const [toIso, setToIso] = useState(initialRange.toIso);

  const [detail, setDetail] = useState<DeviceUsageResponse | null>(null);
  const [fleet, setFleet] = useState<FleetResponse | null>(null);
  const [payments, setPayments] = useState<PaymentsSummary | null>(null);
  const [prints, setPrints] = useState<PrintSummary | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [fleetLoading, setFleetLoading] = useState(false);
  const [overlayLoading, setOverlayLoading] = useState(false);

  const [usageSearch, setUsageSearch] = useState('');
  const [usageServiceFilter, setUsageServiceFilter] = useState('all');
  const [usageSort, setUsageSort] = useState<UsageSort>('clicks_desc');
  const [usageHideZero, setUsageHideZero] = useState(true);

  const selectedDevice = devices.find((d) => d.id === deviceId) ?? null;

  useEffect(() => {
    void (async () => {
      try {
        const result = await apiRequest<{ items: DeviceOption[] }>('/devices', { token });
        setDevices(result.items);
        setDeviceId((current) => current || result.items[0]?.id || '');
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load kiosks');
      }
    })();
  }, [token]);

  const applyPreset = useCallback((preset: Exclude<UsageRangePreset, 'custom'>) => {
    const range = rangeForPreset(preset);
    setRangePreset(preset);
    setFromLocal(range.fromLocal);
    setToLocal(range.toLocal);
    setFromIso(range.fromIso);
    setToIso(range.toIso);
  }, []);

  const applyCustomRange = useCallback(() => {
    const from = fromDatetimeLocalValue(fromLocal);
    const to = fromDatetimeLocalValue(toLocal);
    if (!from || !to) {
      setError('Pick a valid from/to date and time');
      return;
    }
    if (from > to) {
      setError('From must be before To');
      return;
    }
    setError(null);
    setRangePreset('custom');
    setFromIso(from.toISOString());
    setToIso(to.toISOString());
  }, [fromLocal, toLocal]);

  const loadFleet = useCallback(async () => {
    setFleetLoading(true);
    try {
      const params = new URLSearchParams({ from: fromIso, to: toIso });
      const result = await apiRequest<FleetResponse>(`/service-analytics?${params}`, {
        token,
      });
      setFleet(result);
    } catch (err) {
      setFleet(null);
      setError(err instanceof Error ? err.message : 'Failed to load fleet ranking');
    } finally {
      setFleetLoading(false);
    }
  }, [token, fromIso, toIso]);

  const loadDetail = useCallback(async () => {
    if (!deviceId) {
      setDetail(null);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ from: fromIso, to: toIso });
      const result = await apiRequest<DeviceUsageResponse>(
        `/devices/${deviceId}/service-analytics?${params}`,
        { token },
      );
      setDetail(result);
    } catch (err) {
      setDetail(null);
      setError(err instanceof Error ? err.message : 'Failed to load usage');
    } finally {
      setLoading(false);
    }
  }, [token, deviceId, fromIso, toIso]);

  const loadOverlays = useCallback(async () => {
    if (!deviceId) {
      setPayments(null);
      setPrints(null);
      return;
    }
    setOverlayLoading(true);
    const from = toDateOnly(fromIso);
    const to = toDateOnly(toIso);
    const params = new URLSearchParams({ deviceId, from, to });
    try {
      const [pay, print] = await Promise.all([
        apiRequest<PaymentsSummary>(`/payments/summary?${params}`, { token }),
        apiRequest<PrintSummary>(`/print-jobs/summary?${params}`, { token }),
      ]);
      setPayments(pay);
      setPrints(print);
    } catch {
      setPayments(null);
      setPrints(null);
    } finally {
      setOverlayLoading(false);
    }
  }, [token, deviceId, fromIso, toIso]);

  const refreshAll = useCallback(async () => {
    await Promise.all([loadDetail(), loadFleet(), loadOverlays()]);
  }, [loadDetail, loadFleet, loadOverlays]);

  useEffect(() => {
    void loadDetail();
  }, [loadDetail]);

  useEffect(() => {
    void loadFleet();
  }, [loadFleet]);

  useEffect(() => {
    void loadOverlays();
  }, [loadOverlays]);

  const usageRows = useMemo(
    () => (detail ? buildUsageRows(detail.items) : []),
    [detail],
  );
  const filteredUsageRows = useMemo(
    () =>
      filterUsageRows(usageRows, {
        service: usageServiceFilter,
        search: usageSearch,
        hideZero: usageHideZero,
        sort: usageSort,
      }),
    [usageRows, usageServiceFilter, usageSearch, usageHideZero, usageSort],
  );
  const usageStats = useMemo(() => usageSummary(usageRows), [usageRows]);
  const usageMaxCount = useMemo(
    () => filteredUsageRows.reduce((max, row) => Math.max(max, row.count), 0),
    [filteredUsageRows],
  );

  const parentBars = useMemo(() => {
    return usageRows
      .filter((row) => row.depth === 0 && row.count > 0)
      .sort((a, b) => b.count - a.count)
      .slice(0, 8);
  }, [usageRows]);

  const daily = detail?.daily ?? [];
  const hourly = detail?.hourly ?? Array.from({ length: 24 }, (_, hour) => ({ hour, count: 0 }));
  const totalClicks = detail?.totalClicks ?? usageStats.totalClicks;
  const avgPerDay =
    daily.length > 0 ? Math.round((totalClicks / daily.length) * 10) / 10 : 0;
  const peakDay = daily.reduce<{ date: string; count: number } | null>(
    (best, row) => (!best || row.count > best.count ? row : best),
    null,
  );
  const topLabel = detail?.topEventKey
    ? labelForEventKey(detail.topEventKey)
    : usageStats.top && usageStats.top.count > 0
      ? usageStats.top.label
      : '—';
  const topCount = detail?.topEventCount ?? usageStats.top?.count ?? 0;
  const clicksDeltaPct = detail?.comparison?.totalClicksDeltaPct ?? null;
  const activeDeltaPct = detail?.comparison?.uniqueServicesDeltaPct ?? null;
  const fleetMax = Math.max(1, ...(fleet?.items.map((item) => item.totalClicks) ?? [0]));
  const fleetRank =
    fleet?.items.findIndex((item) => item.deviceId === deviceId) ?? -1;
  const deadServices = useMemo(
    () => usageRows.filter((row) => row.depth === 0 && row.count === 0),
    [usageRows],
  );
  const idleKiosks = fleet?.idleKiosks ?? [];
  const sites = fleet?.sites ?? [];
  const siteMax = Math.max(1, ...sites.map((site) => site.totalClicks));

  function onDownload() {
    if (!detail || !selectedDevice) return;
    const stamp = new Date().toISOString().slice(0, 10);
    const slug = selectedDevice.name.replace(/\s+/g, '-').toLowerCase();
    downloadCsv(`usage-${slug}-services-${stamp}.csv`, [
      ['kiosk', 'site', 'from', 'to', 'service_key', 'label', 'depth', 'clicks'],
      ...filteredUsageRows.map((row) => [
        selectedDevice.name,
        selectedDevice.siteName,
        detail.from,
        detail.to,
        row.key,
        row.label,
        String(row.depth),
        String(row.count),
      ]),
    ]);
    downloadCsv(`usage-${slug}-daily-${stamp}.csv`, [
      ['kiosk', 'date', 'clicks'],
      ...daily.map((row) => [selectedDevice.name, row.date, String(row.count)]),
    ]);
  }

  return (
    <div className="pb-2">
      <PageHeader
        title="Usage analytics"
        subtitle="Fleet, payments, prints, hourly patterns, and export"
        actions={
          <>
            <Button
              type="button"
              variant="secondary"
              disabled={!detail || loading}
              onClick={onDownload}
              className="h-8 gap-1.5 px-2.5"
            >
              <Download className="h-3.5 w-3.5" />
              Export
            </Button>
            <Button
              type="button"
              variant="secondary"
              disabled={loading || fleetLoading || overlayLoading}
              onClick={() => void refreshAll()}
              className="h-8 gap-1.5 px-2.5"
            >
              <RefreshCw
                className={cn(
                  'h-3.5 w-3.5',
                  (loading || fleetLoading || overlayLoading) && 'animate-spin',
                )}
              />
              Refresh
            </Button>
          </>
        }
      />

      <div className="mb-3 rounded-lg border border-border bg-card px-3 py-2.5">
        <div className="flex flex-col gap-2.5 lg:flex-row lg:items-center">
          <Select
            aria-label="Select kiosk"
            value={deviceId}
            onChange={(e) => setDeviceId(e.target.value)}
            disabled={devices.length === 0}
            className="h-8 w-full max-w-none border-sky-200 bg-sky-50/50 text-sm font-medium lg:max-w-64"
          >
            {devices.length === 0 ? <option value="">No kiosks</option> : null}
            {devices.map((device) => (
              <option key={device.id} value={device.id}>
                {device.name}
                {device.siteName ? ` · ${device.siteName}` : ''}
              </option>
            ))}
          </Select>

          <div className="flex min-w-0 flex-1 flex-wrap items-center gap-2">
            <FilterChips
              options={USAGE_RANGE_FILTERS}
              value={rangePreset}
              onChange={(value) => {
                const preset = value as UsageRangePreset;
                if (preset === 'custom') {
                  setRangePreset('custom');
                  return;
                }
                applyPreset(preset);
              }}
            />
            {rangePreset !== 'custom' ? (
              <span className="inline-flex items-center gap-1.5 text-[11px] text-muted-foreground">
                <CalendarRange className="h-3 w-3" />
                {formatRangeLabel(fromIso, toIso)}
                {selectedDevice ? (
                  <>
                    <span className="text-border">·</span>
                    <StatusBadge status={selectedDevice.status} />
                  </>
                ) : null}
              </span>
            ) : null}
          </div>
        </div>

        {rangePreset === 'custom' ? (
          <div className="mt-2 flex flex-col gap-2 border-t border-border/70 pt-2 sm:flex-row sm:items-end">
            <label className="min-w-0 flex-1 space-y-1 text-[11px] text-muted-foreground">
              From
              <Input
                type="datetime-local"
                value={fromLocal}
                disabled={loading}
                onChange={(e) => setFromLocal(e.target.value)}
                className="h-8"
              />
            </label>
            <label className="min-w-0 flex-1 space-y-1 text-[11px] text-muted-foreground">
              To
              <Input
                type="datetime-local"
                value={toLocal}
                disabled={loading}
                onChange={(e) => setToLocal(e.target.value)}
                className="h-8"
              />
            </label>
            <Button
              type="button"
              variant="secondary"
              className="h-8 px-3"
              disabled={loading}
              onClick={applyCustomRange}
            >
              Apply
            </Button>
          </div>
        ) : null}
      </div>

      {error ? <p className="error mb-3">{error}</p> : null}

      {!deviceId ? (
        <EmptyState title="Select a kiosk" description="Choose a kiosk above to load usage." />
      ) : (
        <>
          {idleKiosks.length > 0 ? (
            <div className="mb-3 rounded-lg border border-amber-200 bg-amber-50/70 px-3 py-2 text-sm text-amber-950">
              <span className="font-medium">
                {idleKiosks.length} idle kiosk{idleKiosks.length === 1 ? '' : 's'}
              </span>
              <span className="text-amber-800/80"> — no clicks in this range: </span>
              <span className="text-amber-900">
                {idleKiosks
                  .slice(0, 4)
                  .map((k) => k.name)
                  .join(', ')}
                {idleKiosks.length > 4 ? ` +${idleKiosks.length - 4} more` : ''}
              </span>
            </div>
          ) : null}

          <div className="mb-3 grid gap-2 sm:grid-cols-2 xl:grid-cols-5">
            <MetricCard
              label="Total clicks"
              value={String(totalClicks)}
              hint="vs prior"
              deltaPct={clicksDeltaPct}
              icon={MousePointerClick}
              tone="primary"
            />
            <MetricCard
              label="Active"
              value={`${usageStats.active}/${usageRows.length || 0}`}
              hint="services"
              deltaPct={activeDeltaPct}
              icon={Activity}
              tone="success"
            />
            <MetricCard
              label="Avg / day"
              value={String(avgPerDay)}
              hint={`${daily.length}d`}
              icon={TrendingUp}
              tone="slate"
            />
            <MetricCard
              label="Peak"
              value={peakDay && peakDay.count > 0 ? String(peakDay.count) : '—'}
              hint={peakDay && peakDay.count > 0 ? peakDay.date.slice(5) : undefined}
              icon={Sparkles}
              tone="warning"
            />
            <MetricCard
              label="Top"
              value={topCount > 0 ? String(topCount) : '—'}
              hint={
                fleetRank >= 0
                  ? `#${fleetRank + 1} fleet · ${topLabel !== '—' ? topLabel : '—'}`
                  : topLabel !== '—'
                    ? topLabel
                    : undefined
              }
              icon={Activity}
              tone="primary"
            />
          </div>

          <div className="mb-3 grid gap-2 sm:grid-cols-2 xl:grid-cols-4">
            <MetricCard
              label="Revenue"
              value={payments ? rupees(payments.totalPaidPaise) : overlayLoading ? '…' : '—'}
              hint={payments ? `${payments.paidCount} paid` : 'payments'}
              icon={IndianRupee}
              tone="success"
            />
            <MetricCard
              label="Payment intents"
              value={payments ? String(payments.totalCount) : overlayLoading ? '…' : '—'}
              hint={
                payments
                  ? `${payments.freePages ?? 0} free · ${payments.paidPages ?? 0} paid pg`
                  : undefined
              }
              icon={CreditCard}
              tone="primary"
            />
            <MetricCard
              label="Print jobs"
              value={prints ? String(prints.jobs) : overlayLoading ? '…' : '—'}
              hint={
                prints
                  ? `${prints.freeJobs} free · ${prints.paidJobs} paid`
                  : undefined
              }
              icon={Printer}
              tone="slate"
            />
            <MetricCard
              label="Pages printed"
              value={prints ? String(prints.pages) : overlayLoading ? '…' : '—'}
              hint={
                prints
                  ? `${prints.freePages} free · ${prints.paidPages} paid`
                  : undefined
              }
              icon={Printer}
              tone="warning"
            />
          </div>

          <div className="mb-4 grid gap-4 xl:grid-cols-[1.1fr_1fr_0.9fr]">
            <Panel
              title="Fleet ranking"
              className="mb-0"
              actions={
                <span className="text-xs text-muted-foreground">
                  {fleet
                    ? `${fleet.activeKiosks}/${fleet.items.length} active · ${fleet.fleetTotalClicks} clicks`
                    : 'All kiosks'}
                </span>
              }
            >
              {fleetLoading && !fleet ? (
                <p className="muted py-6">Loading fleet…</p>
              ) : !fleet || fleet.items.length === 0 ? (
                <EmptyState title="No fleet data" description="No kiosks found for this range." />
              ) : (
                <div className="max-h-72 overflow-auto rounded-lg border border-border">
                  <table className="table w-full">
                    <thead>
                      <tr className="bg-slate-50/90">
                        <th className="w-12">#</th>
                        <th>Kiosk</th>
                        <th className="w-[36%]">Share</th>
                        <th className="w-24 text-right">Clicks</th>
                      </tr>
                    </thead>
                    <tbody>
                      {fleet.items.map((item, index) => {
                        const share = (item.totalClicks / fleetMax) * 100;
                        const selected = item.deviceId === deviceId;
                        return (
                          <tr
                            key={item.deviceId}
                            className={cn(
                              'cursor-pointer transition-colors',
                              selected ? 'bg-sky-50' : 'hover:bg-slate-50/80',
                            )}
                            onClick={() => setDeviceId(item.deviceId)}
                          >
                            <td className="tabular-nums text-muted-foreground">{index + 1}</td>
                            <td>
                              <div className="font-medium">{item.name}</div>
                              <div className="mt-0.5 flex items-center gap-1.5 text-[11px] text-muted-foreground">
                                {item.siteName ? <span>{item.siteName}</span> : null}
                                <StatusBadge status={item.status} />
                              </div>
                            </td>
                            <td>
                              <div className="h-2 overflow-hidden rounded-md bg-slate-100">
                                <div
                                  className="h-full rounded-md bg-sky-500/80"
                                  style={{ width: `${share}%` }}
                                />
                              </div>
                            </td>
                            <td className="text-right text-sm font-semibold tabular-nums">
                              {item.totalClicks}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </Panel>

            <Panel
              title="Hour of day"
              className="mb-0"
              actions={
                <span className="text-xs text-muted-foreground">When people use it</span>
              }
            >
              {loading ? (
                <div className="flex h-40 items-center justify-center text-sm text-muted-foreground">
                  Loading heatmap…
                </div>
              ) : (
                <HourHeatmap hours={hourly} />
              )}
            </Panel>

            <Panel
              title="Sites"
              className="mb-0"
              actions={
                <span className="text-xs text-muted-foreground">
                  {sites.length ? `${sites.length} sites` : 'Rollup'}
                </span>
              }
            >
              {fleetLoading && sites.length === 0 ? (
                <p className="muted py-6">Loading sites…</p>
              ) : sites.length === 0 ? (
                <EmptyState title="No sites" description="Sites appear once kiosks are assigned." />
              ) : (
                <div className="max-h-72 space-y-2.5 overflow-auto pr-1">
                  {sites.map((site) => {
                    const share = (site.totalClicks / siteMax) * 100;
                    return (
                      <div key={site.siteName}>
                        <div className="mb-1 flex items-center justify-between gap-2 text-sm">
                          <span className="truncate font-medium">{site.siteName}</span>
                          <span className="shrink-0 tabular-nums text-muted-foreground">
                            {site.totalClicks}
                            <span className="ml-1.5 text-[11px]">
                              {site.activeKiosks}/{site.kiosks}
                            </span>
                          </span>
                        </div>
                        <div className="h-2 overflow-hidden rounded-md bg-slate-100">
                          <div
                            className="h-full rounded-md bg-emerald-500/80"
                            style={{ width: `${share}%` }}
                          />
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </Panel>
          </div>

          <div className="mb-4 grid gap-4 md:grid-cols-2">
            <Panel
              title="Dead services"
              className="mb-0"
              actions={
                <span className="text-xs text-muted-foreground">
                  {deadServices.length} with 0 clicks
                </span>
              }
            >
              {loading ? (
                <p className="muted py-4">Loading…</p>
              ) : deadServices.length === 0 ? (
                <p className="text-sm text-muted-foreground">
                  All home services had traffic in this range.
                </p>
              ) : (
                <div className="flex flex-wrap gap-1.5">
                  {deadServices.map((row) => (
                    <span
                      key={row.key}
                      className="rounded-md border border-rose-200 bg-rose-50 px-2 py-1 text-xs font-medium text-rose-800"
                    >
                      {row.label}
                    </span>
                  ))}
                </div>
              )}
            </Panel>

            <Panel
              title="Idle kiosks"
              className="mb-0"
              actions={
                <span className="text-xs text-muted-foreground">
                  {idleKiosks.length} zero traffic
                </span>
              }
            >
              {fleetLoading && !fleet ? (
                <p className="muted py-4">Loading…</p>
              ) : idleKiosks.length === 0 ? (
                <p className="text-sm text-muted-foreground">
                  Every kiosk had at least one click in this range.
                </p>
              ) : (
                <div className="max-h-40 space-y-1 overflow-auto">
                  {idleKiosks.map((kiosk) => (
                    <button
                      key={kiosk.deviceId}
                      type="button"
                      className={cn(
                        'flex w-full items-center justify-between gap-2 rounded-md px-2 py-1.5 text-left text-sm transition-colors',
                        kiosk.deviceId === deviceId
                          ? 'bg-amber-100'
                          : 'hover:bg-amber-50',
                      )}
                      onClick={() => setDeviceId(kiosk.deviceId)}
                    >
                      <span className="truncate font-medium">{kiosk.name}</span>
                      <span className="shrink-0 text-[11px] text-muted-foreground">
                        {kiosk.siteName ?? '—'}
                      </span>
                    </button>
                  ))}
                </div>
              )}
            </Panel>
          </div>

          <div className="mb-5 grid gap-4 xl:grid-cols-[1.35fr_1fr_0.95fr]">
            <Panel
              title="Engagement trend"
              className="mb-0"
              actions={
                <span className="text-xs text-muted-foreground">Daily clicks</span>
              }
            >
              {loading ? (
                <div className="flex h-52 items-center justify-center text-sm text-muted-foreground">
                  Loading chart…
                </div>
              ) : (
                <LineChart points={daily} />
              )}
            </Panel>

            <Panel
              title="Top services"
              className="mb-0"
              actions={
                <span className="text-xs text-muted-foreground">By clicks</span>
              }
            >
              {loading ? (
                <div className="flex h-64 items-center justify-center text-sm text-muted-foreground">
                  Loading…
                </div>
              ) : (
                <ServiceBars rows={parentBars} />
              )}
            </Panel>

            <Panel
              title="Mix"
              className="mb-0"
              actions={
                <span className="text-xs text-muted-foreground">Share</span>
              }
            >
              {loading ? (
                <div className="flex h-64 items-center justify-center text-sm text-muted-foreground">
                  Loading…
                </div>
              ) : (
                <DonutChart rows={parentBars} />
              )}
            </Panel>
          </div>

          <Panel
            title="Service breakdown"
            actions={
              <span className="hidden text-xs text-muted-foreground sm:inline">
                {selectedDevice?.name}
                {selectedDevice?.siteName ? ` · ${selectedDevice.siteName}` : ''}
              </span>
            }
          >
            <div className="mb-4 flex flex-col gap-2 rounded-lg border border-border/80 bg-slate-50/70 p-3 sm:flex-row sm:flex-wrap sm:items-center">
              <Input
                value={usageSearch}
                onChange={(e) => setUsageSearch(e.target.value)}
                placeholder="Search service or option"
                aria-label="Search usage"
                className="h-9 w-full border-border bg-card sm:max-w-xs"
              />
              <Select
                aria-label="Filter by service"
                value={usageServiceFilter}
                onChange={(e) => setUsageServiceFilter(e.target.value)}
                className="h-9 sm:min-w-[10rem]"
              >
                {USAGE_SERVICE_FILTERS.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </Select>
              <Select
                aria-label="Sort usage"
                value={usageSort}
                onChange={(e) => setUsageSort(e.target.value as UsageSort)}
                className="h-9 sm:min-w-[9.5rem]"
              >
                {USAGE_SORT_FILTERS.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </Select>
              <FilterChips
                options={[
                  { value: 'all', label: 'Show all' },
                  { value: 'active', label: 'With clicks' },
                ]}
                value={usageHideZero ? 'active' : 'all'}
                onChange={(value) => setUsageHideZero(value === 'active')}
              />
            </div>

            {loading ? (
              <p className="muted py-8">Loading usage…</p>
            ) : usageRows.length === 0 ? (
              <EmptyState
                title="No service clicks yet"
                description="Counts appear after visitors open services on this kiosk."
              />
            ) : filteredUsageRows.length === 0 ? (
              <EmptyState
                title="No matches"
                description="Adjust search, service, sort, or show all rows."
              />
            ) : (
              <div className="overflow-hidden rounded-xl border border-border">
                <table className="table w-full">
                  <thead>
                    <tr className="bg-slate-50/90">
                      <th>Service / option</th>
                      <th className="w-[44%]">Share of max</th>
                      <th className="w-28 text-right">Clicks</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredUsageRows.map((row, index) => {
                      const share = usageMaxCount > 0 ? (row.count / usageMaxCount) * 100 : 0;
                      const pctOfTotal =
                        usageStats.totalClicks > 0
                          ? Math.round((row.count / usageStats.totalClicks) * 100)
                          : 0;
                      const color =
                        SERVICE_COLORS[
                          Math.max(
                            0,
                            parentBars.findIndex((p) => row.key === p.key || row.key.startsWith(p.key.split('.')[0] + '.')),
                          ) % SERVICE_COLORS.length
                        ] ?? SERVICE_COLORS[index % SERVICE_COLORS.length]!;
                      return (
                        <tr
                          key={row.key}
                          className={cn(
                            row.depth === 0 ? 'bg-sky-50/40' : 'bg-card',
                            'border-border/60',
                          )}
                        >
                          <td
                            className={
                              row.depth === 1
                                ? 'border-l-2 border-sky-200 pl-7 text-sm text-muted-foreground'
                                : 'font-semibold text-foreground'
                            }
                          >
                            {row.label}
                          </td>
                          <td>
                            <div className="flex items-center gap-3">
                              <div className="h-2.5 min-w-0 flex-1 overflow-hidden rounded-md bg-slate-100">
                                <div
                                  className="h-full rounded-md transition-all"
                                  style={{
                                    width: `${share}%`,
                                    backgroundColor:
                                      row.depth === 0 ? color : 'oklch(0.72 0.08 255)',
                                  }}
                                />
                              </div>
                              <span className="w-10 shrink-0 text-right text-xs tabular-nums text-muted-foreground">
                                {pctOfTotal}%
                              </span>
                            </div>
                          </td>
                          <td className="text-right text-sm font-semibold tabular-nums text-foreground">
                            {row.count}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </Panel>
        </>
      )}
    </div>
  );
}

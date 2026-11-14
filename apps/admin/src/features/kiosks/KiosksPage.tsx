import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import {
  BarChart3,
  CloudUpload,
  MoreHorizontal,
  PauseCircle,
  Pencil,
  ScrollText,
  Settings,
  Video,
  VideoOff,
  AlertTriangle,
} from 'lucide-react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  EmptyState,
  FilterChips,
  Input,
  Modal,
  PageHeader,
  Panel,
  Select,
  StatusBadge,
  Toolbar,
} from '../../core/ui/primitives';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Button as UiButton } from '@/components/ui/button';
import {
  hasPrinterDuplex,
  hasPrinterParts,
  hasPrinterRefill,
  resolvePrinterErrorHistory,
  resolvePrinterMaintenance,
  resolvePrinterRowSummary,
  resolvePrinterStatus,
  type PrinterHealthView,
} from './printerMaintenance';
import {
  buildUsageRows,
  filterUsageRows,
  fromDatetimeLocalValue,
  rangeForPreset,
  usageSummary,
  USAGE_RANGE_FILTERS,
  USAGE_SERVICE_FILTERS,
  type ServiceAnalyticsItem,
  type UsageRangePreset,
  type UsageRow,
} from './serviceUsage';
import {
  resolveRecordingDisplay,
  type SurveillanceHealth,
} from '../surveillance/surveillanceStatus';

type DiagnosticLogItem = {
  id: string;
  occurredAt: string;
  level: string;
  category: string;
  event: string;
  message: string;
  correlationId: string | null;
  metadata: unknown;
};

type Device = {
  id: string;
  name: string;
  deviceKey: string;
  status: string;
  siteName: string;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  lastHeartbeatAt: string | null;
  surveillanceEnabled: boolean;
  surveillanceHealth?: SurveillanceHealth | null;
  surveillanceHealthAt?: string | null;
  printerHealth?: PrinterHealthView | null;
  printerHealthAt?: string | null;
  printerRefreshRequestedAt?: string | null;
  printingPausedReason?: string | null;
  maxPagesPerSession: number;
  freePagesPerSession: number;
  extraPageChargeRupees: number;
  freeColorPagesPerSession: number;
  extraColorPageChargeRupees: number;
  kundaliColorPrintChargeRupees: number;
  freeDisabledFromLocal?: string | null;
  freeDisabledToLocal?: string | null;
  bannerHorizontalEnabled?: boolean;
  bannerVerticalEnabled?: boolean;
  pagesLeft?: number | null;
  trayReserved?: number | null;
  trayAvailable?: number | null;
};

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

const PRINTER_ROW_TONE: Record<string, string> = {
  muted: 'text-muted-foreground',
  ok: 'font-medium text-emerald-700',
  amber: 'font-medium text-amber-700',
  alert: 'font-medium text-red-700',
};

function pagesLeftBand(pagesLeft: number | null): 'muted' | 'low' | 'very-low' {
  if (pagesLeft == null || pagesLeft >= 100) return 'muted';
  if (pagesLeft < 50) return 'very-low';
  return 'low';
}

const PAGES_LEFT_FIGURE: Record<ReturnType<typeof pagesLeftBand>, string> = {
  muted: 'text-foreground',
  low: 'text-orange-700',
  'very-low': 'text-red-700',
};

const PAGES_LEFT_TILE: Record<ReturnType<typeof pagesLeftBand>, string> = {
  muted: 'bg-muted/40',
  low: 'border border-orange-200 bg-orange-50',
  'very-low': 'border border-red-200 bg-red-50',
};

const PAGES_LEFT_NOTE: Record<ReturnType<typeof pagesLeftBand>, string | null> = {
  muted: null,
  low: 'Low',
  'very-low': 'Very low',
};

function PrinterSummaryCell({
  device,
  onDetails,
}: {
  device: Device;
  onDetails: () => void;
}) {
  const summary = resolvePrinterRowSummary(device.printerHealth);
  const pagesLeft = device.pagesLeft == null ? '—' : String(device.pagesLeft);
  const available = device.trayAvailable == null ? null : String(device.trayAvailable);
  return (
    <div className="flex min-w-0 items-center gap-2 text-sm">
      <div className="min-w-0">
        <p className={PRINTER_ROW_TONE[summary.tone]}>{summary.label}</p>
        <p className="truncate text-xs text-muted-foreground">
          Left {pagesLeft}
          {available != null ? ` · Avail ${available}` : ''}
        </p>
      </div>
      <Button type="button" variant="secondary" className="h-7 shrink-0 px-2 text-xs" onClick={onDetails}>
        Details
      </Button>
    </div>
  );
}

type TonerColor = 'black' | 'cyan' | 'magenta' | 'yellow';

const TONER_TILE: Record<TonerColor, { wash: string; bar: string }> = {
  black: { wash: 'border-neutral-300 bg-neutral-100', bar: 'bg-neutral-900' },
  cyan: { wash: 'border-cyan-200 bg-cyan-50', bar: 'bg-cyan-500' },
  magenta: { wash: 'border-fuchsia-200 bg-fuchsia-50', bar: 'bg-fuchsia-500' },
  yellow: { wash: 'border-yellow-200 bg-yellow-50', bar: 'bg-yellow-400' },
};

function tonerPercent(value: string): number | null {
  const match = /^(\d{1,3})%$/.exec(value);
  if (!match) return null;
  const percent = Number(match[1]);
  return percent <= 100 ? percent : null;
}

function TonerTile({ label, value, color }: { label: string; value: string; color: TonerColor }) {
  const percent = tonerPercent(value);
  if (percent == null) {
    return (
      <div className="rounded-lg border border-border bg-muted/40 px-3 py-2">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="mt-0.5 text-sm font-medium">{value}</p>
      </div>
    );
  }
  const tone = TONER_TILE[color];
  return (
    <div className={`rounded-lg border px-3 py-2 ${tone.wash}`}>
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-0.5 text-sm font-medium text-foreground">{value}</p>
      <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-white/80">
        <div className={`h-full rounded-full ${tone.bar}`} style={{ width: `${percent}%` }} />
      </div>
    </div>
  );
}

function usbPagesTotal(health: PrinterHealthView | null | undefined) {
  const total = health?.maintenance?.pages?.total;
  return typeof total === 'number' ? total : null;
}

function PrinterDetailsBody({
  health,
  pagesLeft,
  trayReserved,
  trayAvailable,
  canEditTray,
  canClearOpen,
  trayInput,
  onTrayInput,
  trayError,
  traySaving,
  onSaveTray,
  clearOpenSaving,
  onClearOpen,
}: {
  health: PrinterHealthView | null | undefined;
  pagesLeft: number | null;
  trayReserved: number | null;
  trayAvailable: number | null;
  canEditTray: boolean;
  canClearOpen: boolean;
  trayInput: string;
  onTrayInput: (value: string) => void;
  trayError: string | null;
  traySaving: boolean;
  onSaveTray: (mode: 'add' | 'replace') => void;
  clearOpenSaving: boolean;
  onClearOpen: () => void;
}) {
  const maintenance = resolvePrinterMaintenance(health);
  const errors = resolvePrinterErrorHistory(health);
  const stale = maintenance.status === 'stale' || errors.status === 'stale';
  const staleTitle =
    (maintenance.status === 'stale' ? maintenance.title : undefined) ??
    (errors.status === 'stale' ? errors.title : undefined);

  const printerStatus = resolvePrinterStatus(health);
  const statusClass = printerStatus.fault
    ? health?.snmpOk === false
      ? 'font-medium text-amber-700'
      : 'font-medium text-red-700'
    : printerStatus.kind === 'ready' || printerStatus.kind === 'printing'
      ? 'font-medium text-emerald-700'
      : 'text-muted-foreground';

  const pagesReady = maintenance.status !== 'unavailable';
  const pagesLeftLabel = pagesLeft == null ? '—' : String(pagesLeft);
  const pagesBand = pagesLeftBand(pagesLeft);
  const availableBand = pagesLeftBand(trayAvailable);
  const trayBlocked = traySaving || usbPagesTotal(health) == null;
  const reservedBlocking =
    trayAvailable === 0 && pagesLeft != null && pagesLeft > 0 && (trayReserved ?? 0) > 0;

  return (
    <div className="flex flex-col gap-4 pr-1">
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-sm text-muted-foreground">Status</span>
        <span className={`text-sm ${statusClass}`}>{printerStatus.label}</span>
        {stale ? (
          <span className="text-sm font-medium text-amber-700" title={staleTitle}>
            Stale
          </span>
        ) : null}
      </div>

      <section className="rounded-xl border border-border p-3">
        <h3 className="mb-2 text-sm font-medium">Ink</h3>
        {maintenance.status === 'unavailable' ? (
          <p className="text-sm text-muted-foreground">Unavailable</p>
        ) : (
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            <TonerTile label="Black" value={maintenance.toner.black} color="black" />
            <TonerTile label="Cyan" value={maintenance.toner.cyan} color="cyan" />
            <TonerTile label="Magenta" value={maintenance.toner.magenta} color="magenta" />
            <TonerTile label="Yellow" value={maintenance.toner.yellow} color="yellow" />
          </div>
        )}
      </section>

      <section className="rounded-xl border border-border p-3">
        <h3 className="mb-2 text-sm font-medium">Pages</h3>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          <div className="rounded-lg bg-muted/40 px-3 py-3">
            <p className="text-xs text-muted-foreground">Total</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums">
              {pagesReady ? maintenance.pages.total : '—'}
            </p>
          </div>
          <div className={`rounded-lg px-3 py-3 ${PAGES_LEFT_TILE[pagesBand]}`}>
            <p className="text-xs text-muted-foreground">Pages left</p>
            <p className={`mt-1 text-2xl font-semibold tabular-nums ${PAGES_LEFT_FIGURE[pagesBand]}`}>
              {pagesLeftLabel}
            </p>
            {PAGES_LEFT_NOTE[pagesBand] ? (
              <p className={`text-xs font-medium ${PAGES_LEFT_FIGURE[pagesBand]}`}>{PAGES_LEFT_NOTE[pagesBand]}</p>
            ) : null}
          </div>
          <div className={`rounded-lg px-3 py-3 ${PAGES_LEFT_TILE[availableBand]}`}>
            <p className="text-xs text-muted-foreground">Available</p>
            <p className={`mt-1 text-2xl font-semibold tabular-nums ${PAGES_LEFT_FIGURE[availableBand]}`}>
              {trayAvailable == null ? '—' : String(trayAvailable)}
            </p>
            <p className="text-xs text-muted-foreground">
              Reserved {trayReserved == null ? '—' : String(trayReserved)}
            </p>
          </div>
        </div>
        {reservedBlocking ? (
          <p className="mt-2 text-sm text-amber-700">
            Open print jobs are reserving paper. Clear them to free Available.
          </p>
        ) : null}
        {pagesReady ? (
          <p className="mt-2 text-sm text-muted-foreground">
            Color {maintenance.pages.color} · Black and white {maintenance.pages.blackAndWhite}
          </p>
        ) : null}
        {canClearOpen ? (
          <div className="mt-3">
            <Button
              type="button"
              variant="secondary"
              disabled={clearOpenSaving}
              onClick={onClearOpen}
            >
              {clearOpenSaving ? 'Clearing…' : 'Clear open jobs'}
            </Button>
          </div>
        ) : null}
        {pagesReady && hasPrinterDuplex(health) ? (
          <p className="mt-1 text-sm text-muted-foreground">
            2-sided {maintenance.pages.duplexTotal} · Color {maintenance.pages.duplexColor} · B&W{' '}
            {maintenance.pages.duplexBlackAndWhite}
          </p>
        ) : null}

        {canEditTray ? (
          <div className="mt-3 rounded-lg border border-border p-3">
            <p className="mb-2 text-sm text-muted-foreground">
              Add keeps the leftover. Replace starts the tray over.
            </p>
            <Input
              type="number"
              min={1}
              max={2000}
              inputMode="numeric"
              placeholder="Pages to load"
              aria-label="Pages to load"
              value={trayInput}
              disabled={traySaving}
              onChange={(event) => onTrayInput(event.target.value)}
            />
            {usbPagesTotal(health) == null ? (
              <p className="mt-2 text-sm text-muted-foreground">
                The printer page total is not available yet.
              </p>
            ) : null}
            {trayError ? <p className="error mt-2">{trayError}</p> : null}
            <div className="mt-3 flex flex-wrap gap-2">
              <Button
                type="button"
                variant="secondary"
                disabled={trayBlocked}
                onClick={() => onSaveTray('add')}
              >
                Add to current
              </Button>
              <Button
                type="button"
                variant="secondary"
                disabled={trayBlocked}
                onClick={() => onSaveTray('replace')}
              >
                Replace tray
              </Button>
            </div>
          </div>
        ) : null}
      </section>

      {hasPrinterRefill(health) ? (
        <section className="rounded-xl border border-border p-3">
          <h3 className="mb-2 text-sm font-medium">Refill</h3>
          {maintenance.status === 'unavailable' ? (
            <p className="text-sm text-muted-foreground">Unavailable</p>
          ) : (
            <p className="text-sm text-muted-foreground">
              Black {maintenance.refill.black} · Cyan {maintenance.refill.cyan} · Magenta{' '}
              {maintenance.refill.magenta} · Yellow {maintenance.refill.yellow}
            </p>
          )}
        </section>
      ) : null}

      <section className="rounded-xl border border-border bg-muted/20 p-3">
        {hasPrinterParts(health) ? (
          <>
            <h3 className="mb-2 text-sm font-medium text-muted-foreground">Parts</h3>
            {maintenance.status === 'unavailable' ? (
              <p className="text-sm text-muted-foreground">Unavailable</p>
            ) : (
              <p className="text-sm">
                Belt {maintenance.parts.belt} · Fuser {maintenance.parts.fuser}
              </p>
            )}
          </>
        ) : null}
        <h3
          className={`mb-2 text-sm font-medium text-muted-foreground${hasPrinterParts(health) ? ' mt-3' : ''}`}
        >
          Errors
        </h3>
        {errors.status === 'unavailable' ? (
          <p className="text-sm text-muted-foreground">Unavailable</p>
        ) : errors.status === 'empty' || errors.entries.length === 0 ? (
          <p className="text-sm text-muted-foreground">No recorded errors</p>
        ) : (
          <ul className="space-y-1 text-sm">
            {errors.entries.map((entry) => (
              <li key={entry.index}>{entry.description}</li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function RecordingStatusCell({ device }: { device: Device }) {
  const display = resolveRecordingDisplay(device);
  const Icon =
    display.key === 'off'
      ? VideoOff
      : display.key === 'uploading'
        ? CloudUpload
        : display.key === 'paused_palm'
          ? PauseCircle
          : display.key === 'camera_error' || display.key === 'storage_low'
            ? AlertTriangle
            : Video;

  return (
    <span
      className={`inline-flex items-center gap-1.5 text-sm font-medium ${display.className}`}
      title={display.title}
    >
      <Icon className="h-4 w-4" />
      {display.label}
    </span>
  );
}

type PrintLimitsForm = {
  maxPagesPerSession: number;
  freePagesPerSession: number;
  extraPageChargeRupees: number;
  freeColorPagesPerSession: number;
  extraColorPageChargeRupees: number;
  kundaliColorPrintChargeRupees: number;
  freeDisabledFromLocal: string;
  freeDisabledToLocal: string;
  bannerHorizontalEnabled: boolean;
  bannerVerticalEnabled: boolean;
};

const DEFAULT_PRINT_LIMITS: PrintLimitsForm = {
  maxPagesPerSession: 10,
  freePagesPerSession: 5,
  extraPageChargeRupees: 10,
  freeColorPagesPerSession: 0,
  extraColorPageChargeRupees: 20,
  kundaliColorPrintChargeRupees: 0,
  freeDisabledFromLocal: '',
  freeDisabledToLocal: '',
  bannerHorizontalEnabled: true,
  bannerVerticalEnabled: true,
};

function printLimitsFromDevice(device: Device): PrintLimitsForm {
  return {
    maxPagesPerSession: device.maxPagesPerSession ?? DEFAULT_PRINT_LIMITS.maxPagesPerSession,
    freePagesPerSession: device.freePagesPerSession ?? DEFAULT_PRINT_LIMITS.freePagesPerSession,
    extraPageChargeRupees: device.extraPageChargeRupees ?? DEFAULT_PRINT_LIMITS.extraPageChargeRupees,
    freeColorPagesPerSession:
      device.freeColorPagesPerSession ?? DEFAULT_PRINT_LIMITS.freeColorPagesPerSession,
    extraColorPageChargeRupees:
      device.extraColorPageChargeRupees ?? DEFAULT_PRINT_LIMITS.extraColorPageChargeRupees,
    kundaliColorPrintChargeRupees:
      device.kundaliColorPrintChargeRupees ?? DEFAULT_PRINT_LIMITS.kundaliColorPrintChargeRupees,
    freeDisabledFromLocal: device.freeDisabledFromLocal ?? '',
    freeDisabledToLocal: device.freeDisabledToLocal ?? '',
    bannerHorizontalEnabled: device.bannerHorizontalEnabled !== false,
    bannerVerticalEnabled: device.bannerVerticalEnabled !== false,
  };
}

type CreatedCredentials = {
  name: string;
  deviceKey: string;
  deviceSecret: string;
};

function formatLocation(device: Device): string {
  if (device.address?.trim()) return device.address.trim();
  if (device.latitude != null && device.longitude != null) {
    return `${device.latitude.toFixed(5)}, ${device.longitude.toFixed(5)}`;
  }
  return '—';
}

const STATUS_FILTERS = [
  { value: 'all', label: 'All statuses' },
  { value: 'active', label: 'Active' },
  { value: 'provisioning', label: 'Provisioning' },
  { value: 'inactive', label: 'Inactive' },
];

const RECORDING_FILTERS = [
  { value: 'all', label: 'All recording' },
  { value: 'on', label: 'Recording on' },
  { value: 'off', label: 'Recording off' },
];

export function KiosksPage() {
  const { token } = useAuth();
  const [items, setItems] = useState<Device[]>([]);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [siteFilter, setSiteFilter] = useState('all');
  const [recordingFilter, setRecordingFilter] = useState('all');
  const [error, setError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [editDevice, setEditDevice] = useState<Device | null>(null);
  const [name, setName] = useState('');
  const [siteName, setSiteName] = useState('');
  const [latitude, setLatitude] = useState('');
  const [longitude, setLongitude] = useState('');
  const [address, setAddress] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [credentials, setCredentials] = useState<CreatedCredentials | null>(null);
  const [copiedField, setCopiedField] = useState<'key' | 'secret' | null>(null);
  const [settingsDevice, setSettingsDevice] = useState<Device | null>(null);
  const [printLimits, setPrintLimits] = useState<PrintLimitsForm>(DEFAULT_PRINT_LIMITS);
  const [settingsError, setSettingsError] = useState<string | null>(null);
  const [settingsSaving, setSettingsSaving] = useState(false);
  const [printerDeviceId, setPrinterDeviceId] = useState<string | null>(null);
  const [printerRefreshing, setPrinterRefreshing] = useState(false);
  const [printerRefreshNote, setPrinterRefreshNote] = useState<string | null>(null);
  const [trayInput, setTrayInput] = useState('');
  const [trayError, setTrayError] = useState<string | null>(null);
  const [traySaving, setTraySaving] = useState(false);
  const [clearOpenSaving, setClearOpenSaving] = useState(false);
  const [usageDevice, setUsageDevice] = useState<Device | null>(null);
  const [usageRangePreset, setUsageRangePreset] = useState<UsageRangePreset>('30');
  const [usageFromLocal, setUsageFromLocal] = useState(() => rangeForPreset('30').fromLocal);
  const [usageToLocal, setUsageToLocal] = useState(() => rangeForPreset('30').toLocal);
  const [usageRows, setUsageRows] = useState<UsageRow[]>([]);
  const [usageLoading, setUsageLoading] = useState(false);
  const [usageError, setUsageError] = useState<string | null>(null);
  const [usageSearch, setUsageSearch] = useState('');
  const [usageServiceFilter, setUsageServiceFilter] = useState('all');
  const [usageHideZero, setUsageHideZero] = useState(false);
  const [logsDevice, setLogsDevice] = useState<Device | null>(null);
  const [logsHours, setLogsHours] = useState<24 | 168>(24);
  const [logsLevelMode, setLogsLevelMode] = useState<'problems' | 'all'>('problems');
  const [logsCategory, setLogsCategory] = useState<string>('');
  const [logsItems, setLogsItems] = useState<DiagnosticLogItem[]>([]);
  const [logsLoading, setLogsLoading] = useState(false);
  const [logsLoadingMore, setLogsLoadingMore] = useState(false);
  const [logsError, setLogsError] = useState<string | null>(null);
  const [logsHasMore, setLogsHasMore] = useState(false);
  const [logsNextBefore, setLogsNextBefore] = useState<string | null>(null);
  const [logsNextBeforeId, setLogsNextBeforeId] = useState<string | null>(null);
  const printerRefreshGeneration = useRef(0);
  const canEnablePrinting =
    roleFromToken(token) === 'admin' || roleFromToken(token) === 'operator';

  async function load() {
    try {
      const result = await apiRequest<{ items: Device[] }>('/devices', { token });
      setItems(result.items);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load devices');
    }
  }

  useEffect(() => {
    void load();
  }, [token]);

  useEffect(() => {
    if (!printerDeviceId) return;
    const timer = window.setInterval(() => {
      void load();
    }, 30_000);
    return () => window.clearInterval(timer);
  }, [printerDeviceId, token]);

  function resetForm() {
    setName('');
    setSiteName('');
    setLatitude('');
    setLongitude('');
    setAddress('');
    setFormError(null);
  }

  function openAdd() {
    resetForm();
    setEditDevice(null);
    setAddOpen(true);
  }

  function openEdit(device: Device) {
    setAddOpen(false);
    setFormError(null);
    setEditDevice(device);
    setName(device.name);
    setSiteName(device.siteName);
    setLatitude(device.latitude != null ? String(device.latitude) : '');
    setLongitude(device.longitude != null ? String(device.longitude) : '');
    setAddress(device.address ?? '');
  }

  function closeEdit() {
    if (submitting) return;
    setEditDevice(null);
    resetForm();
  }

  async function onRegister(event: FormEvent) {
    event.preventDefault();
    const trimmedName = name.trim();
    const trimmedSite = siteName.trim();
    const lat = Number(latitude);
    const lng = Number(longitude);
    if (!trimmedName || !trimmedSite) {
      setFormError('Device name and site name are required');
      return;
    }
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      setFormError('Latitude and longitude are required numbers');
      return;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      setFormError('Latitude must be −90…90 and longitude −180…180');
      return;
    }

    setSubmitting(true);
    setFormError(null);
    try {
      const result = await apiRequest<Device & { deviceSecret: string }>('/devices', {
        method: 'POST',
        token,
        body: {
          name: trimmedName,
          siteName: trimmedSite,
          latitude: lat,
          longitude: lng,
          address: address.trim() || undefined,
        },
      });
      setCredentials({
        name: result.name,
        deviceKey: result.deviceKey,
        deviceSecret: result.deviceSecret,
      });
      setCopiedField(null);
      setAddOpen(false);
      resetForm();
      await load();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to register device');
    } finally {
      setSubmitting(false);
    }
  }

  async function onUpdate(event: FormEvent) {
    event.preventDefault();
    if (!editDevice) return;

    const trimmedName = name.trim();
    const trimmedSite = siteName.trim();
    const lat = Number(latitude);
    const lng = Number(longitude);
    if (!trimmedName || !trimmedSite) {
      setFormError('Device name and site name are required');
      return;
    }
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      setFormError('Latitude and longitude are required numbers');
      return;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      setFormError('Latitude must be −90…90 and longitude −180…180');
      return;
    }

    setSubmitting(true);
    setFormError(null);
    try {
      await apiRequest<Device>(`/devices/${editDevice.id}`, {
        method: 'PATCH',
        token,
        body: {
          name: trimmedName,
          siteName: trimmedSite,
          latitude: lat,
          longitude: lng,
          address: address.trim() || undefined,
        },
      });
      setEditDevice(null);
      resetForm();
      await load();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to update device');
    } finally {
      setSubmitting(false);
    }
  }

  async function onSetStatus(device: Device, status: 'active' | 'inactive') {
    if (status === 'inactive') {
      const ok = window.confirm(
        `Stop “${device.name}”? This kiosk will go offline until you Start it again.`,
      );
      if (!ok) {
        return;
      }
    }
    setSubmitting(true);
    setError(null);
    try {
      await apiRequest(`/devices/${device.id}/status`, {
        method: 'PATCH',
        token,
        body: { status },
      });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update kiosk');
    } finally {
      setSubmitting(false);
    }
  }

  async function onEnablePrinting(device: Device) {
    setSubmitting(true);
    setError(null);
    try {
      await apiRequest(`/devices/${device.id}/printing-enable`, {
        method: 'POST',
        token,
      });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not enable printing');
    } finally {
      setSubmitting(false);
    }
  }

  async function onSetSurveillance(device: Device, enabled: boolean) {
    if (enabled) {
      const ok = window.confirm(
        `Start 24/7 camera recording on “${device.name}”? Visitors at this kiosk must be notified that video surveillance is in use.`,
      );
      if (!ok) {
        return;
      }
    }
    setSubmitting(true);
    setError(null);
    try {
      await apiRequest(`/devices/${device.id}/surveillance`, {
        method: 'PATCH',
        token,
        body: { enabled },
      });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update surveillance');
    } finally {
      setSubmitting(false);
    }
  }

  async function loadUsage(device: Device, fromIso: string, toIso: string) {
    setUsageLoading(true);
    setUsageError(null);
    try {
      const result = await apiRequest<{
        items: ServiceAnalyticsItem[];
      }>(
        `/devices/${device.id}/service-analytics?from=${encodeURIComponent(fromIso)}&to=${encodeURIComponent(toIso)}`,
        { token },
      );
      setUsageRows(buildUsageRows(result.items ?? []));
    } catch (err) {
      setUsageRows([]);
      setUsageError(err instanceof Error ? err.message : 'Failed to load usage');
    } finally {
      setUsageLoading(false);
    }
  }

  function applyUsageRange(
    device: Device,
    preset: UsageRangePreset,
    fromLocal = usageFromLocal,
    toLocal = usageToLocal,
  ) {
    if (preset !== 'custom') {
      const range = rangeForPreset(preset);
      setUsageRangePreset(preset);
      setUsageFromLocal(range.fromLocal);
      setUsageToLocal(range.toLocal);
      void loadUsage(device, range.fromIso, range.toIso);
      return;
    }

    const from = fromDatetimeLocalValue(fromLocal);
    const to = fromDatetimeLocalValue(toLocal);
    if (!from || !to) {
      setUsageError('Choose a valid from and to date/time');
      return;
    }
    if (from.getTime() > to.getTime()) {
      setUsageError('From must be before to');
      return;
    }
    setUsageRangePreset('custom');
    setUsageFromLocal(fromLocal);
    setUsageToLocal(toLocal);
    void loadUsage(device, from.toISOString(), to.toISOString());
  }

  function openUsage(device: Device) {
    const range = rangeForPreset('30');
    setUsageDevice(device);
    setUsageRangePreset('30');
    setUsageFromLocal(range.fromLocal);
    setUsageToLocal(range.toLocal);
    setUsageRows([]);
    setUsageError(null);
    setUsageSearch('');
    setUsageServiceFilter('all');
    setUsageHideZero(false);
    void loadUsage(device, range.fromIso, range.toIso);
  }

  async function loadLogs(
    device: Device,
    opts: {
      hours: 24 | 168;
      levelMode: 'problems' | 'all';
      category: string;
      append?: boolean;
      before?: string | null;
      beforeId?: string | null;
    },
  ) {
    const appending = opts.append === true;
    if (appending) {
      setLogsLoadingMore(true);
    } else {
      setLogsLoading(true);
      setLogsError(null);
    }
    try {
      const to = new Date();
      const from = new Date(to.getTime() - opts.hours * 60 * 60 * 1000);
      const params = new URLSearchParams({
        from: from.toISOString(),
        to: to.toISOString(),
        limit: '100',
      });
      if (opts.levelMode === 'problems') {
        params.set('levels', 'error,warn');
      }
      if (opts.category) {
        params.set('category', opts.category);
      }
      if (opts.before) {
        params.set('before', opts.before);
      }
      if (opts.beforeId) {
        params.set('beforeId', opts.beforeId);
      }
      const result = await apiRequest<{
        items: DiagnosticLogItem[];
        hasMore: boolean;
        nextBefore: string | null;
        nextBeforeId: string | null;
      }>(`/devices/${device.id}/diagnostic-logs?${params.toString()}`, { token });
      setLogsItems((prev) =>
        appending ? [...prev, ...(result.items ?? [])] : (result.items ?? []),
      );
      setLogsHasMore(Boolean(result.hasMore));
      setLogsNextBefore(result.nextBefore ?? null);
      setLogsNextBeforeId(result.nextBeforeId ?? null);
    } catch (err) {
      if (!appending) {
        setLogsItems([]);
      }
      setLogsError(err instanceof Error ? err.message : 'Failed to load logs');
    } finally {
      setLogsLoading(false);
      setLogsLoadingMore(false);
    }
  }

  function openLogs(device: Device) {
    setLogsDevice(device);
    setLogsHours(24);
    setLogsLevelMode('problems');
    setLogsCategory('');
    setLogsItems([]);
    setLogsError(null);
    setLogsHasMore(false);
    setLogsNextBefore(null);
    setLogsNextBeforeId(null);
    void loadLogs(device, { hours: 24, levelMode: 'problems', category: '' });
  }

  function openSettings(device: Device) {
    setSettingsDevice(device);
    setPrintLimits(printLimitsFromDevice(device));
    setSettingsError(null);
  }

  async function onSavePrintLimits(event: FormEvent) {
    event.preventDefault();
    if (!settingsDevice) {
      return;
    }
    if (printLimits.freePagesPerSession > printLimits.maxPagesPerSession) {
      setSettingsError('Black & white free pages cannot exceed max pages');
      return;
    }
    if (printLimits.freeColorPagesPerSession > printLimits.maxPagesPerSession) {
      setSettingsError('Color free pages cannot exceed max pages');
      return;
    }
    setSettingsSaving(true);
    setSettingsError(null);
    try {
      const from = printLimits.freeDisabledFromLocal.trim();
      const to = printLimits.freeDisabledToLocal.trim();
      if ((from && !to) || (!from && to)) {
        setSettingsError('Set both free-disabled from and to times, or clear both');
        setSettingsSaving(false);
        return;
      }
      await apiRequest(`/devices/${settingsDevice.id}/print-limits`, {
        method: 'PATCH',
        token,
        body: {
          maxPagesPerSession: Number(printLimits.maxPagesPerSession),
          freePagesPerSession: Number(printLimits.freePagesPerSession),
          extraPageChargeRupees: Number(printLimits.extraPageChargeRupees),
          freeColorPagesPerSession: Number(printLimits.freeColorPagesPerSession),
          extraColorPageChargeRupees: Number(printLimits.extraColorPageChargeRupees),
          kundaliColorPrintChargeRupees: Number(printLimits.kundaliColorPrintChargeRupees),
          freeDisabledFromLocal: from || null,
          freeDisabledToLocal: to || null,
          bannerHorizontalEnabled: printLimits.bannerHorizontalEnabled,
          bannerVerticalEnabled: printLimits.bannerVerticalEnabled,
        },
      });
      setSettingsDevice(null);
      await load();
    } catch (err) {
      setSettingsError(err instanceof Error ? err.message : 'Failed to save print limits');
    } finally {
      setSettingsSaving(false);
    }
  }

  async function copyValue(field: 'key' | 'secret', value: string) {
    try {
      await navigator.clipboard.writeText(value);
      setCopiedField(field);
    } catch {
      setError('Could not copy to clipboard');
    }
  }

  async function refreshPrinterDetails() {
    if (!printerDeviceId || printerRefreshing) return;
    const generation = printerRefreshGeneration.current + 1;
    printerRefreshGeneration.current = generation;
    setPrinterRefreshing(true);
    setPrinterRefreshNote(null);
    try {
      const pending = await apiRequest<{ requestedAt: string }>(
        `/devices/${printerDeviceId}/printer-refresh`,
        { method: 'POST', token },
      );
      const requestedAt = Date.parse(pending.requestedAt);
      const deadline = Date.now() + 8000;
      while (Date.now() < deadline) {
        if (printerRefreshGeneration.current !== generation) return;
        const result = await apiRequest<{ items: Device[] }>('/devices', { token });
        if (printerRefreshGeneration.current !== generation) return;
        setItems(result.items);
        const device = result.items.find((item) => item.id === printerDeviceId);
        const posted = device?.printerHealthAt ? Date.parse(device.printerHealthAt) : NaN;
        if (
          device &&
          !device.printerRefreshRequestedAt &&
          Number.isFinite(posted) &&
          Number.isFinite(requestedAt) &&
          posted >= requestedAt
        ) {
          return;
        }
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }
      if (printerRefreshGeneration.current === generation) {
        setPrinterRefreshNote('The kiosk did not answer. Showing the last report.');
      }
    } catch (err) {
      if (printerRefreshGeneration.current === generation) {
        setPrinterRefreshNote(
          err instanceof Error ? err.message : 'The kiosk did not answer. Showing the last report.',
        );
      }
    } finally {
      if (printerRefreshGeneration.current === generation) {
        setPrinterRefreshing(false);
      }
    }
  }

  function closePrinterDetails() {
    printerRefreshGeneration.current += 1;
    setPrinterRefreshing(false);
    setPrinterRefreshNote(null);
    setTrayInput('');
    setTrayError(null);
    setClearOpenSaving(false);
    setPrinterDeviceId(null);
  }

  async function clearOpenJobs() {
    if (!printerDeviceId || clearOpenSaving || !canEnablePrinting) return;
    setClearOpenSaving(true);
    setPrinterRefreshNote(null);
    try {
      const result = await apiRequest<{ closedCount: number }>(
        `/devices/${printerDeviceId}/print-jobs/close-open`,
        { method: 'POST', token },
      );
      await load();
      setPrinterRefreshNote(
        result.closedCount === 0
          ? 'No open print jobs to clear.'
          : `Cleared ${result.closedCount} open print job${result.closedCount === 1 ? '' : 's'}.`,
      );
    } catch (err) {
      setPrinterRefreshNote(
        err instanceof Error ? err.message : 'Could not clear open print jobs',
      );
    } finally {
      setClearOpenSaving(false);
    }
  }

  async function saveTray(mode: 'add' | 'replace') {
    if (!printerDeviceId || traySaving) return;
    const pages = Number(trayInput);
    if (!Number.isInteger(pages) || pages < 1 || pages > 2000) {
      setTrayError('Enter a whole number of pages from 1 to 2000');
      return;
    }
    setTraySaving(true);
    setTrayError(null);
    try {
      await apiRequest(`/devices/${printerDeviceId}/printer-tray`, {
        method: 'PATCH',
        token,
        body: { mode, pages },
      });
      setTrayInput('');
      await load();
    } catch (err) {
      setTrayError(err instanceof Error ? err.message : 'Could not update the tray');
    } finally {
      setTraySaving(false);
    }
  }

  const printerDevice = printerDeviceId
    ? items.find((device) => device.id === printerDeviceId) ?? null
    : null;

  const sites = useMemo(
    () => Array.from(new Set(items.map((device) => device.siteName).filter(Boolean))).sort(),
    [items],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter((device) => {
      if (statusFilter !== 'all' && device.status !== statusFilter) return false;
      if (siteFilter !== 'all' && device.siteName !== siteFilter) return false;
      if (recordingFilter === 'on' && !device.surveillanceEnabled) return false;
      if (recordingFilter === 'off' && device.surveillanceEnabled) return false;
      if (!q) return true;
      const haystack = [
        device.name,
        device.siteName,
        device.deviceKey,
        device.address ?? '',
        formatLocation(device),
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [items, search, statusFilter, siteFilter, recordingFilter]);

  const filteredUsageRows = useMemo(
    () =>
      filterUsageRows(usageRows, {
        service: usageServiceFilter,
        search: usageSearch,
        hideZero: usageHideZero,
      }),
    [usageRows, usageServiceFilter, usageSearch, usageHideZero],
  );

  const usageStats = useMemo(() => usageSummary(usageRows), [usageRows]);
  const usageMaxCount = useMemo(
    () => filteredUsageRows.reduce((max, row) => Math.max(max, row.count), 0),
    [filteredUsageRows],
  );

  return (
    <div>
      <PageHeader
        title="Kiosks"
        subtitle="Register a Windows terminal, then paste the credentials into the kiosk Activate screen"
        actions={
          <Button type="button" onClick={openAdd}>
            Add kiosk
          </Button>
        }
      />

      {error ? <p className="error mb-4">{error}</p> : null}

      {credentials ? (
        <Panel title={`Device credentials for ${credentials.name}`}>
          <div className="credentials-panel">
            <p className="warning">
              The device secret is shown only once. Copy both values now and paste them into the
              Windows kiosk Activate screen.
            </p>

            <div className="credential-row">
              <label>
                Device key
                <Input readOnly value={credentials.deviceKey} />
              </label>
              <Button type="button" onClick={() => void copyValue('key', credentials.deviceKey)}>
                {copiedField === 'key' ? 'Copied' : 'Copy key'}
              </Button>
            </div>

            <div className="credential-row">
              <label>
                Device secret
                <Input readOnly value={credentials.deviceSecret} />
              </label>
              <Button
                type="button"
                onClick={() => void copyValue('secret', credentials.deviceSecret)}
              >
                {copiedField === 'secret' ? 'Copied' : 'Copy secret'}
              </Button>
            </div>

            <Button type="button" variant="secondary" onClick={() => setCredentials(null)}>
              Dismiss
            </Button>
          </div>
        </Panel>
      ) : null}

      <Panel title="Registered kiosks">
        {items.length === 0 ? (
          <EmptyState
            title="No devices registered yet"
            description="Add a kiosk, then paste the credentials into the Windows Activate screen."
            action={
              <Button type="button" onClick={openAdd}>
                Add kiosk
              </Button>
            }
          />
        ) : (
          <>
          <Toolbar
            search={search}
            onSearchChange={setSearch}
            searchPlaceholder="Search name, site, key, location"
          >
            <FilterChips
              options={STATUS_FILTERS}
              value={statusFilter}
              onChange={setStatusFilter}
            />
            <Select
              aria-label="Filter by site"
              value={siteFilter}
              onChange={(event) => setSiteFilter(event.target.value)}
            >
              <option value="all">All sites</option>
              {sites.map((site) => (
                <option key={site} value={site}>
                  {site}
                </option>
              ))}
            </Select>
            <Select
              aria-label="Filter by recording"
              value={recordingFilter}
              onChange={(event) => setRecordingFilter(event.target.value)}
            >
              {RECORDING_FILTERS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </Select>
          </Toolbar>
          {filtered.length === 0 ? (
            <EmptyState
              title="No matches"
              description="Adjust filters or search to find a kiosk."
            />
          ) : (
          <div className="overflow-x-auto">
          <table className="table w-full min-w-[64rem]">
            <thead>
              <tr>
                <th className="w-[12%]">Name</th>
                <th className="w-[10%]">Site</th>
                <th className="w-[14%]">Location</th>
                <th className="w-[9%]">Status</th>
                <th className="w-[12%]">Device key</th>
                <th className="w-[12%]">Last heartbeat</th>
                <th className="w-[14%]">Printer</th>
                <th className="w-[10%]">Recording</th>
                <th className="w-[7%]">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((device) => {
                const location = formatLocation(device);
                return (
                <tr key={device.id}>
                  <td className="font-medium">
                    <span className="block truncate" title={device.name}>
                      {device.name}
                    </span>
                  </td>
                  <td>
                    <span className="block truncate" title={device.siteName}>
                      {device.siteName}
                    </span>
                  </td>
                  <td>
                    <span className="block truncate text-muted-foreground" title={location}>
                      {location}
                    </span>
                  </td>
                  <td>
                    <StatusBadge status={device.status} />
                  </td>
                  <td>
                    <code className="block truncate text-xs text-muted-foreground" title={device.deviceKey}>
                      {device.deviceKey}
                    </code>
                  </td>
                  <td className="text-muted-foreground">
                    <span className="block truncate">
                      {device.lastHeartbeatAt
                        ? new Date(device.lastHeartbeatAt).toLocaleString()
                        : '—'}
                    </span>
                  </td>
                  <td>
                    <PrinterSummaryCell
                      device={device}
                      onDetails={() => {
                        setPrinterRefreshNote(null);
                        setTrayInput('');
                        setTrayError(null);
                        setPrinterDeviceId(device.id);
                      }}
                    />
                  </td>
                  <td>
                    <RecordingStatusCell device={device} />
                  </td>
                  <td>
                    <div className="flex items-center gap-1">
                      {device.status === 'inactive' ? (
                        <Button
                          type="button"
                          variant="secondary"
                          className="h-7 px-2 text-xs"
                          disabled={submitting}
                          onClick={() => void onSetStatus(device, 'active')}
                        >
                          Start
                        </Button>
                      ) : (
                        <Button
                          type="button"
                          variant="danger"
                          className="h-7 px-2 text-xs"
                          disabled={submitting}
                          onClick={() => void onSetStatus(device, 'inactive')}
                        >
                          Stop
                        </Button>
                      )}
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <UiButton
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="h-7 w-7"
                            disabled={submitting}
                          >
                            <MoreHorizontal className="h-4 w-4" />
                            <span className="sr-only">More actions</span>
                          </UiButton>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          {canEnablePrinting ? (
                            <DropdownMenuItem onClick={() => openEdit(device)}>
                              <Pencil className="h-4 w-4" />
                              Edit
                            </DropdownMenuItem>
                          ) : null}
                          <DropdownMenuItem onClick={() => openSettings(device)}>
                            <Settings className="h-4 w-4" />
                            Settings
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => openUsage(device)}>
                            <BarChart3 className="h-4 w-4" />
                            Usage
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => openLogs(device)}>
                            <ScrollText className="h-4 w-4" />
                            Logs
                          </DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem
                            disabled={device.status === 'inactive'}
                            onClick={() => void onSetSurveillance(device, !device.surveillanceEnabled)}
                          >
                            {device.surveillanceEnabled ? (
                              <VideoOff className="h-4 w-4" />
                            ) : (
                              <Video className="h-4 w-4" />
                            )}
                            {device.surveillanceEnabled ? 'Stop recording' : 'Start recording'}
                          </DropdownMenuItem>
                          {device.printingPausedReason && canEnablePrinting ? (
                            <>
                              <DropdownMenuSeparator />
                              <DropdownMenuItem onClick={() => void onEnablePrinting(device)}>
                                Enable printing
                              </DropdownMenuItem>
                            </>
                          ) : null}
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                    {device.printingPausedReason ? (
                      <p className="mt-1 text-[11px] text-red-700">Printing paused</p>
                    ) : null}
                  </td>
                </tr>
                );
              })}
            </tbody>
          </table>
          </div>
          )}
          </>
        )}
      </Panel>

      <Modal
        open={addOpen}
        title="Add kiosk"
        onClose={() => {
          if (!submitting) {
            setAddOpen(false);
          }
        }}
        footer={
          <>
            <Button
              type="button"
              variant="ghost"
              disabled={submitting}
              onClick={() => setAddOpen(false)}
            >
              Cancel
            </Button>
            <Button type="submit" form="register-kiosk-form" disabled={submitting}>
              {submitting ? 'Registering…' : 'Register device'}
            </Button>
          </>
        }
      >
        <form id="register-kiosk-form" className="grid gap-4 md:grid-cols-2" onSubmit={(e) => void onRegister(e)}>
          <label>
            Device name
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Lobby Kiosk"
              required
            />
          </label>
          <label>
            Site name
            <Input
              value={siteName}
              onChange={(e) => setSiteName(e.target.value)}
              placeholder="Demo Site"
              required
            />
          </label>
          <label>
            Latitude
            <Input
              value={latitude}
              onChange={(e) => setLatitude(e.target.value)}
              placeholder="28.613900"
              inputMode="decimal"
              required
            />
          </label>
          <label>
            Longitude
            <Input
              value={longitude}
              onChange={(e) => setLongitude(e.target.value)}
              placeholder="77.209000"
              inputMode="decimal"
              required
            />
          </label>
          <label className="md:col-span-2">
            Address (optional)
            <Input
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              placeholder="City Mall, Gate 2"
            />
          </label>
          {formError ? <p className="error md:col-span-2">{formError}</p> : null}
        </form>
      </Modal>

      <Modal
        open={editDevice != null}
        title={editDevice ? `Edit kiosk · ${editDevice.name}` : 'Edit kiosk'}
        onClose={closeEdit}
        footer={
          <>
            <Button type="button" variant="ghost" disabled={submitting} onClick={closeEdit}>
              Cancel
            </Button>
            <Button type="submit" form="edit-kiosk-form" disabled={submitting}>
              {submitting ? 'Saving…' : 'Save changes'}
            </Button>
          </>
        }
      >
        <form
          id="edit-kiosk-form"
          className="grid gap-4 md:grid-cols-2"
          onSubmit={(e) => void onUpdate(e)}
        >
          <label>
            Device name
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Lobby Kiosk"
              required
            />
          </label>
          <label>
            Site name
            <Input
              value={siteName}
              onChange={(e) => setSiteName(e.target.value)}
              placeholder="Demo Site"
              required
            />
          </label>
          <label>
            Latitude
            <Input
              value={latitude}
              onChange={(e) => setLatitude(e.target.value)}
              placeholder="28.613900"
              inputMode="decimal"
              required
            />
          </label>
          <label>
            Longitude
            <Input
              value={longitude}
              onChange={(e) => setLongitude(e.target.value)}
              placeholder="77.209000"
              inputMode="decimal"
              required
            />
          </label>
          <label className="md:col-span-2">
            Address (optional)
            <Input
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              placeholder="City Mall, Gate 2"
            />
          </label>
          {formError ? <p className="error md:col-span-2">{formError}</p> : null}
        </form>
      </Modal>

      <Modal
        open={settingsDevice != null}
        title={settingsDevice ? `Print limits · ${settingsDevice.name}` : 'Print limits'}
        onClose={() => {
          if (!settingsSaving) {
            setSettingsDevice(null);
          }
        }}
        footer={
          <>
            <Button
              type="button"
              variant="ghost"
              disabled={settingsSaving}
              onClick={() => setSettingsDevice(null)}
            >
              Cancel
            </Button>
            <Button type="submit" form="kiosk-print-limits-form" disabled={settingsSaving}>
              {settingsSaving ? 'Saving…' : 'Save limits'}
            </Button>
          </>
        }
      >
        <form
          id="kiosk-print-limits-form"
          className="grid gap-4 md:grid-cols-2"
          onSubmit={(e) => void onSavePrintLimits(e)}
        >
          <label>
            Max pages / session
            <Input
              type="number"
              min={1}
              max={100}
              value={printLimits.maxPagesPerSession}
              onChange={(e) =>
                setPrintLimits((s) => ({ ...s, maxPagesPerSession: Number(e.target.value) }))
              }
            />
          </label>
          <label>
            Black & white free pages
            <Input
              type="number"
              min={0}
              max={100}
              value={printLimits.freePagesPerSession}
              onChange={(e) =>
                setPrintLimits((s) => ({ ...s, freePagesPerSession: Number(e.target.value) }))
              }
            />
          </label>
          <label>
            Black & white extra page charge (₹)
            <Input
              type="number"
              min={0}
              max={1000}
              value={printLimits.extraPageChargeRupees}
              onChange={(e) =>
                setPrintLimits((s) => ({ ...s, extraPageChargeRupees: Number(e.target.value) }))
              }
            />
          </label>
          <label>
            Color free pages
            <Input
              type="number"
              min={0}
              max={100}
              value={printLimits.freeColorPagesPerSession}
              onChange={(e) =>
                setPrintLimits((s) => ({
                  ...s,
                  freeColorPagesPerSession: Number(e.target.value),
                }))
              }
            />
          </label>
          <label>
            Color extra page charge (₹)
            <Input
              type="number"
              min={0}
              max={1000}
              value={printLimits.extraColorPageChargeRupees}
              onChange={(e) =>
                setPrintLimits((s) => ({
                  ...s,
                  extraColorPageChargeRupees: Number(e.target.value),
                }))
              }
            />
          </label>
          <label>
            Kundali color print (₹)
            <Input
              type="number"
              min={0}
              max={1000}
              value={printLimits.kundaliColorPrintChargeRupees}
              onChange={(e) =>
                setPrintLimits((s) => ({
                  ...s,
                  kundaliColorPrintChargeRupees: Number(e.target.value),
                }))
              }
            />
          </label>
          <label>
            Free disabled from (Asia/Kolkata)
            <Input
              type="time"
              value={printLimits.freeDisabledFromLocal}
              onChange={(e) =>
                setPrintLimits((s) => ({ ...s, freeDisabledFromLocal: e.target.value }))
              }
            />
          </label>
          <label>
            Free disabled to (Asia/Kolkata)
            <Input
              type="time"
              value={printLimits.freeDisabledToLocal}
              onChange={(e) =>
                setPrintLimits((s) => ({ ...s, freeDisabledToLocal: e.target.value }))
              }
            />
          </label>
          <p className="muted md:col-span-2" style={{ margin: 0 }}>
            Session free caps: B/W first {printLimits.freePagesPerSession} page(s), color first{' '}
            {printLimits.freeColorPagesPerSession} page(s), then paid rates apply. Global per-phone
            quota is set under Platform settings. Optional free-disabled window (e.g. 22:00–10:00)
            blocks all free pages at this kiosk during those Asia/Kolkata hours. Clear both times to
            disable the window.
          </p>
          <fieldset className="md:col-span-2 stack border-0 p-0 m-0">
            <legend className="muted">Home banners</legend>
            <label>
              <input
                type="checkbox"
                checked={printLimits.bannerHorizontalEnabled}
                onChange={(e) =>
                  setPrintLimits((s) => ({ ...s, bannerHorizontalEnabled: e.target.checked }))
                }
              />{' '}
              Show top / bottom banners
            </label>
            <label>
              <input
                type="checkbox"
                checked={printLimits.bannerVerticalEnabled}
                onChange={(e) =>
                  setPrintLimits((s) => ({ ...s, bannerVerticalEnabled: e.target.checked }))
                }
              />{' '}
              Show left / right banners
            </label>
          </fieldset>
          {settingsError ? <p className="error md:col-span-2">{settingsError}</p> : null}
        </form>
      </Modal>

      <Modal
        open={printerDevice != null}
        title={printerDevice ? `Printer · ${printerDevice.name}` : 'Printer'}
        className="max-w-2xl"
        onClose={closePrinterDetails}
        footer={
          <>
            <Button
              type="button"
              variant="secondary"
              disabled={printerRefreshing}
              onClick={() => void refreshPrinterDetails()}
            >
              {printerRefreshing ? 'Refreshing…' : 'Refresh'}
            </Button>
            <Button type="button" variant="ghost" onClick={closePrinterDetails}>
              Close
            </Button>
          </>
        }
      >
        {printerRefreshNote ? (
          <p
            className={
              printerRefreshNote.startsWith('Cleared') || printerRefreshNote.startsWith('No open')
                ? 'mb-2 text-sm text-muted-foreground'
                : 'error'
            }
          >
            {printerRefreshNote}
          </p>
        ) : null}
        {printerDevice ? (
          <PrinterDetailsBody
            health={printerDevice.printerHealth}
            pagesLeft={printerDevice.pagesLeft ?? null}
            trayReserved={printerDevice.trayReserved ?? null}
            trayAvailable={printerDevice.trayAvailable ?? null}
            canEditTray={canEnablePrinting}
            canClearOpen={canEnablePrinting}
            trayInput={trayInput}
            onTrayInput={(value) => {
              setTrayInput(value);
              setTrayError(null);
            }}
            trayError={trayError}
            traySaving={traySaving}
            onSaveTray={(mode) => void saveTray(mode)}
            clearOpenSaving={clearOpenSaving}
            onClearOpen={() => void clearOpenJobs()}
          />
        ) : null}
      </Modal>

      <Modal
        open={logsDevice != null}
        title={logsDevice ? `Device logs · ${logsDevice.name}` : 'Device logs'}
        className="max-w-4xl"
        onClose={() => {
          if (!logsLoading && !logsLoadingMore) {
            setLogsDevice(null);
          }
        }}
        footer={
          <Button
            type="button"
            variant="ghost"
            disabled={logsLoading || logsLoadingMore}
            onClick={() => setLogsDevice(null)}
          >
            Close
          </Button>
        }
      >
        <div className="mb-4 flex flex-wrap items-center gap-2">
          <span className="text-sm text-muted-foreground">Range</span>
          <Button
            type="button"
            variant={logsHours === 24 ? 'primary' : 'secondary'}
            className="h-8 px-3"
            disabled={logsLoading || !logsDevice}
            onClick={() => {
              if (!logsDevice) return;
              setLogsHours(24);
              void loadLogs(logsDevice, {
                hours: 24,
                levelMode: logsLevelMode,
                category: logsCategory,
              });
            }}
          >
            Last 24h
          </Button>
          <Button
            type="button"
            variant={logsHours === 168 ? 'primary' : 'secondary'}
            className="h-8 px-3"
            disabled={logsLoading || !logsDevice}
            onClick={() => {
              if (!logsDevice) return;
              setLogsHours(168);
              void loadLogs(logsDevice, {
                hours: 168,
                levelMode: logsLevelMode,
                category: logsCategory,
              });
            }}
          >
            Last 7 days
          </Button>
          <span className="ml-2 text-sm text-muted-foreground">Level</span>
          <Button
            type="button"
            variant={logsLevelMode === 'problems' ? 'primary' : 'secondary'}
            className="h-8 px-3"
            disabled={logsLoading || !logsDevice}
            onClick={() => {
              if (!logsDevice) return;
              setLogsLevelMode('problems');
              void loadLogs(logsDevice, {
                hours: logsHours,
                levelMode: 'problems',
                category: logsCategory,
              });
            }}
          >
            Errors + warnings
          </Button>
          <Button
            type="button"
            variant={logsLevelMode === 'all' ? 'primary' : 'secondary'}
            className="h-8 px-3"
            disabled={logsLoading || !logsDevice}
            onClick={() => {
              if (!logsDevice) return;
              setLogsLevelMode('all');
              void loadLogs(logsDevice, {
                hours: logsHours,
                levelMode: 'all',
                category: logsCategory,
              });
            }}
          >
            All levels
          </Button>
          <span className="ml-2 text-sm text-muted-foreground">Category</span>
          <select
            className="h-8 rounded-md border border-border bg-background px-2 text-sm"
            value={logsCategory}
            disabled={logsLoading || !logsDevice}
            onChange={(e) => {
              if (!logsDevice) return;
              const next = e.target.value;
              setLogsCategory(next);
              void loadLogs(logsDevice, {
                hours: logsHours,
                levelMode: logsLevelMode,
                category: next,
              });
            }}
          >
            <option value="">All</option>
            <option value="printer">Printer</option>
            <option value="astrology">Astrology</option>
            <option value="well_being">Well-being</option>
            <option value="shutter">Shutter</option>
            <option value="cabinet_light">Cabinet light</option>
            <option value="charging">Charging</option>
            <option value="serial">Serial</option>
            <option value="app">App</option>
          </select>
        </div>
        {logsError ? <p className="error mb-3">{logsError}</p> : null}
        {logsLoading ? (
          <p className="text-muted-foreground">Loading logs…</p>
        ) : logsItems.length === 0 ? (
          <EmptyState
            title="No diagnostic logs yet"
            description="Errors and warnings from this kiosk appear here (kept for 7 days)."
          />
        ) : (
          <div className="space-y-3">
            <div className="overflow-x-auto">
              <table className="table w-full">
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>Level</th>
                    <th>Category</th>
                    <th>Event</th>
                    <th>Message</th>
                  </tr>
                </thead>
                <tbody>
                  {logsItems.map((row) => (
                    <tr key={row.id}>
                      <td className="whitespace-nowrap text-xs tabular-nums text-muted-foreground">
                        {new Date(row.occurredAt).toLocaleString()}
                      </td>
                      <td className="text-xs font-medium uppercase">{row.level}</td>
                      <td className="text-xs">{row.category}</td>
                      <td className="text-xs font-mono">{row.event}</td>
                      <td className="text-sm">{row.message}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {logsHasMore ? (
              <Button
                type="button"
                variant="secondary"
                className="h-8 px-3"
                disabled={logsLoadingMore || !logsDevice}
                onClick={() => {
                  if (!logsDevice) return;
                  void loadLogs(logsDevice, {
                    hours: logsHours,
                    levelMode: logsLevelMode,
                    category: logsCategory,
                    append: true,
                    before: logsNextBefore,
                    beforeId: logsNextBeforeId,
                  });
                }}
              >
                {logsLoadingMore ? 'Loading…' : 'Load more'}
              </Button>
            ) : null}
          </div>
        )}
      </Modal>

      <Modal
        open={usageDevice != null}
        title={usageDevice ? `Service usage · ${usageDevice.name}` : 'Service usage'}
        className="max-w-3xl"
        onClose={() => {
          if (!usageLoading) {
            setUsageDevice(null);
          }
        }}
        footer={
          <Button
            type="button"
            variant="ghost"
            disabled={usageLoading}
            onClick={() => setUsageDevice(null)}
          >
            Close
          </Button>
        }
      >
        <div className="mb-3 space-y-3 border-b border-border/70 pb-3">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
            <Input
              value={usageSearch}
              onChange={(e) => setUsageSearch(e.target.value)}
              placeholder="Search service or option"
              aria-label="Search usage"
              className="h-8 w-full sm:max-w-xs"
            />
            <Select
              aria-label="Filter by service"
              value={usageServiceFilter}
              onChange={(e) => setUsageServiceFilter(e.target.value)}
              className="sm:min-w-[10rem]"
            >
              {USAGE_SERVICE_FILTERS.map((opt) => (
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

          <div className="flex flex-col gap-2">
            <FilterChips
              options={USAGE_RANGE_FILTERS}
              value={usageRangePreset}
              onChange={(value) => {
                if (!usageDevice || usageLoading) return;
                const preset = value as UsageRangePreset;
                if (preset === 'custom') {
                  setUsageRangePreset('custom');
                  return;
                }
                applyUsageRange(usageDevice, preset);
              }}
            />
            <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-end">
              <label className="min-w-0 flex-1 space-y-1 text-xs text-muted-foreground">
                From
                <Input
                  type="datetime-local"
                  value={usageFromLocal}
                  disabled={usageLoading}
                  onChange={(e) => {
                    setUsageFromLocal(e.target.value);
                    setUsageRangePreset('custom');
                  }}
                  className="h-8"
                />
              </label>
              <label className="min-w-0 flex-1 space-y-1 text-xs text-muted-foreground">
                To
                <Input
                  type="datetime-local"
                  value={usageToLocal}
                  disabled={usageLoading}
                  onChange={(e) => {
                    setUsageToLocal(e.target.value);
                    setUsageRangePreset('custom');
                  }}
                  className="h-8"
                />
              </label>
              <Button
                type="button"
                variant="secondary"
                className="h-8 px-3"
                disabled={usageLoading || !usageDevice}
                onClick={() => {
                  if (!usageDevice) return;
                  applyUsageRange(usageDevice, 'custom', usageFromLocal, usageToLocal);
                }}
              >
                {usageLoading ? 'Loading…' : 'Apply'}
              </Button>
            </div>
          </div>
        </div>

        {usageError ? <p className="error mb-3">{usageError}</p> : null}

        {!usageLoading && usageRows.length > 0 ? (
          <div className="mb-3 flex flex-wrap items-baseline gap-x-5 gap-y-1 rounded-md border border-primary/10 bg-accent/50 px-3 py-2 text-sm">
            <div>
              <span className="text-muted-foreground">Total </span>
              <span className="font-medium tabular-nums">{usageStats.totalClicks}</span>
            </div>
            <div>
              <span className="text-muted-foreground">Active </span>
              <span className="font-medium tabular-nums">
                {usageStats.active}
                <span className="font-normal text-muted-foreground">/{usageRows.length}</span>
              </span>
            </div>
            <div className="min-w-0 truncate">
              <span className="text-muted-foreground">Top </span>
              <span className="font-medium">
                {usageStats.top && usageStats.top.count > 0
                  ? `${usageStats.top.label} (${usageStats.top.count})`
                  : '—'}
              </span>
            </div>
          </div>
        ) : null}

        {usageLoading ? (
          <p className="py-6 text-sm text-muted-foreground">Loading usage…</p>
        ) : usageRows.length === 0 ? (
          <EmptyState
            title="No service clicks yet"
            description="Counts appear after visitors open services on this kiosk."
          />
        ) : filteredUsageRows.length === 0 ? (
          <EmptyState
            title="No matches"
            description="Adjust search, service, date range, or show all rows."
          />
        ) : (
          <div className="overflow-x-auto rounded-md border border-border">
            <table className="table w-full">
              <thead>
                <tr>
                  <th>Service / option</th>
                  <th className="w-[42%]">Share</th>
                  <th className="w-24 text-right">Clicks</th>
                </tr>
              </thead>
              <tbody>
                {filteredUsageRows.map((row) => {
                  const share = usageMaxCount > 0 ? (row.count / usageMaxCount) * 100 : 0;
                  const pctOfTotal =
                    usageStats.totalClicks > 0
                      ? Math.round((row.count / usageStats.totalClicks) * 100)
                      : 0;
                  return (
                    <tr key={row.key} className={row.depth === 0 ? 'bg-muted/20' : undefined}>
                      <td
                        className={
                          row.depth === 1
                            ? 'border-l-2 border-border pl-7 text-sm text-muted-foreground'
                            : 'text-sm font-medium'
                        }
                      >
                        {row.label}
                      </td>
                      <td>
                        <div className="flex items-center gap-2">
                          <div className="h-1.5 min-w-0 flex-1 overflow-hidden rounded-full bg-muted">
                            <div
                              className={`h-full rounded-full ${row.depth === 0 ? 'bg-primary' : 'bg-primary/45'}`}
                              style={{ width: `${share}%` }}
                            />
                          </div>
                          <span className="w-8 shrink-0 text-right text-[11px] tabular-nums text-muted-foreground">
                            {row.count > 0 ? `${pctOfTotal}%` : ''}
                          </span>
                        </div>
                      </td>
                      <td className="text-right text-sm tabular-nums font-medium">{row.count}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Modal>
    </div>
  );
}

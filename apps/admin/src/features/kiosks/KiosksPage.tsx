import { useEffect, useRef, useState, type FormEvent } from 'react';
import {
  CloudUpload,
  PauseCircle,
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
  Input,
  Modal,
  PageHeader,
  Panel,
  StatusBadge,
} from '../../core/ui/primitives';
import {
  resolvePrinterErrorHistory,
  resolvePrinterMaintenance,
  resolvePrinterRowSummary,
  resolvePrinterStatus,
  type PrinterHealthView,
} from './printerMaintenance';
import {
  resolveRecordingDisplay,
  type SurveillanceHealth,
} from '../surveillance/surveillanceStatus';

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
  freeDisabledFromLocal?: string | null;
  freeDisabledToLocal?: string | null;
  bannerHorizontalEnabled?: boolean;
  bannerVerticalEnabled?: boolean;
  pagesLeft?: number | null;
};

function latestReportPaperOut(health: PrinterHealthView | null | undefined) {
  return health?.state === 'paper_out' || health?.noPaper === true;
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

const PRINTER_ROW_TONE: Record<string, string> = {
  muted: 'text-muted-foreground',
  ok: 'font-medium text-emerald-700',
  amber: 'font-medium text-amber-700',
  alert: 'font-medium text-red-700',
};

function PrinterSummaryCell({
  device,
  onDetails,
}: {
  device: Device;
  onDetails: () => void;
}) {
  const summary = resolvePrinterRowSummary(device.printerHealth);
  return (
    <div className="flex items-center gap-2 whitespace-nowrap text-sm">
      <span className={PRINTER_ROW_TONE[summary.tone]}>{summary.label}</span>
      <Button type="button" variant="secondary" onClick={onDetails}>
        Details
      </Button>
    </div>
  );
}

function PrinterMetricList({ rows }: { rows: { label: string; value: string }[] }) {
  return (
    <dl className="grid grid-cols-[9rem_1fr] gap-y-1 text-sm">
      {rows.map((row) => (
        <div key={row.label} className="contents">
          <dt className="text-muted-foreground">{row.label}</dt>
          <dd>{row.value}</dd>
        </div>
      ))}
    </dl>
  );
}

function usbPagesTotal(health: PrinterHealthView | null | undefined) {
  const total = health?.maintenance?.pages?.total;
  return typeof total === 'number' ? total : null;
}

function PrinterDetailsBody({
  health,
  pagesLeft,
  canEditTray,
  trayInput,
  onTrayInput,
  trayError,
  traySaving,
  onSaveTray,
}: {
  health: PrinterHealthView | null | undefined;
  pagesLeft: number | null;
  canEditTray: boolean;
  trayInput: string;
  onTrayInput: (value: string) => void;
  trayError: string | null;
  traySaving: boolean;
  onSaveTray: (mode: 'add' | 'replace') => void;
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

  return (
    <div className="stack">
      {stale ? (
        <p className="font-medium text-amber-700" title={staleTitle}>
          Stale
        </p>
      ) : null}
      <section className="stack">
        <h3 className="text-sm font-medium">Status</h3>
        <p className={`text-sm ${statusClass}`}>{printerStatus.label}</p>
      </section>
      <section className="stack">
        <h3 className="text-sm font-medium">Toner</h3>
        {maintenance.status === 'unavailable' ? (
          <p className="text-sm text-muted-foreground">Unavailable</p>
        ) : (
          <PrinterMetricList
            rows={[
              { label: 'Black', value: maintenance.toner.black },
              { label: 'Cyan', value: maintenance.toner.cyan },
              { label: 'Magenta', value: maintenance.toner.magenta },
              { label: 'Yellow', value: maintenance.toner.yellow },
            ]}
          />
        )}
      </section>
      <section className="stack">
        <h3 className="text-sm font-medium">Pages</h3>
        {maintenance.status === 'unavailable' ? (
          <p className="text-sm text-muted-foreground">Unavailable</p>
        ) : (
          <PrinterMetricList
            rows={[
              { label: 'Total', value: maintenance.pages.total },
              { label: 'Color', value: maintenance.pages.color },
              { label: 'Black and white', value: maintenance.pages.blackAndWhite },
              { label: 'Pages left', value: pagesLeft == null ? '—' : String(pagesLeft) },
            ]}
          />
        )}
        {maintenance.status === 'unavailable' ? (
          <p className="text-sm">
            Pages left <span className="text-muted-foreground">{pagesLeft == null ? '—' : pagesLeft}</span>
          </p>
        ) : null}
        {canEditTray ? (
          <div className="stack">
            <Input
              type="number"
              min={1}
              max={2000}
              inputMode="numeric"
              placeholder="Pages to load"
              value={trayInput}
              disabled={traySaving}
              onChange={(event) => onTrayInput(event.target.value)}
            />
            {usbPagesTotal(health) == null ? (
              <p className="text-sm text-muted-foreground">
                The printer page total is not available yet.
              </p>
            ) : null}
            {trayError ? <p className="error">{trayError}</p> : null}
            <div className="flex flex-wrap gap-2">
              <Button
                type="button"
                variant="secondary"
                disabled={traySaving || usbPagesTotal(health) == null}
                onClick={() => onSaveTray('add')}
              >
                Add to current
              </Button>
              <Button
                type="button"
                variant="secondary"
                disabled={traySaving || usbPagesTotal(health) == null}
                onClick={() => onSaveTray('replace')}
              >
                Replace tray
              </Button>
            </div>
          </div>
        ) : null}
      </section>
      <section className="stack">
        <h3 className="text-sm font-medium">Parts</h3>
        {maintenance.status === 'unavailable' ? (
          <p className="text-sm text-muted-foreground">Unavailable</p>
        ) : (
          <PrinterMetricList
            rows={[
              { label: 'Belt', value: maintenance.parts.belt },
              { label: 'Fuser', value: maintenance.parts.fuser },
            ]}
          />
        )}
      </section>
      <section className="stack">
        <h3 className="text-sm font-medium">Errors</h3>
        {errors.status === 'unavailable' ? (
          <p className="text-sm text-muted-foreground">Unavailable</p>
        ) : errors.status === 'empty' || errors.entries.length === 0 ? (
          <p className="text-sm text-muted-foreground">No recorded errors</p>
        ) : (
          <ul className="text-sm">
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

export function KiosksPage() {
  const { token } = useAuth();
  const [items, setItems] = useState<Device[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
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
    setAddOpen(true);
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
    setPrinterDeviceId(null);
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
          <div className="overflow-x-auto">
          <table className="table border-separate border-spacing-0">
            <thead>
              <tr>
                <th>Name</th>
                <th>Site</th>
                <th>Location</th>
                <th>Status</th>
                <th>Device key</th>
                <th>Last heartbeat</th>
                <th>Printer</th>
                <th>Recording</th>
                <th className="sticky right-0 z-20 w-52 border-l border-border bg-card">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody>
              {items.map((device) => (
                <tr key={device.id}>
                  <td className="font-medium">{device.name}</td>
                  <td>{device.siteName}</td>
                  <td>{formatLocation(device)}</td>
                  <td>
                    <StatusBadge status={device.status} />
                  </td>
                  <td>
                    <code className="break-all">{device.deviceKey}</code>
                  </td>
                  <td className="text-muted-foreground">
                    {device.lastHeartbeatAt
                      ? new Date(device.lastHeartbeatAt).toLocaleString()
                      : '—'}
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
                  <td className="sticky right-0 z-10 w-52 border-l border-border bg-card align-top">
                    <div className="flex w-full flex-col gap-2">
                      {device.status === 'inactive' ? (
                        <Button
                          type="button"
                          variant="secondary"
                          className="w-full"
                          disabled={submitting}
                          onClick={() => void onSetStatus(device, 'active')}
                        >
                          Start
                        </Button>
                      ) : (
                        <Button
                          type="button"
                          variant="danger"
                          className="w-full"
                          disabled={submitting}
                          onClick={() => void onSetStatus(device, 'inactive')}
                        >
                          Stop
                        </Button>
                      )}
                      <Button
                        type="button"
                        variant="secondary"
                        className="w-full"
                        disabled={submitting}
                        onClick={() => openSettings(device)}
                      >
                        <span className="inline-flex items-center gap-1.5">
                          <Settings className="h-4 w-4" />
                          Settings
                        </span>
                      </Button>
                      {device.printingPausedReason ? (
                        <>
                          <p className="text-sm font-medium text-red-700">Printing paused</p>
                          {latestReportPaperOut(device.printerHealth) ? (
                            <p className="text-xs text-muted-foreground">
                              The latest report still says out of paper.
                            </p>
                          ) : (
                            <p className="text-xs text-muted-foreground">
                              The latest report says paper is back.
                            </p>
                          )}
                          {canEnablePrinting ? (
                            <Button
                              type="button"
                              variant="secondary"
                              className="w-full"
                              disabled={submitting}
                              onClick={() => void onEnablePrinting(device)}
                            >
                              Enable printing
                            </Button>
                          ) : null}
                        </>
                      ) : null}
                      {device.surveillanceEnabled ? (
                        <Button
                          type="button"
                          variant="secondary"
                          className="w-full"
                          disabled={submitting || device.status === 'inactive'}
                          onClick={() => void onSetSurveillance(device, false)}
                        >
                          Stop surveillance
                        </Button>
                      ) : (
                        <Button
                          type="button"
                          variant="secondary"
                          className="w-full"
                          disabled={submitting || device.status === 'inactive'}
                          onClick={() => void onSetSurveillance(device, true)}
                        >
                          Start surveillance
                        </Button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          </div>
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
        {printerRefreshNote ? <p className="error">{printerRefreshNote}</p> : null}
        {printerDevice ? (
          <PrinterDetailsBody
            health={printerDevice.printerHealth}
            pagesLeft={printerDevice.pagesLeft ?? null}
            canEditTray={canEnablePrinting}
            trayInput={trayInput}
            onTrayInput={(value) => {
              setTrayInput(value);
              setTrayError(null);
            }}
            trayError={trayError}
            traySaving={traySaving}
            onSaveTray={(mode) => void saveTray(mode)}
          />
        ) : null}
      </Modal>
    </div>
  );
}

import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { Link, useParams } from 'react-router-dom';
import {
  Activity,
  Camera,
  Cpu,
  DoorOpen,
  Lightbulb,
  MonitorSmartphone,
  Printer,
  RefreshCw,
  Thermometer,
  Zap,
  type LucideIcon,
} from 'lucide-react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, PageHeader, Panel, StatusBadge } from '../../core/ui/primitives';
import { cn } from '@/lib/utils';
import {
  buildFleetRow,
  printerErrorEntries,
  type ComponentStatus,
  type ComponentTone,
  type FleetDevice,
} from './fleetHealth';
import { toneClass, toneLabel } from './healthUi';
import { resolveUploadBacklogWarning } from '../surveillance/surveillanceStatus';

function formatWhen(value?: string | null) {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
}

function formatMaybe(value: string | number | boolean | null | undefined) {
  if (value == null || value === '') return '—';
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  return String(value);
}

function DetailRow({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="grid grid-cols-[9rem_1fr] gap-2 border-b border-border/60 py-2 text-sm last:border-0">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="min-w-0 break-words font-medium text-foreground">{value}</dd>
    </div>
  );
}

function ComponentDetailCard({
  title,
  icon: Icon,
  status,
  children,
}: {
  title: string;
  icon: LucideIcon;
  status: ComponentStatus;
  children: ReactNode;
}) {
  return (
    <div className={cn('rounded-xl border p-4', toneClass(status.tone))}>
      <div className="mb-3 flex items-start justify-between gap-3">
        <div className="flex items-center gap-2">
          <span className="grid h-8 w-8 place-items-center rounded-lg bg-background/70">
            <Icon className="h-4 w-4" />
          </span>
          <div>
            <p className="text-sm font-semibold">{title}</p>
            <p className="text-xs opacity-80">{status.label}</p>
          </div>
        </div>
        <StatusBadge status={status.tone} />
      </div>
      {status.detail ? <p className="mb-3 text-sm opacity-90">{status.detail}</p> : null}
      <dl>{children}</dl>
    </div>
  );
}

export function FleetHealthDetailPage() {
  const { deviceId } = useParams<{ deviceId: string }>();
  const { token } = useAuth();
  const [device, setDevice] = useState<FleetDevice | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  async function load() {
    if (!deviceId) return;
    setLoading(true);
    try {
      const result = await apiRequest<{ items: FleetDevice[] }>('/devices', { token });
      const match = (result.items ?? []).find((item) => item.id === deviceId) ?? null;
      setDevice(match);
      setError(match ? null : 'Kiosk not found');
    } catch (err) {
      setDevice(null);
      setError(err instanceof Error ? err.message : 'Failed to load kiosk health');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(), 30_000);
    return () => window.clearInterval(timer);
  }, [token, deviceId]);

  const row = useMemo(() => (device ? buildFleetRow(device) : null), [device]);

  if (loading && !device) {
    return (
      <div>
        <PageHeader title="Kiosk health" subtitle="Loading component status…" />
      </div>
    );
  }

  if (!device || !row) {
    return (
      <div>
        <PageHeader title="Kiosk health" subtitle="Could not load this kiosk" />
        {error ? <p className="error mb-3">{error}</p> : null}
        <Link to="/fleet-health" className="text-sm font-medium text-primary hover:underline">
          Back to fleet health
        </Link>
      </div>
    );
  }

  const printer = device.printerHealth;
  const camera = device.surveillanceHealth;
  const cameraBacklog = resolveUploadBacklogWarning(camera);
  const hw = device.hardwareHealth;
  const overallTone: ComponentTone = row.overall;
  const printerErrors = printerErrorEntries(printer);

  return (
    <div>
      <PageHeader
        title={device.name}
        subtitle={`${device.siteName} · full component health`}
        actions={
          <div className="flex flex-wrap gap-2">
            <Button type="button" variant="secondary" disabled={loading} onClick={() => void load()}>
              <RefreshCw className={cn('h-4 w-4', loading && 'animate-spin')} />
              Refresh
            </Button>
            <Link
              to="/kiosks"
              className="inline-flex h-9 items-center rounded-md border border-input px-3 text-sm hover:bg-accent"
            >
              Manage kiosk
            </Link>
            <Link
              to="/fleet-health"
              className="inline-flex h-9 items-center rounded-md border border-input px-3 text-sm hover:bg-accent"
            >
              Back to fleet
            </Link>
          </div>
        }
      />

      {error ? <p className="error mb-3">{error}</p> : null}

      {!device.hardwareHealth ? (
        <div className="mb-4 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-950">
          <p className="font-medium">ESP32 / shutter / light / charging / sensors not reported yet</p>
          <p className="mt-1 text-amber-900/90">
            Printer and camera are updating, but this kiosk has not sent a hardware heartbeat.
            {device.reportedAppVersion &&
            device.activeAppVersion &&
            device.reportedAppVersion !== device.activeAppVersion
              ? ` App is ${device.reportedAppVersion} (fleet target ${device.activeAppVersion}) — rebuild and restart the kiosk so hardware status appears.`
              : ' Rebuild/restart the kiosk app, wait for the next heartbeat (~1 min), then refresh.'}
          </p>
        </div>
      ) : null}

      <Panel title="Overview">
        <div className="mb-4 flex flex-wrap items-center gap-3">
          <StatusBadge status={overallTone} />
          <span className="text-sm text-muted-foreground">{toneLabel(overallTone)}</span>
        </div>
        <dl className="max-w-2xl">
          <DetailRow label="Site" value={device.siteName} />
          <DetailRow label="Device status" value={<StatusBadge status={device.status} />} />
          <DetailRow label="Device key" value={device.deviceKey ?? '—'} />
          <DetailRow label="Address" value={device.address || '—'} />
          <DetailRow label="Last heartbeat" value={formatWhen(device.lastHeartbeatAt)} />
          <DetailRow label="Printer snapshot" value={formatWhen(device.printerHealthAt)} />
          <DetailRow label="Camera snapshot" value={formatWhen(device.surveillanceHealthAt)} />
          <DetailRow label="Hardware snapshot" value={formatWhen(device.hardwareHealthAt)} />
        </dl>
      </Panel>

      {printerErrors.length > 0 ? (
        <Panel title={`Printer errors · ${printerErrors.length}`}>
          <ol className="space-y-2">
            {printerErrors.map((entry, i) => (
              <li
                key={`${entry.index}-${entry.description}`}
                className="flex gap-3 rounded-lg border border-red-200 bg-red-50 px-3 py-2.5"
              >
                <span className="mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full bg-red-100 text-xs font-semibold text-red-800">
                  {i + 1}
                </span>
                <div className="min-w-0">
                  <p className="text-sm font-medium text-red-950">{entry.description}</p>
                  <p className="mt-0.5 text-xs text-muted-foreground">Printer log #{entry.index}</p>
                </div>
              </li>
            ))}
          </ol>
        </Panel>
      ) : null}

      <div className="mb-4 grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
        <ComponentDetailCard title="Connectivity" icon={MonitorSmartphone} status={row.connectivity}>
          <DetailRow label="Online" value={formatMaybe(row.online)} />
          <DetailRow label="Device status" value={device.status} />
          <DetailRow label="Last heartbeat" value={formatWhen(device.lastHeartbeatAt)} />
        </ComponentDetailCard>

        <ComponentDetailCard title="Printer" icon={Printer} status={row.printer}>
          <DetailRow label="State" value={printer?.state ?? '—'} />
          <DetailRow label="Online" value={formatMaybe(printer?.online)} />
          <DetailRow label="Name" value={printer?.printerName ?? '—'} />
          <DetailRow label="Model" value={printer?.model ?? '—'} />
          <DetailRow label="SNMP reachable" value={formatMaybe(printer?.snmpReachable ?? printer?.snmpOk)} />
          <DetailRow label="Paper out" value={formatMaybe(printer?.noPaper)} />
          <DetailRow label="Jam" value={formatMaybe(printer?.jammed)} />
          <DetailRow label="HR status" value={printer?.hrPrinterStatusLabel ?? '—'} />
          <DetailRow label="Spooler queued" value={formatMaybe(printer?.spoolerJobsQueued)} />
          <DetailRow label="Spooler printing" value={formatMaybe(printer?.spoolerJobsPrinting)} />
          <DetailRow label="Pages left (tray)" value={formatMaybe(device.pagesLeft)} />
          <DetailRow label="Tray available" value={formatMaybe(device.trayAvailable)} />
          <DetailRow label="Tray reserved" value={formatMaybe(device.trayReserved)} />
          <DetailRow
            label="Recorded errors"
            value={
              printerErrors.length === 0
                ? 'None'
                : printerErrors.map((entry) => entry.description).join(' · ')
            }
          />
          <DetailRow
            label="Toner black"
            value={
              printer?.maintenance?.toner?.blackPercent != null
                ? `${printer.maintenance.toner.blackPercent}%`
                : '—'
            }
          />
          <DetailRow
            label="Pages total"
            value={formatMaybe(printer?.maintenance?.pages?.total)}
          />
          <DetailRow label="Print paused" value={device.printingPausedReason?.replace(/_/g, ' ') ?? '—'} />
          <DetailRow label="Last success" value={formatWhen(printer?.lastSuccessAt)} />
          <DetailRow label="Last error" value={printer?.lastPollError || printer?.lastErrorCode || '—'} />
          <DetailRow label="Error at" value={formatWhen(printer?.lastErrorAt)} />
        </ComponentDetailCard>

        <ComponentDetailCard title="Camera" icon={Camera} status={row.camera}>
          <DetailRow label="Enabled" value={formatMaybe(device.surveillanceEnabled)} />
          <DetailRow label="State" value={camera?.state ?? '—'} />
          <DetailRow label="Recording" value={formatMaybe(camera?.recording)} />
          <DetailRow label="Camera name" value={camera?.cameraName ?? '—'} />
          <DetailRow label="Queue pending" value={formatMaybe(camera?.queuePending)} />
          <DetailRow label="Queue failed" value={formatMaybe(camera?.queueFailed)} />
          <DetailRow label="Oldest queued" value={formatWhen(camera?.oldestQueuedAt)} />
          <DetailRow
            label="Backlog"
            value={
              cameraBacklog.warn
                ? `Warning${cameraBacklog.ageLabel ? ` · oldest ${cameraBacklog.ageLabel}` : ''}`
                : cameraBacklog.pending > 0
                  ? 'Pending'
                  : 'Clear'
            }
          />
          <DetailRow label="Last segment" value={formatWhen(camera?.lastSegmentAt)} />
          <DetailRow
            label="Last segment size"
            value={
              camera?.lastSegmentBytes != null
                ? `${Math.round(camera.lastSegmentBytes / 1024)} KB`
                : '—'
            }
          />
          <DetailRow label="Last error" value={camera?.lastErrorCode ?? '—'} />
          <DetailRow label="Error at" value={formatWhen(camera?.lastErrorAt)} />
          <DetailRow label="Snapshot at" value={formatWhen(device.surveillanceHealthAt)} />
        </ComponentDetailCard>

        <ComponentDetailCard title="ESP32 / serial" icon={Cpu} status={row.controller}>
          {hw?.serial ? (
            <>
              <DetailRow label="Status" value={hw.serial.status ?? '—'} />
              <DetailRow label="Port" value={hw.serial.portName ?? '—'} />
              <DetailRow label="Last error" value={hw.serial.lastError ?? '—'} />
              <DetailRow label="Snapshot at" value={formatWhen(device.hardwareHealthAt)} />
              <DetailRow
                label="Note"
                value="Shared by shutter, cabinet light, charging, and well-being sensors"
              />
            </>
          ) : (
            <DetailRow
              label="Status"
              value="Not reported — restart kiosk app after updating to a build that sends hardware heartbeats"
            />
          )}
        </ComponentDetailCard>

        <ComponentDetailCard title="Shutter" icon={DoorOpen} status={row.shutter}>
          <DetailRow label="Status" value={hw?.shutter?.status ?? (device.shutterCommand ? 'pending' : 'Not reported')} />
          <DetailRow label="Pending command" value={device.shutterCommand ?? hw?.shutter?.pendingCommand ?? '—'} />
          <DetailRow label="Command requested" value={formatWhen(device.shutterCommandRequestedAt)} />
          <DetailRow label="Last error" value={hw?.shutter?.lastError ?? '—'} />
        </ComponentDetailCard>

        <ComponentDetailCard title="Cabinet light" icon={Lightbulb} status={row.light}>
          <DetailRow label="Status" value={hw?.cabinetLight?.status ?? 'Not reported'} />
          <DetailRow label="Relay on" value={formatMaybe(hw?.cabinetLight?.on)} />
          <DetailRow label="Last error" value={hw?.cabinetLight?.lastError ?? '—'} />
        </ComponentDetailCard>

        <ComponentDetailCard title="Charging" icon={Zap} status={row.charging}>
          <DetailRow label="Status" value={hw?.charging?.status ?? 'Not reported'} />
          <DetailRow label="Sensor OK" value={formatMaybe(hw?.charging?.sensorOk)} />
          <DetailRow label="Phase" value={hw?.charging?.phase ?? '—'} />
          <DetailRow label="Last error" value={hw?.charging?.lastError ?? '—'} />
        </ComponentDetailCard>

        <ComponentDetailCard title="Sensors" icon={Thermometer} status={row.sensors}>
          <DetailRow label="Overall" value={hw?.sensors?.status ?? 'Not reported'} />
          <DetailRow label="MAX30102 (SpO₂ / HR)" value={hw?.sensors?.max30102 ?? '—'} />
          <DetailRow label="MLX90614 (temperature)" value={hw?.sensors?.mlx90614 ?? '—'} />
          <DetailRow label="Last error" value={hw?.sensors?.lastError ?? '—'} />
        </ComponentDetailCard>

        <ComponentDetailCard title="App version" icon={Activity} status={row.app}>
          <DetailRow label="Reported" value={device.reportedAppVersion ?? '—'} />
          <DetailRow label="Fleet target" value={device.activeAppVersion ?? '—'} />
          <DetailRow
            label="Match"
            value={
              device.reportedAppVersion && device.activeAppVersion
                ? device.reportedAppVersion === device.activeAppVersion
                  ? 'Up to date'
                  : 'Behind'
                : '—'
            }
          />
        </ComponentDetailCard>
      </div>
    </div>
  );
}

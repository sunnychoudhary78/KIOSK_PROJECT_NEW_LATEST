import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  Activity,
  Camera,
  Cpu,
  DoorOpen,
  Lightbulb,
  MonitorSmartphone,
  Printer,
  ChevronRight,
  RefreshCw,
  Thermometer,
  Zap,
} from 'lucide-react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  EmptyState,
  FilterChips,
  PageHeader,
  Panel,
  StatusBadge,
  Toolbar,
} from '../../core/ui/primitives';
import { cn } from '@/lib/utils';
import {
  buildFleetRow,
  summarizeFleet,
  type ComponentStatus,
  type ComponentTone,
  type FleetDevice,
} from './fleetHealth';
import { toneClass } from './healthUi';

const HEALTH_FILTERS = [
  { value: 'all', label: 'All kiosks' },
  { value: 'unhealthy', label: 'Problems' },
  { value: 'offline', label: 'Offline' },
  { value: 'online', label: 'Online' },
];

function HealthChip({ status }: { status: ComponentStatus }) {
  return (
    <div
      className={cn(
        'min-w-[7.5rem] rounded-md border px-2 py-1.5',
        toneClass(status.tone),
      )}
      title={status.detail}
    >
      <p className="text-[10px] font-medium uppercase tracking-wide opacity-70">{status.label}</p>
      {status.detail ? (
        <p className="mt-0.5 truncate text-[11px] opacity-80">{status.detail}</p>
      ) : null}
    </div>
  );
}

function SummaryCard({
  label,
  value,
  hint,
  tone = 'unknown',
}: {
  label: string;
  value: number | string;
  hint?: string;
  tone?: ComponentTone;
}) {
  return (
    <div className={cn('stat-card border', toneClass(tone))}>
      <strong className="!text-inherit">{value}</strong>
      <span className="!text-inherit opacity-80">{label}</span>
      {hint ? <p className="mt-1 text-[11px] opacity-70">{hint}</p> : null}
    </div>
  );
}

export function FleetHealthPage() {
  const { token } = useAuth();
  const navigate = useNavigate();
  const [devices, setDevices] = useState<FleetDevice[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [healthFilter, setHealthFilter] = useState('all');
  const [updatedAt, setUpdatedAt] = useState<Date | null>(null);

  async function load() {
    setLoading(true);
    try {
      const result = await apiRequest<{ items: FleetDevice[] }>('/devices', { token });
      setDevices(result.items ?? []);
      setUpdatedAt(new Date());
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load fleet health');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(), 30_000);
    return () => window.clearInterval(timer);
  }, [token]);

  const rows = useMemo(() => devices.map((device) => buildFleetRow(device)), [devices]);
  const summary = useMemo(() => summarizeFleet(rows), [rows]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return rows.filter((row) => {
      if (healthFilter === 'online' && !row.online) return false;
      if (healthFilter === 'offline' && row.online) return false;
      if (
        healthFilter === 'unhealthy' &&
        row.overall !== 'error' &&
        row.overall !== 'offline' &&
        row.overall !== 'warn'
      ) {
        return false;
      }
      if (!q) return true;
      return (
        row.device.name.toLowerCase().includes(q) ||
        row.device.siteName.toLowerCase().includes(q)
      );
    });
  }, [rows, search, healthFilter]);

  return (
    <div>
      <PageHeader
        title="Fleet health"
        subtitle="All kiosks — click any row to open full component status (printer, camera, ESP32, shutter, light, charging, sensors, app)"
        actions={
          <Button type="button" variant="secondary" disabled={loading} onClick={() => void load()}>
            <RefreshCw className={cn('h-4 w-4', loading && 'animate-spin')} />
            Refresh
          </Button>
        }
      />

      {error ? <p className="error mb-3">{error}</p> : null}
      {updatedAt ? (
        <p className="mb-3 text-xs text-muted-foreground">
          Updated {updatedAt.toLocaleTimeString()} · auto-refresh every 30s
        </p>
      ) : null}

      <div className="mb-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-8">
        <SummaryCard label="Kiosks" value={summary.total} tone="unknown" />
        <SummaryCard label="Online" value={summary.online} tone="ok" />
        <SummaryCard label="Offline" value={summary.offline} tone={summary.offline ? 'error' : 'ok'} />
        <SummaryCard
          label="Problems"
          value={summary.unhealthy + summary.warn}
          tone={summary.unhealthy ? 'error' : summary.warn ? 'warn' : 'ok'}
        />
        <SummaryCard
          label="Printer faults"
          value={summary.printerFaults}
          tone={summary.printerFaults ? 'error' : 'ok'}
        />
        <SummaryCard
          label="Camera faults"
          value={summary.cameraFaults}
          tone={summary.cameraFaults ? 'error' : 'ok'}
        />
        <SummaryCard
          label="Controller issues"
          value={summary.controllerFaults}
          tone={summary.controllerFaults ? 'error' : 'ok'}
        />
        <SummaryCard
          label="Version lag"
          value={summary.versionLag}
          tone={summary.versionLag ? 'warn' : 'ok'}
        />
      </div>

      <Panel title="Component legend">
        <div className="flex flex-wrap gap-4 text-sm text-muted-foreground">
          <span className="inline-flex items-center gap-1.5">
            <MonitorSmartphone className="h-3.5 w-3.5" /> Connectivity
          </span>
          <span className="inline-flex items-center gap-1.5">
            <Printer className="h-3.5 w-3.5" /> Printer
          </span>
          <span className="inline-flex items-center gap-1.5">
            <Camera className="h-3.5 w-3.5" /> Camera
          </span>
          <span className="inline-flex items-center gap-1.5">
            <Cpu className="h-3.5 w-3.5" /> ESP32 / serial
          </span>
          <span className="inline-flex items-center gap-1.5">
            <DoorOpen className="h-3.5 w-3.5" /> Shutter
          </span>
          <span className="inline-flex items-center gap-1.5">
            <Lightbulb className="h-3.5 w-3.5" /> Cabinet light
          </span>
          <span className="inline-flex items-center gap-1.5">
            <Zap className="h-3.5 w-3.5" /> Charging
          </span>
          <span className="inline-flex items-center gap-1.5">
            <Thermometer className="h-3.5 w-3.5" /> Sensors
          </span>
          <span className="inline-flex items-center gap-1.5">
            <Activity className="h-3.5 w-3.5" /> App version
          </span>
        </div>
      </Panel>

      <Panel>
        <Toolbar
          search={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search kiosk or site"
        >
          <FilterChips
            options={HEALTH_FILTERS}
            value={healthFilter}
            onChange={setHealthFilter}
          />
        </Toolbar>

        {filtered.length === 0 ? (
          <EmptyState
            title={devices.length === 0 ? 'No kiosks yet' : 'No matches'}
            description={
              devices.length === 0
                ? 'Register a kiosk first. Health appears after the device starts heartbeating.'
                : 'Adjust filters or search.'
            }
            action={
              devices.length === 0 ? (
                <Link to="/kiosks" className="text-sm font-medium text-primary hover:underline">
                  Go to Kiosks
                </Link>
              ) : undefined
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="table w-full min-w-[76rem]">
              <thead>
                <tr>
                  <th>Kiosk</th>
                  <th>Overall</th>
                  <th>Link</th>
                  <th>Printer</th>
                  <th>Camera</th>
                  <th>Controller</th>
                  <th>Shutter</th>
                  <th>Light</th>
                  <th>Charging</th>
                  <th>Sensors</th>
                  <th>App</th>
                  <th className="w-[1%] whitespace-nowrap"> </th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((row) => (
                  <tr
                    key={row.device.id}
                    className="cursor-pointer transition-colors hover:bg-accent/50"
                    onClick={() => navigate(`/fleet-health/${row.device.id}`)}
                  >
                    <td>
                      <Link
                        to={`/fleet-health/${row.device.id}`}
                        className="font-medium text-foreground hover:text-primary hover:underline"
                        onClick={(event) => event.stopPropagation()}
                      >
                        {row.device.name}
                      </Link>
                      <p className="text-xs text-muted-foreground">{row.device.siteName}</p>
                    </td>
                    <td>
                      <StatusBadge status={row.overall} />
                    </td>
                    <td>
                      <HealthChip status={row.connectivity} />
                    </td>
                    <td>
                      <HealthChip status={row.printer} />
                    </td>
                    <td>
                      <HealthChip status={row.camera} />
                    </td>
                    <td>
                      <HealthChip status={row.controller} />
                    </td>
                    <td>
                      <HealthChip status={row.shutter} />
                    </td>
                    <td>
                      <HealthChip status={row.light} />
                    </td>
                    <td>
                      <HealthChip status={row.charging} />
                    </td>
                    <td>
                      <HealthChip status={row.sensors} />
                    </td>
                    <td>
                      <HealthChip status={row.app} />
                    </td>
                    <td className="text-right">
                      <span className="inline-flex items-center gap-1 text-xs font-medium text-primary">
                        Open
                        <ChevronRight className="h-3.5 w-3.5" />
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Panel>
    </div>
  );
}

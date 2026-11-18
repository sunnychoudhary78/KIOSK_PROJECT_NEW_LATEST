import { useEffect, useMemo, useState } from 'react';
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

type ServiceStatus = 'available' | 'under_maintenance' | 'out_of_service';

type PlatformService = {
  code: string;
  name: string;
  description?: string;
  enabled: boolean;
  status?: ServiceStatus;
};

const HOME_SERVICE_CODES = [
  'print',
  'local_services',
  'well_being',
  'phone_charging',
  'astrology',
  'fuel_stations',
] as const;

const STATUS_OPTIONS: Array<{ value: ServiceStatus; label: string }> = [
  { value: 'available', label: 'Available' },
  { value: 'under_maintenance', label: 'Under maintenance' },
  { value: 'out_of_service', label: 'Out of service' },
];

const STATUS_FILTERS = [
  { value: 'all', label: 'All' },
  { value: 'available', label: 'Available' },
  { value: 'under_maintenance', label: 'Maintenance' },
  { value: 'out_of_service', label: 'Out of service' },
];

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

function resolveStatus(service: PlatformService): ServiceStatus {
  return service.status ?? (service.enabled ? 'available' : 'out_of_service');
}

export function ServicesPage() {
  const { token } = useAuth();
  const role = roleFromToken(token);
  const canEdit = role === 'admin' || role === 'operator';
  const [items, setItems] = useState<PlatformService[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [savingCode, setSavingCode] = useState<string | null>(null);

  async function load() {
    try {
      const result = await apiRequest<{ items: PlatformService[] }>('/services', { token });
      setItems(result.items ?? []);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load services');
    }
  }

  useEffect(() => {
    void load();
  }, [token]);

  const homeItems = useMemo(
    () =>
      HOME_SERVICE_CODES.map((code) => items.find((item) => item.code === code)).filter(
        (item): item is PlatformService => item != null,
      ),
    [items],
  );

  const otherItems = useMemo(
    () => items.filter((item) => !(HOME_SERVICE_CODES as readonly string[]).includes(item.code)),
    [items],
  );

  const filteredHome = useMemo(() => {
    const q = search.trim().toLowerCase();
    return homeItems.filter((service) => {
      const status = resolveStatus(service);
      if (statusFilter !== 'all' && status !== statusFilter) return false;
      if (!q) return true;
      return [service.name, service.code, service.description ?? ''].join(' ').toLowerCase().includes(q);
    });
  }, [homeItems, search, statusFilter]);

  const filteredOther = useMemo(() => {
    const q = search.trim().toLowerCase();
    return otherItems.filter((service) => {
      const status = resolveStatus(service);
      if (statusFilter !== 'all' && status !== statusFilter) return false;
      if (!q) return true;
      return [service.name, service.code, service.description ?? ''].join(' ').toLowerCase().includes(q);
    });
  }, [otherItems, search, statusFilter]);

  async function onStatusChange(service: PlatformService, status: ServiceStatus) {
    if (!canEdit || savingCode) return;
    setSavingCode(service.code);
    setNote(null);
    setError(null);
    try {
      const updated = await apiRequest<PlatformService>(`/services/${service.code}/status`, {
        method: 'PATCH',
        token,
        body: { status },
      });
      setItems((prev) =>
        prev.map((item) => {
          if (item.code === updated.code) return { ...item, ...updated };
          if (service.code === 'print' && ['otp_print', 'quick_print', 'digilocker_print'].includes(item.code)) {
            return { ...item, status };
          }
          return item;
        }),
      );
      setNote(
        `${updated.name} set to ${STATUS_OPTIONS.find((opt) => opt.value === status)?.label ?? status}`,
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update service status');
    } finally {
      setSavingCode(null);
    }
  }

  function renderCard(service: PlatformService) {
    const status = resolveStatus(service);
    return (
      <div key={service.code} className="rounded-xl border border-border p-4">
        <div className="mb-2 flex items-start justify-between gap-3">
          <p className="font-semibold">{service.name}</p>
          <StatusBadge status={status} />
        </div>
        <p className="mb-2 font-mono text-xs text-muted-foreground">{service.code}</p>
        {service.description ? (
          <p className="mb-3 text-sm text-muted-foreground">{service.description}</p>
        ) : null}
        {canEdit ? (
          <div className="flex flex-wrap items-center gap-2">
            <Select
              aria-label={`${service.name} status`}
              value={status}
              disabled={savingCode === service.code}
              onChange={(event) => void onStatusChange(service, event.target.value as ServiceStatus)}
              className="min-w-[12rem]"
            >
              {STATUS_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </Select>
            {savingCode === service.code ? (
              <span className="text-xs text-muted-foreground">Saving…</span>
            ) : null}
          </div>
        ) : null}
      </div>
    );
  }

  return (
    <div>
      <PageHeader
        title="Services"
        subtitle="Mark home services Available, Under maintenance, or Out of service — kiosks show the status on each tile"
        actions={
          <Button type="button" variant="secondary" onClick={() => void load()}>
            Refresh
          </Button>
        }
      />
      <Panel>
        <Toolbar search={search} onSearchChange={setSearch} searchPlaceholder="Search services">
          <FilterChips options={STATUS_FILTERS} value={statusFilter} onChange={setStatusFilter} />
        </Toolbar>
        {error ? <p className="error mb-3">{error}</p> : null}
        {note ? <p className="mb-3 text-sm text-muted-foreground">{note}</p> : null}

        <h3 className="mb-3 text-sm font-medium">Home screen services</h3>
        {filteredHome.length === 0 && !error ? (
          <EmptyState
            title={homeItems.length === 0 ? 'No home services yet' : 'No matches'}
            description={
              homeItems.length === 0
                ? 'Run API seed / migrate so print, well being, charging, and other home services exist.'
                : 'Adjust filters or search.'
            }
          />
        ) : (
          <div className="mb-6 grid gap-3 md:grid-cols-2">{filteredHome.map(renderCard)}</div>
        )}

        {filteredOther.length > 0 ? (
          <>
            <h3 className="mb-3 text-sm font-medium">Other platform services</h3>
            <div className="grid gap-3 md:grid-cols-2">{filteredOther.map(renderCard)}</div>
          </>
        ) : null}
      </Panel>
    </div>
  );
}

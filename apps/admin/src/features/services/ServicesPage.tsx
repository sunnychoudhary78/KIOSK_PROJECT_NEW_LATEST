import { useEffect, useMemo, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  EmptyState,
  FilterChips,
  PageHeader,
  Panel,
  StatusBadge,
  Toolbar,
} from '../../core/ui/primitives';

type PlatformService = {
  code: string;
  name: string;
  description?: string;
  enabled: boolean;
};

const STATUS_FILTERS = [
  { value: 'all', label: 'All' },
  { value: 'enabled', label: 'Enabled' },
  { value: 'disabled', label: 'Disabled' },
];

export function ServicesPage() {
  const { token } = useAuth();
  const [items, setItems] = useState<PlatformService[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  useEffect(() => {
    void (async () => {
      try {
        const result = await apiRequest<{ items: PlatformService[] }>('/services', { token });
        setItems(result.items);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load services');
      }
    })();
  }, [token]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter((service) => {
      if (statusFilter === 'enabled' && !service.enabled) return false;
      if (statusFilter === 'disabled' && service.enabled) return false;
      if (!q) return true;
      const haystack = [service.name, service.code, service.description ?? '']
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [items, search, statusFilter]);

  return (
    <div>
      <PageHeader title="Services" subtitle="Platform service catalog" />
      <Panel>
        <Toolbar
          search={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search services"
        >
          <FilterChips
            options={STATUS_FILTERS}
            value={statusFilter}
            onChange={setStatusFilter}
          />
        </Toolbar>
        {error ? <p className="error">{error}</p> : null}
        {filtered.length === 0 && !error ? (
          <EmptyState
            title={items.length === 0 ? 'No services' : 'No matches'}
            description={
              items.length === 0
                ? 'The service catalog is empty.'
                : 'Adjust filters or search.'
            }
          />
        ) : (
          <div className="grid gap-3 md:grid-cols-2">
            {filtered.map((service) => (
              <div key={service.code} className="rounded-xl border border-border p-4">
                <div className="mb-2 flex items-start justify-between gap-3">
                  <p className="font-semibold">{service.name}</p>
                  <StatusBadge status={service.enabled ? 'active' : 'inactive'} />
                </div>
                <p className="mb-2 font-mono text-xs text-muted-foreground">{service.code}</p>
                {service.description ? (
                  <p className="text-sm text-muted-foreground">{service.description}</p>
                ) : null}
              </div>
            ))}
          </div>
        )}
      </Panel>
    </div>
  );
}

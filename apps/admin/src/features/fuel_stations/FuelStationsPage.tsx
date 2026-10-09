import { useEffect, useMemo, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { EmptyState, Input, PageHeader, Panel, StatusBadge } from '../../core/ui/primitives';
import { cn } from '@/lib/utils';

type CatalogKind = 'all' | 'fuel' | 'cng' | 'ev';

type CatalogCounts = {
  all: number;
  fuel: number;
  cng: number;
  ev: number;
};

type CatalogStation = {
  id: string;
  osmId: string;
  name: string | null;
  address: string | null;
  latitude: number;
  longitude: number;
  petrol: boolean;
  diesel: boolean;
  cng: boolean;
  ev: boolean;
  fuelUntyped: boolean;
  googlePlaceId: string | null;
  isActive: boolean;
  lastSeenAt: string;
};

const KIND_CHIPS: Array<{ kind: CatalogKind; label: string }> = [
  { kind: 'all', label: 'All' },
  { kind: 'fuel', label: 'Fuel' },
  { kind: 'cng', label: 'CNG' },
  { kind: 'ev', label: 'EV' },
];

function categoryLabels(station: CatalogStation): string {
  const labels = [
    ...(station.petrol ? ['Petrol'] : []),
    ...(station.diesel ? ['Diesel'] : []),
    ...(station.cng ? ['CNG'] : []),
    ...(station.ev ? ['EV'] : []),
    ...(station.fuelUntyped ? ['Fuel'] : []),
  ];
  return labels.length > 0 ? labels.join(', ') : '—';
}

export function FuelStationsPage() {
  const { token } = useAuth();
  const [kind, setKind] = useState<CatalogKind>('all');
  const [q, setQ] = useState('');
  const [debouncedQ, setDebouncedQ] = useState('');
  const [items, setItems] = useState<CatalogStation[]>([]);
  const [counts, setCounts] = useState<CatalogCounts>({ all: 0, fuel: 0, cng: 0, ev: 0 });
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedQ(q.trim()), 250);
    return () => window.clearTimeout(timer);
  }, [q]);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      setLoading(true);
      try {
        const params = new URLSearchParams({ kind, active: 'true' });
        if (debouncedQ) {
          params.set('q', debouncedQ);
        }
        const result = await apiRequest<{ items: CatalogStation[]; counts: CatalogCounts }>(
          `/fuel-stations/catalog?${params.toString()}`,
          { token },
        );
        if (cancelled) {
          return;
        }
        setItems(result.items);
        setCounts(result.counts);
        setError(null);
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : 'Failed to load stations');
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token, kind, debouncedQ]);

  const subtitle = useMemo(() => {
    return `${counts.all} active stations in the master catalog (Fuel ${counts.fuel}, CNG ${counts.cng}, EV ${counts.ev})`;
  }, [counts]);

  return (
    <div>
      <PageHeader title="Fuel stations" subtitle={subtitle} />
      <Panel>
        <div className="mb-4 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div className="flex flex-wrap gap-2">
            {KIND_CHIPS.map((chip) => {
              const selected = kind === chip.kind;
              const count = counts[chip.kind];
              return (
                <button
                  key={chip.kind}
                  type="button"
                  onClick={() => setKind(chip.kind)}
                  className={cn(
                    'rounded-full border px-3 py-1.5 text-sm font-medium transition-colors',
                    selected
                      ? 'border-primary bg-primary text-primary-foreground'
                      : 'border-border bg-background text-muted-foreground hover:bg-muted',
                  )}
                >
                  {chip.label} ({count})
                </button>
              );
            })}
          </div>
          <div className="w-full md:max-w-xs">
            <Input
              value={q}
              onChange={(event) => setQ(event.target.value)}
              placeholder="Search name or address"
            />
          </div>
        </div>

        {error ? <p className="error mb-3">{error}</p> : null}

        {loading ? (
          <p className="text-sm text-muted-foreground">Loading stations…</p>
        ) : items.length === 0 && !error ? (
          <EmptyState
            title="No stations"
            description="Nothing matched this filter. Run the OSM sync if the catalog is empty."
          />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Categories</th>
                <th>Address</th>
                <th>Coords</th>
                <th>Google place id</th>
                <th>Active</th>
                <th>Last seen</th>
              </tr>
            </thead>
            <tbody>
              {items.map((station) => (
                <tr key={station.id}>
                  <td className="font-medium">{station.name ?? '—'}</td>
                  <td>{categoryLabels(station)}</td>
                  <td className="text-muted-foreground">{station.address ?? '—'}</td>
                  <td className="font-mono text-xs">
                    {station.latitude.toFixed(5)}, {station.longitude.toFixed(5)}
                  </td>
                  <td className="font-mono text-xs text-muted-foreground">
                    {station.googlePlaceId ?? '—'}
                  </td>
                  <td>
                    <StatusBadge status={station.isActive ? 'active' : 'inactive'} />
                  </td>
                  <td className="text-muted-foreground">
                    {new Date(station.lastSeenAt).toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}

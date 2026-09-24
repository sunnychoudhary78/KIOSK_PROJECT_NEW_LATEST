import { useEffect, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { EmptyState, PageHeader, Panel, StatusBadge } from '../../core/ui/primitives';

type PlatformService = {
  code: string;
  name: string;
  description?: string;
  enabled: boolean;
};

export function ServicesPage() {
  const { token } = useAuth();
  const [items, setItems] = useState<PlatformService[]>([]);
  const [error, setError] = useState<string | null>(null);

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

  return (
    <div>
      <PageHeader title="Services" subtitle="Platform service catalog" />
      <Panel>
        {error ? <p className="error">{error}</p> : null}
        {items.length === 0 && !error ? (
          <EmptyState title="No services" description="The service catalog is empty." />
        ) : (
          <div className="grid gap-3 md:grid-cols-2">
            {items.map((service) => (
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

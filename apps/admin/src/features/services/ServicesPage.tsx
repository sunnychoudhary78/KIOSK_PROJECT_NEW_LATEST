import { useEffect, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { PageHeader, Panel } from '../../core/ui/primitives';

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
        <ul className="list">
          {items.map((service) => (
            <li key={service.code}>
              <strong>{service.name}</strong> <code>{service.code}</code>
              <div>{service.description}</div>
            </li>
          ))}
        </ul>
      </Panel>
    </div>
  );
}

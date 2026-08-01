import { useEffect, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { PageHeader, Panel } from '../../core/ui/primitives';

type AuditLog = {
  id: string;
  action: string;
  principalType: string;
  correlationId: string | null;
  createdAt: string;
};

export function AuditLogsPage() {
  const { token } = useAuth();
  const [items, setItems] = useState<AuditLog[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void (async () => {
      try {
        const result = await apiRequest<{ items: AuditLog[] }>('/audit-logs', { token });
        setItems(result.items);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load audit logs');
      }
    })();
  }, [token]);

  return (
    <div>
      <PageHeader title="Audit logs" subtitle="Security and operations trail" />
      <Panel>
        {error ? <p className="error">{error}</p> : null}
        <table className="table">
          <thead>
            <tr>
              <th>Action</th>
              <th>Principal</th>
              <th>Correlation</th>
              <th>When</th>
            </tr>
          </thead>
          <tbody>
            {items.map((log) => (
              <tr key={log.id}>
                <td>{log.action}</td>
                <td>{log.principalType}</td>
                <td>{log.correlationId ?? '—'}</td>
                <td>{new Date(log.createdAt).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Panel>
    </div>
  );
}

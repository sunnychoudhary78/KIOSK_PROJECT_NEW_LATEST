import { useEffect, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { EmptyState, PageHeader, Panel, StatusBadge } from '../../core/ui/primitives';

type PrintJob = {
  id: string;
  status: string;
  source: string;
  title: string;
  printColorMode?: 'bw' | 'color';
  createdAt: string;
};

export function PrintJobsPage() {
  const { token } = useAuth();
  const [items, setItems] = useState<PrintJob[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void (async () => {
      try {
        const result = await apiRequest<{ items: PrintJob[] }>('/print-jobs', { token });
        setItems(result.items);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load print jobs');
      }
    })();
  }, [token]);

  return (
    <div>
      <PageHeader title="Print jobs" subtitle="OTP and DigiLocker print activity" />
      <Panel>
        {error ? <p className="error">{error}</p> : null}
        {items.length === 0 && !error ? (
          <EmptyState
            title="No print jobs yet"
            description="OTP uploads and DigiLocker prints will appear here when a kiosk queues them."
          />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Title</th>
                <th>Source</th>
                <th>Color</th>
                <th>Status</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {items.map((job) => (
                <tr key={job.id}>
                  <td className="font-medium">{job.title}</td>
                  <td className="capitalize">{job.source.replace(/_/g, ' ')}</td>
                  <td>{job.printColorMode === 'color' ? 'Color' : 'B/W'}</td>
                  <td>
                    <StatusBadge status={job.status} />
                  </td>
                  <td className="text-muted-foreground">
                    {new Date(job.createdAt).toLocaleString()}
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

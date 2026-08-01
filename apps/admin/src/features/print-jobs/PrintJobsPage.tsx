import { useEffect, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { PageHeader, Panel } from '../../core/ui/primitives';

type PrintJob = {
  id: string;
  status: string;
  source: string;
  title: string;
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
        <table className="table">
          <thead>
            <tr>
              <th>Title</th>
              <th>Source</th>
              <th>Status</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {items.map((job) => (
              <tr key={job.id}>
                <td>{job.title}</td>
                <td>{job.source}</td>
                <td>{job.status}</td>
                <td>{new Date(job.createdAt).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Panel>
    </div>
  );
}

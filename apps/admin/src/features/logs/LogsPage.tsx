import { useCallback } from 'react';
import { useSearchParams } from 'react-router-dom';
import { FilterChips, PageHeader } from '../../core/ui/primitives';
import { AuditLogsPanel } from './AuditLogsPanel';
import { DiagnosticLogsPanel } from './DiagnosticLogsPanel';
import { PrintJobsPanel } from './PrintJobsPanel';

const LOG_TABS = [
  { value: 'diagnostics', label: 'Diagnostics' },
  { value: 'audit', label: 'Audit' },
  { value: 'print-jobs', label: 'Print jobs' },
] as const;

type LogTab = (typeof LOG_TABS)[number]['value'];

function parseTab(raw: string | null): LogTab {
  if (raw === 'audit' || raw === 'print-jobs' || raw === 'diagnostics') {
    return raw;
  }
  return 'diagnostics';
}

export function LogsPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const tab = parseTab(searchParams.get('tab'));
  const deviceId = searchParams.get('deviceId') ?? '';

  const setTab = useCallback(
    (next: LogTab) => {
      setSearchParams(
        (prev) => {
          const params = new URLSearchParams(prev);
          params.set('tab', next);
          if (next !== 'diagnostics') {
            params.delete('deviceId');
          }
          return params;
        },
        { replace: true },
      );
    },
    [setSearchParams],
  );

  const setDeviceId = useCallback(
    (next: string) => {
      setSearchParams(
        (prev) => {
          const params = new URLSearchParams(prev);
          params.set('tab', 'diagnostics');
          if (next) {
            params.set('deviceId', next);
          } else {
            params.delete('deviceId');
          }
          return params;
        },
        { replace: true },
      );
    },
    [setSearchParams],
  );

  return (
    <div>
      <PageHeader
        title="Logs"
        subtitle="Kiosk diagnostics, audit trail, and print jobs in one place"
      />
      <div className="mb-4">
        <FilterChips
          options={[...LOG_TABS]}
          value={tab}
          onChange={(value) => setTab(value as LogTab)}
        />
      </div>
      {tab === 'diagnostics' ? (
        <DiagnosticLogsPanel deviceId={deviceId} onDeviceIdChange={setDeviceId} />
      ) : null}
      {tab === 'audit' ? <AuditLogsPanel /> : null}
      {tab === 'print-jobs' ? <PrintJobsPanel /> : null}
    </div>
  );
}

import { PageHeader, Panel } from '../../core/ui/primitives';

export function DigiLockerPage() {
  return (
    <div>
      <PageHeader
        title="DigiLocker"
        subtitle="Session visibility for DigiLocker print flows"
      />
      <Panel>
        <p>
          DigiLocker sessions are initiated on kiosk devices. Use Print jobs and Audit logs to
          trace document print requests. Detailed session listing can be extended when ops needs
          a dedicated view.
        </p>
      </Panel>
    </div>
  );
}

import { PageHeader, Panel } from '../../core/ui/primitives';

export function UsersPage() {
  return (
    <div>
      <PageHeader title="Users" subtitle="Admin and operator accounts" />
      <Panel>
        <p>
          Seeded admin: <code>admin@smartkiosk.local</code>. User management APIs can be expanded
          in a later iteration without changing the feature layout.
        </p>
      </Panel>
    </div>
  );
}

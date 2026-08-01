import { Navigate, Outlet, NavLink } from 'react-router-dom';
import { useAuth } from '../core/auth/auth-context';
import { Button } from '../core/ui/primitives';
import { config } from '../core/config';

export function AppShell() {
  const auth = useAuth();

  if (!auth.token) {
    return <Navigate to="/login" replace />;
  }

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">{config.appName}</div>
        <nav className="nav">
          <NavLink to="/">Dashboard</NavLink>
          <NavLink to="/kiosks">Kiosks</NavLink>
          <div className="nav-section">Ads</div>
          <NavLink to="/advertisers">Advertisers</NavLink>
          <NavLink to="/campaigns">Campaigns</NavLink>
          <div className="nav-section">Operations</div>
          <NavLink to="/services">Services</NavLink>
          <NavLink to="/print-jobs">Print jobs</NavLink>
          <NavLink to="/digilocker">DigiLocker</NavLink>
          <NavLink to="/audit-logs">Audit logs</NavLink>
          <NavLink to="/users">Users</NavLink>
          <NavLink to="/platform-settings">Platform settings</NavLink>
        </nav>
        <Button type="button" onClick={auth.logout}>
          Sign out
        </Button>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}

import { useEffect, useState } from 'react';
import { Navigate, Outlet, NavLink, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  MonitorSmartphone,
  Megaphone,
  Clapperboard,
  AppWindow,
  Fuel,
  Printer,
  LifeBuoy,
  Gauge,
  Phone,
  Siren,
  Fingerprint,
  Video,
  ScrollText,
  Users,
  Settings,
  Lightbulb,
  Wrench,
  Package,
  LogOut,
  Menu,
  PanelLeft,
  PanelLeftClose,
} from 'lucide-react';
import { apiRequest } from '../core/api/client';
import { useAuth } from '../core/auth/auth-context';
import { config } from '../core/config';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Sheet, SheetContent } from '@/components/ui/sheet';
import { cn } from '@/lib/utils';

const NAV = [
  {
    label: 'Overview',
    items: [
      { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
      { to: '/kiosks', label: 'Kiosks', icon: MonitorSmartphone },
      { to: '/kiosk-updates', label: 'Kiosk updates', icon: Package },
    ],
  },
  {
    label: 'Ads',
    items: [
      { to: '/advertisers', label: 'Advertisers', icon: Megaphone },
      { to: '/campaigns', label: 'Campaigns', icon: Clapperboard },
    ],
  },
  {
    label: 'Operations',
    items: [
      { to: '/services', label: 'Services', icon: AppWindow },
      { to: '/find-services', label: 'Find services', icon: Wrench },
      { to: '/cabinet-light', label: 'Cabinet light', icon: Lightbulb },
      { to: '/fuel-stations', label: 'Fuel stations', icon: Fuel },
      { to: '/print-jobs', label: 'Print jobs', icon: Printer },
      { to: '/support', label: 'Support', icon: LifeBuoy },
      { to: '/print-quota', label: 'Free print usage', icon: Gauge },
      { to: '/society-phones', label: 'Society phones', icon: Phone },
      { to: '/emergency-contacts', label: 'Emergency helplines', icon: Siren },
      { to: '/digilocker', label: 'DigiLocker', icon: Fingerprint },
      { to: '/recordings', label: 'Recordings', icon: Video },
      { to: '/audit-logs', label: 'Audit logs', icon: ScrollText },
      { to: '/users', label: 'Users', icon: Users },
      { to: '/platform-settings', label: 'Settings', icon: Settings },
    ],
  },
];

const PAGE_TITLES: Array<{ prefix: string; title: string }> = [
  { prefix: '/advertisers', title: 'Advertisers' },
  { prefix: '/campaigns', title: 'Campaigns' },
  { prefix: '/kiosk-updates', title: 'Kiosk updates' },
  { prefix: '/kiosks', title: 'Kiosks' },
  { prefix: '/find-services', title: 'Find services' },
  { prefix: '/cabinet-light', title: 'Cabinet light' },
  { prefix: '/services', title: 'Services' },
  { prefix: '/fuel-stations', title: 'Fuel stations' },
  { prefix: '/print-jobs', title: 'Print jobs' },
  { prefix: '/support', title: 'Support' },
  { prefix: '/print-quota', title: 'Free print usage' },
  { prefix: '/society-phones', title: 'Society phones' },
  { prefix: '/emergency-contacts', title: 'Emergency helplines' },
  { prefix: '/digilocker', title: 'DigiLocker' },
  { prefix: '/recordings', title: 'Recordings' },
  { prefix: '/audit-logs', title: 'Audit logs' },
  { prefix: '/users', title: 'Users' },
  { prefix: '/platform-settings', title: 'Platform settings' },
  { prefix: '/', title: 'Dashboard' },
];

function pageTitle(pathname: string) {
  const match = PAGE_TITLES.find((item) =>
    item.prefix === '/' ? pathname === '/' : pathname.startsWith(item.prefix),
  );
  return match?.title ?? 'Admin';
}

function initials(email: string | null) {
  if (!email) return 'SK';
  return email.slice(0, 2).toUpperCase();
}

function SidebarNav({
  onNavigate,
  openSupportCount,
}: {
  onNavigate?: () => void;
  openSupportCount: number;
}) {
  return (
    <nav
      className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto overscroll-contain px-3 py-3"
      style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
    >
      {NAV.map((section) => (
        <div key={section.label}>
          <p className="mb-1.5 text-[10px] font-medium tracking-[0.14em] text-sidebar-foreground/50 uppercase">
            {section.label}
          </p>
          <div className="flex flex-col gap-0.5">
            {section.items.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                onClick={onNavigate}
                className={({ isActive }) =>
                  cn(
                    'flex items-center gap-2.5 rounded-md px-2 py-1.5 text-[13px] transition-colors',
                    isActive
                      ? 'bg-sidebar-accent font-medium text-sidebar-primary'
                      : 'text-sidebar-foreground/80 hover:bg-sidebar-accent/70 hover:text-sidebar-accent-foreground',
                  )
                }
              >
                <item.icon className="h-3.5 w-3.5 shrink-0 opacity-70" strokeWidth={1.75} />
                <span className="min-w-0 flex-1 truncate leading-none">{item.label}</span>
                {item.to === '/support' && openSupportCount > 0 ? (
                  <span className="inline-flex min-w-5 items-center justify-center rounded-full bg-sidebar-primary px-1.5 text-[10px] font-medium text-sidebar">
                    {openSupportCount}
                  </span>
                ) : null}
              </NavLink>
            ))}
          </div>
        </div>
      ))}
    </nav>
  );
}

function Brand() {
  return (
    <div className="shrink-0 px-3 py-4">
      <div className="mb-2 h-1.5 w-8 rounded-full bg-sidebar-primary" />
      <p className="truncate text-sm font-medium text-sidebar-accent-foreground">{config.appName}</p>
      <p className="text-xs text-sidebar-foreground/70">Admin</p>
    </div>
  );
}

function SidebarBody({
  onNavigate,
  openSupportCount,
}: {
  onNavigate?: () => void;
  openSupportCount: number;
}) {
  return (
    <div className="flex h-full min-h-0 flex-col">
      <Brand />
      <div className="mx-3 shrink-0 border-t border-sidebar-border" />
      <SidebarNav onNavigate={onNavigate} openSupportCount={openSupportCount} />
    </div>
  );
}

const SIDEBAR_STORAGE_KEY = 'skp-sidebar-open';

export function AppShell() {
  const auth = useAuth();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(() => {
    try {
      return localStorage.getItem(SIDEBAR_STORAGE_KEY) !== '0';
    } catch {
      return true;
    }
  });
  const [openSupportCount, setOpenSupportCount] = useState(0);

  useEffect(() => {
    try {
      localStorage.setItem(SIDEBAR_STORAGE_KEY, sidebarOpen ? '1' : '0');
    } catch {
      /* ignore */
    }
  }, [sidebarOpen]);

  useEffect(() => {
    if (!auth.token) return;
    let cancelled = false;
    async function loadCount() {
      try {
        const result = await apiRequest<{ openCount: number }>('/support-queries?status=open', {
          token: auth.token,
        });
        if (!cancelled) setOpenSupportCount(result.openCount);
      } catch {
        if (!cancelled) setOpenSupportCount(0);
      }
    }
    void loadCount();
    window.addEventListener('skp-support-changed', loadCount);
    return () => {
      cancelled = true;
      window.removeEventListener('skp-support-changed', loadCount);
    };
  }, [auth.token]);

  if (!auth.token) {
    return <Navigate to="/login" replace />;
  }

  return (
    <div className="flex h-dvh max-h-dvh overflow-hidden bg-background">
      <aside
        className={cn(
          'skp-sidebar hidden h-full shrink-0 flex-col overflow-hidden border-r border-sidebar-border bg-sidebar text-sidebar-foreground transition-[width] duration-200 lg:flex',
          sidebarOpen ? 'w-48' : 'pointer-events-none w-0 border-r-0',
        )}
        aria-hidden={!sidebarOpen}
      >
        <div className="flex h-full w-48 min-w-48 flex-col">
          <SidebarBody openSupportCount={openSupportCount} />
        </div>
      </aside>

      <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
        <SheetContent className="skp-sidebar w-56 overflow-hidden p-0">
          <SidebarBody openSupportCount={openSupportCount} onNavigate={() => setMobileOpen(false)} />
        </SheetContent>
      </Sheet>

      <div className="flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden">
        <header className="z-20 flex h-12 shrink-0 items-center justify-between gap-3 border-b border-border bg-card/80 px-3 lg:px-6">
          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="lg:hidden"
              onClick={() => setMobileOpen(true)}
            >
              <Menu className="h-4 w-4" />
              <span className="sr-only">Open navigation</span>
            </Button>
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="hidden lg:inline-flex"
              onClick={() => setSidebarOpen((open) => !open)}
              aria-pressed={sidebarOpen}
              title={sidebarOpen ? 'Close sidebar' : 'Open sidebar'}
            >
              {sidebarOpen ? <PanelLeftClose className="h-4 w-4" /> : <PanelLeft className="h-4 w-4" />}
              <span className="sr-only">{sidebarOpen ? 'Close sidebar' : 'Open sidebar'}</span>
            </Button>
            <p className="text-sm text-muted-foreground">{pageTitle(location.pathname)}</p>
          </div>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" className="h-8 gap-2 px-1.5">
                <Avatar className="h-7 w-7">
                  <AvatarFallback className="text-[10px]">{initials(auth.email)}</AvatarFallback>
                </Avatar>
                <span className="hidden max-w-40 truncate text-left text-sm sm:block">
                  {auth.email ?? 'Admin'}
                </span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuLabel>{auth.email ?? 'Signed in'}</DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={auth.logout}>
                <LogOut className="h-4 w-4" />
                Sign out
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </header>

        <main className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-3 py-5 lg:px-6 lg:py-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}

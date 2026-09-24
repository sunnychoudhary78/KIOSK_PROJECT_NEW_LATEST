import { useState } from 'react';
import { Navigate, Outlet, NavLink, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  MonitorSmartphone,
  Megaphone,
  Clapperboard,
  AppWindow,
  Printer,
  Fingerprint,
  Video,
  ScrollText,
  Users,
  Settings,
  LogOut,
  Menu,
  Monitor,
} from 'lucide-react';
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
import { Separator } from '@/components/ui/separator';
import { Sheet, SheetContent } from '@/components/ui/sheet';
import { cn } from '@/lib/utils';

const NAV = [
  {
    label: 'Overview',
    items: [
      { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
      { to: '/kiosks', label: 'Kiosks', icon: MonitorSmartphone },
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
      { to: '/print-jobs', label: 'Print jobs', icon: Printer },
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
  { prefix: '/kiosks', title: 'Kiosks' },
  { prefix: '/services', title: 'Services' },
  { prefix: '/print-jobs', title: 'Print jobs' },
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

function SidebarNav({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <nav className="flex flex-1 flex-col gap-6 overflow-y-auto px-3 py-4">
      {NAV.map((section) => (
        <div key={section.label}>
          <p className="mb-2 px-2 text-[11px] font-semibold tracking-[0.12em] text-sidebar-foreground/45 uppercase">
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
                    'flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-sm font-medium transition-colors',
                    isActive
                      ? 'bg-sidebar-accent text-sidebar-accent-foreground'
                      : 'text-sidebar-foreground/75 hover:bg-sidebar-accent/70 hover:text-sidebar-accent-foreground',
                  )
                }
              >
                <item.icon className="h-4 w-4 shrink-0 opacity-80" />
                {item.label}
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
    <div className="flex items-center gap-2.5 px-5 py-5">
      <div className="grid h-9 w-9 place-items-center rounded-lg bg-sidebar-primary text-sidebar">
        <Monitor className="h-4 w-4" />
      </div>
      <div className="min-w-0">
        <p className="truncate text-sm font-semibold text-sidebar-foreground">{config.appName}</p>
        <p className="text-xs text-sidebar-foreground/50">Operator console</p>
      </div>
    </div>
  );
}

function SidebarBody({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <>
      <Brand />
      <Separator className="bg-sidebar-border" />
      <SidebarNav onNavigate={onNavigate} />
    </>
  );
}

export function AppShell() {
  const auth = useAuth();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);

  if (!auth.token) {
    return <Navigate to="/login" replace />;
  }

  return (
    <div className="flex min-h-screen bg-background">
      <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col bg-sidebar text-sidebar-foreground lg:flex">
        <SidebarBody />
      </aside>

      <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
        <SheetContent className="p-0">
          <SidebarBody onNavigate={() => setMobileOpen(false)} />
        </SheetContent>
      </Sheet>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-20 flex h-16 items-center justify-between gap-3 border-b border-border bg-background/90 px-4 backdrop-blur lg:px-8">
          <div className="flex items-center gap-3">
            <Button
              type="button"
              variant="outline"
              size="icon"
              className="lg:hidden"
              onClick={() => setMobileOpen(true)}
            >
              <Menu className="h-4 w-4" />
              <span className="sr-only">Open navigation</span>
            </Button>
            <div>
              <p className="text-sm font-semibold">{pageTitle(location.pathname)}</p>
              <p className="hidden text-xs text-muted-foreground sm:block">Smart Kiosk Platform</p>
            </div>
          </div>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" className="h-auto gap-2 px-2 py-1.5">
                <Avatar>
                  <AvatarFallback>{initials(auth.email)}</AvatarFallback>
                </Avatar>
                <span className="hidden max-w-48 truncate text-left text-sm font-medium sm:block">
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

        <main className="flex-1 px-4 py-6 lg:px-8 lg:py-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}

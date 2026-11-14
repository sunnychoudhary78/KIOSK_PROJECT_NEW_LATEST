import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode, SelectHTMLAttributes } from 'react';
import { Badge } from '@/components/ui/badge';
import { Button as UiButton } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input as UiInput } from '@/components/ui/input';
import { cn } from '@/lib/utils';

export function PageHeader({
  title,
  subtitle,
  actions,
}: {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}) {
  return (
    <header className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0 space-y-1">
        <h1 className="text-xl font-medium tracking-tight">{title}</h1>
        {subtitle ? <p className="max-w-2xl text-sm leading-5 text-muted-foreground">{subtitle}</p> : null}
      </div>
      {actions ? <div className="flex shrink-0 flex-wrap items-center gap-2 sm:pt-0.5">{actions}</div> : null}
    </header>
  );
}

export function Panel({
  children,
  title,
  actions,
  className,
}: {
  children: ReactNode;
  title?: string;
  actions?: ReactNode;
  className?: string;
}) {
  return (
    <Card className={cn('mb-4 last:mb-0', className)}>
      {title || actions ? (
        <CardHeader className="flex-row items-center justify-between space-y-0 pb-3">
          {title ? <CardTitle>{title}</CardTitle> : <span />}
          {actions ? <div className="flex flex-wrap gap-2">{actions}</div> : null}
        </CardHeader>
      ) : null}
      <CardContent className={title || actions ? undefined : 'pt-4'}>{children}</CardContent>
    </Card>
  );
}

const BUTTON_VARIANTS = {
  primary: 'default',
  secondary: 'outline',
  ghost: 'ghost',
  danger: 'destructive',
} as const;

export function Button({
  variant = 'primary',
  className = '',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: keyof typeof BUTTON_VARIANTS;
}) {
  return <UiButton variant={BUTTON_VARIANTS[variant]} className={className} {...props} />;
}

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return <UiInput className={className} {...props} />;
}

export function Select({ className, ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={cn(
        'flex h-8 w-auto min-w-[8.5rem] rounded-md border border-input bg-card px-2.5 py-1 text-sm shadow-none outline-none ring-0 focus-visible:border-primary focus-visible:outline-none focus-visible:ring-0 disabled:cursor-not-allowed disabled:opacity-50',
        className,
      )}
      {...props}
    />
  );
}

function badgeVariant(status: string): 'success' | 'destructive' | 'warning' | 'muted' | 'secondary' {
  const value = status.toLowerCase();
  if (['active', 'ready', 'printed', 'completed', 'paid', 'resolved', 'on'].includes(value)) return 'success';
  if (value === 'open') return 'warning';
  if (['inactive', 'ended', 'failed', 'expired', 'not_configured'].includes(value)) return 'destructive';
  if (['paused', 'draft', 'scheduled', 'printing'].includes(value)) return 'warning';
  if (['off'].includes(value)) return 'muted';
  return 'secondary';
}

export function StatusBadge({ status }: { status: string }) {
  const label = status.replace(/_/g, ' ');
  return <Badge variant={badgeVariant(status)}>{label}</Badge>;
}

export function Toolbar({
  children,
  search,
  onSearchChange,
  searchPlaceholder = 'Search…',
  actions,
}: {
  children?: ReactNode;
  search?: string;
  onSearchChange?: (value: string) => void;
  searchPlaceholder?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-4 flex flex-col gap-2.5 border-b border-border/70 pb-3">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        {onSearchChange ? (
          <Input
            value={search ?? ''}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder={searchPlaceholder}
            aria-label="Search"
            className="h-8 w-full sm:max-w-xs"
          />
        ) : (
          <span />
        )}
        {actions ? <div className="flex shrink-0 flex-wrap items-center gap-2">{actions}</div> : null}
      </div>
      {children ? (
        <div className="flex flex-wrap items-center gap-x-3 gap-y-2">{children}</div>
      ) : null}
    </div>
  );
}

export function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-start justify-center px-1 py-8">
      <h3 className="text-sm font-medium">{title}</h3>
      {description ? <p className="mt-1 max-w-lg text-sm text-muted-foreground">{description}</p> : null}
      {action ? <div className="mt-3">{action}</div> : null}
    </div>
  );
}

function splitModalTitle(title: string): { heading: string; subtitle?: string } {
  const sep = ' · ';
  const idx = title.indexOf(sep);
  if (idx <= 0) return { heading: title };
  return {
    heading: title.slice(0, idx).trim(),
    subtitle: title.slice(idx + sep.length).trim() || undefined,
  };
}

export function Modal({
  open,
  title,
  description,
  onClose,
  children,
  footer,
  className,
}: {
  open: boolean;
  title: string;
  description?: string;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
  className?: string;
}) {
  const { heading, subtitle } = splitModalTitle(title);

  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent
        className={cn(
          'flex max-h-[min(92vh,56rem)] flex-col overflow-hidden sm:max-h-[min(90vh,56rem)]',
          className,
        )}
      >
        <DialogHeader className="shrink-0">
          <DialogTitle>{heading}</DialogTitle>
          {subtitle || description ? (
            <p className="text-sm text-muted-foreground">{description ?? subtitle}</p>
          ) : null}
        </DialogHeader>
        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">{children}</div>
        {footer ? <DialogFooter className="shrink-0">{footer}</DialogFooter> : null}
      </DialogContent>
    </Dialog>
  );
}

export function Stepper({
  steps,
  current,
}: {
  steps: string[];
  current: number;
}) {
  return (
    <ol className="mb-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      {steps.map((label, index) => {
        const state = index < current ? 'done' : index === current ? 'active' : 'todo';
        return (
          <li key={label} className="flex items-center gap-2.5 text-sm">
            <span
              className={cn(
                'grid h-7 w-7 shrink-0 place-items-center rounded-full border text-xs font-semibold',
                state === 'active' && 'border-primary bg-primary text-primary-foreground',
                state === 'done' && 'border-primary/30 bg-accent text-accent-foreground',
                state === 'todo' && 'border-border bg-background text-muted-foreground',
              )}
            >
              {index + 1}
            </span>
            <span className={cn(state === 'todo' ? 'text-muted-foreground' : 'font-medium')}>{label}</span>
          </li>
        );
      })}
    </ol>
  );
}

export function FilterChips({
  options,
  value,
  onChange,
}: {
  options: Array<{ value: string; label: string }>;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <div className="flex flex-wrap gap-1">
      {options.map((opt) => (
        <button
          key={opt.value}
          type="button"
          className={cn(
            'rounded-md border px-2 py-1 text-xs transition-colors',
            value === opt.value
              ? 'border-primary/25 bg-primary text-primary-foreground'
              : 'border-transparent bg-transparent text-muted-foreground hover:bg-accent hover:text-accent-foreground',
          )}
          onClick={() => onChange(opt.value)}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}

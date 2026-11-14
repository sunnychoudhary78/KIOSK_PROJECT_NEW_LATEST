import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const badgeVariants = cva(
  'inline-flex items-center rounded-md border px-1.5 py-0.5 text-[11px] font-medium capitalize transition-colors',
  {
    variants: {
      variant: {
        default: 'border-transparent bg-primary text-primary-foreground',
        secondary: 'border-primary/15 bg-secondary text-secondary-foreground',
        destructive: 'border-transparent bg-destructive/10 text-destructive',
        outline: 'border-border text-foreground',
        success: 'border-transparent bg-success text-success-foreground',
        warning: 'border-transparent bg-warning text-warning-foreground',
        muted: 'border-transparent bg-muted text-muted-foreground',
      },
    },
    defaultVariants: {
      variant: 'secondary',
    },
  },
);

function Badge({
  className,
  variant,
  ...props
}: React.ComponentProps<'span'> & VariantProps<typeof badgeVariants>) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />;
}

export { Badge, badgeVariants };

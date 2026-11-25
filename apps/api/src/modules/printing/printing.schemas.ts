import { z } from 'zod';

export const printJobReconcileStatuses = [
  'pending',
  'verified',
  'partial',
  'reconciliation_required',
  'unknown',
] as const;

export const updatePrintJobStatusSchema = z.object({
  status: z.enum(['printing', 'completed', 'failed']),
  errorMessage: z.string().max(500).optional(),
  pagesReported: z.number().int().min(0).optional(),
  spoolerJobId: z.string().max(120).optional(),
  pageCounterBefore: z.number().int().min(0).optional(),
  pageCounterAfter: z.number().int().min(0).optional(),
  reconcileStatus: z.enum(printJobReconcileStatuses).optional(),
  reconcileDetail: z.string().max(500).optional(),
  needsAdminReview: z.boolean().optional(),
  holdForRetry: z.boolean().optional(),
});

export const printJobSupportSchema = z
  .object({
    /** Required with phone for “didn’t receive print” complaints. */
    name: z.string().trim().min(1).max(80).optional(),
    phone: z
      .string()
      .trim()
      .regex(/^\d{10}$/, 'Phone must be a 10-digit mobile number')
      .optional(),
    message: z.string().trim().min(1).max(500),
  })
  .superRefine((value, ctx) => {
    const hasName = Boolean(value.name?.trim());
    const hasPhone = Boolean(value.phone);
    if (hasName !== hasPhone) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Name and phone are both required for print complaints',
        path: hasName ? ['phone'] : ['name'],
      });
    }
  });

const dateOnly = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const printJobsSummaryQuerySchema = z.object({
  deviceId: z.string().uuid().optional(),
  from: dateOnly.optional(),
  to: dateOnly.optional(),
});

export type UpdatePrintJobStatusInput = z.infer<typeof updatePrintJobStatusSchema>;
export type PrintJobsSummaryQuery = z.infer<typeof printJobsSummaryQuerySchema>;

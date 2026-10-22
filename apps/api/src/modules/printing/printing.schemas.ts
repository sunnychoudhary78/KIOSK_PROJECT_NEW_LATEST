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
});

export type UpdatePrintJobStatusInput = z.infer<typeof updatePrintJobStatusSchema>;

import { z } from 'zod';

export const updatePrintJobStatusSchema = z.object({
  status: z.enum(['printing', 'completed', 'failed']),
  errorMessage: z.string().max(500).optional(),
});

export type UpdatePrintJobStatusInput = z.infer<typeof updatePrintJobStatusSchema>;

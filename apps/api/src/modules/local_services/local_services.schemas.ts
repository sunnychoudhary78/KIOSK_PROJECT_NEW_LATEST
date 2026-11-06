import { z } from 'zod';

export const createLocalServiceCategorySchema = z.object({
  name: z.string().trim().min(1).max(80),
  sortOrder: z.number().int().min(0).max(10_000).optional(),
});

export const createLocalServiceContactSchema = z.object({
  name: z.string().trim().min(1).max(80),
  phone: z
    .string()
    .trim()
    .regex(/^\d{10}$/, 'Phone must be a 10-digit mobile number'),
});

export type CreateLocalServiceCategoryBody = z.infer<typeof createLocalServiceCategorySchema>;
export type CreateLocalServiceContactBody = z.infer<typeof createLocalServiceContactSchema>;

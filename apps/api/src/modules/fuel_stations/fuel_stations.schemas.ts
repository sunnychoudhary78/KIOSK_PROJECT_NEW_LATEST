import { z } from 'zod';

export const fuelStationsQuerySchema = z.object({
  kind: z.enum(['all', 'fuel', 'cng', 'ev']).default('all'),
  limit: z.coerce.number().int().min(1).max(50).default(30),
});

export type FuelStationsQuery = z.infer<typeof fuelStationsQuerySchema>;

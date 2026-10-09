import { z } from 'zod';

export const fuelStationsQuerySchema = z.object({
  kind: z.enum(['all', 'fuel', 'cng', 'ev']).default('all'),
  limit: z.coerce.number().int().min(1).max(50).default(30),
});

export type FuelStationsQuery = z.infer<typeof fuelStationsQuerySchema>;

export const fuelStationsCatalogQuerySchema = z.object({
  kind: z.enum(['all', 'fuel', 'cng', 'ev']).default('all'),
  q: z.string().trim().max(80).optional(),
  active: z.enum(['all', 'true', 'false']).default('true'),
});

export type FuelStationsCatalogQuery = z.infer<typeof fuelStationsCatalogQuerySchema>;

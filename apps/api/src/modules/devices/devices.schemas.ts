import { z } from 'zod';

export const registerDeviceSchema = z.object({
  name: z.string().min(2).max(120),
  siteName: z.string().min(2).max(120),
  tenantId: z.string().uuid().optional(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  address: z.string().trim().max(240).optional(),
});

export type RegisterDeviceInput = z.infer<typeof registerDeviceSchema>;

export const nearbyDevicesQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export type NearbyDevicesQuery = z.infer<typeof nearbyDevicesQuerySchema>;

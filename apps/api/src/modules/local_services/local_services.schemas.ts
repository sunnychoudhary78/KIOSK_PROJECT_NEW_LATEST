import { z } from 'zod';

export const DEFAULT_LOCAL_SERVICE_RADIUS_KM = 5;
/** Kiosk still lists providers out to this range (sorted after true nearby). */
export const KIOSK_LOCAL_SERVICE_EXTENDED_RADIUS_KM = 50;

export const createLocalServiceCategorySchema = z.object({
  name: z.string().trim().min(1).max(80),
  sortOrder: z.number().int().min(0).max(10_000).optional(),
});

export const setLocalServiceCategoryStatusSchema = z.object({
  isActive: z.boolean(),
});

const phoneSchema = z
  .string()
  .trim()
  .regex(/^\d{10}$/, 'Phone must be a 10-digit mobile number');

const ratingSchema = z.number().min(0).max(5);
const addressSchema = z.string().trim().max(240).nullable().optional();
const latSchema = z.number().min(-90).max(90).nullable().optional();
const lngSchema = z.number().min(-180).max(180).nullable().optional();

export const createLocalServiceContactSchema = z
  .object({
    name: z.string().trim().min(1).max(80),
    phone: phoneSchema,
    rating: ratingSchema.optional(),
    pinned: z.boolean().optional(),
    address: addressSchema,
    latitude: latSchema,
    longitude: lngSchema,
  })
  .superRefine((value, ctx) => {
    const hasLat = value.latitude != null;
    const hasLng = value.longitude != null;
    if (hasLat !== hasLng) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Latitude and longitude must both be set (or both empty)',
        path: hasLat ? ['longitude'] : ['latitude'],
      });
    }
  });

export const updateLocalServiceContactSchema = z
  .object({
    name: z.string().trim().min(1).max(80).optional(),
    phone: phoneSchema.optional(),
    rating: ratingSchema.optional(),
    pinned: z.boolean().optional(),
    address: addressSchema,
    latitude: latSchema,
    longitude: lngSchema,
    clearPhoto: z.boolean().optional(),
  })
  .refine(
    (body) =>
      body.name !== undefined ||
      body.phone !== undefined ||
      body.rating !== undefined ||
      body.pinned !== undefined ||
      body.address !== undefined ||
      body.latitude !== undefined ||
      body.longitude !== undefined ||
      body.clearPhoto === true,
    { message: 'Provide at least one field to update' },
  )
  .superRefine((value, ctx) => {
    if (value.latitude === undefined && value.longitude === undefined) return;
    const latNull = value.latitude === null;
    const lngNull = value.longitude === null;
    if (latNull && lngNull) return;
    if (value.latitude == null || value.longitude == null) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Latitude and longitude must both be set (or both cleared)',
        path: value.latitude == null ? ['latitude'] : ['longitude'],
      });
    }
  });

export const nearbyLocalServicesQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radiusKm: z.coerce
    .number()
    .min(0.5)
    .max(50)
    .default(DEFAULT_LOCAL_SERVICE_RADIUS_KM),
});

export type CreateLocalServiceCategoryBody = z.infer<typeof createLocalServiceCategorySchema>;
export type SetLocalServiceCategoryStatusBody = z.infer<typeof setLocalServiceCategoryStatusSchema>;
export type CreateLocalServiceContactBody = z.infer<typeof createLocalServiceContactSchema>;
export type UpdateLocalServiceContactBody = z.infer<typeof updateLocalServiceContactSchema>;
export type NearbyLocalServicesQuery = z.infer<typeof nearbyLocalServicesQuerySchema>;

import { z } from 'zod';

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

export const createLocalServiceContactSchema = z.object({
  name: z.string().trim().min(1).max(80),
  phone: phoneSchema,
  rating: ratingSchema.optional(),
  pinned: z.boolean().optional(),
  address: addressSchema,
});

export const updateLocalServiceContactSchema = z
  .object({
    name: z.string().trim().min(1).max(80).optional(),
    phone: phoneSchema.optional(),
    rating: ratingSchema.optional(),
    pinned: z.boolean().optional(),
    address: addressSchema,
    clearPhoto: z.boolean().optional(),
  })
  .refine(
    (body) =>
      body.name !== undefined ||
      body.phone !== undefined ||
      body.rating !== undefined ||
      body.pinned !== undefined ||
      body.address !== undefined ||
      body.clearPhoto === true,
    { message: 'Provide at least one field to update' },
  );

export type CreateLocalServiceCategoryBody = z.infer<typeof createLocalServiceCategorySchema>;
export type SetLocalServiceCategoryStatusBody = z.infer<typeof setLocalServiceCategoryStatusSchema>;
export type CreateLocalServiceContactBody = z.infer<typeof createLocalServiceContactSchema>;
export type UpdateLocalServiceContactBody = z.infer<typeof updateLocalServiceContactSchema>;

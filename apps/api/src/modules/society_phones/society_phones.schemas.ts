import { z } from 'zod';

export const addSocietyPhoneSchema = z.object({
  phone: z.string().trim().min(8).max(20),
});

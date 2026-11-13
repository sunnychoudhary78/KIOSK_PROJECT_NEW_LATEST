import { z } from 'zod';

const versionSchema = z
  .string()
  .trim()
  .min(1)
  .max(64)
  .regex(/^[0-9A-Za-z][0-9A-Za-z._+-]*$/, 'Invalid version string');

const sha256Schema = z
  .string()
  .trim()
  .toLowerCase()
  .regex(/^[a-f0-9]{64}$/, 'sha256 must be 64 hex characters');

export const createKioskReleaseSchema = z.object({
  version: versionSchema,
  contentType: z
    .enum(['application/zip', 'application/x-zip-compressed'])
    .default('application/zip'),
  byteSize: z.number().int().positive().max(2_147_483_647),
  sha256: sha256Schema,
});

export type CreateKioskReleaseInput = z.infer<typeof createKioskReleaseSchema>;

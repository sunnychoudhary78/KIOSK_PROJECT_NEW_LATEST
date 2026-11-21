import { z } from 'zod';
import { MAX_DIAGNOSTIC_BUNDLE_BYTES } from './diagnostic_bundles.constants.js';

export const diagnosticBundleUploadUrlBodySchema = z.object({
  commandId: z.string().uuid(),
  bytes: z.number().int().min(1).max(MAX_DIAGNOSTIC_BUNDLE_BYTES),
  contentType: z.literal('application/zip').default('application/zip'),
});

export type DiagnosticBundleUploadUrlBody = z.infer<
  typeof diagnosticBundleUploadUrlBodySchema
>;

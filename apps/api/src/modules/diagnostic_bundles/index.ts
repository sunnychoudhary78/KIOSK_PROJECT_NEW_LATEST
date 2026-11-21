import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { diagnosticBundleUploadUrlBodySchema } from './diagnostic_bundles.schemas.js';
import { DiagnosticBundlesService } from './diagnostic_bundles.service.js';

export { DiagnosticBundlesService } from './diagnostic_bundles.service.js';
export {
  DIAGNOSTIC_BUNDLE_KEEP_PER_DEVICE,
  DIAGNOSTIC_BUNDLE_RETENTION_DAYS,
  MAX_DIAGNOSTIC_BUNDLE_BYTES,
} from './diagnostic_bundles.constants.js';

export function registerDiagnosticBundlesModule(router: Router, deps: AppDeps): void {
  const service = new DiagnosticBundlesService(deps.db, deps.objectStorage, deps.auditService);

  router.post(
    '/devices/:deviceId/diagnostic-bundles/upload-url',
    ...requireDevice(deps),
    validateBody(diagnosticBundleUploadUrlBodySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.createUploadUrl(
          requireParam(req.params.deviceId, 'deviceId'),
          req.principal.deviceId,
          req.body,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/devices/:deviceId/diagnostic-bundles/:bundleId/complete',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.complete(
          requireParam(req.params.deviceId, 'deviceId'),
          req.principal.deviceId,
          requireParam(req.params.bundleId, 'bundleId'),
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/devices/:deviceId/diagnostic-bundles/:bundleId/download-url',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.createDownloadUrl(
          requireParam(req.params.deviceId, 'deviceId'),
          requireParam(req.params.bundleId, 'bundleId'),
          req.principal.id,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

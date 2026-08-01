import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { PrintingService } from './printing.service.js';
import { updatePrintJobStatusSchema } from './printing.schemas.js';

export function registerPrintingModule(router: Router, deps: AppDeps): void {
  const service = new PrintingService(deps.db, deps.auditService);

  router.get(
    '/print-jobs',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (_req: Request, res: Response, next: NextFunction) => {
      try {
        res.json(await service.list());
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/print-jobs/:jobId',
    authRequired(deps.config, ['admin', 'device', 'citizen']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        res.json(await service.get(requireParam(req.params.jobId, 'jobId')));
      } catch (error) {
        next(error);
      }
    },
  );

  router.patch(
    '/print-jobs/:jobId/status',
    authRequired(deps.config, ['device']),
    validateBody(updatePrintJobStatusSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.updateStatus(
          requireParam(req.params.jobId, 'jobId'),
          req.body,
          req.principal.deviceId,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

export { PrintingService } from './printing.service.js';

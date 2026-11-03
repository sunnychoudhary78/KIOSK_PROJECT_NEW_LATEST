import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { requireDevice } from '../../shared/device-guard.js';
import { AppError } from '../../shared/errors.js';
import { wellBeingPrintBodySchema } from './well_being.schemas.js';
import { WellBeingService } from './well_being.service.js';

export function registerWellBeingModule(router: Router, deps: AppDeps): void {
  const service = new WellBeingService(deps.db, deps.auditService);

  router.post(
    '/well-being/print',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const parsed = wellBeingPrintBodySchema.safeParse(req.body);
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const job = await service.printReport(
          req.principal.deviceId,
          parsed.data,
          req.correlationId,
        );
        res.status(200).json(job);
      } catch (error) {
        next(error);
      }
    },
  );
}

export { WellBeingService } from './well_being.service.js';

import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { requireDevice } from '../../shared/device-guard.js';
import { AppError } from '../../shared/errors.js';
import { LocalServicesService } from './local_services.service.js';

export function registerLocalServicesModule(router: Router, deps: AppDeps): void {
  const service = new LocalServicesService(deps.db);

  router.get(
    '/local-services',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        res.json(await service.list());
      } catch (error) {
        next(error);
      }
    },
  );
}

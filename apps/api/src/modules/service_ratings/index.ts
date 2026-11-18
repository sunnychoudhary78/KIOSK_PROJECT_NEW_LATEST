import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateBody, validateQuery } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { ServiceRatingsService } from './service_ratings.service.js';
import {
  reportServiceRatingsSchema,
  serviceRatingsQuerySchema,
  type ServiceRatingsQuery,
} from './service_ratings.schemas.js';

export function registerServiceRatingsModule(router: Router, deps: AppDeps): void {
  const service = new ServiceRatingsService(deps.db);

  router.post(
    '/analytics/service-ratings',
    ...requireDevice(deps),
    validateBody(reportServiceRatingsSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        res.status(202).json(await service.reportRatings(req.principal.deviceId, req.body));
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/devices/:deviceId/service-ratings',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    validateQuery(serviceRatingsQuerySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const query = req.query as unknown as ServiceRatingsQuery;
        res.json(
          await service.ratingsForDevice(
            requireParam(req.params.deviceId, 'deviceId'),
            query,
          ),
        );
      } catch (error) {
        next(error);
      }
    },
  );
}

export { ServiceRatingsService } from './service_ratings.service.js';

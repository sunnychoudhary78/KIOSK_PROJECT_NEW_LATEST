import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateBody, validateQuery } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { ServiceAnalyticsService } from './service_analytics.service.js';
import {
  reportServiceEventsSchema,
  serviceAnalyticsQuerySchema,
  type ServiceAnalyticsQuery,
} from './service_analytics.schemas.js';

export function registerServiceAnalyticsModule(router: Router, deps: AppDeps): void {
  const service = new ServiceAnalyticsService(deps.db);

  router.post(
    '/analytics/service-events',
    ...requireDevice(deps),
    validateBody(reportServiceEventsSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        res.status(202).json(await service.reportEvents(req.principal.deviceId, req.body));
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/devices/:deviceId/service-analytics',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    validateQuery(serviceAnalyticsQuerySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const query = req.query as unknown as ServiceAnalyticsQuery;
        res.json(
          await service.analyticsForDevice(
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

export { ServiceAnalyticsService } from './service_analytics.service.js';

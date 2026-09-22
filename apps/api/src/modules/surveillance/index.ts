import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateBody, validateQuery } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { listSegmentsQuerySchema, uploadUrlBodySchema } from './surveillance.schemas.js';
import type { ListSegmentsQuery } from './surveillance.schemas.js';
import { SurveillanceService } from './surveillance.service.js';

export function registerSurveillanceModule(router: Router, deps: AppDeps): void {
  const service = new SurveillanceService(deps.db, deps.objectStorage, deps.auditService);

  router.get(
    '/devices/:deviceId/surveillance/segments',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    validateQuery(listSegmentsQuerySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const query = req.query as unknown as ListSegmentsQuery;
        const result = await service.listSegments(
          requireParam(req.params.deviceId, 'deviceId'),
          query,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/devices/:deviceId/surveillance/segments/:segmentId/playback-url',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.createPlaybackUrl(
          requireParam(req.params.deviceId, 'deviceId'),
          requireParam(req.params.segmentId, 'segmentId'),
          req.principal.id,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/devices/:deviceId/surveillance/segments/upload-url',
    ...requireDevice(deps),
    validateBody(uploadUrlBodySchema),
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
    '/devices/:deviceId/surveillance/segments/:segmentId/complete',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.complete(
          requireParam(req.params.deviceId, 'deviceId'),
          req.principal.deviceId,
          requireParam(req.params.segmentId, 'segmentId'),
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

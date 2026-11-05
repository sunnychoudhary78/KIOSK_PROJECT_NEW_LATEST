import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { authRequired } from '../../shared/auth.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { emergencyContactBodySchema } from './emergency_contacts.schemas.js';
import { EmergencyContactsService } from './emergency_contacts.service.js';

export function registerEmergencyContactsModule(router: Router, deps: AppDeps): void {
  const service = new EmergencyContactsService(deps.db, deps.auditService);

  router.get(
    '/emergency-contacts',
    authRequired(deps.config, ['admin', 'device']),
    async (_req: Request, res: Response, next: NextFunction) => {
      try {
        res.json(await service.list());
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/emergency-contacts',
    authRequired(deps.config, ['admin']),
    validateBody(emergencyContactBodySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.create(req.body, req.principal.id, req.correlationId);
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.put(
    '/emergency-contacts/:id',
    authRequired(deps.config, ['admin']),
    validateBody(emergencyContactBodySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.update(
          requireParam(req.params.id, 'id'),
          req.body,
          req.principal.id,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.delete(
    '/emergency-contacts/:id',
    authRequired(deps.config, ['admin']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        await service.remove(
          requireParam(req.params.id, 'id'),
          req.principal.id,
          req.correlationId,
        );
        res.status(204).send();
      } catch (error) {
        next(error);
      }
    },
  );
}

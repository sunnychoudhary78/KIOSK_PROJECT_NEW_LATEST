import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { authRequired } from '../../shared/auth.js';
import { assertActiveDevice } from '../../shared/device-guard.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import {
  createLocalServiceCategorySchema,
  createLocalServiceContactSchema,
} from './local_services.schemas.js';
import { LocalServicesService } from './local_services.service.js';

export function registerLocalServicesModule(router: Router, deps: AppDeps): void {
  const service = new LocalServicesService(deps.db, deps.auditService);

  router.get(
    '/local-services',
    authRequired(deps.config, ['admin', 'device']),
    assertActiveDevice(deps.db),
    async (_req: Request, res: Response, next: NextFunction) => {
      try {
        res.json(await service.list());
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/local-services',
    authRequired(deps.config, ['admin']),
    validateBody(createLocalServiceCategorySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.createCategory(req.body, req.principal.id, req.correlationId);
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.delete(
    '/local-services/:id',
    authRequired(deps.config, ['admin']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        await service.removeCategory(
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

  router.post(
    '/local-services/:id/contacts',
    authRequired(deps.config, ['admin']),
    validateBody(createLocalServiceContactSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.createContact(
          requireParam(req.params.id, 'id'),
          req.body,
          req.principal.id,
          req.correlationId,
        );
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.delete(
    '/local-services/:id/contacts/:contactId',
    authRequired(deps.config, ['admin']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        await service.removeContact(
          requireParam(req.params.id, 'id'),
          requireParam(req.params.contactId, 'contactId'),
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

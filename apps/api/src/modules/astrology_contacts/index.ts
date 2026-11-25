import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { authRequired } from '../../shared/auth.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import {
  ASTROLOGY_CONTACT_KINDS,
  astrologyContactBodySchema,
  type AstrologyContactKind,
} from './astrology_contacts.schemas.js';
import { AstrologyContactsService } from './astrology_contacts.service.js';

function parseKindQuery(raw: unknown): AstrologyContactKind | undefined {
  if (raw === undefined || raw === null || raw === '') {
    return undefined;
  }
  if (typeof raw !== 'string') {
    throw new AppError('invalid_kind', 'kind must be astrologer or pandit', 400);
  }
  if (!(ASTROLOGY_CONTACT_KINDS as readonly string[]).includes(raw)) {
    throw new AppError('invalid_kind', 'kind must be astrologer or pandit', 400);
  }
  return raw as AstrologyContactKind;
}

export function registerAstrologyContactsModule(router: Router, deps: AppDeps): void {
  const service = new AstrologyContactsService(deps.db, deps.auditService);

  router.get(
    '/astrology-contacts',
    authRequired(deps.config, ['admin', 'device']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const kind = parseKindQuery(req.query.kind);
        res.json(await service.list(kind));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/astrology-contacts',
    authRequired(deps.config, ['admin']),
    validateBody(astrologyContactBodySchema),
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
    '/astrology-contacts/:id',
    authRequired(deps.config, ['admin']),
    validateBody(astrologyContactBodySchema),
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
    '/astrology-contacts/:id',
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

  router.post(
    '/astrology-contacts/:id/reveal',
    authRequired(deps.config, ['device']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const result = await service.reveal(requireParam(req.params.id, 'id'));
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

export { AstrologyContactsService } from './astrology_contacts.service.js';

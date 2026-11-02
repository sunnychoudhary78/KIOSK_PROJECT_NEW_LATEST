import type { NextFunction, Request, Response, Router } from 'express';
import multer from 'multer';
import type { AppDeps } from '../../types/deps.js';
import { authRequired } from '../../shared/auth.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { addSocietyPhoneSchema } from './society_phones.schemas.js';
import { SocietyPhonesService } from './society_phones.service.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024 },
});

function uploadSingle(req: Request, res: Response, next: NextFunction): void {
  upload.single('file')(req, res, (error: unknown) => {
    if (error) {
      next(new AppError('invalid_file', 'Upload must be a CSV or Excel file up to 2 MB', 400));
      return;
    }
    next();
  });
}

function parseLimit(raw: unknown): number | undefined {
  if (raw === undefined || raw === null || raw === '') return undefined;
  const n = Number(raw);
  if (!Number.isFinite(n)) return undefined;
  return n;
}

export function registerSocietyPhonesModule(router: Router, deps: AppDeps): void {
  const service = new SocietyPhonesService(deps.db, deps.auditService);

  router.get(
    '/society-phones',
    authRequired(deps.config, ['admin']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const q = typeof req.query.q === 'string' ? req.query.q : undefined;
        const limit = parseLimit(req.query.limit);
        res.json(await service.list({ q, limit }));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/society-phones',
    authRequired(deps.config, ['admin']),
    validateBody(addSocietyPhoneSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.add(req.body.phone, req.principal.id, req.correlationId);
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/society-phones/import',
    authRequired(deps.config, ['admin']),
    uploadSingle,
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const file = req.file;
        if (!file) {
          throw new AppError('invalid_file', 'Choose a CSV or Excel file', 400);
        }
        const result = await service.importFile(
          { originalname: file.originalname, buffer: file.buffer },
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
    '/society-phones/:id',
    authRequired(deps.config, ['admin']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        await service.remove(requireParam(req.params.id, 'id'), req.principal.id, req.correlationId);
        res.status(204).send();
      } catch (error) {
        next(error);
      }
    },
  );
}

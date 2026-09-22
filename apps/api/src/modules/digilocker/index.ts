import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { PrintingService } from '../printing/printing.service.js';
import { ServicesCatalogService } from '../services/services.service.js';
import { DigiLockerService } from './digilocker.service.js';
import { printDigiLockerSchema, startDigiLockerSessionSchema } from './digilocker.schemas.js';

export function registerDigiLockerModule(router: Router, deps: AppDeps): void {
  const printing = new PrintingService(deps.db, deps.auditService);
  const services = new ServicesCatalogService(deps.db, deps.auditService);
  const service = new DigiLockerService(
    deps.db,
    deps.digiLocker,
    deps.auditService,
    printing,
    services,
  );

  router.post(
    '/digilocker/sessions',
    ...requireDevice(deps),
    validateBody(startDigiLockerSessionSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.startSession(
          req.principal.deviceId,
          req.body,
          req.correlationId,
        );
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/digilocker/sessions/:sessionId',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.getSession(
          requireParam(req.params.sessionId, 'sessionId'),
          req.principal.deviceId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/digilocker/sessions/:sessionId/cancel',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.cancelSession(
          requireParam(req.params.sessionId, 'sessionId'),
          req.principal.deviceId,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/digilocker/sessions/:sessionId/documents',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.listDocuments(
          requireParam(req.params.sessionId, 'sessionId'),
          req.principal.deviceId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/digilocker/sessions/:sessionId/print',
    ...requireDevice(deps),
    validateBody(printDigiLockerSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.printDocument(
          requireParam(req.params.sessionId, 'sessionId'),
          req.principal.deviceId,
          req.body,
          req.correlationId,
        );
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

export function registerDigiLockerOAuthCallback(deps: AppDeps) {
  const printing = new PrintingService(deps.db, deps.auditService);
  const services = new ServicesCatalogService(deps.db, deps.auditService);
  const service = new DigiLockerService(
    deps.db,
    deps.digiLocker,
    deps.auditService,
    printing,
    services,
  );

  return async (req: Request, res: Response) => {
    try {
      await service.handleOAuthCallback({
        code: typeof req.query.code === 'string' ? req.query.code : undefined,
        state: typeof req.query.state === 'string' ? req.query.state : undefined,
        error: typeof req.query.error === 'string' ? req.query.error : undefined,
      });
      res.status(200).type('html').send(`<!doctype html>
<html><head><title>DigiLocker</title></head>
<body style="font-family:Segoe UI,sans-serif;padding:2rem;">
  <h1>DigiLocker connected</h1>
  <p>You can close this window and return to the kiosk.</p>
  <script>setTimeout(function(){ window.close(); }, 1200);</script>
</body></html>`);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Authorization failed';
      const safe = message
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
      deps.logger.warn({ err: error }, 'DigiLocker OAuth callback failed');
      res.status(400).type('html').send(`<!doctype html>
<html><head><title>DigiLocker</title></head>
<body style="font-family:Segoe UI,sans-serif;padding:2rem;">
  <h1>DigiLocker authorization failed</h1>
  <p>${safe}</p>
  <p>Close this window and try again on the kiosk.</p>
</body></html>`);
    }
  };
}

export { DigiLockerService } from './digilocker.service.js';

import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { IdentityService } from './identity.service.js';
import {
  adminLoginSchema,
  citizenOtpRequestSchema,
  citizenOtpVerifySchema,
  deviceTokenSchema,
} from './identity.schemas.js';

export function registerIdentityModule(router: Router, deps: AppDeps): void {
  const service = new IdentityService(deps.db, deps.config, deps.auditService, deps.sms);

  router.post(
    '/auth/citizen/otp-request',
    validateBody(citizenOtpRequestSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const result = await service.citizenOtpRequest(req.body, req.correlationId);
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/auth/citizen/otp-verify',
    validateBody(citizenOtpVerifySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const result = await service.citizenOtpVerify(req.body, req.correlationId);
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/auth/citizen/login',
    async (_req: Request, _res: Response, next: NextFunction) => {
      next(
        new AppError(
          'gone',
          'Password login is no longer supported. Use OTP login.',
          410,
        ),
      );
    },
  );

  router.post(
    '/auth/admin/login',
    validateBody(adminLoginSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const result = await service.adminLogin(req.body, req.correlationId);
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/auth/device/token',
    validateBody(deviceTokenSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const result = await service.deviceToken(req.body, req.correlationId);
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

export { IdentityService } from './identity.service.js';

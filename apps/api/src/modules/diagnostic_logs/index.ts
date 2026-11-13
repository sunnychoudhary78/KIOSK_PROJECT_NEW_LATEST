import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateBody, validateQuery } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { DiagnosticLogsService } from './diagnostic_logs.service.js';
import {
  listDiagnosticLogsQuerySchema,
  reportDiagnosticLogsSchema,
  type ListDiagnosticLogsQuery,
} from './diagnostic_logs.schemas.js';

export function registerDiagnosticLogsModule(router: Router, deps: AppDeps): void {
  const service = new DiagnosticLogsService(deps.db);

  router.post(
    '/diagnostics/logs',
    ...requireDevice(deps),
    validateBody(reportDiagnosticLogsSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        res.status(202).json(await service.ingest(req.principal.deviceId, req.body));
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/devices/:deviceId/diagnostic-logs',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    validateQuery(listDiagnosticLogsQuerySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const query = req.query as unknown as ListDiagnosticLogsQuery;
        res.json(
          await service.listForDevice(
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

export { DiagnosticLogsService } from './diagnostic_logs.service.js';
export {
  DAILY_LOG_CAP,
  RETENTION_DAYS,
  MAX_LIST_RANGE_MS,
} from './diagnostic_logs.service.js';

import type { Request, Response, NextFunction, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { UserRole } from '@prisma/client';

export function registerAuditModule(router: Router, deps: AppDeps): void {
  const service = deps.auditService;

  router.get(
    '/audit-logs',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const limit = req.query.limit ? Number(req.query.limit) : 50;
        const result = await service.list(Number.isFinite(limit) ? limit : 50);
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

export { AuditService } from './audit.service.js';

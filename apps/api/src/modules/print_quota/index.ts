import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { requireParam } from '../../shared/params.js';
import { PrintQuotaService } from './print_quota.service.js';

function parseLimit(raw: unknown): number | undefined {
  if (raw === undefined || raw === null || raw === '') return undefined;
  const n = Number(raw);
  if (!Number.isFinite(n)) return undefined;
  return n;
}

export function registerPrintQuotaModule(router: Router, deps: AppDeps): void {
  const service = new PrintQuotaService(deps.db, deps.auditService);

  router.get(
    '/print-quota/usage',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const q = typeof req.query.q === 'string' ? req.query.q : undefined;
        const limit = parseLimit(req.query.limit);
        res.json(await service.listUsage({ q, limit }));
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/print-quota/usage/:phone',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const phone = requireParam(req.params.phone, 'phone');
        res.json(await service.getPhoneUsageDetail(phone));
      } catch (error) {
        next(error);
      }
    },
  );
}

export { PrintQuotaService } from './print_quota.service.js';

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
        const audience =
          req.query.audience === 'society' || req.query.audience === 'public'
            ? req.query.audience
            : 'all';
        const usage =
          req.query.usage === 'has_remaining' ||
          req.query.usage === 'exhausted' ||
          req.query.usage === 'used_bw' ||
          req.query.usage === 'used_color'
            ? req.query.usage
            : 'all';
        const scope = req.query.scope === 'all' ? 'all' : 'current';
        const periodKey =
          typeof req.query.periodKey === 'string' && req.query.periodKey.trim()
            ? req.query.periodKey.trim()
            : undefined;
        res.json(await service.listUsage({ q, limit, audience, usage, scope, periodKey }));
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
        const periodKey =
          typeof req.query.periodKey === 'string' && req.query.periodKey.trim()
            ? req.query.periodKey.trim()
            : undefined;
        res.json(await service.getPhoneUsageDetail(phone, { periodKey }));
      } catch (error) {
        next(error);
      }
    },
  );
}

export { PrintQuotaService } from './print_quota.service.js';

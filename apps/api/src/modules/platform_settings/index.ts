import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { authRequired } from '../../shared/auth.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { SMS_CONFIG_KEY } from './platform_settings.defaults.js';
import { updatePlatformSettingSchema } from './platform_settings.schemas.js';
import { PlatformSettingsService } from './platform_settings.service.js';

export function registerPlatformSettingsModule(router: Router, deps: AppDeps): void {
  const service = new PlatformSettingsService(deps.db, deps.auditService);

  router.get(
    '/platform-settings',
    authRequired(deps.config, ['admin']),
    async (_req: Request, res: Response, next: NextFunction) => {
      try {
        const items = await service.list();
        res.json({ items });
      } catch (error) {
        next(error);
      }
    },
  );

  router.put(
    '/platform-settings/:settingKey',
    authRequired(deps.config, ['admin']),
    validateBody(updatePlatformSettingSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const settingKey = requireParam(req.params.settingKey, 'settingKey');
        let settingValue = req.body.settingValue;
        if (settingKey === SMS_CONFIG_KEY) {
          settingValue = await service.prepareSmsUpdate(settingValue);
        }
        const result = await service.update(
          settingKey,
          { ...req.body, settingValue },
          req.principal.id,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

export { PlatformSettingsService } from './platform_settings.service.js';
export {
  SMS_CONFIG_KEY,
  OTP_PRINT_CONFIG_KEY,
  CITIZEN_AUTH_CONFIG_KEY,
  DEFAULT_SMS_CONFIG,
  DEFAULT_OTP_PRINT_CONFIG,
  DEFAULT_CITIZEN_AUTH_CONFIG,
} from './platform_settings.defaults.js';

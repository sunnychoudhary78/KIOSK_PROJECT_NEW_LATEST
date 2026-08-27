import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { authRequired } from '../../shared/auth.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { isMsg91Configured } from '../../infrastructure/external/sms.client.js';
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
        const items = await service.listOperational();
        const configured = isMsg91Configured({
          provider: deps.config.smsProvider,
          authKey: deps.config.msg91.authKey,
          senderId: deps.config.msg91.senderId,
          flowId: deps.config.msg91.flowId,
          otpVar: deps.config.msg91.otpVar,
          expiryVar: deps.config.msg91.expiryVar,
        });
        res.json({
          items,
          smsStatus: {
            provider: deps.config.smsProvider,
            configured,
            senderId: configured ? deps.config.msg91.senderId : null,
            flowIdConfigured: Boolean(deps.config.msg91.flowId),
            otpVar: deps.config.msg91.otpVar,
            expiryVar: deps.config.msg91.expiryVar,
          },
        });
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
        if (settingKey === SMS_CONFIG_KEY) {
          throw new AppError(
            'sms_config_deprecated',
            'SMS credentials are configured via environment variables (SKP_MSG91_*), not platform settings',
            400,
          );
        }
        const result = await service.update(
          settingKey,
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
}

export { PlatformSettingsService } from './platform_settings.service.js';
export {
  SMS_CONFIG_KEY,
  OTP_PRINT_CONFIG_KEY,
  CITIZEN_AUTH_CONFIG_KEY,
  DEFAULT_OTP_PRINT_CONFIG,
  DEFAULT_CITIZEN_AUTH_CONFIG,
} from './platform_settings.defaults.js';

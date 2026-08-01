import type { AppConfig } from '../config/index.js';
import type { DbClient } from '../infrastructure/database/prisma.js';
import type { Logger } from '../infrastructure/logging/logger.js';
import type { DigiLockerClient } from '../infrastructure/external/digilocker.types.js';
import type { SmsClient } from '../infrastructure/external/sms.client.js';
import type { AuditService } from '../modules/audit/audit.service.js';

export type AppDeps = {
  config: AppConfig;
  db: DbClient;
  logger: Logger;
  digiLocker: DigiLockerClient;
  sms: SmsClient;
  auditService: AuditService;
};

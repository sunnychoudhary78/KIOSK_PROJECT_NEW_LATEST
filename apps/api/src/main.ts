import { loadEnvFile } from './config/load-env.js';
import { loadConfig } from './config/index.js';
import { prisma } from './infrastructure/database/prisma.js';
import { createLogger } from './infrastructure/logging/logger.js';
import { createDigiLockerClient } from './infrastructure/external/digilocker.client.js';
import { createMsg91FlowSmsClient } from './infrastructure/external/sms.client.js';
import { createVedAstroClient } from './infrastructure/external/vedastro.client.js';
import { createAstrologyLlmClient } from './infrastructure/external/openai.client.js';
import { createObjectStorageClient } from './infrastructure/storage/s3.client.js';
import { AuditService } from './modules/audit/audit.service.js';
import { PlatformSettingsService } from './modules/platform_settings/platform_settings.service.js';
import { createApp } from './app.js';
import type { AppDeps } from './types/deps.js';

async function main() {
  loadEnvFile();
  const config = loadConfig();
  const logger = createLogger(config);
  const auditService = new AuditService(prisma);
  const platformSettings = new PlatformSettingsService(prisma, auditService);
  // MSG91 credentials come from env. When not configured, local/dev/test (or SKP_SMS_PROVIDER=noop) skip send.
  const allowNoopWhenDisabled =
    config.smsProvider === 'noop' ||
    config.env === 'local' ||
    config.env === 'test' ||
    config.env === 'dev';
  const sms = createMsg91FlowSmsClient({
    msg91: {
      provider: config.smsProvider,
      authKey: config.msg91.authKey,
      senderId: config.msg91.senderId,
      flowId: config.msg91.flowId,
      otpVar: config.msg91.otpVar,
      expiryVar: config.msg91.expiryVar,
    },
    logger,
    allowNoopWhenDisabled,
  });
  const allowLlmNoop =
    config.aiProvider === 'noop' ||
    config.env === 'local' ||
    config.env === 'test' ||
    config.env === 'dev';
  const astrologyLlm = createAstrologyLlmClient({
    provider: config.aiProvider,
    apiKey: config.openai.apiKey,
    model: config.openai.model,
    logger,
    allowNoopWhenDisabled: allowLlmNoop,
  });

  const deps: AppDeps = {
    config,
    db: prisma,
    logger,
    digiLocker: createDigiLockerClient(config, logger),
    sms,
    vedastro: createVedAstroClient({ baseUrl: config.vedastro.baseUrl, logger }),
    astrologyLlm,
    auditService,
    objectStorage: createObjectStorageClient(config),
  };

  const app = createApp(deps);

  const server = app.listen(config.port, () => {
    logger.info({ port: config.port, env: config.env }, 'SKP API listening');
  });

  const shutdown = async (signal: string) => {
    logger.info({ signal }, 'Shutting down');
    server.close(async () => {
      await prisma.$disconnect();
      process.exit(0);
    });
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

import pino from 'pino';
import type { AppConfig } from '../../config/index.js';

export function createLogger(config: AppConfig) {
  return pino({
    level: config.logLevel,
    base: { service: 'skp-api', env: config.env },
  });
}

export type Logger = ReturnType<typeof createLogger>;

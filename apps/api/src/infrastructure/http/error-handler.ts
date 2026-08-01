import type { NextFunction, Request, Response } from 'express';
import { isAppError } from '../../shared/errors.js';
import type { Logger } from '../logging/logger.js';

export function errorHandler(logger: Logger) {
  return (error: unknown, req: Request, res: Response, _next: NextFunction): void => {
    const correlationId = req.correlationId ?? 'unknown';

    if (isAppError(error)) {
      if (error.statusCode >= 500) {
        logger.error({ err: error, correlationId }, error.message);
      } else {
        logger.warn({ err: error, correlationId, code: error.code }, error.message);
      }

      res.status(error.statusCode).json({
        code: error.code,
        message: error.message,
        correlationId,
      });
      return;
    }

    logger.error({ err: error, correlationId }, 'Unhandled error');
    res.status(500).json({
      code: 'internal_error',
      message: 'An unexpected error occurred',
      correlationId,
    });
  };
}

import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import type { PrincipalType, UserRole } from '@prisma/client';
import { AppError } from './errors.js';
import type { AppConfig } from '../config/index.js';
import type { AuthPrincipal } from '../types/auth.js';

type AccessTokenPayload = {
  sub: string;
  typ: PrincipalType;
  role?: UserRole;
  deviceId?: string;
  tenantId?: string;
};

export function signAccessToken(
  config: AppConfig,
  principal: AuthPrincipal,
): { accessToken: string; expiresIn: number } {
  const payload: AccessTokenPayload = {
    sub: principal.id,
    typ: principal.type,
    role: principal.role,
    deviceId: principal.deviceId,
    tenantId: principal.tenantId,
  };

  const accessToken = jwt.sign(payload, config.auth.jwtSecret, {
    expiresIn: config.auth.accessTtlSeconds,
  });

  return { accessToken, expiresIn: config.auth.accessTtlSeconds };
}

export function authRequired(config: AppConfig, allowed: PrincipalType[] = []) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const header = req.header('authorization');
    if (!header?.startsWith('Bearer ')) {
      next(new AppError('unauthorized', 'Missing bearer token', 401));
      return;
    }

    const token = header.slice('Bearer '.length).trim();
    try {
      const decoded = jwt.verify(token, config.auth.jwtSecret) as AccessTokenPayload;
      if (allowed.length > 0 && !allowed.includes(decoded.typ)) {
        next(new AppError('forbidden', 'Principal type not allowed', 403));
        return;
      }

      req.principal = {
        type: decoded.typ,
        id: decoded.sub,
        role: decoded.role,
        deviceId: decoded.deviceId,
        tenantId: decoded.tenantId,
      };
      next();
    } catch {
      next(new AppError('unauthorized', 'Invalid or expired token', 401));
    }
  };
}

export function requireAdminRole(...roles: UserRole[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.principal || req.principal.type !== 'admin') {
      next(new AppError('forbidden', 'Admin access required', 403));
      return;
    }
    if (roles.length > 0 && req.principal.role && !roles.includes(req.principal.role)) {
      next(new AppError('forbidden', 'Insufficient admin role', 403));
      return;
    }
    next();
  };
}

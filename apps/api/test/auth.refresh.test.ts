import type { NextFunction, Request, Response } from 'express';
import { UserRole } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { SmsClient } from '../src/infrastructure/external/sms.client.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { IdentityService } from '../src/modules/identity/identity.service.js';
import { AppError } from '../src/shared/errors.js';
import {
  authRequired,
  signAccessToken,
  signAdminRefreshToken,
  verifyAdminRefreshToken,
} from '../src/shared/auth.js';

const config = {
  auth: {
    jwtSecret: 'test-secret-must-be-at-least-32-chars!!',
    accessTtlSeconds: 3600,
    adminRefreshTtlSeconds: 43_200,
  },
} as AppConfig;

const admin = {
  type: 'admin' as const,
  id: '22222222-2222-2222-2222-222222222222',
  role: UserRole.admin,
  tenantId: undefined,
};

function runAuth(token: string) {
  const req = {
    header: (name: string) => (name === 'authorization' ? `Bearer ${token}` : undefined),
  } as Request;
  const next = vi.fn() as NextFunction & ReturnType<typeof vi.fn>;
  authRequired(config, ['admin'])(req, {} as Response, next);
  return { req, next };
}

describe('admin refresh tokens', () => {
  it('rejects a refresh token used as a bearer token', () => {
    const { refreshToken } = signAdminRefreshToken(config, admin);
    const { next } = runAuth(refreshToken);
    const error = next.mock.calls[0]?.[0] as AppError;
    expect(error).toBeInstanceOf(AppError);
    expect(error.code).toBe('unauthorized');
    expect(error.statusCode).toBe(401);
  });

  it('accepts an access token', () => {
    const { accessToken } = signAccessToken(config, admin);
    const { req, next } = runAuth(accessToken);
    expect(next).toHaveBeenCalledWith();
    expect(req.principal).toMatchObject({ type: 'admin', id: admin.id, role: UserRole.admin });
  });

  it('does not treat an access token as a refresh token', () => {
    const { accessToken } = signAccessToken(config, admin);
    expect(() => verifyAdminRefreshToken(config, accessToken)).toThrow(AppError);
  });
});

describe('IdentityService.adminRefresh', () => {
  const user = {
    id: admin.id,
    role: UserRole.operator,
    tenantId: null,
    isActive: true,
    email: 'ops@smartkiosk.local',
    passwordHash: 'hash',
  };

  function serviceWith(found: typeof user | null) {
    const db = {
      user: { findUnique: vi.fn(async () => found) },
    };
    return new IdentityService(
      db as unknown as DbClient,
      config,
      { record: vi.fn() } as unknown as AuditService,
      {} as SmsClient,
    );
  }

  it('issues a new access token and refresh token for an active admin', async () => {
    const refreshToken = signAdminRefreshToken(config, admin).refreshToken;
    const result = await serviceWith(user).adminRefresh({ refreshToken });

    expect(result.principalType).toBe('admin');
    expect(result.expiresIn).toBe(3600);
    expect(result.accessToken).not.toBe(result.refreshToken);
    expect(verifyAdminRefreshToken(config, result.refreshToken).sub).toBe(user.id);
  });

  it('rejects a refresh token when the admin is inactive', async () => {
    const refreshToken = signAdminRefreshToken(config, admin).refreshToken;
    await expect(serviceWith({ ...user, isActive: false }).adminRefresh({ refreshToken })).rejects.toMatchObject({
      code: 'unauthorized',
      statusCode: 401,
    });
  });
});

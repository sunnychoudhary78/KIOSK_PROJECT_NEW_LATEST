import type { PrincipalType, UserRole } from '@prisma/client';

export type AuthPrincipal = {
  type: PrincipalType;
  id: string;
  role?: UserRole;
  deviceId?: string;
  tenantId?: string;
};

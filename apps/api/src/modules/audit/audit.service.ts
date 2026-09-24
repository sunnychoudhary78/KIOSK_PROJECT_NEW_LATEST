import type { PrincipalType, Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';

export type AuditWriteInput = {
  action: string;
  principalType: PrincipalType;
  principalId?: string | null;
  resourceType?: string | null;
  resourceId?: string | null;
  correlationId?: string | null;
  metadata?: Prisma.InputJsonValue;
};

export class AuditService {
  constructor(private readonly db: DbClient) {}

  async record(input: AuditWriteInput): Promise<void> {
    await this.db.auditLog.create({
      data: {
        action: input.action,
        principalType: input.principalType,
        principalId: input.principalId ?? null,
        resourceType: input.resourceType ?? null,
        resourceId: input.resourceId ?? null,
        correlationId: input.correlationId ?? null,
        metadata: input.metadata ?? undefined,
      },
    });
  }

  async list(limit = 50) {
    const items = await this.db.auditLog.findMany({
      where: { action: { not: 'device.heartbeat' } },
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 200),
    });
    return { items };
  }
}

import { PrismaClient } from '@prisma/client';

export const prisma = new PrismaClient({
  log: process.env.SKP_NODE_ENV === 'local' ? ['warn', 'error'] : ['error'],
});

export type DbClient = typeof prisma;

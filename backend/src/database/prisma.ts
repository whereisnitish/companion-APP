import { PrismaClient } from '@prisma/client';
import { env, isProduction } from '../config/env';

/**
 * One client for the process. In dev, `tsx watch` re-evaluates modules on every
 * save, so we stash the instance on globalThis to avoid exhausting connections.
 */
const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: isProduction ? ['error'] : ['warn', 'error'],
  });

if (!isProduction) globalForPrisma.prisma = prisma;

export async function connectDatabase(): Promise<void> {
  await prisma.$connect();
}

export async function disconnectDatabase(): Promise<void> {
  await prisma.$disconnect();
}

export const DATABASE_URL = env.DATABASE_URL;

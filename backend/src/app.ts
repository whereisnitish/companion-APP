import Fastify, { type FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import websocket from '@fastify/websocket';
import { env, isProduction, isTest } from './config/env';
import { authPlugin } from './middleware/auth';
import { registerErrorHandler } from './middleware/error-handler';
import { prisma } from './database/prisma';
import { isRedisHealthy } from './database/redis';

import { authRoutes } from './modules/auth/auth.routes';
import { catalogRoutes, userRoutes } from './modules/profiles/profiles.routes';
import { discoveryRoutes } from './modules/discovery/discovery.routes';
import { activityRoutes } from './modules/activities/activities.routes';
import { invitationRoutes } from './modules/invitations/invitations.routes';
import { conversationRoutes } from './modules/conversations/conversations.routes';
import { notificationRoutes } from './modules/notifications/notifications.routes';
import { safetyRoutes } from './modules/safety/safety.routes';
import { realtimeRoutes } from './modules/realtime/realtime.routes';
import { mediaRoutes } from './modules/media/media.routes';

export async function buildApp(): Promise<FastifyInstance> {
  const app = Fastify({
    // Pretty logging spawns a worker thread, which is unwanted noise (and a
    // shutdown hazard) under the test runner — tests get no logger at all.
    logger: isTest
        ? false
        : isProduction
            ? { level: env.LOG_LEVEL }
            : {
                level: env.LOG_LEVEL,
                transport: {
                  target: 'pino-pretty',
                  options: { translateTime: 'HH:MM:ss', ignore: 'pid,hostname' },
                },
              },
    trustProxy: true,
    bodyLimit: 1_048_576,
  });

  registerErrorHandler(app);

  await app.register(helmet, { contentSecurityPolicy: false });
  await app.register(cors, {
    origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(',').map((o) => o.trim()),
    credentials: true,
  });
  await app.register(rateLimit, {
    max: env.RATE_LIMIT_MAX,
    timeWindow: env.RATE_LIMIT_WINDOW,
    // Authenticated traffic is limited per user; anonymous traffic per IP.
    keyGenerator: (request) => request.userId || request.ip,
  });
  await app.register(websocket, { options: { maxPayload: 64 * 1024 } });
  await app.register(authPlugin);

  app.get('/health', async () => {
    const database = await prisma.$queryRaw`SELECT 1`.then(() => true).catch(() => false);
    return {
      status: database ? 'ok' : 'degraded',
      database,
      redis: isRedisHealthy(),
      uptime: Math.round(process.uptime()),
      timestamp: new Date().toISOString(),
    };
  });

  // ------------------------------------------------------------ API surface
  await app.register(
    async (api) => {
      await api.register(authRoutes, { prefix: '/auth' });
      await api.register(catalogRoutes, { prefix: '/catalog' });
      await api.register(userRoutes, { prefix: '/users' });
      await api.register(discoveryRoutes, { prefix: '/discover' });
      await api.register(activityRoutes, { prefix: '/activities' });
      await api.register(invitationRoutes, { prefix: '/invitations' });
      await api.register(conversationRoutes, { prefix: '/conversations' });
      await api.register(notificationRoutes, { prefix: '/notifications' });
      await api.register(safetyRoutes, { prefix: '/safety' });
    },
    { prefix: '/api' },
  );

  await app.register(mediaRoutes, { prefix: '/media' });
  await app.register(realtimeRoutes);

  return app;
}

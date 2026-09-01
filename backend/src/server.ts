import { buildApp } from './app';
import { env } from './config/env';
import { connectDatabase, disconnectDatabase } from './database/prisma';
import { disconnectRedis, getRedis } from './database/redis';

async function main(): Promise<void> {
  await connectDatabase();
  getRedis();

  const app = await buildApp();

  const shutdown = async (signal: string): Promise<void> => {
    app.log.info({ signal }, 'Shutting down');
    try {
      await app.close();
      await disconnectRedis();
      await disconnectDatabase();
      process.exit(0);
    } catch (error) {
      app.log.error({ err: error }, 'Failed to shut down cleanly');
      process.exit(1);
    }
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));

  await app.listen({ port: env.PORT, host: env.HOST });
  app.log.info(`Companion API ready on http://${env.HOST}:${env.PORT}`);
}

main().catch((error: unknown) => {
  console.error('Failed to start the Companion API:');
  console.error(error);
  process.exit(1);
});

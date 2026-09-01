import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { ok, parse } from '../../common/http';
import { paginationSchema } from '../../common/pagination';
import * as service from './notifications.service';

const listSchema = paginationSchema.extend({
  unreadOnly: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => value === 'true'),
});

interface IdParams {
  id: string;
}

export async function notificationRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', app.authenticate);

  app.get('/', async (request) => {
    const query = parse(listSchema, request.query);
    const { items, ...meta } = await service.listNotifications(request.userId, {
      cursor: query.cursor,
      limit: query.limit,
      unreadOnly: query.unreadOnly,
    });
    return ok(items, meta);
  });

  app.post<{ Params: IdParams }>('/:id/read', async (request) =>
    ok(await service.markRead(request.userId, request.params.id)),
  );

  app.post('/read-all', async (request) => ok(await service.markAllRead(request.userId)));
}

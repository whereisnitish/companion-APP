import type { FastifyInstance } from 'fastify';
import { ok, parse } from '../../common/http';
import { createActivitySchema, listActivitiesSchema } from './activities.schema';
import * as service from './activities.service';

interface IdParams {
  id: string;
}

export async function activityRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', app.authenticate);

  app.get('/', async (request) => {
    const query = parse(listActivitiesSchema, request.query);
    const page = await service.listActivities(request.userId, query);
    const { items, ...meta } = page;
    return ok(items, meta);
  });

  app.post(
    '/',
    { config: { rateLimit: { max: 30, timeWindow: '1 hour' } } },
    async (request, reply) => {
      const input = parse(createActivitySchema, request.body);
      const activity = await service.createActivity(request.userId, input);
      return reply.code(201).send(ok(activity));
    },
  );

  app.get<{ Params: IdParams }>('/:id', async (request) =>
    ok(await service.getActivity(request.userId, request.params.id)),
  );

  app.delete<{ Params: IdParams }>('/:id', async (request) =>
    ok(await service.cancelActivity(request.userId, request.params.id)),
  );
}

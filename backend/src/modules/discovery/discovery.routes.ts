import type { FastifyInstance } from 'fastify';
import { ok, parse } from '../../common/http';
import { discoverActivitiesSchema, discoverPeopleSchema } from './discovery.schema';
import * as service from './discovery.service';

export async function discoveryRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', app.authenticate);

  /** Everything the home screen needs, in one request. */
  app.get('/', async (request) => ok(await service.getHomeFeed(request.userId)));

  app.get('/people', async (request) => {
    const query = parse(discoverPeopleSchema, request.query);
    const page = await service.discoverPeople(request.userId, query);
    const { items, ...meta } = page;
    return ok(items, meta);
  });

  app.get('/activities', async (request) => {
    const query = parse(discoverActivitiesSchema, request.query);
    const page = await service.discoverActivities(request.userId, query);
    const { items, ...meta } = page;
    return ok(items, meta);
  });
}

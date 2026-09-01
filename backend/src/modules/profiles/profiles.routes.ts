import type { FastifyInstance } from 'fastify';
import { ok, parse } from '../../common/http';
import { createProfileSchema, updateProfileSchema } from './profiles.schema';
import * as service from './profiles.service';

interface UserIdParams {
  id: string;
}

/** Public catalog — no session required, used by the profile setup flow. */
export async function catalogRoutes(app: FastifyInstance): Promise<void> {
  app.get('/interests', async () => ok({ items: await service.listInterests() }));
}

export async function userRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', app.authenticate);

  app.get('/me', async (request) => ok(await service.getMe(request.userId)));

  app.put('/me', async (request) => {
    const input = parse(updateProfileSchema, request.body);
    return ok(await service.updateProfile(request.userId, input));
  });

  /** Profile setup submits the whole profile at once; safe to call again to overwrite. */
  app.post('/me/profile', async (request, reply) => {
    const input = parse(createProfileSchema, request.body);
    const me = await service.upsertProfile(request.userId, input);
    return reply.code(201).send(ok(me));
  });

  app.get<{ Params: UserIdParams }>('/:id', async (request) =>
    ok(await service.getPublicProfile(request.userId, request.params.id)),
  );
}

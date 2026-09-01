import type { FastifyInstance } from 'fastify';
import { ok, parse } from '../../common/http';
import { createInvitationSchema, listInvitationsSchema } from './invitations.schema';
import * as service from './invitations.service';

interface IdParams {
  id: string;
}

export async function invitationRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', app.authenticate);

  app.post(
    '/',
    { config: { rateLimit: { max: 60, timeWindow: '1 hour' } } },
    async (request, reply) => {
      const input = parse(createInvitationSchema, request.body);
      const invitation = await service.createInvitation(request.userId, input);
      return reply.code(201).send(ok(invitation));
    },
  );

  app.get('/counts', async (request) => ok(await service.invitationCounts(request.userId)));

  app.get('/received', async (request) => {
    const query = parse(listInvitationsSchema, request.query);
    const { items, ...meta } = await service.listInvitations(request.userId, 'received', query);
    return ok(items, meta);
  });

  app.get('/sent', async (request) => {
    const query = parse(listInvitationsSchema, request.query);
    const { items, ...meta } = await service.listInvitations(request.userId, 'sent', query);
    return ok(items, meta);
  });

  app.get<{ Params: IdParams }>('/:id', async (request) =>
    ok(await service.getInvitation(request.userId, request.params.id)),
  );

  app.post<{ Params: IdParams }>('/:id/accept', async (request) =>
    ok(await service.acceptInvitation(request.userId, request.params.id)),
  );

  app.post<{ Params: IdParams }>('/:id/decline', async (request) =>
    ok(await service.declineInvitation(request.userId, request.params.id)),
  );

  app.post<{ Params: IdParams }>('/:id/cancel', async (request) =>
    ok(await service.cancelInvitation(request.userId, request.params.id)),
  );
}

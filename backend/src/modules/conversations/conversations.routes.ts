import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { ok, parse } from '../../common/http';
import { paginationSchema } from '../../common/pagination';
import { MESSAGES } from '../../config/constants';
import * as service from './conversations.service';

const sendMessageSchema = z.object({
  body: z
    .string()
    .trim()
    .min(1, 'Write something first.')
    .max(MESSAGES.maxLength, 'That message is too long.'),
});

interface IdParams {
  id: string;
}

export async function conversationRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', app.authenticate);

  app.get('/', async (request) => ok(await service.listConversations(request.userId)));

  app.get<{ Params: IdParams }>('/:id', async (request) =>
    ok(await service.getConversation(request.userId, request.params.id)),
  );

  app.get<{ Params: IdParams }>('/:id/messages', async (request) => {
    const query = parse(paginationSchema, request.query);
    const { items, ...meta } = await service.listMessages(request.userId, request.params.id, {
      cursor: query.cursor,
      limit: query.limit,
    });
    return ok(items, meta);
  });

  app.post<{ Params: IdParams }>(
    '/:id/messages',
    { config: { rateLimit: { max: 120, timeWindow: '1 minute' } } },
    async (request, reply) => {
      const { body } = parse(sendMessageSchema, request.body);
      const message = await service.sendMessage(request.userId, request.params.id, body);
      return reply.code(201).send(ok(message));
    },
  );

  app.post<{ Params: IdParams }>('/:id/read', async (request) =>
    ok(await service.markConversationRead(request.userId, request.params.id)),
  );
}

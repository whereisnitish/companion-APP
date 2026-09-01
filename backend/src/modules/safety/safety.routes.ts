import type { FastifyInstance } from 'fastify';
import { ok, parse } from '../../common/http';
import { blockSchema, reportSchema, REPORT_REASONS } from './safety.schema';
import * as service from './safety.service';

interface UserIdParams {
  id: string;
}

export async function safetyRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('preHandler', app.authenticate);

  app.get('/report-reasons', async () => ok({ reasons: REPORT_REASONS }));

  app.get('/blocks', async (request) => ok({ items: await service.listBlocked(request.userId) }));

  app.post<{ Params: UserIdParams }>('/users/:id/block', async (request) => {
    const { reason } = parse(blockSchema, request.body ?? {});
    return ok(await service.blockUser(request.userId, request.params.id, reason));
  });

  app.delete<{ Params: UserIdParams }>('/users/:id/block', async (request) =>
    ok(await service.unblockUser(request.userId, request.params.id)),
  );

  app.post<{ Params: UserIdParams }>(
    '/users/:id/report',
    { config: { rateLimit: { max: 10, timeWindow: '1 hour' } } },
    async (request, reply) => {
      const input = parse(reportSchema, request.body ?? {});
      const result = await service.reportUser(
        request.userId,
        request.params.id,
        input.reason,
        input.details,
      );
      return reply.code(201).send(ok(result));
    },
  );
}

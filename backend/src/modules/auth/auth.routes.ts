import type { FastifyInstance } from 'fastify';
import { ok, parse } from '../../common/http';
import {
  loginSchema,
  refreshSchema,
  registerSchema,
  requestOtpSchema,
  verifyOtpSchema,
} from './auth.schema';
import * as service from './auth.service';

/** Auth endpoints are the only unauthenticated writes — they get a tighter limit. */
const strictLimit = {
  config: { rateLimit: { max: 20, timeWindow: '1 minute' } },
};

export async function authRoutes(app: FastifyInstance): Promise<void> {
  app.post('/register', strictLimit, async (request, reply) => {
    const input = parse(registerSchema, request.body);
    const session = await service.register(app, input);
    return reply.code(201).send(ok(session));
  });

  app.post('/login', strictLimit, async (request) => {
    const input = parse(loginSchema, request.body);
    return ok(await service.login(app, input));
  });

  app.post('/refresh', strictLimit, async (request) => {
    const { refreshToken } = parse(refreshSchema, request.body);
    return ok(await service.refresh(app, refreshToken));
  });

  app.post('/logout', async (request) => {
    const { refreshToken } = parse(refreshSchema, request.body);
    await service.logout(refreshToken);
    return ok({ success: true });
  });

  app.post('/otp/request', strictLimit, async (request) => {
    const { phone } = parse(requestOtpSchema, request.body);
    return ok(await service.requestOtp(phone));
  });

  app.post('/otp/verify', strictLimit, async (request) => {
    const { phone, code } = parse(verifyOtpSchema, request.body);
    return ok(await service.verifyOtp(app, phone, code));
  });
}

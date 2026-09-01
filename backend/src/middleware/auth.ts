import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import fp from 'fastify-plugin';
import jwt from '@fastify/jwt';
import { env } from '../config/env';
import { unauthorized } from '../common/errors';

export interface AccessTokenPayload {
  sub: string;
  typ: 'access';
}

declare module 'fastify' {
  interface FastifyInstance {
    /** `preHandler` guard: rejects the request unless a valid access token is present. */
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
  interface FastifyRequest {
    /** Set by `authenticate`. Safe to read in any guarded handler. */
    userId: string;
  }
}

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: AccessTokenPayload;
    user: AccessTokenPayload;
  }
}

export const authPlugin = fp(async (app: FastifyInstance) => {
  await app.register(jwt, {
    secret: env.JWT_SECRET,
    sign: { expiresIn: env.JWT_ACCESS_TTL },
  });

  app.decorateRequest('userId', '');

  app.decorate('authenticate', async (request: FastifyRequest) => {
    try {
      const payload = await request.jwtVerify<AccessTokenPayload>();
      if (payload.typ !== 'access') throw unauthorized('Invalid token type.');
      request.userId = payload.sub;
    } catch (error) {
      if (error instanceof Error && 'statusCode' in error && (error as { statusCode: number }).statusCode === 401) {
        throw unauthorized('Your session has expired. Please sign in again.');
      }
      throw unauthorized('Your session has expired. Please sign in again.');
    }
  });
});

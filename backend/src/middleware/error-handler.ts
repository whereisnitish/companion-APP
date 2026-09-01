import type { FastifyInstance, FastifyError, FastifyReply, FastifyRequest } from 'fastify';
import { Prisma } from '@prisma/client';
import { ZodError } from 'zod';
import { AppError } from '../common/errors';
import { isProduction } from '../config/env';

interface ErrorBody {
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}

function body(code: string, message: string, details?: unknown): ErrorBody {
  return details === undefined ? { error: { code, message } } : { error: { code, message, details } };
}

/**
 * Every error leaves through here in one shape: `{ error: { code, message, details? } }`.
 * The mobile client can render `message` verbatim — messages are written for humans.
 */
export function registerErrorHandler(app: FastifyInstance): void {
  app.setNotFoundHandler((request: FastifyRequest, reply: FastifyReply) => {
    reply.code(404).send(body('ROUTE_NOT_FOUND', `No route for ${request.method} ${request.url}.`));
  });

  app.setErrorHandler((error: FastifyError, request: FastifyRequest, reply: FastifyReply) => {
    if (error instanceof AppError) {
      if (error.statusCode >= 500) request.log.error({ err: error }, 'Application error');
      return reply.code(error.statusCode).send(body(error.code, error.message, error.details));
    }

    if (error instanceof ZodError) {
      const fields: Record<string, string> = {};
      for (const issue of error.issues) fields[issue.path.join('.') || '_'] = issue.message;
      return reply.code(422).send(body('VALIDATION_ERROR', 'Some fields need attention.', fields));
    }

    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      if (error.code === 'P2002') {
        const target = (error.meta?.target as string[] | undefined)?.join(', ') ?? 'value';
        return reply.code(409).send(body('ALREADY_EXISTS', `That ${target} is already in use.`));
      }
      if (error.code === 'P2025') {
        return reply.code(404).send(body('NOT_FOUND', 'That record no longer exists.'));
      }
      request.log.error({ err: error }, 'Prisma error');
      return reply.code(400).send(body('DATABASE_ERROR', 'The request could not be completed.'));
    }

    if (error.statusCode === 429) {
      return reply.code(429).send(body('RATE_LIMITED', 'Too many requests. Try again shortly.'));
    }

    if (error.validation) {
      return reply.code(422).send(body('VALIDATION_ERROR', 'Some fields need attention.'));
    }

    request.log.error({ err: error }, 'Unhandled error');
    return reply
      .code(error.statusCode && error.statusCode < 500 ? error.statusCode : 500)
      .send(
        body(
          'INTERNAL_ERROR',
          isProduction ? 'Something went wrong on our side.' : error.message || 'Internal error',
        ),
      );
  });
}

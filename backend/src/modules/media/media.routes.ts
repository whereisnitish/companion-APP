import type { FastifyInstance } from 'fastify';
import { AppError } from '../../common/errors';
import { ok } from '../../common/http';
import { ACCEPTED_PHOTO_TYPES, MAX_PHOTO_BYTES, getPhoto, savePhoto } from './media.service';

/**
 * Public, because image widgets cannot send a session token. Ids are long and
 * random, and a new upload gets a new id, so responses can be cached for good.
 */
export async function mediaRoutes(app: FastifyInstance): Promise<void> {
  app.get<{ Params: { id: string } }>('/photos/:id', async (request, reply) => {
    const photo = await getPhoto(request.params.id);
    return reply
      .header('content-type', photo.contentType)
      .header('cache-control', 'public, max-age=31536000, immutable')
      // Helmet's default would stop a web build on another domain showing these.
      .header('cross-origin-resource-policy', 'cross-origin')
      .send(photo.data);
  });
}

/** `POST /users/me/photo`, with the raw image as the request body. Inherits the auth guard. */
export async function photoUploadRoutes(app: FastifyInstance): Promise<void> {
  app.addContentTypeParser(
    ACCEPTED_PHOTO_TYPES,
    { parseAs: 'buffer', bodyLimit: MAX_PHOTO_BYTES },
    (_request, body, done) => done(null, body),
  );

  app.post(
    '/me/photo',
    { config: { rateLimit: { max: 20, timeWindow: '1 minute' } } },
    async (request, reply) => {
      // Text and JSON use the app's other parsers, so they arrive here as something else.
      if (!Buffer.isBuffer(request.body)) {
        throw new AppError(415, 'UNSUPPORTED_IMAGE', 'Please use a JPEG, PNG or WebP photo.');
      }
      const id = await savePhoto(request.userId, request.body);
      const url = `${request.protocol}://${request.host}/media/photos/${id}`;
      return reply.code(201).send(ok({ url }));
    },
  );
}

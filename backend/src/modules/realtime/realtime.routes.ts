import type { FastifyInstance } from 'fastify';
import type { WebSocket } from 'ws';
import { prisma } from '../../database/prisma';
import { setPresence } from '../../database/redis';
import { realtime } from './hub';
import type { AccessTokenPayload } from '../../middleware/auth';

const PRESENCE_TTL_SECONDS = 90;
const HEARTBEAT_MS = 30_000;

interface ClientFrame {
  type: 'ping' | 'typing' | 'read';
  conversationId?: string;
  isTyping?: boolean;
}

/**
 * `GET /ws?token=<accessToken>` — a single multiplexed socket per device.
 * Browsers/mobile clients cannot set headers on a WebSocket handshake, so the
 * access token travels as a query parameter and is verified with the same key.
 */
export async function realtimeRoutes(app: FastifyInstance): Promise<void> {
  app.get<{ Querystring: { token?: string } }>('/ws', { websocket: true }, async (socket: WebSocket, request) => {
    const token = request.query.token;
    let userId: string;

    try {
      if (!token) throw new Error('missing token');
      const payload = app.jwt.verify<AccessTokenPayload>(token);
      if (payload.typ !== 'access') throw new Error('wrong token type');
      userId = payload.sub;
    } catch {
      socket.send(JSON.stringify({ type: 'error', payload: { code: 'UNAUTHORIZED' } }));
      socket.close(4401, 'Unauthorized');
      return;
    }

    realtime.add(userId, socket);
    void setPresence(userId, PRESENCE_TTL_SECONDS);
    socket.send(JSON.stringify({ type: 'connected', conversationId: null, payload: { userId } }));

    const heartbeat = setInterval(() => {
      void setPresence(userId, PRESENCE_TTL_SECONDS);
      if (socket.readyState === 1) socket.send(JSON.stringify({ type: 'ping', payload: null }));
    }, HEARTBEAT_MS);

    socket.on('message', (raw: Buffer | string) => {
      let frame: ClientFrame;
      try {
        frame = JSON.parse(raw.toString()) as ClientFrame;
      } catch {
        return;
      }

      if (frame.type === 'ping') {
        void setPresence(userId, PRESENCE_TTL_SECONDS);
        return;
      }

      if (frame.type === 'typing' && frame.conversationId) {
        const conversationId = frame.conversationId;
        void prisma.conversationParticipant
          .findMany({ where: { conversationId }, select: { userId: true } })
          .then((participants) => {
            const others = participants.map((p) => p.userId).filter((id) => id !== userId);
            realtime.emitMany(others, {
              type: 'typing',
              conversationId,
              payload: { userId, isTyping: frame.isTyping !== false },
            });
          })
          .catch(() => undefined);
      }
    });

    socket.on('close', () => {
      clearInterval(heartbeat);
      realtime.remove(userId, socket);
    });

    socket.on('error', () => {
      clearInterval(heartbeat);
      realtime.remove(userId, socket);
    });
  });
}

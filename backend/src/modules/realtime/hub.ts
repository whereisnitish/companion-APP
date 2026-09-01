import type { WebSocket } from 'ws';

export type RealtimeEvent =
  | { type: 'message:new'; conversationId: string; payload: unknown }
  | { type: 'message:read'; conversationId: string; payload: unknown }
  | { type: 'typing'; conversationId: string; payload: { userId: string; isTyping: boolean } }
  | { type: 'presence'; conversationId: null; payload: { userId: string; isOnline: boolean } }
  | { type: 'invitation:new'; conversationId: null; payload: unknown }
  | { type: 'invitation:updated'; conversationId: null; payload: unknown }
  | { type: 'notification'; conversationId: null; payload: unknown };

/**
 * In-process fan-out registry: userId -> open sockets (a user may have several
 * devices). For a single-node MVP this is all we need; swapping in a Redis
 * pub/sub bridge later only changes this file.
 */
class RealtimeHub {
  private readonly sockets = new Map<string, Set<WebSocket>>();

  add(userId: string, socket: WebSocket): void {
    const existing = this.sockets.get(userId);
    if (existing) existing.add(socket);
    else this.sockets.set(userId, new Set([socket]));
  }

  remove(userId: string, socket: WebSocket): void {
    const existing = this.sockets.get(userId);
    if (!existing) return;
    existing.delete(socket);
    if (existing.size === 0) this.sockets.delete(userId);
  }

  isOnline(userId: string): boolean {
    return this.sockets.has(userId);
  }

  onlineAmong(userIds: string[]): Set<string> {
    return new Set(userIds.filter((id) => this.sockets.has(id)));
  }

  emit(userId: string, event: RealtimeEvent): void {
    const sockets = this.sockets.get(userId);
    if (!sockets || sockets.size === 0) return;
    const frame = JSON.stringify(event);
    for (const socket of sockets) {
      // 1 === WebSocket.OPEN
      if (socket.readyState === 1) {
        try {
          socket.send(frame);
        } catch {
          /* a dead socket is cleaned up by its own close handler */
        }
      }
    }
  }

  emitMany(userIds: string[], event: RealtimeEvent): void {
    for (const userId of userIds) this.emit(userId, event);
  }
}

export const realtime = new RealtimeHub();

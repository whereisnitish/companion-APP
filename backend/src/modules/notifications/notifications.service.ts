import type { NotificationType, Prisma } from '@prisma/client';
import { prisma } from '../../database/prisma';
import { buildPage, cursorArgs, type Page } from '../../common/pagination';
import { serializeNotification, type NotificationDto } from '../../common/serializers';
import { realtime } from '../realtime/hub';

export interface CreateNotificationInput {
  userId: string;
  type: NotificationType;
  title: string;
  body?: string;
  data?: Prisma.InputJsonValue;
}

/**
 * Persist, then push. The row is the source of truth; the socket frame is an
 * optimisation for a client that happens to be connected. Push providers
 * (APNs/FCM) plug in here later without touching call sites.
 */
export async function notify(input: CreateNotificationInput): Promise<NotificationDto> {
  const notification = await prisma.notification.create({
    data: {
      userId: input.userId,
      type: input.type,
      title: input.title,
      body: input.body ?? '',
      data: input.data ?? undefined,
    },
  });

  const dto = serializeNotification(notification);
  realtime.emit(input.userId, { type: 'notification', conversationId: null, payload: dto });
  return dto;
}

export async function listNotifications(
  userId: string,
  options: { cursor?: string; limit: number; unreadOnly: boolean },
): Promise<Page<NotificationDto> & { unreadCount: number }> {
  const [rows, unreadCount] = await Promise.all([
    prisma.notification.findMany({
      where: { userId, ...(options.unreadOnly ? { readAt: null } : {}) },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: options.limit + 1,
      ...cursorArgs(options.cursor),
    }),
    prisma.notification.count({ where: { userId, readAt: null } }),
  ]);

  const page = buildPage(rows, options.limit);
  return { ...page, items: page.items.map(serializeNotification), unreadCount };
}

export async function markRead(userId: string, notificationId: string): Promise<{ id: string }> {
  await prisma.notification.updateMany({
    where: { id: notificationId, userId, readAt: null },
    data: { readAt: new Date() },
  });
  return { id: notificationId };
}

export async function markAllRead(userId: string): Promise<{ updated: number }> {
  const result = await prisma.notification.updateMany({
    where: { userId, readAt: null },
    data: { readAt: new Date() },
  });
  return { updated: result.count };
}

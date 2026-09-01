import { prisma } from '../../database/prisma';
import { forbidden, notFound } from '../../common/errors';
import { MESSAGES } from '../../config/constants';
import { buildPage, cursorArgs, type Page } from '../../common/pagination';
import {
  serializeMessage,
  serializePublicProfile,
  truncatePreview,
  userWithProfileInclude,
  type ConversationDto,
  type MessageDto,
} from '../../common/serializers';
import { realtime } from '../realtime/hub';
import { notify } from '../notifications/notifications.service';
import { getBlockedUserIds, isBlockedBetween } from '../safety/safety.service';

/** Membership check every conversation read/write goes through. */
async function assertMember(userId: string, conversationId: string): Promise<void> {
  const membership = await prisma.conversationParticipant.findUnique({
    where: { conversationId_userId: { conversationId, userId } },
    select: { userId: true },
  });
  if (!membership) throw forbidden('This conversation is not yours.');
}

export async function listConversations(userId: string): Promise<ConversationDto[]> {
  const blocked = await getBlockedUserIds(userId);

  const conversations = await prisma.conversation.findMany({
    where: {
      participants: { some: { userId } },
      ...(blocked.length ? { NOT: { participants: { some: { userId: { in: blocked } } } } } : {}),
    },
    orderBy: { lastMessageAt: 'desc' },
    take: 100,
    include: {
      participants: { include: { user: { include: userWithProfileInclude } } },
      activity: {
        select: { id: true, category: true, title: true, startsAt: true, locationName: true },
      },
    },
  });

  if (conversations.length === 0) return [];

  // One grouped count instead of a query per row — no N+1 on the inbox.
  const unreadRows = await prisma.message.groupBy({
    by: ['conversationId'],
    where: {
      conversationId: { in: conversations.map((conversation) => conversation.id) },
      senderId: { not: userId },
      readAt: null,
      // The system line that opens a chat is context, not an unread message.
      type: 'TEXT',
    },
    _count: { _all: true },
  });
  const unreadByConversation = new Map(
    unreadRows.map((row) => [row.conversationId, row._count._all]),
  );

  return conversations.map((conversation) => {
    const other = conversation.participants.find((participant) => participant.userId !== userId);
    return {
      id: conversation.id,
      lastMessageAt: conversation.lastMessageAt.toISOString(),
      lastMessagePreview: conversation.lastMessagePreview,
      unreadCount: unreadByConversation.get(conversation.id) ?? 0,
      participant: other
        ? serializePublicProfile(other.user, { isOnline: realtime.isOnline(other.userId) })
        : serializePublicProfile({ ...conversations[0]!.participants[0]!.user }),
      activity: conversation.activity
        ? {
            id: conversation.activity.id,
            category: conversation.activity.category,
            title: conversation.activity.title,
            startsAt: conversation.activity.startsAt.toISOString(),
            locationName: conversation.activity.locationName,
          }
        : null,
    };
  });
}

export async function getConversation(userId: string, conversationId: string): Promise<ConversationDto> {
  await assertMember(userId, conversationId);

  const conversation = await prisma.conversation.findUnique({
    where: { id: conversationId },
    include: {
      participants: { include: { user: { include: userWithProfileInclude } } },
      activity: {
        select: { id: true, category: true, title: true, startsAt: true, locationName: true },
      },
    },
  });
  if (!conversation) throw notFound('Conversation');

  const other = conversation.participants.find((participant) => participant.userId !== userId);
  const unreadCount = await prisma.message.count({
    where: { conversationId, senderId: { not: userId }, readAt: null, type: 'TEXT' },
  });

  return {
    id: conversation.id,
    lastMessageAt: conversation.lastMessageAt.toISOString(),
    lastMessagePreview: conversation.lastMessagePreview,
    unreadCount,
    participant: other
      ? serializePublicProfile(other.user, { isOnline: realtime.isOnline(other.userId) })
      : serializePublicProfile(conversation.participants[0]!.user),
    activity: conversation.activity
      ? {
          id: conversation.activity.id,
          category: conversation.activity.category,
          title: conversation.activity.title,
          startsAt: conversation.activity.startsAt.toISOString(),
          locationName: conversation.activity.locationName,
        }
      : null,
  };
}

export async function listMessages(
  userId: string,
  conversationId: string,
  options: { cursor?: string; limit: number },
): Promise<Page<MessageDto>> {
  await assertMember(userId, conversationId);

  // Newest first so the client can render a reversed list and page backwards.
  const rows = await prisma.message.findMany({
    where: { conversationId },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: options.limit + 1,
    ...cursorArgs(options.cursor),
  });

  const page = buildPage(rows, options.limit);
  return { ...page, items: page.items.map((message) => serializeMessage(message, userId)) };
}

export async function sendMessage(
  userId: string,
  conversationId: string,
  body: string,
): Promise<MessageDto> {
  await assertMember(userId, conversationId);

  const participants = await prisma.conversationParticipant.findMany({
    where: { conversationId },
    select: { userId: true },
  });
  const others = participants.map((p) => p.userId).filter((id) => id !== userId);

  for (const otherId of others) {
    if (await isBlockedBetween(userId, otherId)) {
      throw forbidden('You can no longer message this person.');
    }
  }

  const trimmed = body.trim().slice(0, MESSAGES.maxLength);
  const now = new Date();

  const [message] = await prisma.$transaction([
    prisma.message.create({ data: { conversationId, senderId: userId, body: trimmed } }),
    prisma.conversation.update({
      where: { id: conversationId },
      data: { lastMessageAt: now, lastMessagePreview: truncatePreview(trimmed) },
    }),
  ]);

  const dto = serializeMessage(message, userId);

  for (const otherId of others) {
    realtime.emit(otherId, {
      type: 'message:new',
      conversationId,
      payload: { ...dto, isMine: false },
    });
  }

  // Only ping people who are not looking at the app right now.
  const sender = await prisma.profile.findUnique({
    where: { userId },
    select: { displayName: true },
  });
  for (const otherId of others) {
    if (!realtime.isOnline(otherId)) {
      await notify({
        userId: otherId,
        type: 'MESSAGE_RECEIVED',
        title: sender?.displayName ?? 'New message',
        body: truncatePreview(trimmed),
        data: { conversationId, messageId: message.id },
      });
    }
  }

  return dto;
}

export async function markConversationRead(
  userId: string,
  conversationId: string,
): Promise<{ readCount: number }> {
  await assertMember(userId, conversationId);
  const now = new Date();

  const [result] = await prisma.$transaction([
    prisma.message.updateMany({
      where: { conversationId, senderId: { not: userId }, readAt: null },
      data: { readAt: now },
    }),
    prisma.conversationParticipant.update({
      where: { conversationId_userId: { conversationId, userId } },
      data: { lastReadAt: now },
    }),
  ]);

  if (result.count > 0) {
    const others = await prisma.conversationParticipant.findMany({
      where: { conversationId, userId: { not: userId } },
      select: { userId: true },
    });
    for (const other of others) {
      realtime.emit(other.userId, {
        type: 'message:read',
        conversationId,
        payload: { readerId: userId, readAt: now.toISOString() },
      });
    }
  }

  return { readCount: result.count };
}

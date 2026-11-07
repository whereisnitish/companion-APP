import type { Prisma } from '@prisma/client';
import { prisma } from '../../database/prisma';
import { badRequest, conflict, forbidden, notFound, tooManyRequests } from '../../common/errors';
import { INVITATIONS, REDIS_KEYS } from '../../config/constants';
import { buildPage, cursorArgs, type Page } from '../../common/pagination';
import { addHours, dayKey } from '../../utils/dates';
import { cacheDeleteByPrefix, incrementCounter } from '../../database/redis';
import {
  invitationInclude,
  serializeInvitation,
  type InvitationDto,
} from '../../common/serializers';
import { realtime } from '../realtime/hub';
import { notify } from '../notifications/notifications.service';
import { isBlockedBetween } from '../safety/safety.service';
import type { CreateInvitationInput, ListInvitationsQuery } from './invitations.schema';

/** A pending invitation quietly ages out; we settle that lazily on read. */
async function expireStaleInvitations(userId: string): Promise<void> {
  await prisma.invitation.updateMany({
    where: {
      status: 'PENDING',
      createdAt: { lt: addHours(new Date(), -INVITATIONS.expiryHours) },
      OR: [{ senderId: userId }, { recipientId: userId }],
    },
    data: { status: 'EXPIRED', respondedAt: new Date() },
  });
}

/** An invitation that still ties two people together: waiting, or answered with a chat. */
function liveInvitationWhere(): Prisma.InvitationWhereInput {
  return {
    OR: [
      { status: 'PENDING', createdAt: { gte: addHours(new Date(), -INVITATIONS.expiryHours) } },
      { status: 'ACCEPTED', conversation: { isNot: null } },
    ],
  };
}

/** Everyone discovery should stop suggesting to this person, in either direction. */
export async function connectedOrInvitedUserIds(userId: string): Promise<string[]> {
  const rows = await prisma.invitation.findMany({
    where: {
      AND: [{ OR: [{ senderId: userId }, { recipientId: userId }] }, liveInvitationWhere()],
    },
    select: { senderId: true, recipientId: true },
  });
  return [...new Set(rows.map((row) => (row.senderId === userId ? row.recipientId : row.senderId)))];
}

export type PersonConnection =
  | { status: 'CONNECTED'; conversationId: string }
  | { status: 'INVITED_BY_ME' }
  | { status: 'INVITED_ME' };

/** How the viewer stands with someone. A chat outranks any invitation still waiting. */
export async function connectionBetween(
  viewerId: string,
  targetId: string,
): Promise<PersonConnection | null> {
  const rows = await prisma.invitation.findMany({
    where: {
      AND: [
        {
          OR: [
            { senderId: viewerId, recipientId: targetId },
            { senderId: targetId, recipientId: viewerId },
          ],
        },
        liveInvitationWhere(),
      ],
    },
    orderBy: { createdAt: 'desc' },
    select: { senderId: true, conversation: { select: { id: true } } },
  });

  const connected = rows.find((row) => row.conversation);
  if (connected?.conversation) {
    return { status: 'CONNECTED', conversationId: connected.conversation.id };
  }
  const waiting = rows[0];
  if (!waiting) return null;
  return { status: waiting.senderId === viewerId ? 'INVITED_BY_ME' : 'INVITED_ME' };
}

/** Discovery caches each person's list, so a change here must clear both people's. */
async function refreshDiscoveryFor(...userIds: string[]): Promise<void> {
  await Promise.all(userIds.map((id) => cacheDeleteByPrefix(`discover:people:${id}:`)));
}

export async function createInvitation(
  senderId: string,
  input: CreateInvitationInput,
): Promise<InvitationDto> {
  if (senderId === input.recipientId) throw badRequest('You cannot invite yourself.');

  if (await isBlockedBetween(senderId, input.recipientId)) {
    throw forbidden('You cannot send an invitation to this person.');
  }

  const recipient = await prisma.user.findUnique({
    where: { id: input.recipientId },
    select: { id: true, isActive: true, profile: { select: { displayName: true } } },
  });
  if (!recipient || !recipient.isActive) throw notFound('User');

  if (input.activityId) {
    const activity = await prisma.activity.findUnique({
      where: { id: input.activityId },
      select: { id: true, status: true, hostId: true },
    });
    if (!activity) throw notFound('Activity');
    if (activity.status !== 'OPEN') throw conflict('That plan is no longer open.', 'ACTIVITY_CLOSED');
  }

  // A general invitation adds nothing to an open chat or to one already waiting
  // on you. Asking to join a specific plan is still allowed.
  if (!input.activityId) {
    const connection = await connectionBetween(senderId, input.recipientId);
    if (connection?.status === 'CONNECTED') {
      throw conflict('You are already connected. Say hello in your chat.', 'ALREADY_CONNECTED');
    }
    if (connection?.status === 'INVITED_ME') {
      throw conflict('They have already invited you. Check your invitations.', 'INVITATION_PENDING');
    }
  }

  // One live invitation per pair per activity — no repeat-tapping the button.
  const duplicate = await prisma.invitation.findFirst({
    where: {
      senderId,
      recipientId: input.recipientId,
      status: 'PENDING',
      ...(input.activityId ? { activityId: input.activityId } : {}),
    },
    select: { id: true },
  });
  if (duplicate) {
    throw conflict('You already have an invitation waiting with them.', 'INVITATION_PENDING');
  }

  const sentToday = await incrementCounter(
    REDIS_KEYS.invitationQuota(senderId, dayKey()),
    24 * 60 * 60,
  );
  if (sentToday > INVITATIONS.maxPerDay) {
    throw tooManyRequests(`You can send up to ${INVITATIONS.maxPerDay} invitations a day.`);
  }

  const invitation = await prisma.invitation.create({
    data: {
      senderId,
      recipientId: input.recipientId,
      activityId: input.activityId ?? null,
      category: input.category ?? null,
      proposedAt: input.proposedAt ?? null,
      locationName: input.locationName ?? null,
      message: input.message,
    },
    include: invitationInclude,
  });

  await refreshDiscoveryFor(senderId, input.recipientId);

  const dto = serializeInvitation(invitation, input.recipientId);
  const senderName = invitation.sender.profile?.displayName ?? 'Someone';

  await notify({
    userId: input.recipientId,
    type: 'INVITATION_RECEIVED',
    title: `${senderName} invited you`,
    body: invitation.message || `${senderName} would like to join you.`,
    data: { invitationId: invitation.id, senderId },
  });

  realtime.emit(input.recipientId, { type: 'invitation:new', conversationId: null, payload: dto });
  return serializeInvitation(invitation, senderId);
}

export async function listInvitations(
  userId: string,
  direction: 'received' | 'sent',
  query: ListInvitationsQuery,
): Promise<Page<InvitationDto>> {
  await expireStaleInvitations(userId);

  const where: Prisma.InvitationWhereInput = {
    ...(direction === 'received' ? { recipientId: userId } : { senderId: userId }),
    ...(query.status ? { status: query.status } : {}),
  };

  const rows = await prisma.invitation.findMany({
    where,
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: query.limit + 1,
    ...cursorArgs(query.cursor),
    include: invitationInclude,
  });

  const page = buildPage(rows, query.limit);
  return {
    ...page,
    items: page.items.map((invitation) =>
      serializeInvitation(invitation, userId, {
        isOnline: realtime.isOnline(
          direction === 'received' ? invitation.senderId : invitation.recipientId,
        ),
      }),
    ),
  };
}

export async function getInvitation(userId: string, invitationId: string): Promise<InvitationDto> {
  const invitation = await prisma.invitation.findUnique({
    where: { id: invitationId },
    include: invitationInclude,
  });
  if (!invitation) throw notFound('Invitation');
  if (invitation.senderId !== userId && invitation.recipientId !== userId) {
    throw forbidden('This invitation is not yours.');
  }
  return serializeInvitation(invitation, userId);
}

/**
 * Accepting is the product's one real state transition: it creates the
 * connection *and* the conversation, with a system message carrying the
 * activity context so the chat never opens empty.
 */
export async function acceptInvitation(userId: string, invitationId: string): Promise<InvitationDto> {
  const invitation = await prisma.invitation.findUnique({
    where: { id: invitationId },
    include: invitationInclude,
  });
  if (!invitation) throw notFound('Invitation');
  if (invitation.recipientId !== userId) throw forbidden('Only the recipient can accept this.');
  if (invitation.status !== 'PENDING') {
    throw conflict('This invitation has already been answered.', 'INVITATION_SETTLED');
  }

  const recipientName = invitation.recipient.profile?.displayName ?? 'Your companion';
  const openingLine = invitation.activity
    ? `You're both in for ${invitation.activity.title}.`
    : 'You are now connected. Say hello!';

  const conversationId = await prisma.$transaction(async (tx) => {
    await tx.invitation.update({
      where: { id: invitationId },
      data: { status: 'ACCEPTED', respondedAt: new Date() },
    });

    if (invitation.activityId) {
      await tx.activityParticipant.upsert({
        where: { activityId_userId: { activityId: invitation.activityId, userId } },
        create: { activityId: invitation.activityId, userId, role: 'GUEST' },
        update: {},
      });
    }

    const existing = await tx.conversation.findUnique({
      where: { invitationId },
      select: { id: true },
    });
    if (existing) return existing.id;

    const conversation = await tx.conversation.create({
      data: {
        invitationId,
        activityId: invitation.activityId,
        lastMessagePreview: openingLine,
        participants: {
          create: [{ userId: invitation.senderId }, { userId: invitation.recipientId }],
        },
        messages: {
          create: {
            senderId: userId,
            body: openingLine,
            type: 'SYSTEM',
          },
        },
      },
      select: { id: true },
    });
    return conversation.id;
  });

  await refreshDiscoveryFor(invitation.senderId, invitation.recipientId);

  const updated = await prisma.invitation.findUniqueOrThrow({
    where: { id: invitationId },
    include: invitationInclude,
  });

  await notify({
    userId: invitation.senderId,
    type: 'INVITATION_ACCEPTED',
    title: `${recipientName} said yes`,
    body: openingLine,
    data: { invitationId, conversationId },
  });

  realtime.emit(invitation.senderId, {
    type: 'invitation:updated',
    conversationId: null,
    payload: serializeInvitation(updated, invitation.senderId),
  });

  return serializeInvitation(updated, userId);
}

export async function declineInvitation(userId: string, invitationId: string): Promise<InvitationDto> {
  const invitation = await prisma.invitation.findUnique({
    where: { id: invitationId },
    include: invitationInclude,
  });
  if (!invitation) throw notFound('Invitation');
  if (invitation.recipientId !== userId) throw forbidden('Only the recipient can decline this.');
  if (invitation.status !== 'PENDING') {
    throw conflict('This invitation has already been answered.', 'INVITATION_SETTLED');
  }

  const updated = await prisma.invitation.update({
    where: { id: invitationId },
    data: { status: 'DECLINED', respondedAt: new Date() },
    include: invitationInclude,
  });

  await refreshDiscoveryFor(invitation.senderId, invitation.recipientId);

  // The sender is told the invitation was answered, never who declined what — kept low-key.
  await notify({
    userId: invitation.senderId,
    type: 'INVITATION_DECLINED',
    title: 'Your invitation was answered',
    body: 'They are not free for this one. Plenty of other plans nearby.',
    data: { invitationId },
  });

  realtime.emit(invitation.senderId, {
    type: 'invitation:updated',
    conversationId: null,
    payload: serializeInvitation(updated, invitation.senderId),
  });

  return serializeInvitation(updated, userId);
}

export async function cancelInvitation(userId: string, invitationId: string): Promise<InvitationDto> {
  const invitation = await prisma.invitation.findUnique({
    where: { id: invitationId },
    select: { id: true, senderId: true, recipientId: true, status: true },
  });
  if (!invitation) throw notFound('Invitation');
  if (invitation.senderId !== userId) throw forbidden('Only the sender can withdraw this.');
  if (invitation.status !== 'PENDING') {
    throw conflict('This invitation has already been answered.', 'INVITATION_SETTLED');
  }

  const updated = await prisma.invitation.update({
    where: { id: invitationId },
    data: { status: 'CANCELLED', respondedAt: new Date() },
    include: invitationInclude,
  });

  await refreshDiscoveryFor(invitation.senderId, invitation.recipientId);

  return serializeInvitation(updated, userId);
}

export async function invitationCounts(userId: string) {
  const [pendingReceived, pendingSent, accepted] = await Promise.all([
    prisma.invitation.count({ where: { recipientId: userId, status: 'PENDING' } }),
    prisma.invitation.count({ where: { senderId: userId, status: 'PENDING' } }),
    prisma.invitation.count({
      where: { status: 'ACCEPTED', OR: [{ senderId: userId }, { recipientId: userId }] },
    }),
  ]);
  return { pendingReceived, pendingSent, accepted };
}

import { prisma } from '../../database/prisma';
import { badRequest, conflict, notFound } from '../../common/errors';

/**
 * Blocking is symmetric for visibility: if either side has blocked the other,
 * neither appears in the other's discovery, invitations or conversations.
 * Every read path funnels through this so a block can never leak.
 */
export async function getBlockedUserIds(userId: string): Promise<string[]> {
  const blocks = await prisma.block.findMany({
    where: { OR: [{ blockerId: userId }, { blockedId: userId }] },
    select: { blockerId: true, blockedId: true },
  });

  const ids = new Set<string>();
  for (const block of blocks) {
    ids.add(block.blockerId === userId ? block.blockedId : block.blockerId);
  }
  return [...ids];
}

export async function isBlockedBetween(a: string, b: string): Promise<boolean> {
  const block = await prisma.block.findFirst({
    where: {
      OR: [
        { blockerId: a, blockedId: b },
        { blockerId: b, blockedId: a },
      ],
    },
    select: { id: true },
  });
  return block !== null;
}

export async function blockUser(blockerId: string, blockedId: string, reason?: string) {
  if (blockerId === blockedId) throw badRequest('You cannot block yourself.');

  const target = await prisma.user.findUnique({ where: { id: blockedId }, select: { id: true } });
  if (!target) throw notFound('User');

  const existing = await prisma.block.findUnique({
    where: { blockerId_blockedId: { blockerId, blockedId } },
    select: { id: true },
  });
  if (existing) throw conflict('You have already blocked this person.', 'ALREADY_BLOCKED');

  await prisma.$transaction([
    prisma.block.create({ data: { blockerId, blockedId, reason: reason ?? null } }),
    // A block also withdraws anything still pending between the two.
    prisma.invitation.updateMany({
      where: {
        status: 'PENDING',
        OR: [
          { senderId: blockerId, recipientId: blockedId },
          { senderId: blockedId, recipientId: blockerId },
        ],
      },
      data: { status: 'CANCELLED', respondedAt: new Date() },
    }),
  ]);

  return { blocked: true };
}

export async function unblockUser(blockerId: string, blockedId: string) {
  await prisma.block.deleteMany({ where: { blockerId, blockedId } });
  return { blocked: false };
}

export async function listBlocked(blockerId: string) {
  const blocks = await prisma.block.findMany({
    where: { blockerId },
    orderBy: { createdAt: 'desc' },
    include: { blocked: { include: { profile: true } } },
  });

  return blocks.map((block) => ({
    id: block.blocked.id,
    displayName: block.blocked.profile?.displayName ?? 'Someone',
    avatarUrl: block.blocked.profile?.avatarUrl ?? null,
    blockedAt: block.createdAt.toISOString(),
  }));
}

export async function reportUser(
  reporterId: string,
  reportedId: string,
  reason: string,
  details: string,
) {
  if (reporterId === reportedId) throw badRequest('You cannot report yourself.');

  const target = await prisma.user.findUnique({ where: { id: reportedId }, select: { id: true } });
  if (!target) throw notFound('User');

  const report = await prisma.report.create({
    data: { reporterId, reportedId, reason, details },
    select: { id: true, createdAt: true },
  });

  return {
    id: report.id,
    submittedAt: report.createdAt.toISOString(),
    message: 'Thanks for letting us know. Our team will review this within 24 hours.',
  };
}

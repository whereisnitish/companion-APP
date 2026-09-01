import type { Prisma } from '@prisma/client';
import { prisma } from '../../database/prisma';
import { forbidden, notFound } from '../../common/errors';
import { buildPage, cursorArgs, type Page } from '../../common/pagination';
import { distanceKm, roundDistance } from '../../common/geo';
import { cacheDeleteByPrefix } from '../../database/redis';
import {
  activityInclude,
  serializeActivity,
  type ActivityDto,
} from '../../common/serializers';
import { realtime } from '../realtime/hub';
import { getBlockedUserIds } from '../safety/safety.service';
import type { CreateActivityInput, ListActivitiesQuery } from './activities.schema';

async function viewerCoordinates(userId: string) {
  return prisma.profile.findUnique({
    where: { userId },
    select: { latitude: true, longitude: true },
  });
}

export async function createActivity(
  userId: string,
  input: CreateActivityInput,
): Promise<ActivityDto> {
  const activity = await prisma.activity.create({
    data: {
      hostId: userId,
      category: input.category,
      title: input.title,
      description: input.description,
      startsAt: input.startsAt,
      endsAt: input.endsAt ?? null,
      locationName: input.locationName,
      area: input.area ?? null,
      city: input.city,
      latitude: input.latitude,
      longitude: input.longitude,
      lookingFor: input.lookingFor,
      minAge: input.minAge,
      maxAge: input.maxAge,
      capacity: input.capacity,
      // The host is a participant from the moment the plan exists.
      participants: { create: { userId, role: 'HOST' } },
    },
    include: activityInclude,
  });

  await cacheDeleteByPrefix('discover:');
  return serializeActivity(activity, { viewerId: userId, distanceKm: 0 });
}

export async function getActivity(viewerId: string, activityId: string): Promise<ActivityDto> {
  const [activity, viewer, invitation] = await Promise.all([
    prisma.activity.findUnique({ where: { id: activityId }, include: activityInclude }),
    viewerCoordinates(viewerId),
    prisma.invitation.findFirst({
      where: { activityId, senderId: viewerId },
      orderBy: { createdAt: 'desc' },
      select: { status: true },
    }),
  ]);

  if (!activity) throw notFound('Activity');

  const blocked = await getBlockedUserIds(viewerId);
  if (blocked.includes(activity.hostId)) throw notFound('Activity');

  const distance = viewer ? roundDistance(distanceKm(viewer, activity)) : null;

  return serializeActivity(activity, {
    viewerId,
    distanceKm: distance,
    isOnline: realtime.isOnline(activity.hostId),
    viewerInvitationStatus: invitation?.status ?? null,
  });
}

export async function listActivities(
  userId: string,
  query: ListActivitiesQuery,
): Promise<Page<ActivityDto>> {
  const scopeFilter: Prisma.ActivityWhereInput =
    query.scope === 'mine'
      ? { hostId: userId }
      : query.scope === 'joined'
        ? { participants: { some: { userId } }, hostId: { not: userId } }
        : { OR: [{ hostId: userId }, { participants: { some: { userId } } }] };

  const rows = await prisma.activity.findMany({
    where: { ...scopeFilter, ...(query.status ? { status: query.status } : {}) },
    orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
    take: query.limit + 1,
    ...cursorArgs(query.cursor),
    include: activityInclude,
  });

  const viewer = await viewerCoordinates(userId);
  const page = buildPage(rows, query.limit);

  return {
    ...page,
    items: page.items.map((activity) =>
      serializeActivity(activity, {
        viewerId: userId,
        distanceKm: viewer ? roundDistance(distanceKm(viewer, activity)) : null,
        isOnline: realtime.isOnline(activity.hostId),
      }),
    ),
  };
}

export async function cancelActivity(userId: string, activityId: string): Promise<{ id: string; status: string }> {
  const activity = await prisma.activity.findUnique({
    where: { id: activityId },
    select: { id: true, hostId: true },
  });
  if (!activity) throw notFound('Activity');
  if (activity.hostId !== userId) throw forbidden('Only the host can cancel this plan.');

  const [updated] = await prisma.$transaction([
    prisma.activity.update({
      where: { id: activityId },
      data: { status: 'CANCELLED' },
      select: { id: true, status: true },
    }),
    prisma.invitation.updateMany({
      where: { activityId, status: 'PENDING' },
      data: { status: 'CANCELLED', respondedAt: new Date() },
    }),
  ]);

  await cacheDeleteByPrefix('discover:');
  return updated;
}

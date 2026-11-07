import { Prisma } from '@prisma/client';
import type { ActivityCategory, AvailabilitySlot, Gender } from '@prisma/client';
import { prisma } from '../../database/prisma';
import { notFound } from '../../common/errors';
import { DISCOVERY } from '../../config/constants';
import { boundingBox, distanceKm, roundDistance } from '../../common/geo';
import { birthDateForAge } from '../../utils/dates';
import { stableHash } from '../../utils/tokens';
import { cacheGet, cacheSet } from '../../database/redis';
import {
  activityInclude,
  serializeActivity,
  serializePublicProfile,
  userWithProfileInclude,
  type ActivityDto,
  type PublicProfileDto,
} from '../../common/serializers';
import { realtime } from '../realtime/hub';
import { connectedOrInvitedUserIds } from '../invitations/invitations.service';
import { getBlockedUserIds } from '../safety/safety.service';
import type { DiscoverActivitiesQuery, DiscoverPeopleQuery } from './discovery.schema';

/** How many candidates we score in memory before paging. Bounded on purpose. */
const CANDIDATE_LIMIT = 300;

interface Viewer {
  userId: string;
  latitude: number;
  longitude: number;
  city: string;
  preferredActivities: ActivityCategory[];
  interestSlugs: string[];
  availability: AvailabilitySlot[];
}

async function loadViewer(userId: string): Promise<Viewer> {
  const profile = await prisma.profile.findUnique({
    where: { userId },
    include: { interests: { include: { interest: { select: { slug: true } } } } },
  });
  if (!profile) throw notFound('Profile');

  return {
    userId,
    latitude: profile.latitude,
    longitude: profile.longitude,
    city: profile.city,
    preferredActivities: profile.preferredActivities,
    interestSlugs: profile.interests.map((link) => link.interest.slug),
    availability: profile.availability,
  };
}

const overlap = <T>(a: readonly T[], b: readonly T[]): number =>
  a.filter((item) => b.includes(item)).length;

/**
 * Relevance, not romance. The score is deliberately legible: shared activities
 * and interests dominate, proximity and freshness break ties. No black box.
 */
function scorePerson(
  viewer: Viewer,
  candidate: {
    preferredActivities: ActivityCategory[];
    availability: AvailabilitySlot[];
    interestSlugs: string[];
    lastActiveAt: Date;
  },
  distance: number,
): number {
  const activityScore = overlap(viewer.preferredActivities, candidate.preferredActivities) * 14;
  const interestScore = overlap(viewer.interestSlugs, candidate.interestSlugs) * 9;
  const availabilityScore = overlap(viewer.availability, candidate.availability) * 6;
  const proximityScore = Math.max(0, 30 - distance * 1.2);
  const hoursSinceActive = (Date.now() - candidate.lastActiveAt.getTime()) / 3_600_000;
  const freshnessScore = Math.max(0, 20 - hoursSinceActive * 0.4);

  return activityScore + interestScore + availabilityScore + proximityScore + freshnessScore;
}

export interface DiscoveryPage<T> {
  items: T[];
  page: number;
  limit: number;
  total: number;
  hasMore: boolean;
}

function paginate<T>(rows: T[], page: number, limit: number): DiscoveryPage<T> {
  const start = (page - 1) * limit;
  return {
    items: rows.slice(start, start + limit),
    page,
    limit,
    total: rows.length,
    hasMore: start + limit < rows.length,
  };
}

// ------------------------------------------------------------------ people

export async function discoverPeople(
  userId: string,
  query: DiscoverPeopleQuery,
): Promise<DiscoveryPage<PublicProfileDto>> {
  const cacheKey = `discover:people:${userId}:${stableHash(query)}`;
  const cached = await cacheGet<DiscoveryPage<PublicProfileDto>>(cacheKey);
  if (cached) {
    // Presence changes far faster than the feed does, so refresh it on read.
    return { ...cached, items: cached.items.map((item) => ({ ...item, isOnline: realtime.isOnline(item.id) })) };
  }

  const viewer = await loadViewer(userId);
  const [blockedIds, knownIds] = await Promise.all([
    getBlockedUserIds(userId),
    // Discovery is for meeting someone new, not people already in your invitations or chats.
    connectedOrInvitedUserIds(userId),
  ]);
  const box = boundingBox(viewer, query.radiusKm);

  const where: Prisma.ProfileWhereInput = {
    isDiscoverable: true,
    isComplete: true,
    userId: { notIn: [userId, ...blockedIds, ...knownIds] },
    latitude: { gte: box.minLat, lte: box.maxLat },
    longitude: { gte: box.minLon, lte: box.maxLon },
    birthDate: { gte: birthDateForAge(query.maxAge + 1), lte: birthDateForAge(query.minAge) },
    user: { isActive: true },
    ...(query.genders.length ? { gender: { in: query.genders as Gender[] } } : {}),
    ...(query.activities.length
      ? { preferredActivities: { hasSome: query.activities as ActivityCategory[] } }
      : {}),
    ...(query.availability.length
      ? { availability: { hasSome: query.availability as AvailabilitySlot[] } }
      : {}),
    ...(query.interests.length
      ? { interests: { some: { interest: { slug: { in: query.interests } } } } }
      : {}),
    ...(query.query
      ? {
          OR: [
            { displayName: { contains: query.query, mode: 'insensitive' } },
            { bio: { contains: query.query, mode: 'insensitive' } },
            { area: { contains: query.query, mode: 'insensitive' } },
          ],
        }
      : {}),
  };

  const candidates = await prisma.profile.findMany({
    where,
    take: CANDIDATE_LIMIT,
    orderBy: { user: { lastActiveAt: 'desc' } },
    include: {
      user: { include: userWithProfileInclude },
      interests: { include: { interest: { select: { slug: true } } } },
    },
  });

  const scored = candidates
    .map((candidate) => {
      const distance = distanceKm(viewer, candidate);
      return { candidate, distance, score: scorePerson(viewer, {
        preferredActivities: candidate.preferredActivities,
        availability: candidate.availability,
        interestSlugs: candidate.interests.map((link) => link.interest.slug),
        lastActiveAt: candidate.user.lastActiveAt,
      }, distance) };
    })
    .filter((entry) => entry.distance <= query.radiusKm)
    .sort((a, b) => b.score - a.score);

  const items = scored.map((entry) =>
    serializePublicProfile(entry.candidate.user, {
      distanceKm: roundDistance(entry.distance),
      isOnline: realtime.isOnline(entry.candidate.userId),
    }),
  );

  const page = paginate(items, query.page, query.limit);
  await cacheSet(cacheKey, page, DISCOVERY.cacheTtlSeconds);
  return page;
}

// -------------------------------------------------------------- activities

export async function discoverActivities(
  userId: string,
  query: DiscoverActivitiesQuery,
): Promise<DiscoveryPage<ActivityDto>> {
  const viewer = await loadViewer(userId);
  const blockedIds = await getBlockedUserIds(userId);
  const box = boundingBox(viewer, query.radiusKm);
  const from = query.from ? new Date(query.from) : new Date();

  const where: Prisma.ActivityWhereInput = {
    status: 'OPEN',
    startsAt: { gte: from, ...(query.to ? { lte: new Date(query.to) } : {}) },
    hostId: { notIn: [userId, ...blockedIds] },
    latitude: { gte: box.minLat, lte: box.maxLat },
    longitude: { gte: box.minLon, lte: box.maxLon },
    ...(query.activities.length ? { category: { in: query.activities as ActivityCategory[] } } : {}),
    ...(query.query
      ? {
          OR: [
            { title: { contains: query.query, mode: 'insensitive' } },
            { description: { contains: query.query, mode: 'insensitive' } },
            { locationName: { contains: query.query, mode: 'insensitive' } },
          ],
        }
      : {}),
    host: {
      isActive: true,
      profile: {
        isDiscoverable: true,
        ...(query.genders.length ? { gender: { in: query.genders as Gender[] } } : {}),
        birthDate: { gte: birthDateForAge(query.maxAge + 1), lte: birthDateForAge(query.minAge) },
      },
    },
  };

  const [activities, myInvitations] = await Promise.all([
    prisma.activity.findMany({
      where,
      take: CANDIDATE_LIMIT,
      orderBy: { startsAt: 'asc' },
      include: activityInclude,
    }),
    prisma.invitation.findMany({
      where: { senderId: userId, activityId: { not: null } },
      select: { activityId: true, status: true },
    }),
  ]);

  const invitationByActivity = new Map(
    myInvitations.map((invitation) => [invitation.activityId, invitation.status]),
  );

  const items = activities
    .map((activity) => {
      const distance = distanceKm(viewer, activity);
      return { activity, distance };
    })
    .filter((entry) => entry.distance <= query.radiusKm)
    .sort((a, b) => a.activity.startsAt.getTime() - b.activity.startsAt.getTime())
    .map((entry) =>
      serializeActivity(entry.activity, {
        viewerId: userId,
        distanceKm: roundDistance(entry.distance),
        isOnline: realtime.isOnline(entry.activity.hostId),
        viewerInvitationStatus: invitationByActivity.get(entry.activity.id) ?? null,
      }),
    );

  return paginate(items, query.page, query.limit);
}

// -------------------------------------------------------------- home feed

export interface CategoryCount {
  category: string;
  openActivities: number;
  people: number;
}

export interface HomeFeed {
  greeting: 'MORNING' | 'AFTERNOON' | 'EVENING';
  city: string;
  categories: CategoryCount[];
  peopleNearby: PublicProfileDto[];
  activitiesNearby: ActivityDto[];
  tonight: ActivityDto[];
  pendingInvitations: number;
  unreadMessages: number;
}

function greetingFor(date: Date): HomeFeed['greeting'] {
  const hour = date.getHours();
  if (hour < 12) return 'MORNING';
  if (hour < 17) return 'AFTERNOON';
  return 'EVENING';
}

/**
 * One round-trip powers the whole home screen: categories with live counts,
 * a shortlist of people, what is happening nearby, and badge counts.
 */
export async function getHomeFeed(userId: string): Promise<HomeFeed> {
  const viewer = await loadViewer(userId);
  const now = new Date();
  const endOfDay = new Date(now);
  endOfDay.setHours(23, 59, 59, 999);

  const baseQuery: DiscoverActivitiesQuery = {
    activities: [],
    availability: [],
    genders: [],
    interests: [],
    minAge: 18,
    maxAge: 99,
    radiusKm: DISCOVERY.defaultRadiusKm,
    page: 1,
    limit: 10,
  };

  const [people, activities, tonight, categoryRows, pendingInvitations, unreadMessages] =
    await Promise.all([
      discoverPeople(userId, { ...baseQuery, limit: 10 }),
      discoverActivities(userId, { ...baseQuery, limit: 10 }),
      discoverActivities(userId, { ...baseQuery, limit: 6, to: endOfDay.toISOString() }),
      prisma.activity.groupBy({
        by: ['category'],
        where: { status: 'OPEN', startsAt: { gte: now }, city: viewer.city, hostId: { not: userId } },
        _count: { _all: true },
      }),
      prisma.invitation.count({ where: { recipientId: userId, status: 'PENDING' } }),
      prisma.message.count({
        where: {
          senderId: { not: userId },
          readAt: null,
          type: 'TEXT',
          conversation: { participants: { some: { userId } } },
        },
      }),
    ]);

  const peopleByCategory = new Map<string, number>();
  for (const person of people.items) {
    for (const category of person.preferredActivities) {
      peopleByCategory.set(category, (peopleByCategory.get(category) ?? 0) + 1);
    }
  }

  const categories: CategoryCount[] = categoryRows.map((row) => ({
    category: row.category,
    openActivities: row._count._all,
    people: peopleByCategory.get(row.category) ?? 0,
  }));

  return {
    greeting: greetingFor(now),
    city: viewer.city,
    categories,
    peopleNearby: people.items,
    activitiesNearby: activities.items,
    tonight: tonight.items,
    pendingInvitations,
    unreadMessages,
  };
}

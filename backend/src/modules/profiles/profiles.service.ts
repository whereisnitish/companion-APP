import { prisma } from '../../database/prisma';
import { notFound } from '../../common/errors';
import { cacheDeleteByPrefix } from '../../database/redis';
import {
  serializeMe,
  serializePublicProfile,
  userWithProfileInclude,
  type MeDto,
  type PublicProfileDto,
} from '../../common/serializers';
import { distanceKm, roundDistance } from '../../common/geo';
import { realtime } from '../realtime/hub';
import { isBlockedBetween } from '../safety/safety.service';
import type { CreateProfileInput, UpdateProfileInput } from './profiles.schema';

export async function listInterests() {
  const interests = await prisma.interest.findMany({ orderBy: { label: 'asc' } });
  return interests.map((interest) => ({
    slug: interest.slug,
    label: interest.label,
    emoji: interest.emoji,
  }));
}

export async function getMe(userId: string): Promise<MeDto> {
  const user = await prisma.user.findUnique({ where: { id: userId }, include: userWithProfileInclude });
  if (!user) throw notFound('Account');
  return serializeMe(user);
}

/** Resolve interest slugs to ids, creating any the catalog does not have yet. */
async function resolveInterestIds(slugs: string[]): Promise<string[]> {
  if (slugs.length === 0) return [];
  const normalized = [...new Set(slugs.map((slug) => slug.trim().toLowerCase()))];

  const existing = await prisma.interest.findMany({
    where: { slug: { in: normalized } },
    select: { id: true, slug: true },
  });
  const known = new Map(existing.map((interest) => [interest.slug, interest.id]));

  const missing = normalized.filter((slug) => !known.has(slug));
  for (const slug of missing) {
    const created = await prisma.interest.upsert({
      where: { slug },
      update: {},
      create: {
        slug,
        label: slug.replace(/[-_]/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase()),
      },
      select: { id: true, slug: true },
    });
    known.set(created.slug, created.id);
  }

  return normalized.map((slug) => known.get(slug)).filter((id): id is string => Boolean(id));
}

export async function upsertProfile(userId: string, input: CreateProfileInput): Promise<MeDto> {
  const interestIds = await resolveInterestIds(input.interests);

  const base = {
    displayName: input.displayName,
    birthDate: input.birthDate,
    gender: input.gender,
    bio: input.bio,
    occupation: input.occupation ?? null,
    city: input.city,
    area: input.area ?? null,
    latitude: input.latitude,
    longitude: input.longitude,
    avatarUrl: input.avatarUrl ?? null,
    photos: input.photos,
    preferredActivities: input.preferredActivities,
    availability: input.availability,
    isComplete: true,
  };

  await prisma.$transaction(async (tx) => {
    const profile = await tx.profile.upsert({
      where: { userId },
      create: { userId, ...base },
      update: base,
      select: { id: true },
    });

    await tx.profileInterest.deleteMany({ where: { profileId: profile.id } });
    if (interestIds.length) {
      await tx.profileInterest.createMany({
        data: interestIds.map((interestId) => ({ profileId: profile.id, interestId })),
        skipDuplicates: true,
      });
    }
  });

  await cacheDeleteByPrefix('discover:');
  return getMe(userId);
}

export async function updateProfile(userId: string, input: UpdateProfileInput): Promise<MeDto> {
  const profile = await prisma.profile.findUnique({ where: { userId }, select: { id: true } });
  if (!profile) throw notFound('Profile');

  // Only touch what was actually sent — omission never clears a field.
  const data: Record<string, unknown> = {};
  const assign = <K extends keyof UpdateProfileInput>(key: K, value: unknown) => {
    if (input[key] !== undefined) data[key as string] = value;
  };

  assign('displayName', input.displayName);
  assign('birthDate', input.birthDate);
  assign('gender', input.gender);
  assign('bio', input.bio);
  assign('occupation', input.occupation ?? null);
  assign('city', input.city);
  assign('area', input.area ?? null);
  assign('latitude', input.latitude);
  assign('longitude', input.longitude);
  assign('avatarUrl', input.avatarUrl ?? null);
  assign('photos', input.photos);
  assign('preferredActivities', input.preferredActivities);
  assign('availability', input.availability);
  assign('isDiscoverable', input.isDiscoverable);
  assign('showDistance', input.showDistance);
  assign('showAge', input.showAge);

  await prisma.$transaction(async (tx) => {
    if (Object.keys(data).length > 0) {
      await tx.profile.update({ where: { userId }, data });
    }
    if (input.interests !== undefined) {
      const interestIds = await resolveInterestIds(input.interests);
      await tx.profileInterest.deleteMany({ where: { profileId: profile.id } });
      if (interestIds.length) {
        await tx.profileInterest.createMany({
          data: interestIds.map((interestId) => ({ profileId: profile.id, interestId })),
          skipDuplicates: true,
        });
      }
    }
  });

  await cacheDeleteByPrefix('discover:');
  return getMe(userId);
}

export async function getPublicProfile(viewerId: string, targetId: string): Promise<PublicProfileDto> {
  if (await isBlockedBetween(viewerId, targetId)) throw notFound('Profile');

  const [target, viewer] = await Promise.all([
    prisma.user.findUnique({ where: { id: targetId }, include: userWithProfileInclude }),
    prisma.profile.findUnique({
      where: { userId: viewerId },
      select: { latitude: true, longitude: true },
    }),
  ]);

  if (!target || !target.profile) throw notFound('Profile');

  const distance =
    viewer && target.profile
      ? roundDistance(
          distanceKm(
            { latitude: viewer.latitude, longitude: viewer.longitude },
            { latitude: target.profile.latitude, longitude: target.profile.longitude },
          ),
        )
      : null;

  return serializePublicProfile(target, {
    distanceKm: distance,
    isOnline: realtime.isOnline(targetId),
  });
}

export async function touchLastActive(userId: string): Promise<void> {
  await prisma.user
    .update({ where: { id: userId }, data: { lastActiveAt: new Date() } })
    .catch(() => undefined);
}

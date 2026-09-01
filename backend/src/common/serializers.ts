import { Prisma } from '@prisma/client';
import { ageFromBirthDate } from '../utils/dates';
import { MESSAGES } from '../config/constants';

// ------------------------------------------------------------ query shapes
// Declared once and reused by every module so a `select` never drifts from the
// serializer that consumes it (and so we never accidentally over-fetch).

export const profileInclude = {
  interests: { include: { interest: true } },
} satisfies Prisma.ProfileInclude;

export const userWithProfileInclude = {
  profile: { include: profileInclude },
} satisfies Prisma.UserInclude;

export type ProfileWithInterests = Prisma.ProfileGetPayload<{ include: typeof profileInclude }>;

export type UserWithProfile = Prisma.UserGetPayload<{ include: typeof userWithProfileInclude }>;

export const activityInclude = {
  host: { include: userWithProfileInclude },
  _count: { select: { participants: true } },
} satisfies Prisma.ActivityInclude;

export type ActivityWithHost = Prisma.ActivityGetPayload<{ include: typeof activityInclude }>;

export const invitationInclude = {
  sender: { include: userWithProfileInclude },
  recipient: { include: userWithProfileInclude },
  activity: { include: activityInclude },
  conversation: { select: { id: true } },
} satisfies Prisma.InvitationInclude;

export type InvitationFull = Prisma.InvitationGetPayload<{ include: typeof invitationInclude }>;

// ------------------------------------------------------------ DTOs

export interface InterestDto {
  slug: string;
  label: string;
  emoji: string;
}

export interface PublicProfileDto {
  id: string;
  displayName: string;
  age: number | null;
  gender: string;
  bio: string;
  occupation: string | null;
  city: string;
  area: string | null;
  avatarUrl: string | null;
  photos: string[];
  interests: InterestDto[];
  preferredActivities: string[];
  availability: string[];
  verification: string;
  rating: { average: number; count: number };
  distanceKm: number | null;
  isOnline: boolean;
  lastActiveAt: string;
}

export interface SerializeProfileOptions {
  distanceKm?: number | null;
  isOnline?: boolean;
}

/** A placeholder used when a related user somehow has no profile yet. */
const ANONYMOUS: PublicProfileDto = {
  id: '',
  displayName: 'Someone',
  age: null,
  gender: 'OTHER',
  bio: '',
  occupation: null,
  city: '',
  area: null,
  avatarUrl: null,
  photos: [],
  interests: [],
  preferredActivities: [],
  availability: [],
  verification: 'UNVERIFIED',
  rating: { average: 0, count: 0 },
  distanceKm: null,
  isOnline: false,
  lastActiveAt: new Date(0).toISOString(),
};

export function serializePublicProfile(
  user: UserWithProfile,
  options: SerializeProfileOptions = {},
): PublicProfileDto {
  const profile = user.profile;
  if (!profile) return { ...ANONYMOUS, id: user.id };

  return {
    id: user.id,
    displayName: profile.displayName,
    age: profile.showAge ? ageFromBirthDate(profile.birthDate) : null,
    gender: profile.gender,
    bio: profile.bio,
    occupation: profile.occupation,
    city: profile.city,
    area: profile.area,
    avatarUrl: profile.avatarUrl,
    photos: profile.photos,
    interests: profile.interests.map((link) => ({
      slug: link.interest.slug,
      label: link.interest.label,
      emoji: link.interest.emoji,
    })),
    preferredActivities: profile.preferredActivities,
    availability: profile.availability,
    verification: profile.verification,
    rating: { average: profile.ratingAvg, count: profile.ratingCount },
    distanceKm: profile.showDistance ? (options.distanceKm ?? null) : null,
    isOnline: options.isOnline ?? false,
    lastActiveAt: user.lastActiveAt.toISOString(),
  };
}

export interface MeDto extends PublicProfileDto {
  email: string | null;
  phone: string | null;
  birthDate: string | null;
  latitude: number | null;
  longitude: number | null;
  isDiscoverable: boolean;
  showDistance: boolean;
  showAge: boolean;
  isProfileComplete: boolean;
  createdAt: string;
}

export function serializeMe(user: UserWithProfile): MeDto {
  const base = serializePublicProfile(user, { isOnline: true });
  const profile = user.profile;
  return {
    ...base,
    // The owner always sees their own age, regardless of the public toggle.
    age: profile ? ageFromBirthDate(profile.birthDate) : null,
    email: user.email,
    phone: user.phone,
    birthDate: profile ? profile.birthDate.toISOString() : null,
    latitude: profile ? profile.latitude : null,
    longitude: profile ? profile.longitude : null,
    isDiscoverable: profile?.isDiscoverable ?? true,
    showDistance: profile?.showDistance ?? true,
    showAge: profile?.showAge ?? true,
    isProfileComplete: profile?.isComplete ?? false,
    createdAt: user.createdAt.toISOString(),
  };
}

export interface ActivityDto {
  id: string;
  category: string;
  title: string;
  description: string;
  startsAt: string;
  endsAt: string | null;
  locationName: string;
  area: string | null;
  city: string;
  lookingFor: string;
  minAge: number;
  maxAge: number;
  capacity: number;
  status: string;
  createdAt: string;
  host: PublicProfileDto;
  participantCount: number;
  distanceKm: number | null;
  isHost: boolean;
  viewerInvitationStatus: string | null;
}

export interface SerializeActivityOptions {
  viewerId?: string;
  distanceKm?: number | null;
  isOnline?: boolean;
  viewerInvitationStatus?: string | null;
}

export function serializeActivity(
  activity: ActivityWithHost,
  options: SerializeActivityOptions = {},
): ActivityDto {
  return {
    id: activity.id,
    category: activity.category,
    title: activity.title,
    description: activity.description,
    startsAt: activity.startsAt.toISOString(),
    endsAt: activity.endsAt ? activity.endsAt.toISOString() : null,
    locationName: activity.locationName,
    area: activity.area,
    city: activity.city,
    lookingFor: activity.lookingFor,
    minAge: activity.minAge,
    maxAge: activity.maxAge,
    capacity: activity.capacity,
    status: activity.status,
    createdAt: activity.createdAt.toISOString(),
    host: serializePublicProfile(activity.host, {
      distanceKm: options.distanceKm ?? null,
      isOnline: options.isOnline ?? false,
    }),
    participantCount: activity._count.participants,
    distanceKm: options.distanceKm ?? null,
    isHost: options.viewerId ? activity.hostId === options.viewerId : false,
    viewerInvitationStatus: options.viewerInvitationStatus ?? null,
  };
}

export interface InvitationDto {
  id: string;
  direction: 'sent' | 'received';
  status: string;
  message: string;
  category: string | null;
  proposedAt: string | null;
  locationName: string | null;
  createdAt: string;
  respondedAt: string | null;
  counterpart: PublicProfileDto;
  activity: ActivityDto | null;
  conversationId: string | null;
}

export function serializeInvitation(
  invitation: InvitationFull,
  viewerId: string,
  options: { distanceKm?: number | null; isOnline?: boolean } = {},
): InvitationDto {
  const direction: 'sent' | 'received' = invitation.senderId === viewerId ? 'sent' : 'received';
  const counterpartUser = direction === 'sent' ? invitation.recipient : invitation.sender;

  return {
    id: invitation.id,
    direction,
    status: invitation.status,
    message: invitation.message,
    category: invitation.category ?? invitation.activity?.category ?? null,
    proposedAt: (invitation.proposedAt ?? invitation.activity?.startsAt)?.toISOString() ?? null,
    locationName: invitation.locationName ?? invitation.activity?.locationName ?? null,
    createdAt: invitation.createdAt.toISOString(),
    respondedAt: invitation.respondedAt ? invitation.respondedAt.toISOString() : null,
    counterpart: serializePublicProfile(counterpartUser, {
      distanceKm: options.distanceKm ?? null,
      isOnline: options.isOnline ?? false,
    }),
    activity: invitation.activity
      ? serializeActivity(invitation.activity, { viewerId })
      : null,
    conversationId: invitation.conversation?.id ?? null,
  };
}

export interface MessageDto {
  id: string;
  conversationId: string;
  senderId: string;
  body: string;
  type: string;
  createdAt: string;
  readAt: string | null;
  isMine: boolean;
}

export function serializeMessage(
  message: {
    id: string;
    conversationId: string;
    senderId: string;
    body: string;
    type: string;
    createdAt: Date;
    readAt: Date | null;
  },
  viewerId: string,
): MessageDto {
  return {
    id: message.id,
    conversationId: message.conversationId,
    senderId: message.senderId,
    body: message.body,
    type: message.type,
    createdAt: message.createdAt.toISOString(),
    readAt: message.readAt ? message.readAt.toISOString() : null,
    isMine: message.senderId === viewerId,
  };
}

export interface ConversationDto {
  id: string;
  lastMessageAt: string;
  lastMessagePreview: string;
  unreadCount: number;
  participant: PublicProfileDto;
  activity: {
    id: string;
    category: string;
    title: string;
    startsAt: string;
    locationName: string;
  } | null;
}

export function truncatePreview(body: string): string {
  const trimmed = body.trim().replace(/\s+/g, ' ');
  return trimmed.length > MESSAGES.previewLength
    ? `${trimmed.slice(0, MESSAGES.previewLength - 1)}…`
    : trimmed;
}

export interface NotificationDto {
  id: string;
  type: string;
  title: string;
  body: string;
  data: unknown;
  readAt: string | null;
  createdAt: string;
}

export function serializeNotification(notification: {
  id: string;
  type: string;
  title: string;
  body: string;
  data: Prisma.JsonValue | null;
  readAt: Date | null;
  createdAt: Date;
}): NotificationDto {
  return {
    id: notification.id,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    data: notification.data ?? null,
    readAt: notification.readAt ? notification.readAt.toISOString() : null,
    createdAt: notification.createdAt.toISOString(),
  };
}

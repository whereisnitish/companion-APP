/** Discovery + pagination tuning. Kept in one place so limits stay consistent. */
export const PAGINATION = {
  defaultLimit: 20,
  maxLimit: 50,
} as const;

export const DISCOVERY = {
  /** Default search radius in kilometres. */
  defaultRadiusKm: 25,
  maxRadiusKm: 200,
  /** How long a feed page stays cached in Redis. */
  cacheTtlSeconds: 45,
} as const;

export const INVITATIONS = {
  /** A pending invitation stops being actionable after this long. */
  expiryHours: 72,
  /** Guardrail against invitation spam, per sender per rolling day. */
  maxPerDay: 25,
} as const;

export const MESSAGES = {
  maxLength: 2000,
  previewLength: 120,
} as const;

export const REDIS_KEYS = {
  discoverPeople: (userId: string, hash: string) => `discover:people:${userId}:${hash}`,
  discoverActivities: (userId: string, hash: string) => `discover:activities:${userId}:${hash}`,
  presence: (userId: string) => `presence:${userId}`,
  typing: (conversationId: string) => `typing:${conversationId}`,
  invitationQuota: (userId: string, day: string) => `quota:invite:${userId}:${day}`,
} as const;

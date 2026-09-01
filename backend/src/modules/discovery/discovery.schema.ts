import { z } from 'zod';
import { DISCOVERY, PAGINATION } from '../../config/constants';
import { ACTIVITY_CATEGORIES, AVAILABILITY_SLOTS, GENDERS } from '../profiles/profiles.schema';

/** Comma-separated query lists (`?activities=MOVIE,COFFEE`) become arrays. */
const csv = <T extends readonly [string, ...string[]]>(values: T) =>
  z
    .string()
    .optional()
    .transform((value) =>
      value
        ? value
            .split(',')
            .map((part) => part.trim().toUpperCase())
            .filter(Boolean)
        : [],
    )
    .pipe(z.array(z.enum(values)));

export const discoverPeopleSchema = z.object({
  activities: csv(ACTIVITY_CATEGORIES),
  availability: csv(AVAILABILITY_SLOTS),
  genders: csv(GENDERS),
  interests: z
    .string()
    .optional()
    .transform((value) =>
      value ? value.split(',').map((part) => part.trim().toLowerCase()).filter(Boolean) : [],
    ),
  minAge: z.coerce.number().int().min(18).max(99).default(18),
  maxAge: z.coerce.number().int().min(18).max(99).default(99),
  radiusKm: z.coerce.number().min(1).max(DISCOVERY.maxRadiusKm).default(DISCOVERY.defaultRadiusKm),
  query: z.string().trim().max(60).optional(),
  page: z.coerce.number().int().min(1).max(100).default(1),
  limit: z.coerce.number().int().min(1).max(PAGINATION.maxLimit).default(PAGINATION.defaultLimit),
});

export const discoverActivitiesSchema = discoverPeopleSchema.extend({
  /** ISO instants — activities starting within this window. */
  from: z.string().datetime({ offset: true }).optional(),
  to: z.string().datetime({ offset: true }).optional(),
});

export type DiscoverPeopleQuery = z.infer<typeof discoverPeopleSchema>;
export type DiscoverActivitiesQuery = z.infer<typeof discoverActivitiesSchema>;

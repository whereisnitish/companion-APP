import { z } from 'zod';

export const GENDERS = ['MALE', 'FEMALE', 'NON_BINARY', 'OTHER'] as const;
export const ACTIVITY_CATEGORIES = [
  'MOVIE',
  'DINNER',
  'COFFEE',
  'SHOPPING',
  'WALK',
  'EVENT',
  'TRAVEL',
  'SPORTS',
  'CONCERT',
  'STUDY',
  'GAMING',
  'OTHER',
] as const;
export const AVAILABILITY_SLOTS = [
  'TONIGHT',
  'TOMORROW',
  'THIS_WEEK',
  'WEEKEND',
  'FLEXIBLE',
] as const;

const MIN_AGE = 18;
const MAX_AGE = 99;

const birthDate = z
  .string()
  .datetime({ offset: true })
  .or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use the format YYYY-MM-DD.'))
  .transform((value) => new Date(value))
  .refine((date) => !Number.isNaN(date.getTime()), 'That date is not valid.')
  .refine((date) => {
    const age = (Date.now() - date.getTime()) / (365.25 * 24 * 60 * 60 * 1000);
    return age >= MIN_AGE && age <= MAX_AGE;
  }, `You must be between ${MIN_AGE} and ${MAX_AGE}.`);

/** Full profile creation — sent once at the end of the setup flow. */
export const createProfileSchema = z.object({
  displayName: z.string().trim().min(2, 'Tell us your name.').max(40),
  birthDate,
  gender: z.enum(GENDERS),
  bio: z.string().trim().max(500, 'Keep it under 500 characters.').default(''),
  occupation: z.string().trim().max(80).optional().nullable(),
  city: z.string().trim().min(1, 'Where are you based?').max(80),
  area: z.string().trim().max(80).optional().nullable(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  avatarUrl: z.string().url('That does not look like a valid image link.').optional().nullable(),
  photos: z.array(z.string().url()).max(6, 'Up to six photos.').default([]),
  interests: z.array(z.string().trim().min(1)).max(12, 'Pick up to twelve interests.').default([]),
  preferredActivities: z.array(z.enum(ACTIVITY_CATEGORIES)).max(12).default([]),
  availability: z.array(z.enum(AVAILABILITY_SLOTS)).max(5).default([]),
});

/** Partial edit — every field optional, nothing is cleared by omission. */
export const updateProfileSchema = createProfileSchema.partial().extend({
  isDiscoverable: z.boolean().optional(),
  showDistance: z.boolean().optional(),
  showAge: z.boolean().optional(),
});

export type CreateProfileInput = z.infer<typeof createProfileSchema>;
export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;

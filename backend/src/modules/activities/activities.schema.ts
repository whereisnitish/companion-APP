import { z } from 'zod';
import { ACTIVITY_CATEGORIES } from '../profiles/profiles.schema';
import { PAGINATION } from '../../config/constants';

export const GENDER_PREFERENCES = ['ANYONE', 'MALE', 'FEMALE'] as const;

export const createActivitySchema = z
  .object({
    category: z.enum(ACTIVITY_CATEGORIES),
    title: z.string().trim().min(3, 'Give it a short title.').max(80),
    description: z.string().trim().max(600, 'Keep it under 600 characters.').default(''),
    startsAt: z
      .string()
      .datetime({ offset: true })
      .transform((value) => new Date(value))
      .refine((date) => date.getTime() > Date.now() - 60_000, 'Pick a time in the future.'),
    endsAt: z
      .string()
      .datetime({ offset: true })
      .transform((value) => new Date(value))
      .optional()
      .nullable(),
    locationName: z.string().trim().min(2, 'Where should you meet?').max(120),
    area: z.string().trim().max(80).optional().nullable(),
    city: z.string().trim().min(1).max(80),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    lookingFor: z.enum(GENDER_PREFERENCES).default('ANYONE'),
    minAge: z.coerce.number().int().min(18).max(99).default(18),
    maxAge: z.coerce.number().int().min(18).max(99).default(99),
    capacity: z.coerce.number().int().min(1).max(10).default(1),
  })
  .refine((value) => value.minAge <= value.maxAge, {
    message: 'The minimum age cannot be above the maximum.',
    path: ['minAge'],
  })
  .refine((value) => !value.endsAt || value.endsAt > value.startsAt, {
    message: 'The end time must be after the start time.',
    path: ['endsAt'],
  });

export const listActivitiesSchema = z.object({
  scope: z.enum(['mine', 'joined', 'all']).default('mine'),
  status: z.enum(['OPEN', 'CONFIRMED', 'CANCELLED', 'COMPLETED']).optional(),
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(PAGINATION.maxLimit).default(PAGINATION.defaultLimit),
});

export type CreateActivityInput = z.infer<typeof createActivitySchema>;
export type ListActivitiesQuery = z.infer<typeof listActivitiesSchema>;

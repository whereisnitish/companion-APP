import { z } from 'zod';
import { ACTIVITY_CATEGORIES } from '../profiles/profiles.schema';
import { PAGINATION } from '../../config/constants';

export const createInvitationSchema = z
  .object({
    recipientId: z.string().min(1, 'Who are you inviting?'),
    /** Invite someone to a posted activity… */
    activityId: z.string().optional().nullable(),
    /** …or propose something directly. */
    category: z.enum(ACTIVITY_CATEGORIES).optional(),
    proposedAt: z
      .string()
      .datetime({ offset: true })
      .transform((value) => new Date(value))
      .optional()
      .nullable(),
    locationName: z.string().trim().max(120).optional().nullable(),
    message: z.string().trim().max(500, 'Keep your note under 500 characters.').default(''),
  })
  .refine((value) => Boolean(value.activityId) || Boolean(value.category), {
    message: 'Choose an activity to invite them to.',
    path: ['category'],
  });

export const listInvitationsSchema = z.object({
  status: z.enum(['PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'EXPIRED']).optional(),
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(PAGINATION.maxLimit).default(PAGINATION.defaultLimit),
});

export const declineSchema = z.object({
  reason: z.string().trim().max(280).optional(),
});

export type CreateInvitationInput = z.infer<typeof createInvitationSchema>;
export type ListInvitationsQuery = z.infer<typeof listInvitationsSchema>;

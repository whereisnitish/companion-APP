import { z } from 'zod';

export const REPORT_REASONS = [
  'INAPPROPRIATE_MESSAGES',
  'FAKE_PROFILE',
  'HARASSMENT',
  'INAPPROPRIATE_PHOTOS',
  'SCAM_OR_SPAM',
  'UNDERAGE',
  'SAFETY_CONCERN',
  'OTHER',
] as const;

export const blockSchema = z.object({
  reason: z.string().trim().max(280).optional(),
});

export const reportSchema = z.object({
  reason: z.enum(REPORT_REASONS),
  details: z.string().trim().max(1000).default(''),
});

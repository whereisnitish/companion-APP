import { z } from 'zod';

const password = z
  .string()
  .min(8, 'Use at least 8 characters.')
  .max(128, 'That password is too long.')
  .regex(/[a-zA-Z]/, 'Include at least one letter.')
  .regex(/[0-9]/, 'Include at least one number.');

const email = z.string().trim().toLowerCase().email('Enter a valid email address.');
const phone = z
  .string()
  .trim()
  .regex(/^\+?[1-9]\d{6,14}$/, 'Enter a valid phone number with country code.');

export const registerSchema = z
  .object({
    email: email.optional(),
    phone: phone.optional(),
    password,
    displayName: z.string().trim().min(2, 'Tell us your name.').max(40).optional(),
  })
  .refine((value) => Boolean(value.email ?? value.phone), {
    message: 'Provide an email address or a phone number.',
    path: ['email'],
  });

export const loginSchema = z
  .object({
    email: email.optional(),
    phone: phone.optional(),
    password: z.string().min(1, 'Enter your password.'),
  })
  .refine((value) => Boolean(value.email ?? value.phone), {
    message: 'Provide an email address or a phone number.',
    path: ['email'],
  });

export const refreshSchema = z.object({
  refreshToken: z.string().min(10, 'Missing refresh token.'),
});

/**
 * OTP is stubbed for the MVP: the endpoints and the client flow are real, the
 * delivery channel is not. `verifyOtpSchema` already matches what a real
 * provider integration would receive.
 */
export const requestOtpSchema = z.object({
  phone,
});

export const verifyOtpSchema = z.object({
  phone,
  code: z.string().regex(/^\d{6}$/, 'Enter the 6-digit code.'),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type RefreshInput = z.infer<typeof refreshSchema>;
export type RequestOtpInput = z.infer<typeof requestOtpSchema>;
export type VerifyOtpInput = z.infer<typeof verifyOtpSchema>;

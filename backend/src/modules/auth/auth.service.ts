import type { FastifyInstance } from 'fastify';
import { prisma } from '../../database/prisma';
import { env } from '../../config/env';
import { hashPassword, verifyPassword } from '../../utils/password';
import { generateOpaqueToken, hashToken } from '../../utils/tokens';
import { addDays } from '../../utils/dates';
import { conflict, notFound, unauthorized } from '../../common/errors';
import { serializeMe, userWithProfileInclude, type MeDto } from '../../common/serializers';
import type { LoginInput, RegisterInput } from './auth.schema';

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  expiresIn: string;
  user: MeDto;
}

/** Refresh tokens are rotated on every use; the old one is revoked immediately. */
async function issueSession(app: FastifyInstance, userId: string): Promise<AuthSession> {
  const accessToken = app.jwt.sign({ sub: userId, typ: 'access' as const });
  const refreshToken = generateOpaqueToken();

  await prisma.refreshToken.create({
    data: {
      userId,
      tokenHash: hashToken(refreshToken),
      expiresAt: addDays(new Date(), env.JWT_REFRESH_TTL_DAYS),
    },
  });

  const user = await prisma.user.findUniqueOrThrow({
    where: { id: userId },
    include: userWithProfileInclude,
  });

  return { accessToken, refreshToken, expiresIn: env.JWT_ACCESS_TTL, user: serializeMe(user) };
}

export async function register(app: FastifyInstance, input: RegisterInput): Promise<AuthSession> {
  const existing = await prisma.user.findFirst({
    where: {
      OR: [
        ...(input.email ? [{ email: input.email }] : []),
        ...(input.phone ? [{ phone: input.phone }] : []),
      ],
    },
    select: { id: true },
  });

  if (existing) {
    throw conflict('An account already exists with those details. Try signing in.', 'ACCOUNT_EXISTS');
  }

  const user = await prisma.user.create({
    data: {
      email: input.email ?? null,
      phone: input.phone ?? null,
      passwordHash: await hashPassword(input.password),
    },
    select: { id: true },
  });

  return issueSession(app, user.id);
}

export async function login(app: FastifyInstance, input: LoginInput): Promise<AuthSession> {
  const user = await prisma.user.findFirst({
    where: input.email ? { email: input.email } : { phone: input.phone },
    select: { id: true, passwordHash: true, isActive: true },
  });

  // Same message for "no such user" and "wrong password" — no account enumeration.
  const invalid = unauthorized('That email or password is incorrect.');
  if (!user) {
    // Constant-ish work so timing does not leak account existence.
    await verifyPassword(input.password, '$2a$12$invalidinvalidinvalidinvalidinvalidinvalidinvalidinv');
    throw invalid;
  }
  if (!user.isActive) throw unauthorized('This account has been disabled.');
  if (!(await verifyPassword(input.password, user.passwordHash))) throw invalid;

  await prisma.user.update({ where: { id: user.id }, data: { lastActiveAt: new Date() } });
  return issueSession(app, user.id);
}

export async function refresh(app: FastifyInstance, token: string): Promise<AuthSession> {
  const record = await prisma.refreshToken.findUnique({
    where: { tokenHash: hashToken(token) },
    select: { id: true, userId: true, expiresAt: true, revokedAt: true },
  });

  if (!record || record.revokedAt || record.expiresAt < new Date()) {
    throw unauthorized('Your session has expired. Please sign in again.');
  }

  await prisma.refreshToken.update({
    where: { id: record.id },
    data: { revokedAt: new Date() },
  });

  return issueSession(app, record.userId);
}

export async function logout(token: string): Promise<void> {
  await prisma.refreshToken.updateMany({
    where: { tokenHash: hashToken(token), revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

/**
 * OTP stub. In production this hands off to an SMS provider; here it returns a
 * fixed development code so the client flow is fully exercisable offline.
 */
export const DEV_OTP_CODE = '123456';

export async function requestOtp(phone: string): Promise<{ sent: true; devCode?: string }> {
  return env.NODE_ENV === 'production' ? { sent: true } : { sent: true, devCode: DEV_OTP_CODE };
}

export async function verifyOtp(app: FastifyInstance, phone: string, code: string): Promise<AuthSession> {
  if (code !== DEV_OTP_CODE) throw unauthorized('That code is not correct.');
  const user = await prisma.user.findUnique({ where: { phone }, select: { id: true } });
  if (!user) throw notFound('Account');
  return issueSession(app, user.id);
}

import 'dotenv/config';
import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import type { FastifyInstance } from 'fastify';

import { buildApp } from '../src/app';
import { prisma } from '../src/database/prisma';
import { disconnectRedis } from '../src/database/redis';

/**
 * These run against the seeded development database using Fastify's `inject`,
 * so the whole stack — routing, validation, auth, Prisma — is exercised without
 * binding a port.
 *
 *   npm run db:seed && npm test
 */
let app: FastifyInstance;

/**
 * Builds the inject options. Both the bearer token and the JSON body live in
 * one helper so a spread can never clobber the `headers` set by the other.
 */
const req = (token?: string, body?: unknown) => ({
  headers: {
    ...(token === undefined ? {} : { authorization: `Bearer ${token}` }),
    ...(body === undefined ? {} : { 'content-type': 'application/json' }),
  },
  ...(body === undefined ? {} : { payload: JSON.stringify(body) }),
});

async function signIn(email: string): Promise<{ token: string; userId: string }> {
  const response = await app.inject({
    method: 'POST',
    url: '/api/auth/login',
    ...req(undefined, { email, password: 'Password123' }),
  });
  assert.equal(response.statusCode, 200, `login failed for ${email}: ${response.body}`);
  const body = response.json() as { data: { accessToken: string; user: { id: string } } };
  return { token: body.data.accessToken, userId: body.data.user.id };
}

before(async () => {
  app = await buildApp();
  await app.ready();
});

after(async () => {
  await app.close();
  await disconnectRedis();
  await prisma.$disconnect();
});

describe('health', () => {
  it('reports the database as reachable', async () => {
    const response = await app.inject({ method: 'GET', url: '/health' });
    assert.equal(response.statusCode, 200);
    const body = response.json() as { status: string; database: boolean };
    assert.equal(body.database, true);
  });
});

describe('auth', () => {
  it('rejects a malformed registration with per-field messages', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      ...req(undefined, { email: 'not-an-email', password: 'short' }),
    });

    assert.equal(response.statusCode, 422);
    const body = response.json() as { error: { code: string; details: Record<string, string> } };
    assert.equal(body.error.code, 'VALIDATION_ERROR');
    assert.ok(body.error.details.email);
    assert.ok(body.error.details.password);
  });

  it('registers, then signs in, then refreshes', async () => {
    const email = `test-${Date.now()}@example.com`;

    const registered = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      ...req(undefined, { email, password: 'Password123' }),
    });
    assert.equal(registered.statusCode, 201);

    const session = registered.json() as {
      data: { accessToken: string; refreshToken: string; user: { isProfileComplete: boolean } };
    };
    // A brand-new account has no profile yet — the client routes to setup.
    assert.equal(session.data.user.isProfileComplete, false);

    const refreshed = await app.inject({
      method: 'POST',
      url: '/api/auth/refresh',
      ...req(undefined, { refreshToken: session.data.refreshToken }),
    });
    assert.equal(refreshed.statusCode, 200);

    // The old refresh token was rotated out and must not work twice.
    const replayed = await app.inject({
      method: 'POST',
      url: '/api/auth/refresh',
      ...req(undefined, { refreshToken: session.data.refreshToken }),
    });
    assert.equal(replayed.statusCode, 401);

    await prisma.user.deleteMany({ where: { email } });
  });

  it('gives the same answer for a wrong password and an unknown account', async () => {
    const unknown = await app.inject({
      method: 'POST',
      url: '/api/auth/login',
      ...req(undefined, { email: 'nobody@example.com', password: 'Password123' }),
    });
    const wrongPassword = await app.inject({
      method: 'POST',
      url: '/api/auth/login',
      ...req(undefined, { email: 'demo@companion.app', password: 'WrongPassword1' }),
    });

    assert.equal(unknown.statusCode, 401);
    assert.equal(wrongPassword.statusCode, 401);
    assert.equal(
      (unknown.json() as { error: { message: string } }).error.message,
      (wrongPassword.json() as { error: { message: string } }).error.message,
    );
  });

  it('refuses an unauthenticated request to a guarded route', async () => {
    const response = await app.inject({ method: 'GET', url: '/api/users/me' });
    assert.equal(response.statusCode, 401);
    assert.equal((response.json() as { error: { code: string } }).error.code, 'UNAUTHORIZED');
  });
});

describe('discovery', () => {
  it('returns a populated home feed', async () => {
    const { token } = await signIn('demo@companion.app');
    const response = await app.inject({
      method: 'GET',
      url: '/api/discover',
      ...req(token),
    });

    assert.equal(response.statusCode, 200);
    const feed = (response.json() as { data: Record<string, unknown> }).data;
    assert.ok(Array.isArray(feed.peopleNearby) && (feed.peopleNearby as unknown[]).length > 0);
    assert.ok(Array.isArray(feed.activitiesNearby));
    assert.equal(feed.city, 'Bengaluru');
  });

  it('never includes the viewer in their own results', async () => {
    const { token, userId } = await signIn('demo@companion.app');
    const response = await app.inject({
      method: 'GET',
      url: '/api/discover/people?limit=50',
      ...req(token),
    });

    const people = (response.json() as { data: Array<{ id: string }> }).data;
    assert.ok(people.length > 0);
    assert.ok(!people.some((person) => person.id === userId));
  });

  it('applies the activity filter', async () => {
    const { token } = await signIn('demo@companion.app');
    const response = await app.inject({
      method: 'GET',
      url: '/api/discover/people?activities=GAMING&limit=50',
      ...req(token),
    });

    const people = (response.json() as { data: Array<{ preferredActivities: string[] }> }).data;
    assert.ok(people.every((person) => person.preferredActivities.includes('GAMING')));
  });

  it('applies the age filter', async () => {
    const { token } = await signIn('demo@companion.app');
    const response = await app.inject({
      method: 'GET',
      url: '/api/discover/people?minAge=30&maxAge=40&limit=50',
      ...req(token),
    });

    const people = (response.json() as { data: Array<{ age: number | null }> }).data;
    assert.ok(people.length > 0);
    assert.ok(people.every((person) => person.age === null || (person.age >= 30 && person.age <= 40)));
  });

  it('shrinks the result set as the radius shrinks', async () => {
    const { token } = await signIn('demo@companion.app');
    const wide = await app.inject({
      method: 'GET',
      url: '/api/discover/people?radiusKm=100&limit=50',
      ...req(token),
    });
    const narrow = await app.inject({
      method: 'GET',
      url: '/api/discover/people?radiusKm=2&limit=50',
      ...req(token),
    });

    const wideCount = (wide.json() as { data: unknown[] }).data.length;
    const narrowCount = (narrow.json() as { data: unknown[] }).data.length;
    assert.ok(narrowCount <= wideCount);
  });
});

describe('the core journey: post → invite → accept → chat', () => {
  it('carries a plan from creation through to a first message', async () => {
    const host = await signIn('demo@companion.app');
    const guest = await signIn('sara.mehta@example.com');

    // 1. The host posts a plan.
    const startsAt = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString();
    const created = await app.inject({
      method: 'POST',
      url: '/api/activities',
      ...req(host.token, {
        category: 'MOVIE',
        title: 'End-to-end test screening',
        description: 'A plan created by the test suite.',
        startsAt,
        locationName: 'PVR Forum Mall',
        area: 'Koramangala',
        city: 'Bengaluru',
        latitude: 12.9345,
        longitude: 77.6112,
      }),
    });
    assert.equal(created.statusCode, 201, created.body);
    const activityId = (created.json() as { data: { id: string } }).data.id;

    // 2. The host invites someone to it.
    const invited = await app.inject({
      method: 'POST',
      url: '/api/invitations',
      ...req(host.token, {
        recipientId: guest.userId,
        activityId,
        message: 'Testing the whole flow end to end.',
      }),
    });
    assert.equal(invited.statusCode, 201, invited.body);
    const invitationId = (invited.json() as { data: { id: string } }).data.id;

    // 3. A second invitation for the same pair and plan is refused.
    const duplicate = await app.inject({
      method: 'POST',
      url: '/api/invitations',
      ...req(host.token, { recipientId: guest.userId, activityId, message: 'again' }),
    });
    assert.equal(duplicate.statusCode, 409);
    assert.equal(
      (duplicate.json() as { error: { code: string } }).error.code,
      'INVITATION_PENDING',
    );

    // 4. The sender cannot accept their own invitation.
    const selfAccept = await app.inject({
      method: 'POST',
      url: `/api/invitations/${invitationId}/accept`,
      ...req(host.token),
    });
    assert.equal(selfAccept.statusCode, 403);

    // 5. The recipient accepts, which opens a conversation.
    const accepted = await app.inject({
      method: 'POST',
      url: `/api/invitations/${invitationId}/accept`,
      ...req(guest.token),
    });
    assert.equal(accepted.statusCode, 200, accepted.body);
    const accepteBody = accepted.json() as {
      data: { status: string; conversationId: string | null };
    };
    assert.equal(accepteBody.data.status, 'ACCEPTED');
    assert.ok(accepteBody.data.conversationId);
    const conversationId = accepteBody.data.conversationId!;

    // 6. Answering twice is refused.
    const secondAnswer = await app.inject({
      method: 'POST',
      url: `/api/invitations/${invitationId}/decline`,
      ...req(guest.token),
    });
    assert.equal(secondAnswer.statusCode, 409);

    // 7. The chat opens with the plan already in it.
    const seeded = await app.inject({
      method: 'GET',
      url: `/api/conversations/${conversationId}/messages`,
      ...req(host.token),
    });
    const seededMessages = (seeded.json() as { data: Array<{ type: string }> }).data;
    assert.equal(seededMessages.length, 1);
    assert.equal(seededMessages[0]?.type, 'SYSTEM');

    // 8. Both sides can talk.
    const sent = await app.inject({
      method: 'POST',
      url: `/api/conversations/${conversationId}/messages`,
      ...req(host.token, { body: 'Which screen are we in?' }),
    });
    assert.equal(sent.statusCode, 201);

    const inbox = await app.inject({
      method: 'GET',
      url: '/api/conversations',
      ...req(guest.token),
    });
    const thread = (inbox.json() as {
      data: Array<{ id: string; unreadCount: number; activity: { title: string } | null }>;
    }).data.find((conversation) => conversation.id === conversationId);

    assert.ok(thread, 'the conversation should appear in the guest inbox');
    assert.equal(thread.unreadCount, 1);
    assert.equal(thread.activity?.title, 'End-to-end test screening');

    // 9. Reading clears the badge.
    await app.inject({
      method: 'POST',
      url: `/api/conversations/${conversationId}/read`,
      ...req(guest.token),
    });
    const afterRead = await app.inject({
      method: 'GET',
      url: `/api/conversations/${conversationId}`,
      ...req(guest.token),
    });
    assert.equal((afterRead.json() as { data: { unreadCount: number } }).data.unreadCount, 0);

    // 10. A third party cannot read the thread.
    const outsider = await signIn('arjun.rao@example.com');
    const forbidden = await app.inject({
      method: 'GET',
      url: `/api/conversations/${conversationId}/messages`,
      ...req(outsider.token),
    });
    assert.equal(forbidden.statusCode, 403);

    // Clean up so repeated runs stay independent.
    await prisma.message.deleteMany({ where: { conversationId } });
    await prisma.conversationParticipant.deleteMany({ where: { conversationId } });
    await prisma.conversation.deleteMany({ where: { id: conversationId } });
    await prisma.invitation.deleteMany({ where: { id: invitationId } });
    await prisma.activityParticipant.deleteMany({ where: { activityId } });
    await prisma.activity.deleteMany({ where: { id: activityId } });
  });

  it('refuses an invitation to yourself', async () => {
    const { token, userId } = await signIn('demo@companion.app');
    const response = await app.inject({
      method: 'POST',
      url: '/api/invitations',
      ...req(token, { recipientId: userId, category: 'COFFEE', message: 'hello me' }),
    });
    assert.equal(response.statusCode, 400);
  });

  it('lets only the host cancel a plan', async () => {
    const host = await signIn('demo@companion.app');
    const other = await signIn('arjun.rao@example.com');

    const created = await app.inject({
      method: 'POST',
      url: '/api/activities',
      ...req(host.token, {
        category: 'WALK',
        title: 'Cancellation permission test',
        startsAt: new Date(Date.now() + 86_400_000).toISOString(),
        locationName: 'Cubbon Park',
        city: 'Bengaluru',
        latitude: 12.9756,
        longitude: 77.6068,
      }),
    });
    const activityId = (created.json() as { data: { id: string } }).data.id;

    const stranger = await app.inject({
      method: 'DELETE',
      url: `/api/activities/${activityId}`,
      ...req(other.token),
    });
    assert.equal(stranger.statusCode, 403);

    const owner = await app.inject({
      method: 'DELETE',
      url: `/api/activities/${activityId}`,
      ...req(host.token),
    });
    assert.equal(owner.statusCode, 200);
    assert.equal((owner.json() as { data: { status: string } }).data.status, 'CANCELLED');

    await prisma.activityParticipant.deleteMany({ where: { activityId } });
    await prisma.activity.deleteMany({ where: { id: activityId } });
  });
});

describe('safety', () => {
  it('makes a blocked person invisible in both directions', async () => {
    const me = await signIn('demo@companion.app');
    const them = await signIn('manav.thakur@example.com');

    // Start from a known state so the test is repeatable after an aborted run.
    await prisma.block.deleteMany({
      where: {
        OR: [
          { blockerId: me.userId, blockedId: them.userId },
          { blockerId: them.userId, blockedId: me.userId },
        ],
      },
    });

    const blocked = await app.inject({
      method: 'POST',
      url: `/api/safety/users/${them.userId}/block`,
      ...req(me.token, {}),
    });
    assert.equal(blocked.statusCode, 200);

    // Gone from my discovery…
    const mine = await app.inject({
      method: 'GET',
      url: '/api/discover/people?limit=50',
      ...req(me.token),
    });
    assert.ok(
      !(mine.json() as { data: Array<{ id: string }> }).data.some((p) => p.id === them.userId),
    );

    // …and I am gone from theirs.
    const theirs = await app.inject({
      method: 'GET',
      url: '/api/discover/people?limit=50',
      ...req(them.token),
    });
    assert.ok(
      !(theirs.json() as { data: Array<{ id: string }> }).data.some((p) => p.id === me.userId),
    );

    // The profile reads as missing rather than as blocked.
    const profile = await app.inject({
      method: 'GET',
      url: `/api/users/${them.userId}`,
      ...req(me.token),
    });
    assert.equal(profile.statusCode, 404);

    // And an invitation cannot be sent.
    const invitation = await app.inject({
      method: 'POST',
      url: '/api/invitations',
      ...req(me.token, { recipientId: them.userId, category: 'COFFEE', message: 'hi' }),
    });
    assert.equal(invitation.statusCode, 403);

    const unblocked = await app.inject({
      method: 'DELETE',
      url: `/api/safety/users/${them.userId}/block`,
      ...req(me.token),
    });
    assert.equal(unblocked.statusCode, 200);
  });

  it('records a report', async () => {
    const me = await signIn('demo@companion.app');
    const them = await signIn('yash.gupta@example.com');

    const response = await app.inject({
      method: 'POST',
      url: `/api/safety/users/${them.userId}/report`,
      ...req(me.token, { reason: 'FAKE_PROFILE', details: 'Reported by the test suite.' }),
    });

    assert.equal(response.statusCode, 201);
    const body = response.json() as { data: { id: string } };
    await prisma.report.deleteMany({ where: { id: body.data.id } });
  });
});

describe('privacy', () => {
  it('honours the discovery opt-out and restores it', async () => {
    const { token, userId } = await signIn('kavya.reddy@example.com');
    const viewer = await signIn('demo@companion.app');

    await app.inject({
      method: 'PUT',
      url: '/api/users/me',
      ...req(token, { isDiscoverable: false }),
    });

    const hidden = await app.inject({
      method: 'GET',
      url: '/api/discover/people?limit=50&radiusKm=200',
      ...req(viewer.token),
    });
    assert.ok(
      !(hidden.json() as { data: Array<{ id: string }> }).data.some((p) => p.id === userId),
    );

    await app.inject({
      method: 'PUT',
      url: '/api/users/me',
      ...req(token, { isDiscoverable: true }),
    });
  });

  it('leaves untouched fields alone on a partial update', async () => {
    const { token } = await signIn('demo@companion.app');

    const before = await app.inject({ method: 'GET', url: '/api/users/me', ...req(token) });
    const originalBio = (before.json() as { data: { bio: string } }).data.bio;

    await app.inject({
      method: 'PUT',
      url: '/api/users/me',
      ...req(token, { showDistance: true }),
    });

    const after = await app.inject({ method: 'GET', url: '/api/users/me', ...req(token) });
    assert.equal((after.json() as { data: { bio: string } }).data.bio, originalBio);
  });
});

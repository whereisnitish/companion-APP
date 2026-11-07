import 'dotenv/config';
import { PrismaClient, type ActivityCategory, type Prisma } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { ACTIVITIES, AREAS, INTERESTS, PEOPLE } from './seed-data';

const prisma = new PrismaClient();

/** Everyone in the seed shares this password so the demo is easy to explore. */
const SEED_PASSWORD = 'Password123';
const DEMO_EMAIL = 'demo@companion.app';

/** Deterministic PRNG — the same database every time you reset. */
function makeRandom(seed: number) {
  let state = seed;
  return () => {
    state = (state * 1664525 + 1013904223) % 4294967296;
    return state / 4294967296;
  };
}
const random = makeRandom(20260831);

const jitter = (value: number, spread: number) => value + (random() - 0.5) * spread;
const pick = <T>(items: readonly T[]): T => items[Math.floor(random() * items.length)]!;

function birthDateForAge(age: number): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear() - age, (Math.floor(random() * 12)), 1 + Math.floor(random() * 27)));
}

function at(inDays: number, hour: number, minute: number): Date {
  const date = new Date();
  date.setDate(date.getDate() + inDays);
  date.setHours(hour, minute, 0, 0);
  // A plan already in the past is useless in a demo — roll it a week forward.
  if (date.getTime() < Date.now()) date.setDate(date.getDate() + 7);
  return date;
}

function minutesAgo(minutes: number): Date {
  return new Date(Date.now() - minutes * 60_000);
}

function portraitUrl(set: 'women' | 'men', index: number): string {
  return `https://randomuser.me/api/portraits/${set}/${index}.jpg`;
}

/** Secondary gallery shots — seeded so they stay stable between resets. */
function galleryUrls(slug: string, count: number): string[] {
  return Array.from(
    { length: count },
    (_, index) => `https://picsum.photos/seed/${slug}-${index}/900/1200`,
  );
}

async function reset(): Promise<void> {
  // Order matters: children before parents.
  await prisma.message.deleteMany();
  await prisma.conversationParticipant.deleteMany();
  await prisma.conversation.deleteMany();
  await prisma.invitation.deleteMany();
  await prisma.activityParticipant.deleteMany();
  await prisma.activity.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.report.deleteMany();
  await prisma.block.deleteMany();
  await prisma.profileInterest.deleteMany();
  await prisma.interest.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.profile.deleteMany();
  await prisma.user.deleteMany();
}

async function main(): Promise<void> {
  console.log('› Resetting existing data…');
  await reset();

  console.log('› Seeding interests…');
  await prisma.interest.createMany({ data: INTERESTS });
  const interestRows = await prisma.interest.findMany({ select: { id: true, slug: true } });
  const interestId = new Map(interestRows.map((row) => [row.slug, row.id]));

  const passwordHash = await bcrypt.hash(SEED_PASSWORD, 10);
  const userIdByEmail = new Map<string, string>();

  console.log(`› Seeding ${PEOPLE.length + 1} people…`);

  // --- the account you sign into ------------------------------------------
  const demoArea = AREAS['Sector 17']!;
  const demo = await prisma.user.create({
    data: {
      email: DEMO_EMAIL,
      phone: '+919000000001',
      passwordHash,
      lastActiveAt: new Date(),
      profile: {
        create: {
          displayName: 'Nitish',
          birthDate: birthDateForAge(28),
          gender: 'MALE',
          bio: 'New in the neighbourhood and trying to do more of the things I keep putting off. Films, long dinners, the occasional 6am walk.',
          occupation: 'Software engineer',
          city: 'Chandigarh',
          area: 'Sector 17',
          latitude: demoArea.lat,
          longitude: demoArea.lon,
          avatarUrl: portraitUrl('men', 3),
          photos: galleryUrls('nitish', 3),
          preferredActivities: ['MOVIE', 'DINNER', 'COFFEE', 'WALK', 'CONCERT'],
          availability: ['TONIGHT', 'WEEKEND', 'FLEXIBLE'],
          verification: 'VERIFIED',
          ratingAvg: 4.8,
          ratingCount: 11,
          isComplete: true,
          interests: {
            create: ['indie-films', 'specialty-coffee', 'live-music', 'running', 'startups']
              .map((slug) => interestId.get(slug))
              .filter((id): id is string => Boolean(id))
              .map((id) => ({ interestId: id })),
          },
        },
      },
    },
    select: { id: true },
  });
  userIdByEmail.set(DEMO_EMAIL, demo.id);

  // --- the community -------------------------------------------------------
  for (const [index, person] of PEOPLE.entries()) {
    const area = AREAS[person.area] ?? demoArea;
    const user = await prisma.user.create({
      data: {
        email: person.email,
        passwordHash,
        // Staggered activity so "online now" and freshness ranking mean something.
        lastActiveAt: minutesAgo(Math.floor(random() * 2880)),
        profile: {
          create: {
            displayName: person.displayName,
            birthDate: birthDateForAge(person.age),
            gender: person.gender,
            bio: person.bio,
            occupation: person.occupation,
            city: 'Chandigarh',
            area: person.area,
            latitude: jitter(area.lat, 0.02),
            longitude: jitter(area.lon, 0.02),
            avatarUrl: portraitUrl(person.portraitSet, person.portrait),
            photos: galleryUrls(`p${index}`, 2 + Math.floor(random() * 2)),
            preferredActivities: person.preferredActivities,
            availability: person.availability,
            verification: person.verification,
            ratingAvg: person.rating[0],
            ratingCount: person.rating[1],
            isComplete: true,
            interests: {
              create: person.interests
                .map((slug) => interestId.get(slug))
                .filter((id): id is string => Boolean(id))
                .map((id) => ({ interestId: id })),
            },
          },
        },
      },
      select: { id: true },
    });
    userIdByEmail.set(person.email, user.id);
  }

  console.log(`› Seeding ${ACTIVITIES.length + 2} activities…`);
  const activityIdByTitle = new Map<string, string>();

  for (const activity of ACTIVITIES) {
    const hostId = userIdByEmail.get(activity.hostEmail);
    if (!hostId) continue;
    const area = AREAS[activity.area] ?? demoArea;

    const created = await prisma.activity.create({
      data: {
        hostId,
        category: activity.category,
        title: activity.title,
        description: activity.description,
        startsAt: at(activity.inDays, activity.hour, activity.minute),
        locationName: activity.locationName,
        area: activity.area,
        city: 'Chandigarh',
        latitude: jitter(area.lat, 0.01),
        longitude: jitter(area.lon, 0.01),
        lookingFor: activity.lookingFor,
        capacity: activity.capacity ?? 1,
        participants: { create: { userId: hostId, role: 'HOST' } },
      },
      select: { id: true, title: true },
    });
    activityIdByTitle.set(created.title, created.id);
  }

  // Two plans hosted by the demo account, so "My plans" is not empty.
  for (const own of [
    {
      category: 'DINNER' as ActivityCategory,
      title: 'Trying the new ramen place',
      description:
        'Heard the queue is worth it. Going early to beat it — would rather share a table than eat alone.',
      inDays: 1,
      hour: 19,
      minute: 30,
      locationName: 'Noodle Bar, Sector 15',
      area: 'Sector 15',
    },
    {
      category: 'WALK' as ActivityCategory,
      title: 'Sunday morning around Rose Garden',
      description: 'Easy pace, no agenda. Coffee somewhere in Sector 17 afterwards.',
      inDays: 3,
      hour: 7,
      minute: 30,
      locationName: 'Rose Garden',
      area: 'Sector 9',
    },
  ]) {
    const area = AREAS[own.area] ?? demoArea;
    const created = await prisma.activity.create({
      data: {
        hostId: demo.id,
        category: own.category,
        title: own.title,
        description: own.description,
        startsAt: at(own.inDays, own.hour, own.minute),
        locationName: own.locationName,
        area: own.area,
        city: 'Chandigarh',
        latitude: area.lat,
        longitude: area.lon,
        capacity: 2,
        participants: { create: { userId: demo.id, role: 'HOST' } },
      },
      select: { id: true, title: true },
    });
    activityIdByTitle.set(created.title, created.id);
  }

  console.log('› Seeding invitations…');
  const id = (email: string) => userIdByEmail.get(email)!;

  const invitations: Prisma.InvitationCreateManyInput[] = [
    // Waiting on the demo user — the first thing you see in Invites.
    {
      senderId: id('sara.mehta@example.com'),
      recipientId: demo.id,
      activityId: activityIdByTitle.get('The late show at PVR Elante') ?? null,
      message: 'Saw you are into indie films too. The 9:40 show tonight — want to come along?',
      status: 'PENDING',
      createdAt: minutesAgo(42),
    },
    {
      senderId: id('kabir.sen@example.com'),
      recipientId: demo.id,
      activityId: activityIdByTitle.get('Indie set at The Basement') ?? null,
      message: 'Extra ticket for tomorrow. They are genuinely great live.',
      status: 'PENDING',
      createdAt: minutesAgo(180),
    },
    {
      senderId: id('meera.pillai@example.com'),
      recipientId: demo.id,
      category: 'WALK',
      proposedAt: at(1, 7, 0),
      locationName: 'Sukhna Lake',
      message: 'Doing the lake loop tomorrow morning if you are up for an early start.',
      status: 'PENDING',
      createdAt: minutesAgo(320),
    },
    {
      senderId: id('anika.dsouza@example.com'),
      recipientId: demo.id,
      activityId: activityIdByTitle.get('Bookstore hop in Sector 17') ?? null,
      message: 'Three bookshops, one afternoon. You seem like you would last the distance.',
      status: 'PENDING',
      createdAt: minutesAgo(900),
    },
    // Sent by the demo user.
    {
      senderId: demo.id,
      recipientId: id('nikita.shah@example.com'),
      activityId: activityIdByTitle.get('Slow Saturday brunch') ?? null,
      message: 'I am also on the croissant hunt. Saturday works — shall I come by at eleven?',
      status: 'PENDING',
      createdAt: minutesAgo(75),
    },
    {
      senderId: demo.id,
      recipientId: id('aditya.kulkarni@example.com'),
      activityId: activityIdByTitle.get('Morni Hills before sunrise') ?? null,
      message: 'I can do 4am. Playlist duty accepted.',
      status: 'ACCEPTED',
      respondedAt: minutesAgo(600),
      createdAt: minutesAgo(720),
    },
    {
      senderId: demo.id,
      recipientId: id('ritika.sharma@example.com'),
      category: 'MOVIE',
      proposedAt: at(1, 10, 0),
      locationName: 'PVR Centra Mall',
      message: 'First day first show is the only correct way to watch it.',
      status: 'DECLINED',
      respondedAt: minutesAgo(1400),
      createdAt: minutesAgo(1500),
    },
    // Accepted, and already talking — powers the seeded conversations.
    {
      senderId: id('aisha.khan@example.com'),
      recipientId: demo.id,
      activityId: activityIdByTitle.get('Thursday biryani crawl') ?? null,
      message: 'Three places, one street. You in?',
      status: 'ACCEPTED',
      respondedAt: minutesAgo(240),
      createdAt: minutesAgo(300),
    },
    {
      senderId: demo.id,
      recipientId: id('ananya.bose@example.com'),
      category: 'COFFEE',
      proposedAt: at(0, 18, 0),
      locationName: 'Blue Tokai, Sector 17',
      message: 'A two-hour coffee sounds exactly right. This evening?',
      status: 'ACCEPTED',
      respondedAt: minutesAgo(90),
      createdAt: minutesAgo(120),
    },
    {
      senderId: id('siddharth.menon@example.com'),
      recipientId: demo.id,
      activityId: activityIdByTitle.get('Work-from-cafe, parallel play') ?? null,
      message: 'Parallel play, minimal talking. My favourite kind of company.',
      status: 'ACCEPTED',
      respondedAt: minutesAgo(2000),
      createdAt: minutesAgo(2100),
    },
  ];

  // Community-to-community invitations, so the graph is not demo-centric.
  const communityEmails = PEOPLE.map((person) => person.email);
  for (let index = 0; index < 14; index += 1) {
    const sender = pick(communityEmails);
    let recipient = pick(communityEmails);
    while (recipient === sender) recipient = pick(communityEmails);
    invitations.push({
      senderId: id(sender),
      recipientId: id(recipient),
      category: pick(['MOVIE', 'DINNER', 'COFFEE', 'WALK', 'SPORTS'] as ActivityCategory[]),
      proposedAt: at(Math.floor(random() * 6), 18 + Math.floor(random() * 4), 0),
      message: pick([
        'Free this week? I have been meaning to try that place.',
        'Would be nice to have company for this one.',
        'Short notice, but you seemed like you would say yes.',
        'Same neighbourhood, same taste in plans. Worth a shot?',
      ]),
      status: pick(['PENDING', 'ACCEPTED', 'DECLINED'] as const),
      createdAt: minutesAgo(Math.floor(random() * 4000)),
    });
  }

  await prisma.invitation.createMany({ data: invitations });

  console.log('› Opening conversations…');
  const accepted = await prisma.invitation.findMany({
    where: { status: 'ACCEPTED', OR: [{ senderId: demo.id }, { recipientId: demo.id }] },
    select: { id: true, senderId: true, recipientId: true, activityId: true },
  });

  const scripts: Record<string, Array<{ fromDemo: boolean; body: string; minutesAgo: number }>> = {
    default: [
      { fromDemo: false, body: 'Hey! Are you still up for this?', minutesAgo: 180 },
      { fromDemo: true, body: 'Definitely. What time should I be there?', minutesAgo: 174 },
      { fromDemo: false, body: 'Let us say a quarter past — parking is a nightmare after that.', minutesAgo: 170 },
      { fromDemo: true, body: 'Works. See you there.', minutesAgo: 165 },
    ],
  };

  for (const invitation of accepted) {
    const otherId = invitation.senderId === demo.id ? invitation.recipientId : invitation.senderId;
    const script = scripts.default!;

    const conversation = await prisma.conversation.create({
      data: {
        invitationId: invitation.id,
        activityId: invitation.activityId,
        lastMessageAt: minutesAgo(script[script.length - 1]!.minutesAgo),
        lastMessagePreview: script[script.length - 1]!.body,
        participants: { create: [{ userId: demo.id }, { userId: otherId }] },
      },
      select: { id: true },
    });

    await prisma.message.createMany({
      data: script.map((line, index) => ({
        conversationId: conversation.id,
        senderId: line.fromDemo ? demo.id : otherId,
        body: line.body,
        createdAt: minutesAgo(line.minutesAgo),
        // Everything except the last inbound line is read — leaves a real unread badge.
        readAt: index < script.length - 1 ? minutesAgo(line.minutesAgo - 1) : null,
      })),
    });
  }

  // One conversation with a genuinely unread inbound message.
  const aishaConversation = await prisma.conversation.findFirst({
    where: { participants: { some: { userId: id('aisha.khan@example.com') } } },
    select: { id: true },
  });
  if (aishaConversation) {
    await prisma.message.create({
      data: {
        conversationId: aishaConversation.id,
        senderId: id('aisha.khan@example.com'),
        body: 'Changed my mind on the order — we start at the small place, it sells out by nine.',
        createdAt: minutesAgo(12),
      },
    });
    await prisma.conversation.update({
      where: { id: aishaConversation.id },
      data: {
        lastMessageAt: minutesAgo(12),
        lastMessagePreview: 'Changed my mind on the order — we start at the small place, it sells out by nine.',
      },
    });
  }

  console.log('› Seeding notifications…');
  await prisma.notification.createMany({
    data: [
      {
        userId: demo.id,
        type: 'INVITATION_RECEIVED',
        title: 'Sara Mehta invited you',
        body: 'The late show at PVR Elante · Tonight, 9:40 PM',
        createdAt: minutesAgo(42),
      },
      {
        userId: demo.id,
        type: 'INVITATION_RECEIVED',
        title: 'Kabir Sen invited you',
        body: 'Indie set at The Basement · Tomorrow, 8:00 PM',
        createdAt: minutesAgo(180),
      },
      {
        userId: demo.id,
        type: 'MESSAGE_RECEIVED',
        title: 'Aisha Khan',
        body: 'Changed my mind on the order — we start at the small place…',
        createdAt: minutesAgo(12),
      },
      {
        userId: demo.id,
        type: 'INVITATION_ACCEPTED',
        title: 'Aditya Kulkarni said yes',
        body: 'You are both in for Morni Hills before sunrise.',
        readAt: minutesAgo(500),
        createdAt: minutesAgo(600),
      },
      {
        userId: demo.id,
        type: 'ACTIVITY_REMINDER',
        title: 'Tomorrow at 7:30 PM',
        body: 'Trying the new ramen place · Noodle Bar, Sector 15',
        readAt: minutesAgo(30),
        createdAt: minutesAgo(60),
      },
    ],
  });

  const counts = await Promise.all([
    prisma.user.count(),
    prisma.activity.count(),
    prisma.invitation.count(),
    prisma.conversation.count(),
    prisma.message.count(),
  ]);

  console.log('\n  Seed complete.');
  console.log(`  ${counts[0]} users · ${counts[1]} activities · ${counts[2]} invitations · ${counts[3]} conversations · ${counts[4]} messages`);
  console.log(`\n  Sign in with   ${DEMO_EMAIL}  /  ${SEED_PASSWORD}`);
  console.log(`  Every seeded account uses the same password.\n`);
}

main()
  .catch((error: unknown) => {
    console.error('Seed failed:', error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

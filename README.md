# Companion

**Find someone who actually wants to do the thing you want to do.**

Companion is not a dating app. It is a companion-activity platform: you say what
you are up for — a film, dinner, a 6am walk — and it finds someone nearby who
wants the same thing at the same time. Discovery is organised around
**activities and availability**, not faces. There is no swiping, no scarcity
mechanic, and no ranking you cannot explain.

The MVP proves exactly one thing end to end:

> Can somebody easily discover a person who wants to do an activity with them,
> and successfully connect?

---

## Contents

- [What is built](#what-is-built)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Environment variables](#environment-variables)
- [Database](#database)
- [Running the backend](#running-the-backend)
- [Running the mobile app](#running-the-mobile-app)
- [Tests](#tests)
- [API documentation](#api-documentation)
- [Design system](#design-system)
- [Project structure](#project-structure)
- [What is deliberately stubbed](#what-is-deliberately-stubbed)

---

## What is built

**The core journey works end to end, against a real database:**

```
open → onboarding → sign up → build a profile → home
     → pick an activity → discover people → view a profile
     → send an invitation → they accept → a conversation opens → chat
```

…and the other direction:

```
create a plan (what / when / where / who) → post it
     → someone discovers it → asks to join → you accept → chat
```

| Area | Status |
| --- | --- |
| Onboarding, auth (email + password, OTP scaffold) | ✅ |
| Progressive profile creation (7 steps) | ✅ |
| Home feed — categories, tonight, people, plans, badges | ✅ |
| Discovery — people and plans, 7 filters, search | ✅ |
| Activity creation with a live preview of the posted card | ✅ |
| Invitations — send, receive, accept, decline, withdraw, expire | ✅ |
| Connection → conversation, seeded with the plan | ✅ |
| Chat — history, optimistic send, typing, read receipts, WebSocket | ✅ |
| Notifications — persisted, realtime, deep-linked | ✅ |
| Safety — block, report, privacy toggles, safety centre, guidelines | ✅ |
| Light and dark themes, 3 device sizes, 1.3× text scale | ✅ |
| 153 automated tests (136 Flutter, 17 backend) | ✅ |

---

## Architecture

```
┌──────────────────────────┐        REST + WebSocket        ┌──────────────────────────┐
│     Flutter (mobile)     │ ─────────────────────────────► │   Node.js / Fastify API  │
│                          │ ◄───────────────────────────── │                          │
│  Riverpod · go_router    │                                │  modular monolith        │
│  Dio · web_socket_channel│                                │  Zod validation          │
└──────────────────────────┘                                └────────────┬─────────────┘
                                                                         │ Prisma
                                                            ┌────────────┴─────────────┐
                                                            │  PostgreSQL   │  Redis   │
                                                            │  source of    │  cache,  │
                                                            │  truth        │  presence│
                                                            └──────────────────────────┘
```

**A modular monolith, not microservices.** One deployable, one schema, clear
module boundaries (`auth`, `profiles`, `discovery`, `activities`, `invitations`,
`conversations`, `notifications`, `safety`, `realtime`). Each module is
`*.schema.ts` (Zod) → `*.service.ts` (logic) → `*.routes.ts` (HTTP).

**Redis is an accelerator, never a dependency.** It caches discovery pages,
tracks presence and enforces invitation quotas. Every call site degrades
gracefully, so the API runs correctly with Redis switched off — `/health`
simply reports `"redis": false`.

**Realtime is an enhancement, never a requirement.** Everything the WebSocket
delivers is also reachable over REST, so a dropped socket degrades to
pull-to-refresh rather than breaking a screen.

**One error shape, one success shape.** Every endpoint returns
`{ data, meta? }` or `{ error: { code, message, details? } }`, and every
`message` is written for a human to read verbatim.

---

## Prerequisites

| Tool | Version | Notes |
| --- | --- | --- |
| Node.js | ≥ 20 | `node -v` |
| Flutter | ≥ 3.6 | `flutter --version` |
| PostgreSQL | ≥ 14 | Or use Docker (below) |
| Redis | ≥ 6 | Optional — the API runs without it |
| Docker | any recent | Optional, for Postgres + Redis |

---

## Quick start

Two terminals, about five minutes.

### 1. Data

Either with Docker:

```bash
cd companion-app
docker compose up -d postgres redis
```

…or with a Postgres you already run:

```bash
createdb companion
```

### 2. Backend

```bash
cd backend
cp .env.example .env          # then set DATABASE_URL + JWT_SECRET
npm install
npm run prisma:generate
npm run prisma:migrate        # creates the schema
npm run db:seed               # 31 people, 26 plans, conversations, messages
npm run dev                   # http://localhost:4000
```

Check it:

```bash
curl http://localhost:4000/health
# {"status":"ok","database":true,"redis":true,...}
```

### 3. Mobile

```bash
cd ../mobile
./tool/setup.sh               # generates ios/ + android/, fetches packages
flutter run --dart-define=API_BASE_URL=http://localhost:4000
```

> `setup.sh` is safe to re-run: it regenerates the platform folders without
> touching the hand-written `pubspec.yaml`.

### 4. Sign in

The seed creates a fully populated account:

```
demo@companion.app  /  Password123
```

Every seeded account shares that password, so you can sign in as
`sara.mehta@example.com` in a second simulator and watch invitations and
messages arrive live over the WebSocket.

The sign-in screen also has a one-tap **"Sign in as demo@companion.app"** button.

### Choosing the right host

| Target | `API_BASE_URL` |
| --- | --- |
| iOS simulator | `http://localhost:4000` |
| Android emulator | `http://10.0.2.2:4000` |
| Physical device | `http://<your-LAN-IP>:4000` |

Omit the flag and the app guesses: `10.0.2.2` on Android, `localhost` elsewhere.

> A physical Android device also needs cleartext HTTP allowed for local
> development, or point `API_BASE_URL` at an HTTPS tunnel.

---

## Environment variables

`backend/.env` — see `backend/.env.example`.

| Variable | Default | Purpose |
| --- | --- | --- |
| `NODE_ENV` | `development` | `development` \| `test` \| `production` |
| `PORT` | `4000` | HTTP port |
| `HOST` | `0.0.0.0` | Bind address |
| `DATABASE_URL` | — | **Required.** Postgres connection string |
| `REDIS_URL` | `redis://localhost:6379` | Optional; degrades gracefully |
| `JWT_SECRET` | — | **Required**, ≥ 16 chars. `openssl rand -base64 48` |
| `JWT_ACCESS_TTL` | `15m` | Access token lifetime |
| `JWT_REFRESH_TTL_DAYS` | `30` | Refresh token lifetime |
| `CORS_ORIGIN` | `*` | Comma-separated origins, or `*` |
| `LOG_LEVEL` | `info` | pino level |
| `RATE_LIMIT_MAX` | `300` | Requests per window |
| `RATE_LIMIT_WINDOW` | `1 minute` | Window size |

The config is validated with Zod at boot. A missing or malformed variable stops
the process with a readable list of what is wrong, rather than failing later.

Mobile configuration is compile-time, passed to `flutter run`:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:4000
```

---

## Database

Eleven models with real relationships and no duplicated state:

```
User ──1:1── Profile ──*:*── Interest        (via ProfileInterest)
  │
  ├──1:*── Activity ──1:*── ActivityParticipant
  ├──1:*── Invitation ──0:1── Conversation ──1:*── Message
  │                                └──*:*── User (via ConversationParticipant)
  ├──1:*── Notification
  ├──1:*── Block / Report
  └──1:*── RefreshToken
```

Indexed for the queries the product actually makes: `Activity(status, startsAt)`,
`Activity(city, status, startsAt)`, `Profile(city, isDiscoverable)`,
`Message(conversationId, createdAt)`, `Invitation(recipientId, status, createdAt)`.

```bash
npm run prisma:migrate     # create + apply a migration (development)
npm run prisma:deploy      # apply existing migrations (production)
npm run prisma:studio      # browse the data
npm run db:seed            # reset and repopulate
npm run db:reset           # drop, migrate, seed
```

### Seed data

31 fictional people across 16 Chandigarh neighbourhoods — different genders, ages
(22–35), occupations, interests, preferred activities and availability — plus 26
open plans spread over the next ten days, 24 invitations in every state, four
live conversations with message history, and notifications. Portraits come from
`randomuser.me`; no real people's data is used.

The demo account starts with **4 invitations waiting**, **2 plans of its own**,
**4 conversations** and **1 unread message**, so the app looks like a product
the moment you sign in.

---

## Running the backend

```bash
npm run dev          # tsx watch, pretty logs
npm run build        # tsc → dist/
npm start            # node dist/server.js
npm run typecheck    # tsc --noEmit
```

Everything containerised:

```bash
docker compose up -d          # postgres + redis + api
docker compose exec api npx tsx prisma/seed.ts
```

---

## Running the mobile app

```bash
./tool/setup.sh                                   # first time only
flutter run                                       # guesses the host
flutter run --dart-define=API_BASE_URL=http://localhost:4000
flutter analyze                                   # 0 issues
flutter test                                      # 136 tests
```

---

## Tests

**Backend — 17 tests.** Real HTTP through Fastify's `inject`, against the seeded
database: routing, Zod validation, JWT auth, Prisma queries and every
permission rule.

```bash
cd backend
npm run db:seed      # tests read the seeded data
npm test
```

Covered: validation error shapes; account enumeration resistance; refresh-token
rotation and replay rejection; the full post → invite → accept → chat journey;
duplicate-invitation and double-answer rejection; host-only cancellation;
conversation membership enforcement; symmetric blocking; partial profile updates.

**Mobile — 136 tests.**

```bash
cd mobile
flutter test
```

| Suite | What it proves |
| --- | --- |
| `formatters_test.dart` | Dates, distances and relative times — including the midnight boundary |
| `models_test.dart` | JSON parsing survives missing fields and unknown enum values |
| `design_system_test.dart` | Both palettes define every token distinctly; every button variant, chip and input behaves |
| `cards_test.dart` | Person and activity cards across all 12 categories, empty fields and 600-character bios |
| `screens_test.dart` | Splash, Home, Invitations and Messages — loading, empty and populated states against a mocked API |
| `layout_resilience_test.dart` | Every screen at 3 device sizes, 1.3× text scale and in dark mode |

That last suite is the one that keeps the product feeling finished: 33 screen ×
size combinations that fail the build if a single row overflows.

---

## API documentation

Full reference — every endpoint, request body, response shape, auth requirement
and error code — is in **[docs/API.md](docs/API.md)**.

The shape in brief:

```
POST   /api/auth/register            POST   /api/invitations
POST   /api/auth/login               GET    /api/invitations/received
POST   /api/auth/refresh             GET    /api/invitations/sent
POST   /api/auth/logout              GET    /api/invitations/counts
POST   /api/auth/otp/request         POST   /api/invitations/:id/accept
POST   /api/auth/otp/verify          POST   /api/invitations/:id/decline
                                     POST   /api/invitations/:id/cancel
GET    /api/users/me
PUT    /api/users/me                 GET    /api/conversations
POST   /api/users/me/profile         GET    /api/conversations/:id
GET    /api/users/:id                GET    /api/conversations/:id/messages
GET    /api/catalog/interests        POST   /api/conversations/:id/messages
                                     POST   /api/conversations/:id/read
GET    /api/discover
GET    /api/discover/people          GET    /api/notifications
GET    /api/discover/activities      POST   /api/notifications/:id/read
                                     POST   /api/notifications/read-all
GET    /api/activities
POST   /api/activities               POST   /api/safety/users/:id/block
GET    /api/activities/:id           DELETE /api/safety/users/:id/block
DELETE /api/activities/:id           POST   /api/safety/users/:id/report
                                     GET    /api/safety/blocks
GET    /health                       WS     /ws?token=<accessToken>
```

---

## Design system

Everything visual comes from tokens in `mobile/lib/theme/`. No screen invents a
colour, a size or a duration.

**Direction — warm paper, deep pine, one clay accent.** Deliberately not the
saturated pinks and purples of the dating category: this is a product about
plans, and it should look like something you would use in public.

| Token file | Contents |
| --- | --- |
| `app_colors.dart` | 25 semantic colours × light and dark |
| `app_typography.dart` | 13 styles across two faces |
| `app_spacing.dart` | Spacing (2→56), radii (8→pill), motion (90ms→520ms, 3 curves) |
| `app_shadows.dart` | Three elevations, all ≤ 5% opacity |
| `app_theme.dart` | Binds the tokens to `ThemeData` via a `ThemeExtension` |

**Type** pairs a serif display face (Fraunces) with a neutral UI face (Inter).
The serif appears in exactly four places — the home greeting, screen titles,
names on profile detail, and section leads on activity detail. Used everywhere
it would read like a magazine; used nowhere it would read like a template.

**Colour carries meaning, never decoration.** Each of the twelve activity
categories owns one hue; tints and dark-mode variants are derived from it, so
adding a thirteenth category means adding one colour.

**Motion is short and purposeful.** Content enters with a 12px rise and a fade,
staggered by list position and capped after six items so a long list never feels
slow. Buttons scale to 97.5% on press. Material's ink splash is switched off
globally — a ripple crossing a photo card looks cheap; a physical press does not.

**Components** (`mobile/lib/widgets/`): buttons (4 variants × 3 sizes), cards,
chips, category badges, avatars with deterministic initials fallback, inputs,
bottom sheets, confirmations, skeletons, empty/error/offline states, snackbars,
a press effect and an entrance animation.

Nothing here ever shows a blank screen: every list has a loading silhouette
shaped like its real content, an empty state that says what would fill it, and
an error state with exactly one way forward.

---

## Project structure

```
companion-app/
├── backend/
│   ├── prisma/
│   │   ├── schema.prisma          11 models, enums, indexes
│   │   ├── seed.ts                deterministic seeding
│   │   └── seed-data.ts           31 people, 26 plans, 38 interests
│   ├── src/
│   │   ├── common/                errors, envelopes, pagination, geo, serializers
│   │   ├── config/                Zod-validated env, tuning constants
│   │   ├── database/              Prisma + Redis clients
│   │   ├── middleware/            JWT auth, one error handler
│   │   ├── modules/
│   │   │   ├── auth/  profiles/  discovery/  activities/
│   │   │   ├── invitations/  conversations/  notifications/
│   │   │   ├── safety/  realtime/
│   │   ├── utils/                 password, tokens, dates
│   │   ├── app.ts                 plugin + route composition
│   │   └── server.ts              boot, graceful shutdown
│   ├── tests/api.test.ts
│   └── Dockerfile
│
├── mobile/
│   ├── lib/
│   │   ├── core/                  config, network, storage, realtime, utils
│   │   ├── theme/                 the design system
│   │   ├── models/                plain Dart, hand-written parsing
│   │   ├── services/              one per API domain, plus the container
│   │   ├── providers/             Riverpod: auth, discover, chat, notifications
│   │   ├── routing/               go_router, redirects, the auth gate
│   │   ├── widgets/               the shared widget library
│   │   ├── features/
│   │   │   ├── onboarding/  auth/  profile_setup/
│   │   │   ├── home/  discover/  activities/
│   │   │   ├── invitations/  chat/  notifications/
│   │   │   └── profile/  settings/  shell/
│   │   ├── app.dart
│   │   └── main.dart
│   ├── test/
│   ├── tool/setup.sh
│   └── pubspec.yaml
│
├── docs/API.md
├── docker-compose.yml
└── README.md
```

No code generation anywhere — no `build_runner`, no `.g.dart` files. Models and
parsers are hand-written, so `git clone && ./tool/setup.sh && flutter run`
is the whole setup.

---

## What is deliberately stubbed

Honest about the edges, and each one is a swap rather than a rewrite:

| Stub | Where it lives | What replacing it takes |
| --- | --- | --- |
| **Photo storage** | Profile pictures upload from the gallery or camera and live in Postgres, in the `media` module | An object store behind `media.service.ts`, once there are enough photos to justify one |
| **OTP delivery** | `/auth/otp/*` returns a fixed dev code | An SMS provider call inside `auth.service.ts` |
| **Push delivery** | Notifications are persisted and pushed over the WebSocket | APNs/FCM behind the existing `notify()` — no call site changes |
| **Verification** | Badge, states and UI are real; nothing checks identity | A verification provider writing to `Profile.verification` |
| **Geocoding** | 16 curated Chandigarh neighbourhoods with coordinates | A geocoder behind `Places`; distances already use real great-circle maths |
| **Notification preferences** | Switches are local to the device | A `/users/me/notification-preferences` endpoint |
| **Ratings** | Stored, displayed, seeded — never written by the app | A post-meet-up rating flow |

Intentionally **not** built, per the MVP brief: swipe mechanics, subscriptions,
ads, recommendation engines, video calling, AI matching, payments, microservices.

---

## Notes on the things that took the most care

- **Home** answers "what can I do today?" above the fold: the greeting, then the
  category row, then evidence that the answer is real. Everything else scrolls.
- **Discovery** is a browse surface. A person's bio is on the card, not behind a
  tap, because someone should be able to decide without opening anything.
- **Accepting an invitation** is the product's one real state transition. It is a
  single transaction: settle the invitation, join the activity, create the
  conversation, and seed a system message carrying the plan — so the chat never
  opens empty and neither person has to explain what they agreed to.
- **Blocking** is symmetric and silent. A blocked profile returns `404`, not
  `403`, so a block is indistinguishable from a deleted account.
- **Ranking** is arithmetic you can read in fifteen lines: shared activities ×14,
  shared interests ×9, shared availability ×6, then proximity and freshness.

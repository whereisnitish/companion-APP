# Companion API

Base URL: `http://localhost:4000`
All application endpoints live under `/api`. The WebSocket lives at `/ws`.

## Conventions

**Success** — every endpoint returns a single envelope:

```jsonc
{
  "data": { /* or [ ... ] */ },
  "meta": { /* only on paginated or counted responses */ }
}
```

**Failure** — every endpoint fails in one shape:

```jsonc
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Some fields need attention.",
    "details": { "email": "Enter a valid email address." }  // optional
  }
}
```

`message` is written for humans and is safe to display verbatim. `details` (on
`VALIDATION_ERROR`) maps field name → message, ready to drop onto form fields.

**Authentication** — send the access token as a bearer header:

```
Authorization: Bearer <accessToken>
```

Access tokens last 15 minutes; refresh tokens last 30 days and rotate on every
use (the old one is revoked immediately). The mobile client refreshes
transparently on a 401 and replays the original request once.

**Rate limits** — 300 requests/minute per user (per IP when anonymous), with
tighter budgets on sensitive routes (noted per endpoint). Exceeding one returns
`429 RATE_LIMITED`.

**Pagination** — cursor-based on list endpoints:
`?cursor=<id>&limit=20` → `meta: { nextCursor, hasMore }`.
Discovery uses page numbers instead: `?page=1&limit=20` →
`meta: { page, limit, total, hasMore }`.

### Error codes

| Code | Status | Meaning |
| --- | --- | --- |
| `VALIDATION_ERROR` | 422 | One or more fields are invalid; see `details`. |
| `BAD_REQUEST` | 400 | The request itself does not make sense. |
| `UNAUTHORIZED` | 401 | Missing, invalid or expired access token. |
| `FORBIDDEN` | 403 | Authenticated, but not allowed to do this. |
| `NOT_FOUND` | 404 | No such resource (also returned for blocked users). |
| `ROUTE_NOT_FOUND` | 404 | No such endpoint. |
| `ACCOUNT_EXISTS` | 409 | Registration collided with an existing account. |
| `ALREADY_EXISTS` | 409 | Unique constraint violated. |
| `INVITATION_PENDING` | 409 | A live invitation already exists for that pair. |
| `ALREADY_CONNECTED` | 409 | You already have a chat with this person. |
| `INVITATION_SETTLED` | 409 | The invitation has already been answered. |
| `ACTIVITY_CLOSED` | 409 | The plan is no longer open. |
| `ALREADY_BLOCKED` | 409 | You have already blocked this person. |
| `RATE_LIMITED` | 429 | Too many requests. |
| `INTERNAL_ERROR` | 500 | Something failed on our side. |

---

## Health

### `GET /health`
No auth.

```jsonc
{ "status": "ok", "database": true, "redis": false, "uptime": 42, "timestamp": "…" }
```

`status` is `degraded` when the database is unreachable. Redis being `false` is
not an error — it is an accelerator, and every call site degrades gracefully.

---

## Auth — `/api/auth`

All routes below are unauthenticated and limited to **20 requests/minute**.

### `POST /api/auth/register` → `201`

```jsonc
{ "email": "you@example.com", "password": "Password123" }
// or { "phone": "+919000000001", "password": "Password123" }
```

At least one of `email` / `phone` is required. Passwords need 8+ characters
with a letter and a number.

Response — an `AuthSession`:

```jsonc
{
  "data": {
    "accessToken": "eyJhbGciOi…",
    "refreshToken": "R0nd0m…",
    "expiresIn": "15m",
    "user": { /* Me, see below — isProfileComplete is false here */ }
  }
}
```

Errors: `422 VALIDATION_ERROR`, `409 ACCOUNT_EXISTS`.

### `POST /api/auth/login` → `200`

Same body as register (minus the rules), same `AuthSession` response.
Errors: `401 UNAUTHORIZED` (deliberately identical for "no such user" and
"wrong password" — no account enumeration), `422`.

### `POST /api/auth/refresh` → `200`

```jsonc
{ "refreshToken": "…" }
```

Returns a fresh `AuthSession`. The submitted refresh token is revoked.
Errors: `401 UNAUTHORIZED` for unknown, revoked or expired tokens.

### `POST /api/auth/logout` → `200`

```jsonc
{ "refreshToken": "…" }   →   { "data": { "success": true } }
```

### `POST /api/auth/otp/request` → `200`

```jsonc
{ "phone": "+919000000001" }
```

**Stubbed.** Outside production the response includes the fixed development
code so the client flow is exercisable offline:

```jsonc
{ "data": { "sent": true, "devCode": "123456" } }
```

### `POST /api/auth/otp/verify` → `200`

```jsonc
{ "phone": "+919000000001", "code": "123456" }
```

Returns an `AuthSession`. Errors: `401` (wrong code), `404` (no such account).

---

## Catalog — `/api/catalog`

### `GET /api/catalog/interests`
No auth. Used by profile setup before a profile exists.

```jsonc
{ "data": { "items": [ { "slug": "indie-films", "label": "Indie films", "emoji": "🎞" } ] } }
```

---

## Users and profiles — `/api/users`

All routes require authentication.

### `GET /api/users/me` → `200`

Returns **Me** — the public profile plus owner-only fields:

```jsonc
{
  "data": {
    "id": "clx…",
    "displayName": "Nitish",
    "age": 28,
    "gender": "MALE",
    "bio": "New in the neighbourhood…",
    "occupation": "Software engineer",
    "city": "Bengaluru",
    "area": "Indiranagar",
    "avatarUrl": "https://…",
    "photos": ["https://…"],
    "interests": [ { "slug": "…", "label": "…", "emoji": "…" } ],
    "preferredActivities": ["MOVIE", "DINNER"],
    "availability": ["TONIGHT", "WEEKEND"],
    "verification": "VERIFIED",
    "rating": { "average": 4.8, "count": 11 },
    "distanceKm": null,
    "isOnline": true,
    "lastActiveAt": "2026-08-31T06:29:00.000Z",

    "email": "demo@companion.app",
    "phone": null,
    "birthDate": "1998-03-14T00:00:00.000Z",
    "latitude": 12.9784,
    "longitude": 77.6408,
    "isDiscoverable": true,
    "showDistance": true,
    "showAge": true,
    "isProfileComplete": true,
    "createdAt": "2026-08-01T…"
  }
}
```

### `POST /api/users/me/profile` → `201`

Creates (or overwrites) the whole profile. Sent once at the end of setup, so a
half-finished flow never leaves a partial row.

```jsonc
{
  "displayName": "Nitish",
  "birthDate": "1998-03-14",              // or a full ISO instant; 18–99 enforced
  "gender": "MALE",                       // MALE | FEMALE | NON_BINARY | OTHER
  "bio": "…",                             // ≤ 500 chars
  "occupation": "Software engineer",      // optional
  "city": "Bengaluru",
  "area": "Indiranagar",                  // optional
  "latitude": 12.9784,
  "longitude": 77.6408,
  "avatarUrl": "https://…",               // optional
  "photos": ["https://…"],                // ≤ 6
  "interests": ["indie-films", "running"],// ≤ 12 slugs; unknown slugs are created
  "preferredActivities": ["MOVIE", "COFFEE"],
  "availability": ["TONIGHT", "WEEKEND"]  // ≤ 5
}
```

Returns **Me**. Errors: `422 VALIDATION_ERROR`.

### `PUT /api/users/me` → `200`

Partial update — every field of the create body is optional, plus
`isDiscoverable`, `showDistance`, `showAge`. **Omitting a field leaves it
alone**; it is never cleared by omission. Returns **Me**.

### `POST /api/users/me/photo` → `201`

The raw image is the request body, with `Content-Type: image/jpeg`, `image/png`
or `image/webp`. The limit is 5 MB, and 20 uploads a minute.

```jsonc
{ "data": { "url": "https://…/media/photos/clx…" } }
```

The photo becomes the person's picture once that URL is saved as `avatarUrl`.
Each new upload removes older photos, except the one the profile is using.

Errors: `413 TOO_LARGE`, `415 UNSUPPORTED_MEDIA_TYPE` (wrong header),
`415 UNSUPPORTED_IMAGE` (the file's contents are not one of those types).

### `GET /media/photos/:id` → `200`

The image itself. Needs no session, and is safe to cache permanently.

### `GET /api/users/:id` → `200`

A public profile (same shape as Me, minus the owner-only fields). `distanceKm`
is computed from the viewer's own coordinates and is `null` when the target has
`showDistance` off; `age` is `null` when they have `showAge` off.

`connection` says how the viewer stands with them: `null`,
`{ "status": "INVITED_BY_ME" }`, `{ "status": "INVITED_ME" }` or
`{ "status": "CONNECTED", "conversationId": "clx…" }`. Anyone with a live
invitation or chat is also left out of `GET /api/discover/people`.

Errors: `404 NOT_FOUND` — also returned when either party has blocked the
other, so a block is indistinguishable from a deleted account.

---

## Discovery — `/api/discover`

All routes require authentication and a completed profile.

### `GET /api/discover` → `200`

Everything the home screen renders, in one round-trip.

```jsonc
{
  "data": {
    "greeting": "EVENING",             // MORNING | AFTERNOON | EVENING
    "city": "Bengaluru",
    "categories": [ { "category": "MOVIE", "openActivities": 3, "people": 6 } ],
    "peopleNearby": [ /* PublicProfile[] */ ],
    "activitiesNearby": [ /* Activity[] */ ],
    "tonight": [ /* Activity[] starting before midnight */ ],
    "pendingInvitations": 4,
    "unreadMessages": 1
  }
}
```

### `GET /api/discover/people` → `200`

| Query | Type | Default | Notes |
| --- | --- | --- | --- |
| `activities` | CSV of `ActivityCategory` | — | Matches if they want **any** of these |
| `availability` | CSV of `AvailabilitySlot` | — | Any-of |
| `genders` | CSV of `Gender` | — | Any-of |
| `interests` | CSV of interest slugs | — | Any-of |
| `minAge` / `maxAge` | int 18–99 | 18 / 99 | |
| `radiusKm` | number 1–200 | 25 | |
| `query` | string ≤ 60 | — | Name, bio or area, case-insensitive |
| `page` / `limit` | int | 1 / 20 | `limit` ≤ 50 |

Results exclude you, anyone blocked in either direction, incomplete profiles,
and anyone with discovery switched off.

Ranking is deliberately legible: shared activities (×14) + shared interests
(×9) + shared availability (×6) + proximity + recent activity. No black box.

```jsonc
{ "data": [ /* PublicProfile[] */ ],
  "meta": { "page": 1, "limit": 20, "total": 34, "hasMore": true } }
```

### `GET /api/discover/activities` → `200`

Same query parameters, plus `from` and `to` (ISO instants) to window the start
time. Defaults to "from now". Returns `Activity[]` ordered by start time.

---

## Activities — `/api/activities`

All routes require authentication.

### `POST /api/activities` → `201`
Limited to 30/hour.

```jsonc
{
  "category": "MOVIE",
  "title": "The late show at PVR Orion",   // 3–80 chars
  "description": "…",                      // ≤ 600
  "startsAt": "2026-09-01T16:10:00.000Z",  // must be in the future
  "endsAt": null,                          // optional, must be after startsAt
  "locationName": "PVR Orion Mall",        // 2–120 chars
  "area": "Rajajinagar",
  "city": "Bengaluru",
  "latitude": 12.9982,
  "longitude": 77.5525,
  "lookingFor": "ANYONE",                  // ANYONE | MALE | FEMALE
  "minAge": 18, "maxAge": 99,              // minAge ≤ maxAge
  "capacity": 1                            // 1–10
}
```

Returns an **Activity**:

```jsonc
{
  "data": {
    "id": "clx…", "category": "MOVIE", "title": "…", "description": "…",
    "startsAt": "…", "endsAt": null,
    "locationName": "…", "area": "…", "city": "…",
    "lookingFor": "ANYONE", "minAge": 18, "maxAge": 99, "capacity": 1,
    "status": "OPEN",                       // OPEN | CONFIRMED | CANCELLED | COMPLETED
    "createdAt": "…",
    "host": { /* PublicProfile */ },
    "participantCount": 1,
    "distanceKm": 6.1,
    "isHost": true,
    "viewerInvitationStatus": null          // your own request's status, if any
  }
}
```

### `GET /api/activities` → `200`

`?scope=mine|joined|all` (default `mine`), `?status=`, `?cursor=`, `?limit=`.
Returns `Activity[]` with `meta: { nextCursor, hasMore }`.

### `GET /api/activities/:id` → `200`
Returns one **Activity**. `404` if it does not exist or its host is blocked.

### `DELETE /api/activities/:id` → `200`

Cancels the plan (soft — the row stays) and withdraws every pending invitation
to it.

```jsonc
{ "data": { "id": "clx…", "status": "CANCELLED" } }
```

Errors: `403 FORBIDDEN` unless you are the host.

---

## Invitations — `/api/invitations`

All routes require authentication.

### `POST /api/invitations` → `201`
Limited to 60/hour, and to 25 per rolling day per sender.

Two shapes. Invite someone to a **posted plan**:

```jsonc
{ "recipientId": "clx…", "activityId": "clx…", "message": "Saw you like films — 8:30?" }
```

…or **propose something** directly:

```jsonc
{
  "recipientId": "clx…",
  "category": "COFFEE",
  "proposedAt": "2026-09-01T12:30:00.000Z",
  "locationName": "Blue Tokai, 12th Main",
  "message": "…"                            // ≤ 500
}
```

One of `activityId` / `category` is required. Returns an **Invitation**:

```jsonc
{
  "data": {
    "id": "clx…",
    "direction": "sent",                    // relative to the caller
    "status": "PENDING",                    // PENDING|ACCEPTED|DECLINED|CANCELLED|EXPIRED
    "message": "…",
    "category": "MOVIE",
    "proposedAt": "…", "locationName": "…",
    "createdAt": "…", "respondedAt": null,
    "counterpart": { /* PublicProfile — the other person, whichever side you are */ },
    "activity": { /* Activity | null */ },
    "conversationId": null                  // set once accepted
  }
}
```

Errors: `400` (inviting yourself), `403 FORBIDDEN` (blocked either way),
`404` (no such recipient/activity), `409 INVITATION_PENDING` (one is already
live for that pair), `409 ACTIVITY_CLOSED`, `429` (daily quota).

### `GET /api/invitations/received` · `GET /api/invitations/sent` → `200`

`?status=`, `?cursor=`, `?limit=`. Returns `Invitation[]` newest-first with
`meta: { nextCursor, hasMore }`. Reading either list also settles anything
that has aged past 72 hours to `EXPIRED`.

### `GET /api/invitations/counts` → `200`

```jsonc
{ "data": { "pendingReceived": 4, "pendingSent": 1, "accepted": 6 } }
```

### `GET /api/invitations/:id` → `200`
Returns one **Invitation**. `403` if you are neither party.

### `POST /api/invitations/:id/accept` → `200`

The product's one real state transition. Atomically: marks the invitation
accepted, adds you to the activity's participants, creates the conversation
with both people in it, and seeds a `SYSTEM` message carrying the plan — so
the chat never opens empty. Notifies and pushes to the sender.

Returns the updated **Invitation**, now with `conversationId`.

Errors: `403` (only the recipient may accept), `409 INVITATION_SETTLED`.

### `POST /api/invitations/:id/decline` → `200`
Recipient only. Returns the updated **Invitation**.

### `POST /api/invitations/:id/cancel` → `200`
Sender only, withdraws a pending invitation. Returns the updated **Invitation**.

---

## Conversations and messages — `/api/conversations`

All routes require authentication, and every one checks membership first.

### `GET /api/conversations` → `200`

The inbox, newest activity first. Unread counts come from one grouped query,
not one query per row.

```jsonc
{
  "data": [
    {
      "id": "clx…",
      "lastMessageAt": "…",
      "lastMessagePreview": "Changed my mind on the order…",
      "unreadCount": 2,
      "participant": { /* PublicProfile — the other person */ },
      "activity": {
        "id": "clx…", "category": "DINNER",
        "title": "Thursday biryani crawl",
        "startsAt": "…", "locationName": "Mosque Road"
      }
    }
  ]
}
```

### `GET /api/conversations/:id` → `200`
One conversation, same shape.

### `GET /api/conversations/:id/messages` → `200`

`?cursor=&limit=` (default 30, max 50). **Newest first**, so the client renders
a reversed list and pages backwards without disturbing scroll position.

```jsonc
{
  "data": [
    {
      "id": "clx…", "conversationId": "clx…", "senderId": "clx…",
      "body": "Which theatre?",
      "type": "TEXT",                      // TEXT | SYSTEM
      "createdAt": "…", "readAt": null,
      "isMine": false
    }
  ],
  "meta": { "nextCursor": "clx…", "hasMore": true }
}
```

### `POST /api/conversations/:id/messages` → `201`
Limited to 120/minute.

```jsonc
{ "body": "Yes! Which theatre?" }   // 1–2000 chars
```

Returns the created **Message**, pushes `message:new` to the other party over
the socket, and raises a notification only if they are **not** currently
connected.

Errors: `403 FORBIDDEN` (not a member, or blocked since the chat opened).

### `POST /api/conversations/:id/read` → `200`

```jsonc
{ "data": { "readCount": 2 } }
```

Marks every inbound message read and pushes `message:read` to the other party.

---

## Notifications — `/api/notifications`

### `GET /api/notifications` → `200`
`?cursor=&limit=&unreadOnly=true|false`.

```jsonc
{
  "data": [
    {
      "id": "clx…",
      "type": "INVITATION_RECEIVED",
      "title": "Sara Mehta invited you",
      "body": "The late show at PVR Orion · Tonight, 9:40 PM",
      "data": { "invitationId": "clx…", "senderId": "clx…" },
      "readAt": null,
      "createdAt": "…"
    }
  ],
  "meta": { "nextCursor": null, "hasMore": false, "unreadCount": 5 }
}
```

`type` is one of `INVITATION_RECEIVED`, `INVITATION_ACCEPTED`,
`INVITATION_DECLINED`, `MESSAGE_RECEIVED`, `ACTIVITY_REMINDER`, `SYSTEM`.

### `POST /api/notifications/:id/read` → `200`
### `POST /api/notifications/read-all` → `200` → `{ "data": { "updated": 5 } }`

Notifications are persisted server-side, so this list is the record of truth.
APNs/FCM delivery is a transport that plugs in behind `notify()` without
changing anything here.

---

## Safety — `/api/safety`

### `GET /api/safety/report-reasons` → `200`
```jsonc
{ "data": { "reasons": ["INAPPROPRIATE_MESSAGES", "FAKE_PROFILE", "HARASSMENT",
  "INAPPROPRIATE_PHOTOS", "SCAM_OR_SPAM", "UNDERAGE", "SAFETY_CONCERN", "OTHER"] } }
```

### `POST /api/safety/users/:id/block` → `200`

```jsonc
{ "reason": "optional, ≤ 280 chars" }   →   { "data": { "blocked": true } }
```

Blocking is **symmetric for visibility**: afterwards neither person appears in
the other's discovery, invitations or conversations, and any pending
invitation between them is cancelled. The blocked person is never told.

Errors: `400` (blocking yourself), `404`, `409 ALREADY_BLOCKED`.

### `DELETE /api/safety/users/:id/block` → `200` → `{ "data": { "blocked": false } }`

### `GET /api/safety/blocks` → `200`
```jsonc
{ "data": { "items": [ { "id": "clx…", "displayName": "…", "avatarUrl": "…", "blockedAt": "…" } ] } }
```

### `POST /api/safety/users/:id/report` → `201`
Limited to 10/hour.

```jsonc
{ "reason": "FAKE_PROFILE", "details": "Photos look reused." }   // details ≤ 1000
```

```jsonc
{ "data": { "id": "clx…", "submittedAt": "…",
  "message": "Thanks for letting us know. Our team will review this within 24 hours." } }
```

---

## Realtime — `GET /ws`

A single multiplexed socket per device.

```
ws://localhost:4000/ws?token=<accessToken>
```

The token travels as a query parameter because browsers and mobile clients
cannot set headers on a WebSocket handshake; it is verified with the same key
and rules as a bearer token. A bad token gets one `error` frame and close code
`4401`.

**Server → client frames** — always `{ type, conversationId, payload }`:

| `type` | `conversationId` | `payload` |
| --- | --- | --- |
| `connected` | `null` | `{ userId }` |
| `ping` | `null` | `null` — every 30s, also refreshes presence |
| `message:new` | the thread | a **Message** (`isMine` is always `false` here) |
| `message:read` | the thread | `{ readerId, readAt }` |
| `typing` | the thread | `{ userId, isTyping }` |
| `invitation:new` | `null` | an **Invitation** |
| `invitation:updated` | `null` | an **Invitation** |
| `notification` | `null` | a **Notification** |

**Client → server frames:**

```jsonc
{ "type": "ping" }
{ "type": "typing", "conversationId": "clx…", "isTyping": true }
```

Realtime is strictly an enhancement — everything it delivers is also reachable
over REST, so a dropped socket degrades to polling and pull-to-refresh rather
than breaking a screen. The client reconnects with capped exponential backoff.

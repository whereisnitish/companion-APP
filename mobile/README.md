# Companion — mobile

Flutter client for Companion. Riverpod for state, go_router for navigation, Dio
for HTTP, `web_socket_channel` for realtime.

---

## Setup

The `ios/` and `android/` folders are generated, not checked in. Create them
once:

```bash
./tool/setup.sh
```

That runs `flutter create --no-overwrite` with the project's own name and org,
restores the hand-written `pubspec.yaml` afterwards, adds the iOS local-network
usage key, drops the stock counter test that `flutter create` insists on
re-adding, and fetches packages. It is safe to re-run at any time.

---

## Running

```bash
flutter run                                                    # guesses the host
flutter run --dart-define=API_BASE_URL=http://localhost:4000   # iOS simulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000    # Android emulator
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:4000  # physical device
```

Configuration is compile-time — `String.fromEnvironment`, so there is no `.env`
to forget. With no override, [`app_config.dart`](lib/core/config/app_config.dart)
picks `10.0.2.2` on Android and `localhost` everywhere else, and derives the
WebSocket URL from whichever host wins.

### Reaching the API from a physical device

`localhost` on a phone means the phone. Pass your machine's LAN address, and
make sure both are on the same Wi-Fi:

```bash
ipconfig getifaddr en0        # macOS: your LAN IP
```

The iOS `NSLocalNetworkUsageDescription` key is added by `tool/setup.sh` — iOS
otherwise refuses LAN connections silently, with no error the app can see. A
physical Android device additionally needs cleartext HTTP allowed for local
development, or point `API_BASE_URL` at an HTTPS tunnel.

---

## Checks

```bash
flutter analyze     # 0 issues
flutter test        # 136 tests
```

| Suite | What it proves |
| --- | --- |
| `formatters_test.dart` | Dates, distances and relative times — including the midnight boundary |
| `models_test.dart` | JSON parsing survives missing fields and unknown enum values |
| `design_system_test.dart` | Both palettes define every token distinctly; every button variant, chip and input behaves |
| `cards_test.dart` | Person and activity cards across all 12 categories, empty fields and 600-character bios |
| `screens_test.dart` | Splash, Home, Invitations, Messages and Chat — loading, empty and populated states against a mocked API |
| `layout_resilience_test.dart` | Every screen at 3 device sizes, at 1.3× text scale and in dark mode |

That last suite is the one that keeps the product feeling finished: it fails the
build if a single row overflows at any supported size.

---

## Layout

```
lib/
├── core/
│   ├── config/app_config.dart        build-time host resolution
│   ├── network/                      Dio wrapper, single-flight 401 refresh
│   ├── realtime/socket_client.dart   WebSocket with capped backoff
│   ├── storage/token_storage.dart    flutter_secure_storage
│   └── utils/                        formatters, locations
├── theme/                            the design system (ThemeExtension)
├── models/                           plain Dart, hand-written parsing
├── services/                         one per API domain
├── providers/                        Riverpod: auth, chat, feed, core
├── routing/app_router.dart           go_router + the auth gate
├── widgets/                          15 shared widgets
├── features/
│   ├── onboarding/  auth/  profile_setup/
│   ├── home/  discover/  activities/
│   ├── invitations/  chat/  notifications/
│   └── profile/  settings/  shell/
├── app.dart
└── main.dart
```

**No code generation.** No `build_runner`, no `.g.dart`. Every model writes its
own `fromJson`, which means a malformed field fails where you can read it rather
than inside generated code.

**Every endpoint returns `{ data, meta? }`.** `ApiClient` unwraps the envelope
and, on a 401, refreshes the session once and replays the request — coalescing
concurrent refreshes so ten simultaneous failures cause one refresh call.

**Realtime is an enhancement.** Everything the socket delivers is also reachable
over REST, so a dropped connection degrades to pull-to-refresh.

---

## Design system

Everything visual comes from `lib/theme/`. No screen invents a colour, a size or
a duration.

| File | Contents |
| --- | --- |
| `app_colors.dart` | 25 semantic colours × light and dark |
| `app_typography.dart` | 13 styles across two faces (Fraunces + Inter) |
| `app_spacing.dart` | Spacing (2→56), radii (8→pill), motion (90ms→520ms, 3 curves) |
| `app_shadows.dart` | Three elevations, all ≤ 5% opacity |
| `app_theme.dart` | Binds the tokens to `ThemeData` via a `ThemeExtension` |

Reach them with the `context.colors` / `context.type` extensions — two
`ThemeExtension`s (`AppColors`, `AppTypography`) registered on both `ThemeData`s.

---

## Signing in

The backend seed creates a fully populated account:

```
demo@companion.app  /  Password123
```

The sign-in screen has a one-tap button for it. Every seeded account shares that
password, so you can sign in as `sara.mehta@example.com` in a second simulator
and watch invitations and messages arrive live.

import 'package:companion/core/network/api_client.dart';
import 'package:companion/core/storage/token_storage.dart';
import 'package:companion/features/invitations/invitations_screen.dart';
import 'package:companion/models/enums.dart';
import 'package:companion/models/home_feed.dart';
import 'package:companion/models/invitation.dart';
import 'package:companion/models/profile.dart';
import 'package:companion/providers/auth_provider.dart';
import 'package:companion/providers/core_providers.dart';
import 'package:companion/providers/feed_providers.dart';
import 'package:companion/services/auth_service.dart';
import 'package:companion/services/discovery_service.dart';
import 'package:companion/services/invitation_service.dart';
import 'package:companion/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

ApiClient _unusedClient() => ApiClient(tokenStorage: TokenStorage());

/// Keeps tokens in memory; the real one needs the platform keychain.
class _MemoryTokens extends TokenStorage {
  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<String?> readRefreshToken() async => _tokens?.refreshToken;

  @override
  Future<void> save(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}

class _FakeAuth extends AuthService {
  _FakeAuth() : super(_unusedClient());

  @override
  Future<AuthSession> login({String? email, String? phone, required String password}) async =>
      AuthSession(
        tokens: AuthTokens(accessToken: '', refreshToken: 'refresh-$email'),
        user: CurrentUser.fromJson(<String, dynamic>{
          'id': email,
          'displayName': email,
          'isProfileComplete': true,
        }),
      );

  @override
  Future<void> logout(String refreshToken) async {}
}

/// Answers with whoever is signed in, as the server would.
class _FakeDiscovery extends DiscoveryService {
  _FakeDiscovery(this.currentCity) : super(_unusedClient());

  final String Function() currentCity;

  @override
  Future<HomeFeed> fetchHomeFeed() async => HomeFeed(
        greeting: Greeting.evening,
        city: currentCity(),
        categories: const <CategoryCount>[],
        peopleNearby: const <Profile>[],
        activitiesNearby: const [],
        tonight: const [],
        pendingInvitations: 0,
        unreadMessages: 0,
      );
}

class _FakeInvitations extends InvitationService {
  _FakeInvitations(this.accepted) : super(_unusedClient());

  final Invitation accepted;

  @override
  Future<Invitation> accept(String id) async => accepted;
}

Invitation _invitation({required InvitationStatus status, String? conversationId}) => Invitation(
      id: 'i1',
      direction: InvitationDirection.received,
      status: status,
      message: 'hello',
      category: ActivityCategory.coffee,
      proposedAt: null,
      locationName: null,
      createdAt: DateTime(2026, 11, 7),
      respondedAt: null,
      counterpart: makeProfile(),
      activity: null,
      conversationId: conversationId,
    );

void main() {
  test('signing in as someone else never shows the previous account\'s data', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String signedInAs = 'first';
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStorageProvider.overrideWithValue(_MemoryTokens()),
        authServiceProvider.overrideWithValue(_FakeAuth()),
        discoveryServiceProvider.overrideWithValue(_FakeDiscovery(() => signedInAs)),
      ],
    );
    addTearDown(container.dispose);

    final AuthController auth = container.read(authControllerProvider.notifier);
    await pumpEventQueue();

    await auth.login(email: 'first', password: 'x');
    expect((await container.read(homeFeedProvider.future)).city, 'first');

    await auth.signOut();
    signedInAs = 'second';
    await auth.login(email: 'second', password: 'x');

    expect((await container.read(homeFeedProvider.future)).city, 'second');
  });

  testWidgets('Say hello opens the chat once the accepted card has moved', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool accepted = false;
    final Invitation done = _invitation(status: InvitationStatus.accepted, conversationId: 'c1');
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, __) => const InvitationsScreen()),
        GoRoute(
          path: '/chat/:id',
          builder: (_, GoRouterState state) =>
              Scaffold(body: Text('chat ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          invitationServiceProvider.overrideWithValue(_FakeInvitations(done)),
          receivedInvitationsProvider.overrideWith(
            (Ref ref) async => <Invitation>[
              if (accepted) done else _invitation(status: InvitationStatus.pending),
            ],
          ),
          sentInvitationsProvider.overrideWith((Ref ref) async => const <Invitation>[]),
          invitationCountsProvider.overrideWith((Ref ref) async => InvitationCounts.empty),
          homeFeedProvider.overrideWith((Ref ref) => Future<HomeFeed>.value(
                const HomeFeed(
                  greeting: Greeting.evening,
                  city: '',
                  categories: <CategoryCount>[],
                  peopleNearby: <Profile>[],
                  activitiesNearby: [],
                  tonight: [],
                  pendingInvitations: 0,
                  unreadMessages: 0,
                ),
              )),
          conversationsProvider.overrideWith((Ref ref) async => const []),
        ],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    accepted = true;
    await tester.tap(find.text('Accept'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // By now the list has refreshed and the original card is gone.
    await tester.tap(find.text('Say hello'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('chat c1'), findsOneWidget);
  });
}

import 'package:companion/features/auth/sign_in_screen.dart';
import 'package:companion/features/auth/sign_up_screen.dart';
import 'package:companion/features/auth/welcome_screen.dart';
import 'package:companion/features/chat/conversations_screen.dart';
import 'package:companion/features/discover/discover_screen.dart';
import 'package:companion/features/home/home_screen.dart';
import 'package:companion/features/invitations/invitations_screen.dart';
import 'package:companion/features/onboarding/onboarding_screen.dart';
import 'package:companion/features/profile_setup/profile_setup_screen.dart';
import 'package:companion/features/settings/guidelines_screen.dart';
import 'package:companion/features/settings/safety_screen.dart';
import 'package:companion/models/activity.dart';
import 'package:companion/models/app_notification.dart';
import 'package:companion/models/conversation.dart';
import 'package:companion/models/enums.dart';
import 'package:companion/models/home_feed.dart';
import 'package:companion/models/invitation.dart';
import 'package:companion/models/profile.dart';
import 'package:companion/providers/auth_provider.dart';
import 'package:companion/providers/feed_providers.dart';
import 'package:companion/services/notification_service.dart';
import 'package:companion/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// The screen sizes worth caring about: a small phone that is still in the
/// wild, a modern phone, and a large one.
const Map<String, Size> _devices = <String, Size>{
  'small phone (320×568)': Size(320, 568),
  'modern phone (390×844)': Size(390, 844),
  'large phone (430×932)': Size(430, 932),
};

Future<void> _pumpAt(
  WidgetTester tester,
  Widget screen,
  Size size, {
  List<Override> overrides = const <Override>[],
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            devicePixelRatio: 3,
            textScaler: TextScaler.linear(textScale),
          ),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 900));
}

List<Override> _dataOverrides() => <Override>[
      currentUserProvider.overrideWithValue(
        CurrentUser.fromJson(<String, dynamic>{
          'id': 'u0',
          'displayName': 'Nitish',
          'age': 28,
          'city': 'Bengaluru',
          'area': 'Indiranagar',
          'isProfileComplete': true,
        }),
      ),
      homeFeedProvider.overrideWith(
        (Ref ref) async => HomeFeed(
          greeting: Greeting.evening,
          city: 'Bengaluru',
          categories: const <CategoryCount>[
            CategoryCount(category: ActivityCategory.movie, openActivities: 5, people: 3),
          ],
          peopleNearby: <Profile>[makeProfile(), makeProfile(id: 'u2', name: 'Ananya Bose')],
          activitiesNearby: <Activity>[makeActivity()],
          tonight: <Activity>[makeActivity(id: 'a9')],
          pendingInvitations: 4,
          unreadMessages: 1,
        ),
      ),
      notificationsProvider.overrideWith(
        (Ref ref) async => const NotificationPage(items: <AppNotification>[], unreadCount: 2),
      ),
      discoverPeopleProvider.overrideWith((Ref ref) async => <Profile>[makeProfile()]),
      discoverActivitiesProvider.overrideWith((Ref ref) async => <Activity>[makeActivity()]),
      receivedInvitationsProvider.overrideWith((Ref ref) async => <Invitation>[makeInvitation()]),
      sentInvitationsProvider.overrideWith(
        (Ref ref) async => <Invitation>[makeInvitation(direction: 'sent')],
      ),
      invitationCountsProvider.overrideWith(
        (Ref ref) async => const InvitationCounts(pendingReceived: 1, pendingSent: 1, accepted: 2),
      ),
      conversationsProvider.overrideWith((Ref ref) async => <Conversation>[makeConversation()]),
      interestCatalogProvider.overrideWith(
        (Ref ref) async => <Interest>[
          const Interest(slug: 'indie-films', label: 'Indie films', emoji: '🎞'),
          const Interest(slug: 'running', label: 'Running', emoji: '🏃'),
        ],
      ),
    ];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  final Map<String, Widget Function()> screens = <String, Widget Function()>{
    'Welcome': () => const WelcomeScreen(),
    'Onboarding': () => const OnboardingScreen(),
    'Sign in': () => const SignInScreen(),
    'Sign up': () => const SignUpScreen(),
    'Profile setup': () => const ProfileSetupScreen(),
    'Home': () => const HomeScreen(),
    'Discover': () => const DiscoverScreen(),
    'Invitations': () => const InvitationsScreen(),
    'Messages': () => const ConversationsScreen(),
    'Safety centre': () => const SafetyScreen(),
    'Guidelines': () => const GuidelinesScreen(),
  };

  group('no screen overflows at any supported size', () {
    for (final MapEntry<String, Size> device in _devices.entries) {
      for (final MapEntry<String, Widget Function()> screen in screens.entries) {
        testWidgets('${screen.key} — ${device.key}', (WidgetTester tester) async {
          await _pumpAt(
            tester,
            screen.value(),
            device.value,
            overrides: _dataOverrides(),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('no screen overflows at the maximum supported text scale', () {
    // The app clamps accessibility scaling at 1.3; that ceiling must hold.
    for (final MapEntry<String, Widget Function()> screen in screens.entries) {
      testWidgets('${screen.key} — 1.3× text', (WidgetTester tester) async {
        await _pumpAt(
          tester,
          screen.value(),
          const Size(390, 844),
          overrides: _dataOverrides(),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('every screen renders in dark mode', () {
    for (final MapEntry<String, Widget Function()> screen in screens.entries) {
      testWidgets('${screen.key} — dark', (WidgetTester tester) async {
        await _pumpAt(
          tester,
          screen.value(),
          const Size(390, 844),
          overrides: _dataOverrides(),
          brightness: Brightness.dark,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}

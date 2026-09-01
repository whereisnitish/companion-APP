import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activities/activity_detail_screen.dart';
import '../features/activities/create_activity_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/sign_up_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/chat/conversations_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/discover/person_profile_screen.dart';
import '../features/home/home_screen.dart';
import '../features/invitations/invitations_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/my_profile_screen.dart';
import '../features/profile_setup/profile_setup_screen.dart';
import '../features/settings/blocked_users_screen.dart';
import '../features/settings/guidelines_screen.dart';
import '../features/settings/privacy_screen.dart';
import '../features/settings/safety_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../providers/auth_provider.dart';

abstract final class Routes {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String profileSetup = '/profile-setup';

  static const String home = '/home';
  static const String discover = '/discover';
  static const String invites = '/invites';
  static const String messages = '/messages';
  static const String me = '/me';

  static const String notifications = '/notifications';
  static const String createActivity = '/activity/new';
  static const String editProfile = '/me/edit';
  static const String settings = '/settings';
  static const String privacy = '/settings/privacy';
  static const String safety = '/settings/safety';
  static const String guidelines = '/settings/guidelines';
  static const String blocked = '/settings/blocked';

  static String person(String id) => '/person/$id';
  static String activity(String id) => '/activity/$id';
  static String chat(String id) => '/chat/$id';
}

/// Bridges Riverpod's auth state to go-router's imperative refresh.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (AuthState? _, AuthState __) {
      notifyListeners();
    });
  }
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final _AuthRefreshNotifier refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final AuthStage stage = ref.read(authControllerProvider).stage;
      final String location = state.matchedLocation;

      const Set<String> publicRoutes = <String>{
        Routes.splash,
        Routes.onboarding,
        Routes.welcome,
        Routes.signIn,
        Routes.signUp,
      };
      final bool isPublic = publicRoutes.contains(location);

      switch (stage) {
        case AuthStage.loading:
          return location == Routes.splash ? null : Routes.splash;

        case AuthStage.onboarding:
          return location == Routes.onboarding ? null : Routes.onboarding;

        case AuthStage.signedOut:
          // Let people move freely between welcome / sign-in / sign-up.
          if (location == Routes.signIn || location == Routes.signUp) return null;
          return location == Routes.welcome ? null : Routes.welcome;

        case AuthStage.needsProfile:
          return location == Routes.profileSetup ? null : Routes.profileSetup;

        case AuthStage.ready:
          if (isPublic || location == Routes.profileSetup) return Routes.home;
          return null;
      }
    },
    routes: <RouteBase>[
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: Routes.welcome, builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: Routes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, __) => const SignUpScreen()),
      GoRoute(path: Routes.profileSetup, builder: (_, __) => const ProfileSetupScreen()),

      // The five tabs keep independent navigation stacks.
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) =>
            AppShell(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: Routes.discover, builder: (_, __) => const DiscoverScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: Routes.invites, builder: (_, __) => const InvitationsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: Routes.messages, builder: (_, __) => const ConversationsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: Routes.me, builder: (_, __) => const MyProfileScreen()),
            ],
          ),
        ],
      ),

      // Everything below covers the tab bar.
      GoRoute(
        path: '/person/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            PersonProfileScreen(userId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: Routes.createActivity,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const CreateActivityScreen(),
      ),
      GoRoute(
        path: '/activity/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            ActivityDetailScreen(activityId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            ChatScreen(conversationId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: Routes.editProfile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.privacy,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const PrivacyScreen(),
      ),
      GoRoute(
        path: Routes.safety,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SafetyScreen(),
      ),
      GoRoute(
        path: Routes.guidelines,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const GuidelinesScreen(),
      ),
      GoRoute(
        path: Routes.blocked,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const BlockedUsersScreen(),
      ),
    ],
  );
});

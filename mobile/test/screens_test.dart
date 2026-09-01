import 'package:companion/features/chat/chat_screen.dart';
import 'package:companion/features/chat/conversations_screen.dart';
import 'package:companion/features/discover/discover_screen.dart';
import 'package:companion/features/home/home_screen.dart';
import 'package:companion/features/invitations/invitations_screen.dart';
import 'package:companion/features/onboarding/onboarding_screen.dart';
import 'package:companion/features/onboarding/splash_screen.dart';
import 'package:companion/models/activity.dart';
import 'package:companion/models/app_notification.dart';
import 'package:companion/models/conversation.dart';
import 'package:companion/models/enums.dart';
import 'package:companion/models/home_feed.dart';
import 'package:companion/models/invitation.dart';
import 'package:companion/models/profile.dart';
import 'package:companion/providers/auth_provider.dart';
import 'package:companion/providers/chat_provider.dart';
import 'package:companion/providers/core_providers.dart';
import 'package:companion/providers/feed_providers.dart';
import 'package:companion/services/conversation_service.dart';
import 'package:companion/services/notification_service.dart';
import 'package:companion/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Renders a full screen at phone dimensions with its data pre-supplied.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const <Override>[],
  Size size = const Size(390, 844),
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
        theme: AppTheme.light(),
        home: screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 900));
}

CurrentUser get _me => CurrentUser.fromJson(<String, dynamic>{
      'id': 'u0',
      'displayName': 'Nitish',
      'age': 28,
      'city': 'Bengaluru',
      'area': 'Indiranagar',
      'isProfileComplete': true,
      'preferredActivities': <String>['MOVIE', 'DINNER'],
      'availability': <String>['TONIGHT'],
      'rating': <String, dynamic>{'average': 4.8, 'count': 11},
    });

HomeFeed _feed({int pendingInvitations = 4, bool empty = false}) {
  return HomeFeed(
    greeting: Greeting.evening,
    city: 'Bengaluru',
    categories: const <CategoryCount>[
      CategoryCount(category: ActivityCategory.movie, openActivities: 5, people: 3),
      CategoryCount(category: ActivityCategory.dinner, openActivities: 2, people: 4),
    ],
    peopleNearby: empty
        ? const <Profile>[]
        : <Profile>[makeProfile(), makeProfile(id: 'u2', name: 'Ananya Bose')],
    activitiesNearby: empty ? const <Activity>[] : <Activity>[makeActivity()],
    tonight: empty ? const <Activity>[] : <Activity>[makeActivity(id: 'a9')],
    pendingInvitations: pendingInvitations,
    unreadMessages: 1,
  );
}

void main() {
  // ---------------------------------------------------------------- entry

  group('SplashScreen', () {
    testWidgets('draws the mark and the wordmark', (WidgetTester tester) async {
      await pumpScreen(tester, const SplashScreen());
      expect(find.text('Companion'), findsOneWidget);
      expect(find.text('Never do it alone.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('OnboardingScreen', () {
    testWidgets('walks all four pages and ends on Get started', (WidgetTester tester) async {
      await pumpScreen(tester, const OnboardingScreen());

      expect(find.text('Don’t do it alone.'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      for (int page = 0; page < 3; page += 1) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Meet through the thing itself.'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swiping advances the page too', (WidgetTester tester) async {
      await pumpScreen(tester, const OnboardingScreen());
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Post what you’re up for.'), findsOneWidget);
    });
  });

  // ----------------------------------------------------------------- home

  group('HomeScreen', () {
    List<Override> homeOverrides({HomeFeed? feed}) => <Override>[
          currentUserProvider.overrideWithValue(_me),
          homeFeedProvider.overrideWith((Ref ref) async => feed ?? _feed()),
          notificationsProvider.overrideWith(
            (Ref ref) async => const NotificationPage(items: <AppNotification>[], unreadCount: 2),
          ),
        ];

    testWidgets('greets by name and answers "what can I do today?" first',
        (WidgetTester tester) async {
      await pumpScreen(tester, const HomeScreen(), overrides: homeOverrides());

      expect(find.text('Good evening'), findsOneWidget);
      expect(find.text('Nitish'), findsOneWidget);
      expect(find.text('Bengaluru'), findsOneWidget);
      // Categories are the first thing under the greeting.
      expect(find.text('What are you up for?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('surfaces waiting invitations at the top', (WidgetTester tester) async {
      await pumpScreen(tester, const HomeScreen(), overrides: homeOverrides());
      expect(find.text('4 people invited you'), findsOneWidget);
    });

    testWidgets('hides the invitation banner when nothing is waiting', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const HomeScreen(),
        overrides: homeOverrides(feed: _feed(pendingInvitations: 0)),
      );
      expect(find.textContaining('invited you'), findsNothing);
    });

    testWidgets('scrolls through every section without overflowing', (WidgetTester tester) async {
      await pumpScreen(tester, const HomeScreen(), overrides: homeOverrides());

      final Finder scrollable = find.byType(CustomScrollView);
      for (int step = 0; step < 8; step += 1) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull, reason: 'scroll step $step');
      }
      expect(find.text('Create a plan'), findsOneWidget);
    });

    testWidgets('shows a loading silhouette before data arrives', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            currentUserProvider.overrideWithValue(_me),
            homeFeedProvider.overrideWith((Ref ref) async {
              await Future<void>.delayed(const Duration(seconds: 5));
              return _feed();
            }),
            notificationsProvider.overrideWith(
              (Ref ref) async => const NotificationPage(items: <AppNotification>[], unreadCount: 0),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Good evening'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('offers a retry when the feed fails', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const HomeScreen(),
        overrides: <Override>[
          currentUserProvider.overrideWithValue(_me),
          homeFeedProvider.overrideWith((Ref ref) async => throw Exception('boom')),
          notificationsProvider.overrideWith(
            (Ref ref) async => const NotificationPage(items: <AppNotification>[], unreadCount: 0),
          ),
        ],
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------- discover

  group('DiscoverScreen', () {
    testWidgets('lists people and switches to plans', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const DiscoverScreen(),
        overrides: <Override>[
          discoverPeopleProvider.overrideWith(
            (Ref ref) async => <Profile>[makeProfile(), makeProfile(id: 'u2', name: 'Tara Nair')],
          ),
          discoverActivitiesProvider.overrideWith((Ref ref) async => <Activity>[makeActivity()]),
        ],
      );

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Sara Mehta'), findsOneWidget);

      await tester.tap(find.text('Plans'));
      await tester.pumpAndSettle();
      expect(find.text('The late show at PVR Orion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty results offer a way out rather than a blank screen',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const DiscoverScreen(),
        overrides: <Override>[
          discoverPeopleProvider.overrideWith((Ref ref) async => <Profile>[]),
          discoverActivitiesProvider.overrideWith((Ref ref) async => <Activity>[]),
        ],
      );

      expect(find.text('Nobody matches that yet'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------- invitations

  group('InvitationsScreen', () {
    testWidgets('shows received invitations with Accept and Decline on the card',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const InvitationsScreen(),
        overrides: <Override>[
          receivedInvitationsProvider
              .overrideWith((Ref ref) async => <Invitation>[makeInvitation()]),
          sentInvitationsProvider.overrideWith((Ref ref) async => <Invitation>[]),
          invitationCountsProvider.overrideWith(
            (Ref ref) async =>
                const InvitationCounts(pendingReceived: 1, pendingSent: 0, accepted: 3),
          ),
        ],
      );

      expect(find.text('Invitations'), findsOneWidget);
      expect(find.text('1 waiting on your answer.'), findsOneWidget);
      expect(find.text('Sara Mehta'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sent invitations offer Withdraw instead', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const InvitationsScreen(),
        overrides: <Override>[
          receivedInvitationsProvider.overrideWith((Ref ref) async => <Invitation>[]),
          sentInvitationsProvider.overrideWith(
            (Ref ref) async => <Invitation>[makeInvitation(direction: 'sent')],
          ),
          invitationCountsProvider.overrideWith(
            (Ref ref) async =>
                const InvitationCounts(pendingReceived: 0, pendingSent: 1, accepted: 0),
          ),
        ],
      );

      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();
      expect(find.text('Waiting on Sara'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
    });

    testWidgets('an accepted invitation links straight to the chat', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const InvitationsScreen(),
        overrides: <Override>[
          receivedInvitationsProvider.overrideWith(
            (Ref ref) async =>
                <Invitation>[makeInvitation(status: 'ACCEPTED', conversationId: 'c1')],
          ),
          sentInvitationsProvider.overrideWith((Ref ref) async => <Invitation>[]),
          invitationCountsProvider.overrideWith(
            (Ref ref) async =>
                const InvitationCounts(pendingReceived: 0, pendingSent: 0, accepted: 1),
          ),
        ],
      );

      expect(find.text('You are connected'), findsOneWidget);
      expect(find.text('Open chat'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
    });

    testWidgets('an empty inbox explains what would fill it', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const InvitationsScreen(),
        overrides: <Override>[
          receivedInvitationsProvider.overrideWith((Ref ref) async => <Invitation>[]),
          sentInvitationsProvider.overrideWith((Ref ref) async => <Invitation>[]),
          invitationCountsProvider.overrideWith(
            (Ref ref) async => InvitationCounts.empty,
          ),
        ],
      );
      expect(find.text('No invitations yet'), findsOneWidget);
      expect(find.text('Nothing waiting on you right now.'), findsOneWidget);
    });
  });

  // --------------------------------------------------------- conversations

  group('ConversationsScreen', () {
    testWidgets('shows the plan alongside each thread', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ConversationsScreen(),
        overrides: <Override>[
          conversationsProvider.overrideWith((Ref ref) async => <Conversation>[makeConversation()]),
        ],
      );

      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('2 unread messages.'), findsOneWidget);
      expect(find.text('Aisha Khan'), findsOneWidget);
      expect(find.textContaining('Thursday biryani crawl'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('an empty inbox explains where chats come from', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ConversationsScreen(),
        overrides: <Override>[
          conversationsProvider.overrideWith((Ref ref) async => <Conversation>[]),
        ],
      );
      expect(find.text('No conversations yet'), findsOneWidget);
      expect(find.text('All caught up.'), findsOneWidget);
    });
  });

  // ----------------------------------------------------------------- chat

  group('ChatScreen', () {
    testWidgets('renders history, the pinned plan, and sends optimistically',
        (WidgetTester tester) async {
      final FakeConversationService service = FakeConversationService();

      await pumpScreen(
        tester,
        const ChatScreen(conversationId: 'c1'),
        overrides: <Override>[
          conversationServiceProvider.overrideWithValue(service),
          conversationByIdProvider.overrideWith(
            (Ref ref, String id) async => makeConversation(),
          ),
        ],
      );

      // Pinned activity context, so neither person forgets the plan.
      expect(find.textContaining('Thursday biryani crawl'), findsOneWidget);
      expect(find.text('Aisha Khan'), findsOneWidget);
      expect(find.text('Hey! Are you still interested?'), findsOneWidget);
      expect(find.text('Yes! Which theatre?'), findsOneWidget);

      // The system message that seeds the thread renders as a pill, not a bubble.
      expect(find.text('You are both in for the biryani crawl.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'See you at eight');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      // Appears immediately, before the server has answered.
      expect(find.text('See you at eight'), findsOneWidget);
      expect(service.sent, isEmpty);

      await tester.pump(const Duration(milliseconds: 400));
      expect(service.sent.single, 'See you at eight');
      expect(find.text('See you at eight'), findsOneWidget);
    });

    testWidgets('a failed send stays on screen and offers a retry', (WidgetTester tester) async {
      final FakeConversationService service = FakeConversationService(failSend: true);

      await pumpScreen(
        tester,
        const ChatScreen(conversationId: 'c1'),
        overrides: <Override>[
          conversationServiceProvider.overrideWithValue(service),
          conversationByIdProvider.overrideWith(
            (Ref ref, String id) async => makeConversation(),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'Running late');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Running late'), findsOneWidget);
      expect(find.text('Not sent — tap to retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('an empty thread invites the first message', (WidgetTester tester) async {
      final FakeConversationService service = FakeConversationService(empty: true);

      await pumpScreen(
        tester,
        const ChatScreen(conversationId: 'c1'),
        overrides: <Override>[
          conversationServiceProvider.overrideWithValue(service),
          conversationByIdProvider.overrideWith(
            (Ref ref, String id) async => makeConversation(),
          ),
        ],
      );

      expect(find.text('Say the first thing'), findsOneWidget);
    });

    testWidgets('marks the thread read on open', (WidgetTester tester) async {
      final FakeConversationService service = FakeConversationService();

      await pumpScreen(
        tester,
        const ChatScreen(conversationId: 'c1'),
        overrides: <Override>[
          conversationServiceProvider.overrideWithValue(service),
          conversationByIdProvider.overrideWith(
            (Ref ref, String id) async => makeConversation(),
          ),
        ],
      );
      expect(service.readCalls, greaterThanOrEqualTo(1));
    });
  });
}

/// A stand-in for the real service so the chat controller's own logic —
/// optimistic sends, reconciliation, failure handling — is what gets tested.
class FakeConversationService implements ConversationService {
  FakeConversationService({this.failSend = false, this.empty = false});

  final bool failSend;
  final bool empty;
  final List<String> sent = <String>[];
  int readCalls = 0;

  @override
  Future<List<Conversation>> list() async => <Conversation>[makeConversation()];

  @override
  Future<Conversation> fetch(String id) async => makeConversation();

  @override
  Future<MessagePage> messages(String conversationId, {String? cursor, int limit = 30}) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (empty) return const MessagePage(messages: <Message>[], nextCursor: null);

    final DateTime now = DateTime.now();
    return MessagePage(
      // Newest first, as the real endpoint returns them.
      messages: <Message>[
        Message.fromJson(<String, dynamic>{
          'id': 'm3',
          'conversationId': conversationId,
          'senderId': 'u0',
          'body': 'Yes! Which theatre?',
          'type': 'TEXT',
          'createdAt': now.subtract(const Duration(minutes: 3)).toIso8601String(),
          'isMine': true,
        }),
        Message.fromJson(<String, dynamic>{
          'id': 'm2',
          'conversationId': conversationId,
          'senderId': 'u2',
          'body': 'Hey! Are you still interested?',
          'type': 'TEXT',
          'createdAt': now.subtract(const Duration(minutes: 8)).toIso8601String(),
          'isMine': false,
        }),
        Message.fromJson(<String, dynamic>{
          'id': 'm1',
          'conversationId': conversationId,
          'senderId': 'u2',
          'body': 'You are both in for the biryani crawl.',
          'type': 'SYSTEM',
          'createdAt': now.subtract(const Duration(minutes: 10)).toIso8601String(),
          'isMine': false,
        }),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<Message> send(String conversationId, String body) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (failSend) throw Exception('offline');
    sent.add(body);
    return Message.fromJson(<String, dynamic>{
      'id': 'saved-${sent.length}',
      'conversationId': conversationId,
      'senderId': 'u0',
      'body': body,
      'type': 'TEXT',
      'createdAt': DateTime.now().toIso8601String(),
      'isMine': true,
    });
  }

  @override
  Future<void> markRead(String conversationId) async {
    readCalls += 1;
  }
}

import 'package:companion/models/enums.dart';
import 'package:companion/widgets/activity_card.dart';
import 'package:companion/widgets/app_avatar.dart';
import 'package:companion/widgets/person_card.dart';
import 'package:companion/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('PersonCard', () {
    testWidgets('leads with name, then bio, then what they are up for',
        (WidgetTester tester) async {
      await pumpHarness(tester, PersonCard(profile: makeProfile(), onTap: () {}));

      expect(find.text('Sara Mehta'), findsOneWidget);
      expect(find.textContaining('Chronically early'), findsOneWidget);
      expect(find.text('UP FOR'), findsOneWidget);
      expect(find.text('Movie'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.textContaining('Free tonight'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the presence pill only when online', (WidgetTester tester) async {
      await pumpHarness(tester, PersonCard(profile: makeProfile(isOnline: true)));
      expect(find.text('Active now'), findsOneWidget);

      await pumpHarness(tester, PersonCard(profile: makeProfile(isOnline: false)));
      expect(find.text('Active now'), findsNothing);
    });

    testWidgets('omits distance when the person hides it', (WidgetTester tester) async {
      await pumpHarness(tester, PersonCard(profile: makeProfile(distanceKm: null)));
      expect(find.textContaining('km'), findsNothing);
    });

    testWidgets('falls back to initials with no photo', (WidgetTester tester) async {
      await pumpHarness(tester, PersonCard(profile: makeProfile()));
      expect(find.text('SM'), findsWidgets);
    });

    testWidgets('renders without a bio, activities or availability', (WidgetTester tester) async {
      await pumpHarness(
        tester,
        PersonCard(
          profile: makeProfile(
            bio: '',
            activities: const <String>[],
            availability: const <String>[],
          ),
        ),
      );
      expect(find.text('UP FOR'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invite button reaches its callback', (WidgetTester tester) async {
      int invites = 0;
      await pumpHarness(
        tester,
        PersonCard(profile: makeProfile(), onInvite: () => invites += 1),
      );
      await tester.ensureVisible(find.text('Invite'));
      await tester.pump();
      await tester.tap(find.text('Invite'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(invites, 1);
    });

    testWidgets('a very long name and bio do not overflow', (WidgetTester tester) async {
      await pumpHarness(
        tester,
        PersonCard(
          profile: makeProfile(
            name: 'Bartholomew Maximilian Fitzgerald-Wellington III',
            bio: 'A' * 600,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PersonPreviewCard', () {
    testWidgets('fits the home rail without overflowing', (WidgetTester tester) async {
      await pumpHarness(
        tester,
        SizedBox(
          height: 372,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              for (int index = 0; index < 4; index += 1)
                PersonPreviewCard(profile: makeProfile(id: 'u$index')),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PersonPreviewCard), findsWidgets);
    });
  });

  group('ActivityCard', () {
    testWidgets('puts the time above the title', (WidgetTester tester) async {
      await pumpHarness(tester, ActivityCard(activity: makeActivity()));

      expect(find.text('The late show at PVR Orion'), findsOneWidget);
      expect(find.textContaining('PVR Orion Mall'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);
    });

    testWidgets('labels your own plan instead of offering Join', (WidgetTester tester) async {
      await pumpHarness(tester, ActivityCard(activity: makeActivity(isHost: true)));
      expect(find.text('Your plan'), findsOneWidget);
      expect(find.text('Join'), findsNothing);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('replaces Join with a status once you have asked', (WidgetTester tester) async {
      await pumpHarness(
        tester,
        ActivityCard(activity: makeActivity(viewerInvitationStatus: 'PENDING')),
      );
      expect(find.text('Join'), findsNothing);
      expect(find.text('Waiting'), findsOneWidget);
    });

    testWidgets('renders every category without overflowing', (WidgetTester tester) async {
      for (final ActivityCategory category in ActivityCategory.values) {
        await pumpHarness(
          tester,
          ActivityCard(activity: makeActivity(category: category.wire)),
        );
        expect(tester.takeException(), isNull, reason: category.wire);
      }
    });
  });

  group('AppAvatar', () {
    testWidgets('gives the same person the same fallback colour twice',
        (WidgetTester tester) async {
      await pumpHarness(
        tester,
        const Row(
          children: <Widget>[
            AppAvatar(name: 'Sara Mehta'),
            AppAvatar(name: 'Sara Mehta'),
          ],
        ),
      );
      expect(find.text('SM'), findsNWidgets(2));
    });

    testWidgets('AvatarStack collapses the overflow into a counter', (WidgetTester tester) async {
      await pumpHarness(
        tester,
        const AvatarStack(
          entries: <({String name, String? imageUrl})>[
            (name: 'Sara Mehta', imageUrl: null),
            (name: 'Arjun Rao', imageUrl: null),
            (name: 'Meera Pillai', imageUrl: null),
            (name: 'Kabir Sen', imageUrl: null),
            (name: 'Zoya Ahmed', imageUrl: null),
          ],
        ),
      );
      expect(find.text('+2'), findsOneWidget);
    });
  });

  group('StateView', () {
    testWidgets('renders an empty state with its action', (WidgetTester tester) async {
      int taps = 0;
      await pumpHarness(
        tester,
        StateView.empty(
          icon: Icons.event_busy_outlined,
          title: 'No open plans right now',
          message: 'Nothing matches these filters.',
          actionLabel: 'Create a plan',
          onAction: () => taps += 1,
        ),
      );

      expect(find.text('No open plans right now'), findsOneWidget);
      await tester.tap(find.text('Create a plan'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
    });

    testWidgets('turns a network failure into plain language', (WidgetTester tester) async {
      await pumpHarness(
        tester,
        StateView.fromError(
          const ApiExceptionStub(),
          onRetry: () {},
        ),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}

/// Stands in for an arbitrary non-API throwable.
class ApiExceptionStub implements Exception {
  const ApiExceptionStub();
}

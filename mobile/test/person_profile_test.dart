import 'package:companion/features/discover/person_profile_screen.dart';
import 'package:companion/models/profile.dart';
import 'package:companion/providers/feed_providers.dart';
import 'package:companion/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _person(Map<String, dynamic>? connection) => Profile.fromJson(<String, dynamic>{
      'id': 'u1',
      'displayName': 'Sara Mehta',
      if (connection != null) 'connection': connection,
    });

Future<void> _pump(WidgetTester tester, Map<String, dynamic>? connection) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        profileByIdProvider.overrideWith((Ref ref, String id) async => _person(connection)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PersonProfileScreen(userId: 'u1'),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('the action on a profile matches how you stand with them', () {
    testWidgets('someone new can be invited', (WidgetTester tester) async {
      await _pump(tester, null);
      expect(find.text('Invite Sara'), findsOneWidget);
    });

    testWidgets('someone you already invited cannot be invited again', (WidgetTester tester) async {
      await _pump(tester, <String, dynamic>{'status': 'INVITED_BY_ME'});
      expect(find.text('Invitation sent'), findsOneWidget);
      expect(find.text('Invite Sara'), findsNothing);
    });

    testWidgets('someone who invited you points at their invitation', (WidgetTester tester) async {
      await _pump(tester, <String, dynamic>{'status': 'INVITED_ME'});
      expect(find.text('Answer their invitation'), findsOneWidget);
      expect(find.text('Invite Sara'), findsNothing);
    });

    testWidgets('someone you are connected to opens the chat', (WidgetTester tester) async {
      await _pump(tester, <String, dynamic>{'status': 'CONNECTED', 'conversationId': 'c1'});
      expect(find.text('Open chat'), findsOneWidget);
      expect(find.text('Invite Sara'), findsNothing);
    });
  });
}

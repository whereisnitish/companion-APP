import 'package:companion/models/activity.dart';
import 'package:companion/models/conversation.dart';
import 'package:companion/models/invitation.dart';
import 'package:companion/models/profile.dart';
import 'package:companion/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a widget in the real theme and a ProviderScope, so widget tests
/// exercise the production design system rather than a stand-in.
Widget harness(
  Widget child, {
  Brightness brightness = Brightness.light,
  List<Override> overrides = const <Override>[],
  Size surfaceSize = const Size(420, 1400),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: surfaceSize.width, child: child),
        ),
      ),
    ),
  );
}

/// google_fonts tries the network on first use; in tests that would flake, so
/// pumping is wrapped to swallow the resulting async gaps.
Future<void> pumpHarness(WidgetTester tester, Widget child, {Brightness? brightness}) async {
  await tester.pumpWidget(
    harness(child, brightness: brightness ?? Brightness.light),
  );
  await tester.pump(const Duration(milliseconds: 700));
}

// ------------------------------------------------------------------ fixtures

Profile makeProfile({
  String id = 'u1',
  String name = 'Sara Mehta',
  int? age = 24,
  bool isOnline = true,
  double? distanceKm = 2.4,
  List<String> activities = const <String>['MOVIE', 'COFFEE', 'DINNER'],
  List<String> availability = const <String>['TONIGHT', 'WEEKEND'],
  String bio = 'Chronically early to films. Will debate the ending over coffee.',
  String verification = 'VERIFIED',
}) {
  return Profile.fromJson(<String, dynamic>{
    'id': id,
    'displayName': name,
    'age': age,
    'gender': 'FEMALE',
    'bio': bio,
    'occupation': 'Product designer',
    'city': 'Bengaluru',
    'area': 'Indiranagar',
    'avatarUrl': null,
    'photos': const <String>[],
    'interests': const <Map<String, dynamic>>[
      <String, dynamic>{'slug': 'indie-films', 'label': 'Indie films', 'emoji': '🎞'},
      <String, dynamic>{'slug': 'specialty-coffee', 'label': 'Specialty coffee', 'emoji': '☕️'},
    ],
    'preferredActivities': activities,
    'availability': availability,
    'verification': verification,
    'rating': <String, dynamic>{'average': 4.9, 'count': 23},
    'distanceKm': distanceKm,
    'isOnline': isOnline,
    'lastActiveAt': DateTime.now().toUtc().toIso8601String(),
  });
}

Activity makeActivity({
  String id = 'a1',
  String category = 'MOVIE',
  String title = 'The late show at PVR Orion',
  bool isHost = false,
  String? viewerInvitationStatus,
  int capacity = 1,
  String status = 'OPEN',
  DateTime? startsAt,
}) {
  return Activity.fromJson(<String, dynamic>{
    'id': id,
    'category': category,
    'title': title,
    'description': 'Booked two tickets and my friend bailed. I do not talk during films.',
    'startsAt':
        (startsAt ?? DateTime.now().add(const Duration(hours: 5))).toUtc().toIso8601String(),
    'locationName': 'PVR Orion Mall',
    'area': 'Rajajinagar',
    'city': 'Bengaluru',
    'lookingFor': 'ANYONE',
    'minAge': 18,
    'maxAge': 99,
    'capacity': capacity,
    'status': status,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'host': <String, dynamic>{
      'id': 'u1',
      'displayName': 'Sara Mehta',
      'age': 24,
      'verification': 'VERIFIED',
      'rating': <String, dynamic>{'average': 4.9, 'count': 23},
      'isOnline': true,
      'lastActiveAt': DateTime.now().toUtc().toIso8601String(),
    },
    'participantCount': 1,
    'distanceKm': 6.1,
    'isHost': isHost,
    'viewerInvitationStatus': viewerInvitationStatus,
  });
}

Invitation makeInvitation({
  String direction = 'received',
  String status = 'PENDING',
  bool withActivity = true,
  String message = 'Saw you are into indie films too. The 9:40 show tonight?',
  String? conversationId,
}) {
  return Invitation.fromJson(<String, dynamic>{
    'id': 'i1',
    'direction': direction,
    'status': status,
    'message': message,
    'category': withActivity ? null : 'COFFEE',
    'proposedAt':
        withActivity ? null : DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(),
    'locationName': withActivity ? null : 'Blue Tokai, 12th Main',
    'createdAt': DateTime.now().subtract(const Duration(minutes: 42)).toUtc().toIso8601String(),
    'counterpart': <String, dynamic>{
      'id': 'u1',
      'displayName': 'Sara Mehta',
      'age': 24,
      'verification': 'VERIFIED',
      'isOnline': true,
      'rating': <String, dynamic>{'average': 4.9, 'count': 23},
      'lastActiveAt': DateTime.now().toUtc().toIso8601String(),
    },
    'activity': withActivity
        ? <String, dynamic>{
            'id': 'a1',
            'category': 'MOVIE',
            'title': 'The late show at PVR Orion',
            'startsAt': DateTime.now().add(const Duration(hours: 5)).toUtc().toIso8601String(),
            'locationName': 'PVR Orion Mall',
            'host': <String, dynamic>{'id': 'u1', 'displayName': 'Sara Mehta'},
          }
        : null,
    'conversationId': conversationId,
  });
}

Conversation makeConversation({int unreadCount = 2, bool withActivity = true}) {
  return Conversation.fromJson(<String, dynamic>{
    'id': 'c1',
    'lastMessageAt': DateTime.now().subtract(const Duration(minutes: 12)).toUtc().toIso8601String(),
    'lastMessagePreview': 'Changed my mind on the order — we start at the small place.',
    'unreadCount': unreadCount,
    'participant': <String, dynamic>{
      'id': 'u2',
      'displayName': 'Aisha Khan',
      'age': 27,
      'verification': 'VERIFIED',
      'isOnline': true,
      'rating': <String, dynamic>{'average': 4.9, 'count': 18},
      'lastActiveAt': DateTime.now().toUtc().toIso8601String(),
    },
    'activity': withActivity
        ? <String, dynamic>{
            'id': 'a2',
            'category': 'DINNER',
            'title': 'Thursday biryani crawl',
            'startsAt': DateTime.now().add(const Duration(hours: 3)).toUtc().toIso8601String(),
            'locationName': 'Mosque Road',
          }
        : null,
  });
}

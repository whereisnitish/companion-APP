import 'package:companion/models/activity.dart';
import 'package:companion/models/conversation.dart';
import 'package:companion/models/enums.dart';
import 'package:companion/models/home_feed.dart';
import 'package:companion/models/invitation.dart';
import 'package:companion/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile.fromJson', () {
    test('parses a full payload', () {
      final Profile profile = Profile.fromJson(<String, dynamic>{
        'id': 'u1',
        'displayName': 'Sara Mehta',
        'age': 24,
        'gender': 'FEMALE',
        'bio': 'Chronically early to films.',
        'occupation': 'Product designer',
        'city': 'Bengaluru',
        'area': 'Indiranagar',
        'avatarUrl': 'https://example.com/a.jpg',
        'photos': <String>['https://example.com/b.jpg'],
        'interests': <Map<String, dynamic>>[
          <String, dynamic>{'slug': 'indie-films', 'label': 'Indie films', 'emoji': '🎞'},
        ],
        'preferredActivities': <String>['MOVIE', 'COFFEE'],
        'availability': <String>['TONIGHT'],
        'verification': 'VERIFIED',
        'rating': <String, dynamic>{'average': 4.9, 'count': 23},
        'distanceKm': 2.4,
        'isOnline': true,
        'lastActiveAt': '2026-08-31T06:00:00.000Z',
      });

      expect(profile.displayName, 'Sara Mehta');
      expect(profile.firstName, 'Sara');
      expect(profile.preferredActivities, <ActivityCategory>[
        ActivityCategory.movie,
        ActivityCategory.coffee,
      ]);
      expect(profile.availability.single, AvailabilitySlot.tonight);
      expect(profile.verification.isVerified, isTrue);
      expect(profile.ratingAverage, 4.9);
      expect(profile.interests.single.label, 'Indie films');
    });

    test('survives an empty object without throwing', () {
      final Profile profile = Profile.fromJson(const <String, dynamic>{});
      expect(profile.displayName, 'Someone');
      expect(profile.age, isNull);
      expect(profile.gallery, isEmpty);
      expect(profile.verification, VerificationStatus.unverified);
    });

    test('maps an unknown enum value to a safe default rather than throwing', () {
      final Profile profile = Profile.fromJson(<String, dynamic>{
        'gender': 'MARTIAN',
        'preferredActivities': <String>['TELEPORTING'],
      });
      expect(profile.gender, Gender.other);
      expect(profile.preferredActivities.single, ActivityCategory.other);
    });

    test('gallery puts the avatar first and de-duplicates', () {
      final Profile profile = Profile.fromJson(<String, dynamic>{
        'avatarUrl': 'a.jpg',
        'photos': <String>['a.jpg', 'b.jpg'],
      });
      expect(profile.gallery, <String>['a.jpg', 'b.jpg']);
    });

    test('respects a hidden age', () {
      final Profile profile = Profile.fromJson(<String, dynamic>{'age': null});
      expect(profile.age, isNull);
    });
  });

  group('CurrentUser.fromJson', () {
    test('carries the owner-only fields', () {
      final CurrentUser me = CurrentUser.fromJson(<String, dynamic>{
        'id': 'u0',
        'displayName': 'Nitish',
        'email': 'demo@companion.app',
        'isDiscoverable': false,
        'showDistance': true,
        'showAge': false,
        'isProfileComplete': true,
        'latitude': 12.97,
        'longitude': 77.64,
      });

      expect(me.email, 'demo@companion.app');
      expect(me.isDiscoverable, isFalse);
      expect(me.isProfileComplete, isTrue);
      expect(me.latitude, 12.97);
    });
  });

  group('Activity.fromJson', () {
    test('parses a plan and its host', () {
      final Activity activity = Activity.fromJson(<String, dynamic>{
        'id': 'a1',
        'category': 'MOVIE',
        'title': 'The late show',
        'startsAt': '2026-09-01T16:10:00.000Z',
        'locationName': 'PVR Orion',
        'capacity': 2,
        'participantCount': 1,
        'status': 'OPEN',
        'host': <String, dynamic>{'id': 'u1', 'displayName': 'Sara Mehta'},
        'viewerInvitationStatus': 'PENDING',
      });

      expect(activity.category, ActivityCategory.movie);
      expect(activity.isOpen, isTrue);
      expect(activity.spotsLeft, 2);
      expect(activity.host.firstName, 'Sara');
      expect(activity.viewerInvitationStatus, InvitationStatus.pending);
    });

    test('leaves viewerInvitationStatus null when absent', () {
      final Activity activity = Activity.fromJson(<String, dynamic>{'category': 'COFFEE'});
      expect(activity.viewerInvitationStatus, isNull);
    });
  });

  group('Invitation.fromJson', () {
    test('reads direction and falls back to the activity for context', () {
      final Invitation invitation = Invitation.fromJson(<String, dynamic>{
        'id': 'i1',
        'direction': 'received',
        'status': 'PENDING',
        'message': 'Come along?',
        'counterpart': <String, dynamic>{'id': 'u1', 'displayName': 'Sara Mehta'},
        'activity': <String, dynamic>{
          'id': 'a1',
          'category': 'MOVIE',
          'title': 'The late show',
          'startsAt': '2026-09-01T16:10:00.000Z',
          'host': <String, dynamic>{'id': 'u1', 'displayName': 'Sara Mehta'},
        },
      });

      expect(invitation.isReceived, isTrue);
      expect(invitation.status.isOpen, isTrue);
      expect(invitation.resolvedCategory, ActivityCategory.movie);
      expect(invitation.headline, 'The late show');
    });

    test('builds a headline for a free-form proposal', () {
      final Invitation invitation = Invitation.fromJson(<String, dynamic>{
        'direction': 'sent',
        'status': 'ACCEPTED',
        'category': 'COFFEE',
        'counterpart': <String, dynamic>{'displayName': 'Ananya Bose'},
      });

      expect(invitation.isReceived, isFalse);
      expect(invitation.status.isOpen, isFalse);
      expect(invitation.headline, 'Up for something for coffee?');
    });
  });

  group('Message.fromJson', () {
    test('distinguishes system messages', () {
      final Message message = Message.fromJson(<String, dynamic>{
        'id': 'm1',
        'type': 'SYSTEM',
        'body': 'You are both in.',
        'isMine': false,
      });
      expect(message.isSystem, isTrue);
      expect(message.isRead, isFalse);
      expect(message.isPending, isFalse);
    });
  });

  group('HomeFeed', () {
    test('orderedCategories returns all twelve, busiest first', () {
      final HomeFeed feed = HomeFeed.fromJson(<String, dynamic>{
        'greeting': 'EVENING',
        'city': 'Bengaluru',
        'categories': <Map<String, dynamic>>[
          <String, dynamic>{'category': 'COFFEE', 'openActivities': 1, 'people': 0},
          <String, dynamic>{'category': 'MOVIE', 'openActivities': 5, 'people': 2},
        ],
        'pendingInvitations': 4,
      });

      expect(feed.greeting, Greeting.evening);
      expect(feed.orderedCategories.length, ActivityCategory.values.length);
      expect(feed.orderedCategories.first.category, ActivityCategory.movie);
      expect(feed.orderedCategories[1].category, ActivityCategory.coffee);
      expect(feed.pendingInvitations, 4);
    });
  });
}

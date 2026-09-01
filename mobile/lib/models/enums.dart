import 'package:flutter/material.dart';

/// The twelve things people do together. Each one carries its own small visual
/// identity — an icon and a single hue — so a category is recognisable before
/// the label is read.
enum ActivityCategory {
  movie('MOVIE', 'Movie', Icons.local_movies_outlined, Color(0xFF4B5BA6)),
  dinner('DINNER', 'Dinner', Icons.restaurant_outlined, Color(0xFFC0603A)),
  coffee('COFFEE', 'Coffee', Icons.local_cafe_outlined, Color(0xFF8A5A3B)),
  shopping('SHOPPING', 'Shopping', Icons.shopping_bag_outlined, Color(0xFF8C4A70)),
  walk('WALK', 'Walk', Icons.directions_walk_rounded, Color(0xFF2F7A5E)),
  event('EVENT', 'Event', Icons.celebration_outlined, Color(0xFFB0821F)),
  travel('TRAVEL', 'Travel', Icons.luggage_outlined, Color(0xFF2B7683)),
  sports('SPORTS', 'Sports', Icons.sports_tennis_outlined, Color(0xFF5E7A2A)),
  concert('CONCERT', 'Concert', Icons.music_note_outlined, Color(0xFFA43F5F)),
  study('STUDY', 'Study', Icons.menu_book_outlined, Color(0xFF4C6274)),
  gaming('GAMING', 'Gaming', Icons.sports_esports_outlined, Color(0xFF6A4FA3)),
  other('OTHER', 'Something else', Icons.auto_awesome_outlined, Color(0xFF5D6A65));

  const ActivityCategory(this.wire, this.label, this.icon, this.hue);

  final String wire;
  final String label;
  final IconData icon;

  /// The category's single colour. Tints are derived from it so a new category
  /// only needs one value to slot in coherently.
  final Color hue;

  static ActivityCategory fromWire(String? value) {
    for (final ActivityCategory category in ActivityCategory.values) {
      if (category.wire == value) return category;
    }
    return ActivityCategory.other;
  }

  /// A soft background that stays legible in both themes.
  Color tint(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return hue.withValues(alpha: isDark ? 0.20 : 0.10);
  }

  /// The hue lifted just enough to read on a dark canvas.
  Color foreground(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return hue;
    return HSLColor.fromColor(hue).withLightness(0.68).withSaturation(0.52).toColor();
  }

  /// A short, human phrase — "for a movie", "for dinner".
  String get phrase => switch (this) {
        ActivityCategory.movie => 'for a movie',
        ActivityCategory.dinner => 'for dinner',
        ActivityCategory.coffee => 'for coffee',
        ActivityCategory.shopping => 'to go shopping',
        ActivityCategory.walk => 'for a walk',
        ActivityCategory.event => 'for an event',
        ActivityCategory.travel => 'to travel',
        ActivityCategory.sports => 'to play',
        ActivityCategory.concert => 'for a gig',
        ActivityCategory.study => 'to study',
        ActivityCategory.gaming => 'to game',
        ActivityCategory.other => 'to hang out',
      };
}

enum AvailabilitySlot {
  tonight('TONIGHT', 'Tonight'),
  tomorrow('TOMORROW', 'Tomorrow'),
  thisWeek('THIS_WEEK', 'This week'),
  weekend('WEEKEND', 'Weekend'),
  flexible('FLEXIBLE', 'Flexible');

  const AvailabilitySlot(this.wire, this.label);
  final String wire;
  final String label;

  static AvailabilitySlot fromWire(String? value) {
    for (final AvailabilitySlot slot in AvailabilitySlot.values) {
      if (slot.wire == value) return slot;
    }
    return AvailabilitySlot.flexible;
  }
}

enum Gender {
  male('MALE', 'Man'),
  female('FEMALE', 'Woman'),
  nonBinary('NON_BINARY', 'Non-binary'),
  other('OTHER', 'Prefer not to say');

  const Gender(this.wire, this.label);
  final String wire;
  final String label;

  static Gender fromWire(String? value) {
    for (final Gender gender in Gender.values) {
      if (gender.wire == value) return gender;
    }
    return Gender.other;
  }
}

enum GenderPreference {
  anyone('ANYONE', 'Anyone'),
  male('MALE', 'Men'),
  female('FEMALE', 'Women');

  const GenderPreference(this.wire, this.label);
  final String wire;
  final String label;

  static GenderPreference fromWire(String? value) {
    for (final GenderPreference preference in GenderPreference.values) {
      if (preference.wire == value) return preference;
    }
    return GenderPreference.anyone;
  }
}

enum InvitationStatus {
  pending('PENDING', 'Waiting'),
  accepted('ACCEPTED', 'Accepted'),
  declined('DECLINED', 'Declined'),
  cancelled('CANCELLED', 'Withdrawn'),
  expired('EXPIRED', 'Expired');

  const InvitationStatus(this.wire, this.label);
  final String wire;
  final String label;

  bool get isOpen => this == InvitationStatus.pending;

  static InvitationStatus fromWire(String? value) {
    for (final InvitationStatus status in InvitationStatus.values) {
      if (status.wire == value) return status;
    }
    return InvitationStatus.pending;
  }
}

enum VerificationStatus {
  unverified('UNVERIFIED'),
  pending('PENDING'),
  verified('VERIFIED');

  const VerificationStatus(this.wire);
  final String wire;

  bool get isVerified => this == VerificationStatus.verified;

  static VerificationStatus fromWire(String? value) {
    for (final VerificationStatus status in VerificationStatus.values) {
      if (status.wire == value) return status;
    }
    return VerificationStatus.unverified;
  }
}

enum AppNotificationType {
  invitationReceived('INVITATION_RECEIVED', Icons.mail_outline_rounded),
  invitationAccepted('INVITATION_ACCEPTED', Icons.check_circle_outline_rounded),
  invitationDeclined('INVITATION_DECLINED', Icons.do_not_disturb_alt_rounded),
  messageReceived('MESSAGE_RECEIVED', Icons.chat_bubble_outline_rounded),
  activityReminder('ACTIVITY_REMINDER', Icons.schedule_rounded),
  system('SYSTEM', Icons.info_outline_rounded);

  const AppNotificationType(this.wire, this.icon);
  final String wire;
  final IconData icon;

  static AppNotificationType fromWire(String? value) {
    for (final AppNotificationType type in AppNotificationType.values) {
      if (type.wire == value) return type;
    }
    return AppNotificationType.system;
  }
}

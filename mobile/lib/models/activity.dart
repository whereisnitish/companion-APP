import 'enums.dart';
import 'profile.dart';

T? _as<T>(Object? value) => value is T ? value : null;
int _asInt(Object? value, [int fallback = 0]) =>
    value is int ? value : (value is num ? value.toInt() : fallback);
double? _asDouble(Object? value) => value is num ? value.toDouble() : null;
DateTime? _asDate(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// A plan somebody has posted, waiting for company.
class Activity {
  const Activity({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.locationName,
    required this.area,
    required this.city,
    required this.lookingFor,
    required this.minAge,
    required this.maxAge,
    required this.capacity,
    required this.status,
    required this.createdAt,
    required this.host,
    required this.participantCount,
    required this.distanceKm,
    required this.isHost,
    required this.viewerInvitationStatus,
  });

  final String id;
  final ActivityCategory category;
  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String locationName;
  final String? area;
  final String city;
  final GenderPreference lookingFor;
  final int minAge;
  final int maxAge;
  final int capacity;
  final String status;
  final DateTime? createdAt;
  final Profile host;
  final int participantCount;
  final double? distanceKm;
  final bool isHost;
  final InvitationStatus? viewerInvitationStatus;

  bool get isOpen => status == 'OPEN';
  int get spotsLeft => (capacity + 1 - participantCount).clamp(0, capacity);

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: _as<String>(json['id']) ?? '',
        category: ActivityCategory.fromWire(_as<String>(json['category'])),
        title: _as<String>(json['title']) ?? '',
        description: _as<String>(json['description']) ?? '',
        startsAt: _asDate(json['startsAt']) ?? DateTime.now(),
        endsAt: _asDate(json['endsAt']),
        locationName: _as<String>(json['locationName']) ?? '',
        area: _as<String>(json['area']),
        city: _as<String>(json['city']) ?? '',
        lookingFor: GenderPreference.fromWire(_as<String>(json['lookingFor'])),
        minAge: _asInt(json['minAge'], 18),
        maxAge: _asInt(json['maxAge'], 99),
        capacity: _asInt(json['capacity'], 1),
        status: _as<String>(json['status']) ?? 'OPEN',
        createdAt: _asDate(json['createdAt']),
        host:
            Profile.fromJson(_as<Map<String, dynamic>>(json['host']) ?? const <String, dynamic>{}),
        participantCount: _asInt(json['participantCount'], 1),
        distanceKm: _asDouble(json['distanceKm']),
        isHost: _as<bool>(json['isHost']) ?? false,
        viewerInvitationStatus: json['viewerInvitationStatus'] == null
            ? null
            : InvitationStatus.fromWire(_as<String>(json['viewerInvitationStatus'])),
      );
}

/// The compact activity summary carried alongside a conversation.
class ActivityContext {
  const ActivityContext({
    required this.id,
    required this.category,
    required this.title,
    required this.startsAt,
    required this.locationName,
  });

  final String id;
  final ActivityCategory category;
  final String title;
  final DateTime startsAt;
  final String locationName;

  factory ActivityContext.fromJson(Map<String, dynamic> json) => ActivityContext(
        id: _as<String>(json['id']) ?? '',
        category: ActivityCategory.fromWire(_as<String>(json['category'])),
        title: _as<String>(json['title']) ?? '',
        startsAt: _asDate(json['startsAt']) ?? DateTime.now(),
        locationName: _as<String>(json['locationName']) ?? '',
      );
}

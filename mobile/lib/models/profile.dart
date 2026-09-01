import 'enums.dart';

/// Small helpers shared by every model — the API is trusted but never assumed.
T? _as<T>(Object? value) => value is T ? value : null;

int? _asInt(Object? value) =>
    value is int ? value : (value is num ? value.toInt() : int.tryParse('$value'));

double _asDouble(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

DateTime? _asDate(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

List<String> _asStrings(Object? value) =>
    value is List ? value.whereType<String>().toList(growable: false) : const <String>[];

class Interest {
  const Interest({required this.slug, required this.label, required this.emoji});

  final String slug;
  final String label;
  final String emoji;

  factory Interest.fromJson(Map<String, dynamic> json) => Interest(
        slug: _as<String>(json['slug']) ?? '',
        label: _as<String>(json['label']) ?? '',
        emoji: _as<String>(json['emoji']) ?? '',
      );

  @override
  bool operator ==(Object other) => other is Interest && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}

/// Somebody as everybody else sees them.
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.age,
    required this.gender,
    required this.bio,
    required this.occupation,
    required this.city,
    required this.area,
    required this.avatarUrl,
    required this.photos,
    required this.interests,
    required this.preferredActivities,
    required this.availability,
    required this.verification,
    required this.ratingAverage,
    required this.ratingCount,
    required this.distanceKm,
    required this.isOnline,
    required this.lastActiveAt,
  });

  final String id;
  final String displayName;
  final int? age;
  final Gender gender;
  final String bio;
  final String? occupation;
  final String city;
  final String? area;
  final String? avatarUrl;
  final List<String> photos;
  final List<Interest> interests;
  final List<ActivityCategory> preferredActivities;
  final List<AvailabilitySlot> availability;
  final VerificationStatus verification;
  final double ratingAverage;
  final int ratingCount;
  final double? distanceKm;
  final bool isOnline;
  final DateTime? lastActiveAt;

  /// The first name only — the interface addresses people, it does not file them.
  String get firstName => displayName.split(' ').first;

  /// Every image we can show, avatar first, de-duplicated.
  List<String> get gallery {
    final List<String> all = <String>[if (avatarUrl != null) avatarUrl!, ...photos];
    return all.toSet().toList(growable: false);
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rating =
        _as<Map<String, dynamic>>(json['rating']) ?? const <String, dynamic>{};

    return Profile(
      id: _as<String>(json['id']) ?? '',
      displayName: _as<String>(json['displayName']) ?? 'Someone',
      age: _asInt(json['age']),
      gender: Gender.fromWire(_as<String>(json['gender'])),
      bio: _as<String>(json['bio']) ?? '',
      occupation: _as<String>(json['occupation']),
      city: _as<String>(json['city']) ?? '',
      area: _as<String>(json['area']),
      avatarUrl: _as<String>(json['avatarUrl']),
      photos: _asStrings(json['photos']),
      interests: (json['interests'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Interest.fromJson)
          .toList(growable: false),
      preferredActivities: _asStrings(json['preferredActivities'])
          .map(ActivityCategory.fromWire)
          .toList(growable: false),
      availability:
          _asStrings(json['availability']).map(AvailabilitySlot.fromWire).toList(growable: false),
      verification: VerificationStatus.fromWire(_as<String>(json['verification'])),
      ratingAverage: _asDouble(rating['average']),
      ratingCount: _asInt(rating['count']) ?? 0,
      distanceKm: json['distanceKm'] == null ? null : _asDouble(json['distanceKm']),
      isOnline: _as<bool>(json['isOnline']) ?? false,
      lastActiveAt: _asDate(json['lastActiveAt']),
    );
  }
}

/// The signed-in user: everything in [Profile] plus what only they may see.
class CurrentUser extends Profile {
  const CurrentUser({
    required super.id,
    required super.displayName,
    required super.age,
    required super.gender,
    required super.bio,
    required super.occupation,
    required super.city,
    required super.area,
    required super.avatarUrl,
    required super.photos,
    required super.interests,
    required super.preferredActivities,
    required super.availability,
    required super.verification,
    required super.ratingAverage,
    required super.ratingCount,
    required super.distanceKm,
    required super.isOnline,
    required super.lastActiveAt,
    required this.email,
    required this.phone,
    required this.birthDate,
    required this.latitude,
    required this.longitude,
    required this.isDiscoverable,
    required this.showDistance,
    required this.showAge,
    required this.isProfileComplete,
    required this.createdAt,
  });

  final String? email;
  final String? phone;
  final DateTime? birthDate;
  final double? latitude;
  final double? longitude;
  final bool isDiscoverable;
  final bool showDistance;
  final bool showAge;
  final bool isProfileComplete;
  final DateTime? createdAt;

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    final Profile base = Profile.fromJson(json);
    return CurrentUser(
      id: base.id,
      displayName: base.displayName,
      age: base.age,
      gender: base.gender,
      bio: base.bio,
      occupation: base.occupation,
      city: base.city,
      area: base.area,
      avatarUrl: base.avatarUrl,
      photos: base.photos,
      interests: base.interests,
      preferredActivities: base.preferredActivities,
      availability: base.availability,
      verification: base.verification,
      ratingAverage: base.ratingAverage,
      ratingCount: base.ratingCount,
      distanceKm: base.distanceKm,
      isOnline: base.isOnline,
      lastActiveAt: base.lastActiveAt,
      email: _as<String>(json['email']),
      phone: _as<String>(json['phone']),
      birthDate: _asDate(json['birthDate']),
      latitude: json['latitude'] == null ? null : _asDouble(json['latitude']),
      longitude: json['longitude'] == null ? null : _asDouble(json['longitude']),
      isDiscoverable: _as<bool>(json['isDiscoverable']) ?? true,
      showDistance: _as<bool>(json['showDistance']) ?? true,
      showAge: _as<bool>(json['showAge']) ?? true,
      isProfileComplete: _as<bool>(json['isProfileComplete']) ?? false,
      createdAt: _asDate(json['createdAt']),
    );
  }
}

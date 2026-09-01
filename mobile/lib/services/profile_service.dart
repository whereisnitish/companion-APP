import '../core/network/api_client.dart';
import '../models/enums.dart';
import '../models/profile.dart';

/// Everything the profile setup flow collects, in one object.
class ProfileDraft {
  const ProfileDraft({
    this.displayName = '',
    this.birthDate,
    this.gender,
    this.bio = '',
    this.occupation,
    this.city = 'Bengaluru',
    this.area,
    this.latitude,
    this.longitude,
    this.avatarUrl,
    this.photos = const <String>[],
    this.interests = const <String>[],
    this.preferredActivities = const <ActivityCategory>[],
    this.availability = const <AvailabilitySlot>[],
  });

  final String displayName;
  final DateTime? birthDate;
  final Gender? gender;
  final String bio;
  final String? occupation;
  final String city;
  final String? area;
  final double? latitude;
  final double? longitude;
  final String? avatarUrl;
  final List<String> photos;
  final List<String> interests;
  final List<ActivityCategory> preferredActivities;
  final List<AvailabilitySlot> availability;

  ProfileDraft copyWith({
    String? displayName,
    DateTime? birthDate,
    Gender? gender,
    String? bio,
    String? occupation,
    String? city,
    String? area,
    double? latitude,
    double? longitude,
    String? avatarUrl,
    List<String>? photos,
    List<String>? interests,
    List<ActivityCategory>? preferredActivities,
    List<AvailabilitySlot>? availability,
  }) =>
      ProfileDraft(
        displayName: displayName ?? this.displayName,
        birthDate: birthDate ?? this.birthDate,
        gender: gender ?? this.gender,
        bio: bio ?? this.bio,
        occupation: occupation ?? this.occupation,
        city: city ?? this.city,
        area: area ?? this.area,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        photos: photos ?? this.photos,
        interests: interests ?? this.interests,
        preferredActivities: preferredActivities ?? this.preferredActivities,
        availability: availability ?? this.availability,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'displayName': displayName,
        if (birthDate != null) 'birthDate': birthDate!.toUtc().toIso8601String(),
        if (gender != null) 'gender': gender!.wire,
        'bio': bio,
        if (occupation != null && occupation!.isNotEmpty) 'occupation': occupation,
        'city': city,
        if (area != null && area!.isNotEmpty) 'area': area,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'photos': photos,
        'interests': interests,
        'preferredActivities':
            preferredActivities.map((ActivityCategory c) => c.wire).toList(growable: false),
        'availability':
            availability.map((AvailabilitySlot slot) => slot.wire).toList(growable: false),
      };
}

class ProfileService {
  const ProfileService(this._client);

  final ApiClient _client;

  Future<CurrentUser> fetchMe() async {
    final Map<String, dynamic> response = await _client.get('/users/me');
    return CurrentUser.fromJson(response.dataObject);
  }

  Future<CurrentUser> createProfile(ProfileDraft draft) async {
    final Map<String, dynamic> response =
        await _client.post('/users/me/profile', body: draft.toJson());
    return CurrentUser.fromJson(response.dataObject);
  }

  Future<CurrentUser> updateProfile(Map<String, dynamic> patch) async {
    final Map<String, dynamic> response = await _client.put('/users/me', body: patch);
    return CurrentUser.fromJson(response.dataObject);
  }

  Future<Profile> fetchProfile(String userId) async {
    final Map<String, dynamic> response = await _client.get('/users/$userId');
    return Profile.fromJson(response.dataObject);
  }

  Future<List<Interest>> fetchInterests() async {
    final Map<String, dynamic> response = await _client.get('/catalog/interests');
    final Object? items = response.dataObject['items'];
    if (items is! List) return const <Interest>[];
    return items.whereType<Map<String, dynamic>>().map(Interest.fromJson).toList(growable: false);
  }
}

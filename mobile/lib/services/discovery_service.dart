import '../core/network/api_client.dart';
import '../models/activity.dart';
import '../models/enums.dart';
import '../models/home_feed.dart';
import '../models/profile.dart';

/// The full set of discovery filters. Immutable so it can be a provider key.
class DiscoveryFilters {
  const DiscoveryFilters({
    this.activities = const <ActivityCategory>[],
    this.availability = const <AvailabilitySlot>[],
    this.genders = const <Gender>[],
    this.interests = const <String>[],
    this.minAge = 18,
    this.maxAge = 99,
    this.radiusKm = 25,
    this.query = '',
  });

  final List<ActivityCategory> activities;
  final List<AvailabilitySlot> availability;
  final List<Gender> genders;
  final List<String> interests;
  final int minAge;
  final int maxAge;
  final double radiusKm;
  final String query;

  static const DiscoveryFilters none = DiscoveryFilters();

  /// How many filters the user has actually changed — drives the badge on the
  /// filter button, so it only ever counts deliberate choices.
  int get activeCount {
    int count = 0;
    if (activities.isNotEmpty) count += 1;
    if (availability.isNotEmpty) count += 1;
    if (genders.isNotEmpty) count += 1;
    if (interests.isNotEmpty) count += 1;
    if (minAge != 18 || maxAge != 99) count += 1;
    if (radiusKm != 25) count += 1;
    return count;
  }

  bool get isDefault => activeCount == 0;

  DiscoveryFilters copyWith({
    List<ActivityCategory>? activities,
    List<AvailabilitySlot>? availability,
    List<Gender>? genders,
    List<String>? interests,
    int? minAge,
    int? maxAge,
    double? radiusKm,
    String? query,
  }) =>
      DiscoveryFilters(
        activities: activities ?? this.activities,
        availability: availability ?? this.availability,
        genders: genders ?? this.genders,
        interests: interests ?? this.interests,
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
        radiusKm: radiusKm ?? this.radiusKm,
        query: query ?? this.query,
      );

  Map<String, dynamic> toQuery({required int page, int limit = 20}) => <String, dynamic>{
        if (activities.isNotEmpty)
          'activities': activities.map((ActivityCategory c) => c.wire).join(','),
        if (availability.isNotEmpty)
          'availability': availability.map((AvailabilitySlot a) => a.wire).join(','),
        if (genders.isNotEmpty) 'genders': genders.map((Gender g) => g.wire).join(','),
        if (interests.isNotEmpty) 'interests': interests.join(','),
        'minAge': minAge,
        'maxAge': maxAge,
        'radiusKm': radiusKm,
        if (query.trim().isNotEmpty) 'query': query.trim(),
        'page': page,
        'limit': limit,
      };

  @override
  bool operator ==(Object other) =>
      other is DiscoveryFilters &&
      other.minAge == minAge &&
      other.maxAge == maxAge &&
      other.radiusKm == radiusKm &&
      other.query == query &&
      _sameList(other.activities, activities) &&
      _sameList(other.availability, availability) &&
      _sameList(other.genders, genders) &&
      _sameList(other.interests, interests);

  @override
  int get hashCode => Object.hash(
        minAge,
        maxAge,
        radiusKm,
        query,
        Object.hashAll(activities),
        Object.hashAll(availability),
        Object.hashAll(genders),
        Object.hashAll(interests),
      );

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

class PagedResult<T> {
  const PagedResult({required this.items, required this.page, required this.hasMore});

  final List<T> items;
  final int page;
  final bool hasMore;

  static PagedResult<T> empty<T>() => PagedResult<T>(items: <T>[], page: 1, hasMore: false);
}

class DiscoveryService {
  const DiscoveryService(this._client);

  final ApiClient _client;

  Future<HomeFeed> fetchHomeFeed() async {
    final Map<String, dynamic> response = await _client.get('/discover');
    return HomeFeed.fromJson(response.dataObject);
  }

  Future<PagedResult<Profile>> discoverPeople(
    DiscoveryFilters filters, {
    int page = 1,
    int limit = 20,
  }) async {
    final Map<String, dynamic> response = await _client.get(
      '/discover/people',
      query: filters.toQuery(page: page, limit: limit),
    );
    return PagedResult<Profile>(
      items: response.dataList.map(Profile.fromJson).toList(growable: false),
      page: response.meta['page'] as int? ?? page,
      hasMore: response.meta['hasMore'] as bool? ?? false,
    );
  }

  Future<PagedResult<Activity>> discoverActivities(
    DiscoveryFilters filters, {
    int page = 1,
    int limit = 20,
  }) async {
    final Map<String, dynamic> response = await _client.get(
      '/discover/activities',
      query: filters.toQuery(page: page, limit: limit),
    );
    return PagedResult<Activity>(
      items: response.dataList.map(Activity.fromJson).toList(growable: false),
      page: response.meta['page'] as int? ?? page,
      hasMore: response.meta['hasMore'] as bool? ?? false,
    );
  }
}

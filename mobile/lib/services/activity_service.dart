import '../core/network/api_client.dart';
import '../models/activity.dart';
import '../models/enums.dart';

/// What the create-activity flow collects, step by step.
class ActivityDraft {
  const ActivityDraft({
    this.category,
    this.title = '',
    this.description = '',
    this.startsAt,
    this.locationName = '',
    this.area,
    this.city = 'Chandigarh',
    this.latitude,
    this.longitude,
    this.lookingFor = GenderPreference.anyone,
    this.minAge = 18,
    this.maxAge = 99,
    this.capacity = 1,
  });

  final ActivityCategory? category;
  final String title;
  final String description;
  final DateTime? startsAt;
  final String locationName;
  final String? area;
  final String city;
  final double? latitude;
  final double? longitude;
  final GenderPreference lookingFor;
  final int minAge;
  final int maxAge;
  final int capacity;

  bool get isReady =>
      category != null &&
      title.trim().length >= 3 &&
      startsAt != null &&
      locationName.trim().length >= 2;

  ActivityDraft copyWith({
    ActivityCategory? category,
    String? title,
    String? description,
    DateTime? startsAt,
    String? locationName,
    String? area,
    String? city,
    double? latitude,
    double? longitude,
    GenderPreference? lookingFor,
    int? minAge,
    int? maxAge,
    int? capacity,
  }) =>
      ActivityDraft(
        category: category ?? this.category,
        title: title ?? this.title,
        description: description ?? this.description,
        startsAt: startsAt ?? this.startsAt,
        locationName: locationName ?? this.locationName,
        area: area ?? this.area,
        city: city ?? this.city,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        lookingFor: lookingFor ?? this.lookingFor,
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
        capacity: capacity ?? this.capacity,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'category': category?.wire,
        'title': title.trim(),
        'description': description.trim(),
        'startsAt': startsAt?.toUtc().toIso8601String(),
        'locationName': locationName.trim(),
        if (area != null && area!.isNotEmpty) 'area': area,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'lookingFor': lookingFor.wire,
        'minAge': minAge,
        'maxAge': maxAge,
        'capacity': capacity,
      };
}

class ActivityService {
  const ActivityService(this._client);

  final ApiClient _client;

  Future<Activity> create(ActivityDraft draft) async {
    final Map<String, dynamic> response = await _client.post('/activities', body: draft.toJson());
    return Activity.fromJson(response.dataObject);
  }

  Future<Activity> fetch(String id) async {
    final Map<String, dynamic> response = await _client.get('/activities/$id');
    return Activity.fromJson(response.dataObject);
  }

  Future<List<Activity>> list({String scope = 'mine'}) async {
    final Map<String, dynamic> response =
        await _client.get('/activities', query: <String, dynamic>{'scope': scope, 'limit': 50});
    return response.dataList.map(Activity.fromJson).toList(growable: false);
  }

  Future<void> cancel(String id) => _client.delete('/activities/$id');
}

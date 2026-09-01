import 'activity.dart';
import 'enums.dart';
import 'profile.dart';

T? _as<T>(Object? value) => value is T ? value : null;

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return <T>[];
  return value.whereType<Map<String, dynamic>>().map(parse).toList(growable: false);
}

enum Greeting {
  morning('Good morning'),
  afternoon('Good afternoon'),
  evening('Good evening');

  const Greeting(this.label);
  final String label;

  static Greeting fromWire(String? value) => switch (value) {
        'MORNING' => Greeting.morning,
        'AFTERNOON' => Greeting.afternoon,
        _ => Greeting.evening,
      };
}

class CategoryCount {
  const CategoryCount({
    required this.category,
    required this.openActivities,
    required this.people,
  });

  final ActivityCategory category;
  final int openActivities;
  final int people;

  factory CategoryCount.fromJson(Map<String, dynamic> json) => CategoryCount(
        category: ActivityCategory.fromWire(_as<String>(json['category'])),
        openActivities: _as<int>(json['openActivities']) ?? 0,
        people: _as<int>(json['people']) ?? 0,
      );
}

/// One request, one screen. The home feed is assembled server-side so the
/// first paint after launch is a single round-trip.
class HomeFeed {
  const HomeFeed({
    required this.greeting,
    required this.city,
    required this.categories,
    required this.peopleNearby,
    required this.activitiesNearby,
    required this.tonight,
    required this.pendingInvitations,
    required this.unreadMessages,
  });

  final Greeting greeting;
  final String city;
  final List<CategoryCount> categories;
  final List<Profile> peopleNearby;
  final List<Activity> activitiesNearby;
  final List<Activity> tonight;
  final int pendingInvitations;
  final int unreadMessages;

  /// Every category, ordered so the ones with something happening come first.
  List<CategoryCount> get orderedCategories {
    final Map<ActivityCategory, CategoryCount> byCategory = <ActivityCategory, CategoryCount>{
      for (final CategoryCount count in categories) count.category: count,
    };
    final List<CategoryCount> all = ActivityCategory.values
        .map((ActivityCategory category) =>
            byCategory[category] ?? CategoryCount(category: category, openActivities: 0, people: 0))
        .toList();
    all.sort((CategoryCount a, CategoryCount b) {
      final int byActivity = b.openActivities.compareTo(a.openActivities);
      if (byActivity != 0) return byActivity;
      return b.people.compareTo(a.people);
    });
    return all;
  }

  factory HomeFeed.fromJson(Map<String, dynamic> json) => HomeFeed(
        greeting: Greeting.fromWire(_as<String>(json['greeting'])),
        city: _as<String>(json['city']) ?? '',
        categories: _list(json['categories'], CategoryCount.fromJson),
        peopleNearby: _list(json['peopleNearby'], Profile.fromJson),
        activitiesNearby: _list(json['activitiesNearby'], Activity.fromJson),
        tonight: _list(json['tonight'], Activity.fromJson),
        pendingInvitations: _as<int>(json['pendingInvitations']) ?? 0,
        unreadMessages: _as<int>(json['unreadMessages']) ?? 0,
      );
}

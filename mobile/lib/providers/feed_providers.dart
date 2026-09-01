import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/realtime/socket_client.dart';
import '../models/activity.dart';
import '../models/conversation.dart';
import '../models/home_feed.dart';
import '../models/invitation.dart';
import '../models/profile.dart';
import '../services/discovery_service.dart';
import '../services/notification_service.dart';
import 'core_providers.dart';

// ------------------------------------------------------------------- home

/// The home screen's single source. Kept alive so returning to the tab is
/// instant; `ref.invalidate` powers pull-to-refresh.
final FutureProvider<HomeFeed> homeFeedProvider = FutureProvider<HomeFeed>((Ref ref) {
  // Re-fetch when an invitation lands, so the badge and the feed stay honest.
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
      (_, AsyncValue<RealtimeEvent> next) {
    final String? type = next.valueOrNull?.type;
    if (type == 'invitation:new' || type == 'invitation:updated') {
      ref.invalidateSelf();
    }
  });
  return ref.watch(discoveryServiceProvider).fetchHomeFeed();
});

// --------------------------------------------------------------- discover

enum DiscoverMode { people, activities }

final StateProvider<DiscoverMode> discoverModeProvider =
    StateProvider<DiscoverMode>((Ref ref) => DiscoverMode.people);

final StateProvider<DiscoveryFilters> discoveryFiltersProvider =
    StateProvider<DiscoveryFilters>((Ref ref) => DiscoveryFilters.none);

final FutureProvider<List<Profile>> discoverPeopleProvider =
    FutureProvider<List<Profile>>((Ref ref) async {
  final DiscoveryFilters filters = ref.watch(discoveryFiltersProvider);
  final PagedResult<Profile> page =
      await ref.watch(discoveryServiceProvider).discoverPeople(filters, limit: 30);
  return page.items;
});

final FutureProvider<List<Activity>> discoverActivitiesProvider =
    FutureProvider<List<Activity>>((Ref ref) async {
  final DiscoveryFilters filters = ref.watch(discoveryFiltersProvider);
  final PagedResult<Activity> page =
      await ref.watch(discoveryServiceProvider).discoverActivities(filters, limit: 30);
  return page.items;
});

/// The interest catalog, fetched once and reused by filters and profile setup.
final FutureProvider<List<Interest>> interestCatalogProvider =
    FutureProvider<List<Interest>>((Ref ref) => ref.watch(profileServiceProvider).fetchInterests());

// ------------------------------------------------------------- invitations

final FutureProvider<List<Invitation>> receivedInvitationsProvider =
    FutureProvider<List<Invitation>>((Ref ref) {
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
      (_, AsyncValue<RealtimeEvent> next) {
    if (next.valueOrNull?.type == 'invitation:new') ref.invalidateSelf();
  });
  return ref.watch(invitationServiceProvider).list(InvitationDirection.received);
});

final FutureProvider<List<Invitation>> sentInvitationsProvider =
    FutureProvider<List<Invitation>>((Ref ref) {
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
      (_, AsyncValue<RealtimeEvent> next) {
    if (next.valueOrNull?.type == 'invitation:updated') ref.invalidateSelf();
  });
  return ref.watch(invitationServiceProvider).list(InvitationDirection.sent);
});

final FutureProvider<InvitationCounts> invitationCountsProvider =
    FutureProvider<InvitationCounts>((Ref ref) {
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
      (_, AsyncValue<RealtimeEvent> next) {
    final String? type = next.valueOrNull?.type;
    if (type == 'invitation:new' || type == 'invitation:updated') ref.invalidateSelf();
  });
  return ref.watch(invitationServiceProvider).counts();
});

// ------------------------------------------------------------ conversations

/// The inbox. Rebuilt on every inbound message so unread counts and ordering
/// change without the user pulling to refresh.
final FutureProvider<List<Conversation>> conversationsProvider =
    FutureProvider<List<Conversation>>((Ref ref) {
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
      (_, AsyncValue<RealtimeEvent> next) {
    final String? type = next.valueOrNull?.type;
    if (type == 'message:new' || type == 'message:read') ref.invalidateSelf();
  });
  return ref.watch(conversationServiceProvider).list();
});

/// Total unread across every thread — the badge on the Messages tab.
final Provider<int> unreadMessagesProvider = Provider<int>((Ref ref) {
  return ref.watch(conversationsProvider).maybeWhen(
        data: (List<Conversation> conversations) => conversations.fold<int>(
          0,
          (int total, Conversation conversation) => total + conversation.unreadCount,
        ),
        orElse: () => 0,
      );
});

// ----------------------------------------------------------- notifications

final FutureProvider<NotificationPage> notificationsProvider =
    FutureProvider<NotificationPage>((Ref ref) {
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
      (_, AsyncValue<RealtimeEvent> next) {
    if (next.valueOrNull?.type == 'notification') ref.invalidateSelf();
  });
  return ref.watch(notificationServiceProvider).list();
});

final Provider<int> unreadNotificationsProvider = Provider<int>((Ref ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (NotificationPage page) => page.unreadCount,
        orElse: () => 0,
      );
});

// ------------------------------------------------------------- my activity

final FutureProvider<List<Activity>> myActivitiesProvider =
    FutureProvider<List<Activity>>((Ref ref) => ref.watch(activityServiceProvider).list());

/// A single person's public profile, cached per id for the duration of a visit.
final FutureProviderFamily<Profile, String> profileByIdProvider =
    FutureProvider.family<Profile, String>(
  (Ref ref, String userId) => ref.watch(profileServiceProvider).fetchProfile(userId),
);

final FutureProviderFamily<Activity, String> activityByIdProvider =
    FutureProvider.family<Activity, String>(
  (Ref ref, String activityId) => ref.watch(activityServiceProvider).fetch(activityId),
);

/// Refreshes everything the shell shows after a mutation somewhere else —
/// accepting an invitation touches the home feed, the invites list and the inbox.
void invalidateSocialGraphFrom(WidgetRef ref) {
  ref.invalidate(homeFeedProvider);
  ref.invalidate(receivedInvitationsProvider);
  ref.invalidate(sentInvitationsProvider);
  ref.invalidate(invitationCountsProvider);
  ref.invalidate(conversationsProvider);
}

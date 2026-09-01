import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/realtime/socket_client.dart';
import '../core/storage/token_storage.dart';
import '../services/activity_service.dart';
import '../services/auth_service.dart';
import '../services/conversation_service.dart';
import '../services/discovery_service.dart';
import '../services/invitation_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/safety_service.dart';

/// Overridden in `main()` once the plugin has warmed up.
final Provider<SharedPreferences> sharedPreferencesProvider = Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final Provider<TokenStorage> tokenStorageProvider =
    Provider<TokenStorage>((Ref ref) => TokenStorage());

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  return ApiClient(tokenStorage: ref.watch(tokenStorageProvider));
});

final Provider<SocketClient> socketClientProvider = Provider<SocketClient>((Ref ref) {
  final SocketClient client = SocketClient();
  ref.onDispose(client.dispose);
  return client;
});

/// The single realtime stream every feature listens to. Broadcast, so a screen
/// subscribing does not steal frames from another.
final StreamProvider<RealtimeEvent> realtimeEventsProvider = StreamProvider<RealtimeEvent>(
  (Ref ref) => ref.watch(socketClientProvider).events,
);

final Provider<AuthService> authServiceProvider =
    Provider<AuthService>((Ref ref) => AuthService(ref.watch(apiClientProvider)));

final Provider<ProfileService> profileServiceProvider =
    Provider<ProfileService>((Ref ref) => ProfileService(ref.watch(apiClientProvider)));

final Provider<DiscoveryService> discoveryServiceProvider =
    Provider<DiscoveryService>((Ref ref) => DiscoveryService(ref.watch(apiClientProvider)));

final Provider<ActivityService> activityServiceProvider =
    Provider<ActivityService>((Ref ref) => ActivityService(ref.watch(apiClientProvider)));

final Provider<InvitationService> invitationServiceProvider =
    Provider<InvitationService>((Ref ref) => InvitationService(ref.watch(apiClientProvider)));

final Provider<ConversationService> conversationServiceProvider =
    Provider<ConversationService>((Ref ref) => ConversationService(ref.watch(apiClientProvider)));

final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((Ref ref) => NotificationService(ref.watch(apiClientProvider)));

final Provider<SafetyService> safetyServiceProvider =
    Provider<SafetyService>((Ref ref) => SafetyService(ref.watch(apiClientProvider)));

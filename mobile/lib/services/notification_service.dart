import '../core/network/api_client.dart';
import '../models/app_notification.dart';

class NotificationPage {
  const NotificationPage({required this.items, required this.unreadCount});

  final List<AppNotification> items;
  final int unreadCount;
}

class NotificationService {
  const NotificationService(this._client);

  final ApiClient _client;

  Future<NotificationPage> list() async {
    final Map<String, dynamic> response =
        await _client.get('/notifications', query: <String, dynamic>{'limit': 40});
    return NotificationPage(
      items: response.dataList.map(AppNotification.fromJson).toList(growable: false),
      unreadCount: response.meta['unreadCount'] as int? ?? 0,
    );
  }

  Future<void> markRead(String id) => _client.post('/notifications/$id/read');

  Future<void> markAllRead() => _client.post('/notifications/read-all');
}

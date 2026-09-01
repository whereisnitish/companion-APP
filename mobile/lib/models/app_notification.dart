import 'enums.dart';

T? _as<T>(Object? value) => value is T ? value : null;
DateTime? _asDate(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: _as<String>(json['id']) ?? '',
        type: AppNotificationType.fromWire(_as<String>(json['type'])),
        title: _as<String>(json['title']) ?? '',
        body: _as<String>(json['body']) ?? '',
        data: _as<Map<String, dynamic>>(json['data']) ?? const <String, dynamic>{},
        readAt: _asDate(json['readAt']),
        createdAt: _asDate(json['createdAt']) ?? DateTime.now(),
      );
}

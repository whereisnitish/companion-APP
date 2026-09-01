import 'activity.dart';
import 'profile.dart';

T? _as<T>(Object? value) => value is T ? value : null;
DateTime? _asDate(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

class Conversation {
  const Conversation({
    required this.id,
    required this.lastMessageAt,
    required this.lastMessagePreview,
    required this.unreadCount,
    required this.participant,
    required this.activity,
  });

  final String id;
  final DateTime lastMessageAt;
  final String lastMessagePreview;
  final int unreadCount;
  final Profile participant;
  final ActivityContext? activity;

  Conversation copyWith({
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    int? unreadCount,
    Profile? participant,
  }) =>
      Conversation(
        id: id,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
        unreadCount: unreadCount ?? this.unreadCount,
        participant: participant ?? this.participant,
        activity: activity,
      );

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: _as<String>(json['id']) ?? '',
        lastMessageAt: _asDate(json['lastMessageAt']) ?? DateTime.now(),
        lastMessagePreview: _as<String>(json['lastMessagePreview']) ?? '',
        unreadCount: _as<int>(json['unreadCount']) ?? 0,
        participant: Profile.fromJson(
          _as<Map<String, dynamic>>(json['participant']) ?? const <String, dynamic>{},
        ),
        activity: json['activity'] == null
            ? null
            : ActivityContext.fromJson(_as<Map<String, dynamic>>(json['activity'])!),
      );
}

enum MessageKind { text, system }

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.kind,
    required this.createdAt,
    required this.readAt,
    required this.isMine,
    this.isPending = false,
    this.hasFailed = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final MessageKind kind;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isMine;

  /// Set on the optimistic copy shown the instant you hit send.
  final bool isPending;
  final bool hasFailed;

  bool get isSystem => kind == MessageKind.system;
  bool get isRead => readAt != null;

  Message copyWith({String? id, DateTime? readAt, bool? isPending, bool? hasFailed}) => Message(
        id: id ?? this.id,
        conversationId: conversationId,
        senderId: senderId,
        body: body,
        kind: kind,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        isMine: isMine,
        isPending: isPending ?? this.isPending,
        hasFailed: hasFailed ?? this.hasFailed,
      );

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: _as<String>(json['id']) ?? '',
        conversationId: _as<String>(json['conversationId']) ?? '',
        senderId: _as<String>(json['senderId']) ?? '',
        body: _as<String>(json['body']) ?? '',
        kind: _as<String>(json['type']) == 'SYSTEM' ? MessageKind.system : MessageKind.text,
        createdAt: _asDate(json['createdAt']) ?? DateTime.now(),
        readAt: _asDate(json['readAt']),
        isMine: _as<bool>(json['isMine']) ?? false,
      );
}

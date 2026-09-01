import 'activity.dart';
import 'enums.dart';
import 'profile.dart';

T? _as<T>(Object? value) => value is T ? value : null;
DateTime? _asDate(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

enum InvitationDirection { received, sent }

class Invitation {
  const Invitation({
    required this.id,
    required this.direction,
    required this.status,
    required this.message,
    required this.category,
    required this.proposedAt,
    required this.locationName,
    required this.createdAt,
    required this.respondedAt,
    required this.counterpart,
    required this.activity,
    required this.conversationId,
  });

  final String id;
  final InvitationDirection direction;
  final InvitationStatus status;
  final String message;
  final ActivityCategory? category;
  final DateTime? proposedAt;
  final String? locationName;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final Profile counterpart;
  final Activity? activity;
  final String? conversationId;

  bool get isReceived => direction == InvitationDirection.received;
  ActivityCategory get resolvedCategory => category ?? activity?.category ?? ActivityCategory.other;
  String get headline => activity?.title ?? 'Up for something ${resolvedCategory.phrase}?';

  factory Invitation.fromJson(Map<String, dynamic> json) => Invitation(
        id: _as<String>(json['id']) ?? '',
        direction: _as<String>(json['direction']) == 'sent'
            ? InvitationDirection.sent
            : InvitationDirection.received,
        status: InvitationStatus.fromWire(_as<String>(json['status'])),
        message: _as<String>(json['message']) ?? '',
        category: json['category'] == null
            ? null
            : ActivityCategory.fromWire(_as<String>(json['category'])),
        proposedAt: _asDate(json['proposedAt']),
        locationName: _as<String>(json['locationName']),
        createdAt: _asDate(json['createdAt']) ?? DateTime.now(),
        respondedAt: _asDate(json['respondedAt']),
        counterpart: Profile.fromJson(
          _as<Map<String, dynamic>>(json['counterpart']) ?? const <String, dynamic>{},
        ),
        activity: json['activity'] == null
            ? null
            : Activity.fromJson(_as<Map<String, dynamic>>(json['activity'])!),
        conversationId: _as<String>(json['conversationId']),
      );
}

class InvitationCounts {
  const InvitationCounts({
    required this.pendingReceived,
    required this.pendingSent,
    required this.accepted,
  });

  final int pendingReceived;
  final int pendingSent;
  final int accepted;

  static const InvitationCounts empty =
      InvitationCounts(pendingReceived: 0, pendingSent: 0, accepted: 0);

  factory InvitationCounts.fromJson(Map<String, dynamic> json) => InvitationCounts(
        pendingReceived: _as<int>(json['pendingReceived']) ?? 0,
        pendingSent: _as<int>(json['pendingSent']) ?? 0,
        accepted: _as<int>(json['accepted']) ?? 0,
      );
}

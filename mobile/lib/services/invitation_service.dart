import '../core/network/api_client.dart';
import '../models/enums.dart';
import '../models/invitation.dart';

class InvitationService {
  const InvitationService(this._client);

  final ApiClient _client;

  Future<Invitation> send({
    required String recipientId,
    String? activityId,
    ActivityCategory? category,
    DateTime? proposedAt,
    String? locationName,
    String message = '',
  }) async {
    final Map<String, dynamic> response = await _client.post(
      '/invitations',
      body: <String, dynamic>{
        'recipientId': recipientId,
        if (activityId != null) 'activityId': activityId,
        if (category != null) 'category': category.wire,
        if (proposedAt != null) 'proposedAt': proposedAt.toUtc().toIso8601String(),
        if (locationName != null && locationName.isNotEmpty) 'locationName': locationName,
        'message': message,
      },
    );
    return Invitation.fromJson(response.dataObject);
  }

  Future<List<Invitation>> list(InvitationDirection direction, {InvitationStatus? status}) async {
    final String path =
        direction == InvitationDirection.received ? '/invitations/received' : '/invitations/sent';
    final Map<String, dynamic> response = await _client.get(
      path,
      query: <String, dynamic>{'limit': 50, if (status != null) 'status': status.wire},
    );
    return response.dataList.map(Invitation.fromJson).toList(growable: false);
  }

  Future<InvitationCounts> counts() async {
    final Map<String, dynamic> response = await _client.get('/invitations/counts');
    return InvitationCounts.fromJson(response.dataObject);
  }

  Future<Invitation> accept(String id) async {
    final Map<String, dynamic> response = await _client.post('/invitations/$id/accept');
    return Invitation.fromJson(response.dataObject);
  }

  Future<Invitation> decline(String id) async {
    final Map<String, dynamic> response = await _client.post('/invitations/$id/decline');
    return Invitation.fromJson(response.dataObject);
  }

  Future<Invitation> cancel(String id) async {
    final Map<String, dynamic> response = await _client.post('/invitations/$id/cancel');
    return Invitation.fromJson(response.dataObject);
  }
}

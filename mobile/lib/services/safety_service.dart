import '../core/network/api_client.dart';

/// Why someone was reported. The wire values match the backend enum exactly.
enum ReportReason {
  inappropriateMessages('INAPPROPRIATE_MESSAGES', 'Inappropriate messages'),
  fakeProfile('FAKE_PROFILE', 'Fake profile or photos'),
  harassment('HARASSMENT', 'Harassment or hate'),
  inappropriatePhotos('INAPPROPRIATE_PHOTOS', 'Inappropriate photos'),
  scamOrSpam('SCAM_OR_SPAM', 'Scam or spam'),
  underage('UNDERAGE', 'They may be under 18'),
  safetyConcern('SAFETY_CONCERN', 'I felt unsafe'),
  other('OTHER', 'Something else');

  const ReportReason(this.wire, this.label);
  final String wire;
  final String label;
}

class BlockedUser {
  const BlockedUser({required this.id, required this.displayName, required this.avatarUrl});

  final String id;
  final String displayName;
  final String? avatarUrl;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Someone',
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class SafetyService {
  const SafetyService(this._client);

  final ApiClient _client;

  Future<void> block(String userId, {String? reason}) => _client.post(
        '/safety/users/$userId/block',
        body: <String, dynamic>{if (reason != null) 'reason': reason},
      );

  Future<void> unblock(String userId) => _client.delete('/safety/users/$userId/block');

  Future<String> report(String userId, ReportReason reason, String details) async {
    final Map<String, dynamic> response = await _client.post(
      '/safety/users/$userId/report',
      body: <String, dynamic>{'reason': reason.wire, 'details': details},
    );
    return response.dataObject['message'] as String? ??
        'Thanks for letting us know. Our team will review this.';
  }

  Future<List<BlockedUser>> listBlocked() async {
    final Map<String, dynamic> response = await _client.get('/safety/blocks');
    final Object? items = response.dataObject['items'];
    if (items is! List) return const <BlockedUser>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(BlockedUser.fromJson)
        .toList(growable: false);
  }
}

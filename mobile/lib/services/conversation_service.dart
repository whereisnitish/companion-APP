import '../core/network/api_client.dart';
import '../models/conversation.dart';

class MessagePage {
  const MessagePage({required this.messages, required this.nextCursor});

  final List<Message> messages;
  final String? nextCursor;
}

class ConversationService {
  const ConversationService(this._client);

  final ApiClient _client;

  Future<List<Conversation>> list() async {
    final Map<String, dynamic> response = await _client.get('/conversations');
    return response.dataList.map(Conversation.fromJson).toList(growable: false);
  }

  Future<Conversation> fetch(String id) async {
    final Map<String, dynamic> response = await _client.get('/conversations/$id');
    return Conversation.fromJson(response.dataObject);
  }

  /// Returns messages newest-first; the chat view renders a reversed list so
  /// paging older messages never disturbs the scroll position.
  Future<MessagePage> messages(String conversationId, {String? cursor, int limit = 30}) async {
    final Map<String, dynamic> response = await _client.get(
      '/conversations/$conversationId/messages',
      query: <String, dynamic>{'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    return MessagePage(
      messages: response.dataList.map(Message.fromJson).toList(growable: false),
      nextCursor: response.meta['nextCursor'] as String?,
    );
  }

  Future<Message> send(String conversationId, String body) async {
    final Map<String, dynamic> response = await _client.post(
      '/conversations/$conversationId/messages',
      body: <String, dynamic>{'body': body},
    );
    return Message.fromJson(response.dataObject);
  }

  Future<void> markRead(String conversationId) =>
      _client.post('/conversations/$conversationId/read');
}

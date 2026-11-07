import 'dart:async';

import 'package:companion/core/network/api_client.dart';
import 'package:companion/core/storage/token_storage.dart';
import 'package:companion/models/conversation.dart';
import 'package:companion/providers/chat_provider.dart';
import 'package:companion/providers/core_providers.dart';
import 'package:companion/providers/feed_providers.dart';
import 'package:companion/services/conversation_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behaves like the server: the inbox reports unread until `markRead` lands.
class _FakeConversations extends ConversationService {
  _FakeConversations() : super(ApiClient(tokenStorage: TokenStorage()));

  bool isRead = false;
  int inboxFetches = 0;
  Completer<void>? holdMarkRead;

  @override
  Future<List<Conversation>> list() async {
    inboxFetches += 1;
    return <Conversation>[
      Conversation.fromJson(<String, dynamic>{
        'id': 'c1',
        'unreadCount': isRead ? 0 : 1,
        'lastMessagePreview': 'Yo',
        'lastMessageAt': '2026-11-07T07:53:20.000Z',
        'participant': <String, dynamic>{'id': 'u1', 'displayName': 'Sara'},
      }),
    ];
  }

  @override
  Future<MessagePage> messages(String conversationId, {String? cursor, int limit = 30}) async =>
      const MessagePage(messages: <Message>[], nextCursor: null);

  @override
  Future<void> markRead(String conversationId) async {
    await holdMarkRead?.future;
    isRead = true;
  }
}

void main() {
  late _FakeConversations service;
  late ProviderContainer container;

  setUp(() {
    service = _FakeConversations();
    container = ProviderContainer(
      overrides: <Override>[conversationServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    // The shell watches this from every tab, so the badge is always live.
    container.listen<int>(unreadMessagesProvider, (_, __) {});
  });

  Future<int> settledUnread() async {
    await pumpEventQueue();
    return container.read(unreadMessagesProvider);
  }

  test('opening a chat clears its unread count in the inbox', () async {
    expect(await settledUnread(), 1);

    final ProviderSubscription<ChatState> chat =
        container.listen<ChatState>(chatControllerProvider('c1'), (_, __) {});
    addTearDown(chat.close);

    expect(await settledUnread(), 0);
  });

  test('the count still clears when the chat is closed before the server answers', () async {
    expect(await settledUnread(), 1);

    service.holdMarkRead = Completer<void>();
    final ProviderSubscription<ChatState> chat =
        container.listen<ChatState>(chatControllerProvider('c1'), (_, __) {});
    await pumpEventQueue();

    chat.close();
    await pumpEventQueue();

    service.holdMarkRead!.complete();
    expect(await settledUnread(), 0);
  });
}

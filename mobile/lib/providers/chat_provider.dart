import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/realtime/socket_client.dart';
import '../models/conversation.dart';
import '../services/conversation_service.dart';
import 'core_providers.dart';
import 'feed_providers.dart';

@immutable
class ChatState {
  const ChatState({
    this.messages = const <Message>[],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
    this.isPeerTyping = false,
  });

  /// Newest first — the view renders a reversed list.
  final List<Message> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;
  final bool isPeerTyping;

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
    bool? isPeerTyping,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
        isPeerTyping: isPeerTyping ?? this.isPeerTyping,
      );
}

/// Owns one conversation: history, paging, optimistic sends, typing and reads.
class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref, this.conversationId) : super(const ChatState()) {
    _subscription = _ref.read(socketClientProvider).events.listen(_onRealtimeEvent);
    unawaited(load());
  }

  final Ref _ref;
  final String conversationId;

  StreamSubscription<RealtimeEvent>? _subscription;
  Timer? _typingTimeout;
  Timer? _typingThrottle;
  String? _cursor;

  ConversationService get _service => _ref.read(conversationServiceProvider);
  SocketClient get _socket => _ref.read(socketClientProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final MessagePage page = await _service.messages(conversationId);
      if (!mounted) return;
      _cursor = page.nextCursor;
      state = state.copyWith(
        messages: page.messages,
        isLoading: false,
        hasMore: page.nextCursor != null,
      );
      unawaited(markRead());
    } catch (error) {
      if (mounted) state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || _cursor == null) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final MessagePage page = await _service.messages(conversationId, cursor: _cursor);
      if (!mounted) return;
      _cursor = page.nextCursor;
      state = state.copyWith(
        messages: <Message>[...state.messages, ...page.messages],
        isLoadingMore: false,
        hasMore: page.nextCursor != null,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Shows the bubble immediately, then reconciles with the server's copy.
  /// A failure marks the bubble rather than removing it, so nothing is lost.
  Future<void> send(String body) async {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final String temporaryId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final Message optimistic = Message(
      id: temporaryId,
      conversationId: conversationId,
      senderId: 'me',
      body: trimmed,
      kind: MessageKind.text,
      createdAt: DateTime.now(),
      readAt: null,
      isMine: true,
      isPending: true,
    );

    state = state.copyWith(messages: <Message>[optimistic, ...state.messages]);
    _stopTyping();

    try {
      final Message saved = await _service.send(conversationId, trimmed);
      if (!mounted) return;
      state = state.copyWith(
        messages: state.messages
            .map((Message message) => message.id == temporaryId ? saved : message)
            .toList(growable: false),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        messages: state.messages
            .map(
              (Message message) => message.id == temporaryId
                  ? message.copyWith(isPending: false, hasFailed: true)
                  : message,
            )
            .toList(growable: false),
      );
    }
  }

  Future<void> retry(Message failed) async {
    state = state.copyWith(
      messages: state.messages
          .where((Message message) => message.id != failed.id)
          .toList(growable: false),
    );
    await send(failed.body);
  }

  /// Tells the server, then reloads the inbox so its unread badge clears. Held
  /// alive throughout, because people often leave a chat before this finishes.
  Future<void> markRead() async {
    final KeepAliveLink keepAlive = _ref.keepAlive();
    try {
      await _service.markRead(conversationId);
      _ref.invalidate(conversationsProvider);
    } catch (_) {
      /* the badge will settle on the next fetch */
    } finally {
      keepAlive.close();
    }
  }

  /// Throttled to one frame per second — a keystroke should not be a packet.
  void onComposerChanged(String value) {
    if (value.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (_typingThrottle?.isActive ?? false) return;
    _socket.sendTyping(conversationId, isTyping: true);
    _typingThrottle = Timer(const Duration(seconds: 1), () {});
  }

  void _stopTyping() {
    _typingThrottle?.cancel();
    _typingThrottle = null;
    _socket.sendTyping(conversationId, isTyping: false);
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (event.conversationId != conversationId) return;

    switch (event.type) {
      case 'message:new':
        final Message incoming = Message.fromJson(event.payload);
        if (state.messages.any((Message message) => message.id == incoming.id)) return;
        state = state.copyWith(messages: <Message>[incoming, ...state.messages]);
        unawaited(markRead());

      case 'message:read':
        final DateTime now = DateTime.now();
        state = state.copyWith(
          messages: state.messages
              .map((Message message) => message.isMine && message.readAt == null
                  ? message.copyWith(readAt: now)
                  : message)
              .toList(growable: false),
        );

      case 'typing':
        final bool isTyping = event.payload['isTyping'] == true;
        state = state.copyWith(isPeerTyping: isTyping);
        _typingTimeout?.cancel();
        if (isTyping) {
          _typingTimeout = Timer(const Duration(seconds: 4), () {
            if (mounted) state = state.copyWith(isPeerTyping: false);
          });
        }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _typingTimeout?.cancel();
    _typingThrottle?.cancel();
    super.dispose();
  }
}

// Both are dropped when the chat closes, so reopening one always shows the latest
// messages for whoever is signed in, including any missed while the socket was down.
final AutoDisposeStateNotifierProviderFamily<ChatController, ChatState, String>
    chatControllerProvider =
    StateNotifierProvider.autoDispose.family<ChatController, ChatState, String>(
  (Ref ref, String conversationId) => ChatController(ref, conversationId),
);

final AutoDisposeFutureProviderFamily<Conversation, String> conversationByIdProvider =
    FutureProvider.autoDispose.family<Conversation, String>(
  (Ref ref, String conversationId) => ref.watch(conversationServiceProvider).fetch(conversationId),
);

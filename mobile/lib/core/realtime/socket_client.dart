import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';

/// A frame from the server. `type` drives everything downstream.
class RealtimeEvent {
  const RealtimeEvent({required this.type, this.conversationId, this.payload = const {}});

  final String type;
  final String? conversationId;
  final Map<String, dynamic> payload;

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) => RealtimeEvent(
        type: json['type'] as String? ?? 'unknown',
        conversationId: json['conversationId'] as String?,
        payload: json['payload'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      );
}

/// One socket per signed-in session, shared by chat, invites and notifications.
///
/// Reconnects with a capped backoff and never throws at its callers: realtime
/// is an enhancement, and everything it delivers is also reachable over REST.
class SocketClient {
  SocketClient();

  final StreamController<RealtimeEvent> _events = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _events.stream;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  String? _token;
  int _attempt = 0;
  bool _disposed = false;

  /// Called when the server refuses the token, so it can be refreshed.
  VoidCallback? onUnauthorized;

  /// The server's close code for a missing, invalid or expired token.
  static const int _closeUnauthorized = 4401;

  bool get isConnected => _channel != null;

  /// Reconnects use this token, so a dropped socket survives token expiry.
  void updateToken(String accessToken) {
    if (_token != null) _token = accessToken;
  }

  void connect(String accessToken) {
    if (_disposed) return;
    _token = accessToken;
    _attempt = 0;
    _open();
  }

  void _open() {
    final String? token = _token;
    if (token == null || _disposed) return;

    _teardownChannel();

    try {
      final WebSocketChannel channel =
          WebSocketChannel.connect(Uri.parse('${AppConfig.websocketUrl}?token=$token'));
      _channel = channel;

      _subscription = channel.stream.listen(
        (Object? frame) {
          _attempt = 0;
          if (frame is! String) return;
          try {
            final Object? decoded = jsonDecode(frame);
            if (decoded is Map<String, dynamic>) {
              _events.add(RealtimeEvent.fromJson(decoded));
            }
          } catch (_) {
            /* a malformed frame is not worth taking the socket down for */
          }
        },
        onError: (Object _) => _scheduleReconnect(),
        onDone: () {
          if (channel.closeCode == _closeUnauthorized) onUnauthorized?.call();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Realtime connect failed: $error');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _token == null) return;
    _teardownChannel();

    _attempt = (_attempt + 1).clamp(1, 6);
    final Duration delay = Duration(milliseconds: 500 * (1 << (_attempt - 1)));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _open);
  }

  void send(Map<String, dynamic> frame) {
    final WebSocketChannel? channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(frame));
    } catch (_) {
      /* dropped frames are acceptable for typing indicators */
    }
  }

  void sendTyping(String conversationId, {required bool isTyping}) => send(<String, dynamic>{
        'type': 'typing',
        'conversationId': conversationId,
        'isTyping': isTyping,
      });

  void _teardownChannel() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void disconnect() {
    _token = null;
    _reconnectTimer?.cancel();
    _teardownChannel();
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _events.close();
  }
}

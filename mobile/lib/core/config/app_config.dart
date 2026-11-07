import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Override the host when you run:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:4000
///
/// Without an override we guess sensibly: the Android emulator reaches the
/// host machine at 10.0.2.2, everything else at localhost.
abstract final class AppConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:4000';
    return 'http://localhost:4000';
  }

  static String get apiRoot => '$apiBaseUrl/api';

  static String get websocketUrl {
    final String base = apiBaseUrl.replaceFirst(RegExp('^http'), 'ws');
    return '$base/ws';
  }

  // Generous because a free host sleeps when idle and takes about a minute to wake.
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 90);

  static const String appName = 'Companion';
  static const String supportEmail = 'safety@companion.app';
}

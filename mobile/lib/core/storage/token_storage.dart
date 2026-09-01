import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Tokens live in the platform keychain / keystore, never in shared preferences.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  static const String _accessKey = 'companion.access_token';
  static const String _refreshKey = 'companion.refresh_token';

  final FlutterSecureStorage _storage;

  /// Cached in memory so the request interceptor never awaits the keychain.
  String? _cachedAccessToken;
  String? get cachedAccessToken => _cachedAccessToken;

  Future<AuthTokens?> read() async {
    final String? access = await _storage.read(key: _accessKey);
    final String? refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    _cachedAccessToken = access;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> save(AuthTokens tokens) async {
    _cachedAccessToken = tokens.accessToken;
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
